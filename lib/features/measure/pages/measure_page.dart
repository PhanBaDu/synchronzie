import 'package:auto_route/auto_route.dart';
import 'package:flutter/cupertino.dart';
import 'package:synchronzie/shared/colors/colors.dart';
import 'package:synchronzie/shared/permissions/camera_permission.dart';
import 'package:camera/camera.dart';
import 'package:synchronzie/features/measure/widgets/camera_overlay.dart';
import 'package:synchronzie/features/measure/widgets/progress_ring.dart';
import 'package:synchronzie/shared/services/advanced_finger_detection.dart';
import 'package:synchronzie/shared/services/heart_rate_analyzer.dart';
import 'dart:math' as math;

@RoutePage()
class MeasurePage extends StatefulWidget {
  const MeasurePage({super.key});

  @override
  State<MeasurePage> createState() => _MeasurePageState();
}

class _MeasurePageState extends State<MeasurePage>
    with SingleTickerProviderStateMixin {
  CameraController? _controller;
  bool _isToggling = false;
  late final AnimationController _progressController;
  int measurementDurationSeconds = 35; // dễ dàng thay đổi thời gian đo
  bool _fingerOn = false;
  bool _streaming = false;
  // Frame-based measurement buffers (30fps assumed)
  final List<double> _redValues = <double>[];
  final List<double> _greenValues = <double>[];
  int _measurementCount = 0;
  DateTime? _measureStartAt; // wall-clock mốc bắt đầu đếm frame
  bool _isCounting = false; // chỉ đếm khi ngón tay đặt lên
  bool _isMeasuring = false; // trạng thái đo thực sự
  bool _isCameraInitialized = false;
  bool _autoStartEnabled = true;
  // Adaptive measurement params (per spec)
  static const int _minFramesRequired = 600; // ~20s
  static const int _requiredMeasurements = 900; // ~30s
  static const int _maxFramesAllowed = 1200; // ~40s
  static const double _targetSignalQuality = 0.90;
  // Quality tracking
  static const int _minRequiredPeaks = 15;
  static const double _minSignalAmplitude = 3.0;
  static const double _maxNoiseThreshold = 0.4;
  int _detectedPeaks = 0;
  double _signalQuality = 0.0;
  bool _hasStableSignal = false;
  final List<double> _signalQualityHistory = <double>[];
  final List<double> _qualityTrend = <double>[];
  double _averageQuality = 0.0;
  int _consecutiveGoodQuality = 0;
  int _consecutivePoorQuality = 0;
  int? _liveBpm;
  int? _finalBpm;
  // Detector & Analyzer giống reference app
  final AdvancedFingerDetection _fingerDetection = AdvancedFingerDetection();
  final HeartRateAnalyzer _hrAnalyzer = HeartRateAnalyzer();

  @override
  void initState() {
    super.initState();
    _progressController =
        AnimationController(
            vsync: this,
            duration: Duration(seconds: measurementDurationSeconds),
          )
          ..addListener(() {
            if (mounted) setState(() {});
          })
          ..addStatusListener((status) async {
            if (status == AnimationStatus.completed) {
              await _stopCamera();
            }
          });
    Future.microtask(() async {
      await CameraPermission.ensure();
    });
  }

  Future<void> _startCamera() async {
    if (_isToggling) return;
    _isToggling = true;
    final ok = await CameraPermission.ensure();
    if (!ok) return;

    try {
      final cameras = await availableCameras();
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        back,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await controller.initialize();
      _isCameraInitialized = true;
      try {
        await controller.setFocusMode(FocusMode.auto);
      } catch (_) {}
      try {
        await controller.setExposureMode(ExposureMode.auto);
      } catch (_) {}
      try {
        await controller.setZoomLevel(1.0);
      } catch (_) {}
      await controller.setFlashMode(FlashMode.torch);
      // Đợi flash ổn định như app tham chiếu
      await Future.delayed(const Duration(milliseconds: 1500));
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _isMeasuring = true;
        _isCounting = false; // sẽ bật khi phát hiện ngón tay
      });
      _progressController..reset();
      // Bắt đầu xử lý luồng ảnh để kiểm tra màu (ngón tay đặt lên camera)
      try {
        await controller.startImageStream(_onCameraImage);
        _streaming = true;
      } catch (_) {
        _streaming = false;
      }
    } catch (_) {}
    _isToggling = false;
  }

  Future<void> _stopCamera() async {
    if (_isToggling) return;
    _isToggling = true;
    final controller = _controller;
    if (mounted) {
      setState(() {
        _controller = null;
      });
    } else {
      _controller = null;
    }
    try {
      _progressController.reverseDuration = null;
      _progressController.stop();
      _progressController.reset();
    } catch (_) {}
    if (controller != null) {
      try {
        if (controller.value.isInitialized) {
          await controller.setFlashMode(FlashMode.off);
        }
      } catch (_) {}
      try {
        // Đặt cờ trước để khung hình đến muộn bị bỏ qua
        _streaming = false;
        if (controller.value.isStreamingImages) {
          await controller.stopImageStream();
        }
      } catch (_) {}
      await controller.dispose();
    }
    _streaming = false;
    _fingerOn = false;
    _redValues.clear();
    _greenValues.clear();
    _measurementCount = 0;
    _measureStartAt = null;
    _signalQualityHistory.clear();
    _qualityTrend.clear();
    _averageQuality = 0.0;
    _consecutiveGoodQuality = 0;
    _consecutivePoorQuality = 0;
    _detectedPeaks = 0;
    _signalQuality = 0.0;
    _hasStableSignal = false;
    _liveBpm = null;
    _isToggling = false;
  }

  // Xử lý khung hình để ước lượng tỷ lệ đỏ trung bình (phát hiện ngón tay)
  void _onCameraImage(CameraImage image) {
    // Bỏ qua nếu đã stop hoặc đang toggle
    if (_controller == null || !_streaming) return;
    final ctrl = _controller!;
    if (!ctrl.value.isInitialized) return;

    // Trích xuất RGB và phát hiện ngón tay theo reference
    final rgbForDetect = _extractRGBFromImage(image);
    final bool detected = rgbForDetect != null
        ? _fingerDetection.detectFinger(rgbForDetect)
        : false;

    if (detected != _fingerOn) {
      final bool wasFingerOn = _fingerOn;
      _fingerOn = detected;
      if (mounted) {
        setState(() {});
      }
      if (!wasFingerOn && detected) {
        _onFingerPlaced();
      } else if (wasFingerOn && !detected) {
        _onFingerRemoved();
      }
    }

    // Điều khiển tiến trình đo theo FRAME COUNT
    if (_fingerOn && _isMeasuring) {
      // Thu RGB từ frame
      final rgb = rgbForDetect ?? _extractRGBFromImage(image);
      if (rgb != null) {
        if (_isCounting) {
          _measureStartAt ??= DateTime.now();
          _redValues.add(rgb['red']!);
          _greenValues.add(rgb['green']!);
          _measurementCount++;
        }
        // Cập nhật progress theo số frame mục tiêu 900
        final double p = (_measurementCount / _requiredMeasurements).clamp(
          0.0,
          1.0,
        );
        _progressController.value = p;
        // Phân tích chất lượng mỗi ~1s
        if (_isCounting && _measurementCount % 30 == 0) {
          _analyzeSignalQuality();
        }
        // Cập nhật live BPM mỗi 10 frame sau khi đủ ≥90
        if (_isCounting &&
            _measurementCount >= 90 &&
            _measurementCount % 10 == 0) {
          _updateLiveBPM(fps: 30.0);
        }
        // Kiểm tra dừng theo adaptive
        if (_isCounting && !_shouldContinueMeasurement()) {
          _finishMeasurement();
          return;
        }
      }
      if (_progressController.reverseDuration != null) {
        _progressController.reverseDuration = null;
      }
    } else {
      // Khi không hợp lệ: chạy lùi về 0 (mượt) theo tỉ lệ progress
      final double v = _progressController.value;
      if (v > 0.0) {
        int reverseMs;
        if (v <= 0.15) {
          reverseMs = (v * 3000).toInt();
          if (reverseMs < 350) reverseMs = 350;
          if (reverseMs > 1200) reverseMs = 1200;
        } else {
          reverseMs = (v * 800).toInt();
          if (reverseMs < 150) reverseMs = 150;
          if (reverseMs > 600) reverseMs = 600;
        }
        _progressController.reverseDuration = Duration(milliseconds: reverseMs);
        if (_progressController.status != AnimationStatus.reverse ||
            !_progressController.isAnimating) {
          _progressController.reverse();
        }
      } else {
        if (_progressController.isAnimating) {
          _progressController.stop();
        }
      }
    }
  }

  void _onFingerPlaced() {
    // reset đếm và chất lượng khi có ngón tay
    _isCounting = true;
    _redValues.clear();
    _greenValues.clear();
    _measurementCount = 0;
    _signalQualityHistory.clear();
    _qualityTrend.clear();
    _averageQuality = 0.0;
    _consecutiveGoodQuality = 0;
    _consecutivePoorQuality = 0;
    _detectedPeaks = 0;
    _signalQuality = 0.0;
    _hasStableSignal = false;
    _liveBpm = null;
  }

  void _onFingerRemoved() {
    // không dừng camera, chỉ reset dữ liệu đo và đợi đặt lại
    _isCounting = false;
    _redValues.clear();
    _greenValues.clear();
    _measurementCount = 0;
    _signalQualityHistory.clear();
    _qualityTrend.clear();
    _averageQuality = 0.0;
    _consecutiveGoodQuality = 0;
    _consecutivePoorQuality = 0;
    _detectedPeaks = 0;
    _signalQuality = 0.0;
    _hasStableSignal = false;
    _liveBpm = null;
  }

  @override
  void dispose() {
    final controller = _controller;
    _controller = null;
    if (controller != null) {
      controller.setFlashMode(FlashMode.off).catchError((_) {});
      controller.dispose();
    }
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.secondarySystemBackground,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: CupertinoColors.white,
        automaticBackgroundVisibility: false,
        middle: Text(
          'Measure',
          style: TextStyle(
            fontFamily: 'Inter',
            color: AppColors.primary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      child: SafeArea(
        child: CupertinoScrollbar(
          child: SingleChildScrollView(
            physics: BouncingScrollPhysics(),
            child: Column(
              children: [
                Container(height: 50, color: CupertinoColors.white),
                Stack(
                  children: [
                    Container(
                      width: double.infinity,
                      color: CupertinoColors.white,
                      child: Center(
                        child: CameraOverlay(
                          controller: _controller,
                          size: 380,
                          fallbackColor: AppColors.primary,
                          overlayAsset: 'assets/images/heart_rate.png',
                        ),
                      ),
                    ),
                    Positioned(
                      top: -25,
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Center(
                        child: Container(
                          width: 325,
                          height: 325,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.mutedForeground.withOpacity(0.1),
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: -25,
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Center(
                        child: CircularProgressRing(
                          size: 340,
                          progress: _progressController.value,
                          trackColor: AppColors.mutedForeground.withOpacity(
                            0.1,
                          ),
                          progressColor: AppColors.primary,
                          strokeWidth: 6,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Center(
                        child: CupertinoButton(
                          minSize: 0,
                          onPressed: () async {
                            if (_controller == null ||
                                !_controller!.value.isInitialized) {
                              await _startCamera();
                            } else {
                              await _stopCamera();
                            }
                          },
                          child: Text(
                            _controller == null ||
                                    !_controller!.value.isInitialized
                                ? "Start"
                                : "Stop",
                            style: TextStyle(
                              color: CupertinoColors.white,
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w900,
                              fontSize: 36,
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Removed bottom status text used only for testing
                  ],
                ),
                Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: CupertinoColors.white,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(36),
                      bottomRight: Radius.circular(36),
                    ),
                  ),
                ),
                // progress ring is overlaid above
                if (_finalBpm != null)
                  Padding(
                    padding: EdgeInsets.only(top: 16, bottom: 8),
                    child: Text(
                      'Heart rate: ${_finalBpm} BPM',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 22,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Map<String, double>? _extractRGBFromImage(CameraImage image) {
    try {
      final planeData = image.planes[0].bytes; // Y plane (approx)
      final int width = image.width;
      final int height = image.height;
      double totalRed = 0;
      double totalGreen = 0;
      double totalBlue = 0;
      int pixelCount = 0;
      final int centerX = width ~/ 2;
      final int centerY = height ~/ 2;
      final int sampleSize = math.min(width, height) ~/ 4;
      for (int y = centerY - sampleSize; y < centerY + sampleSize; y++) {
        for (int x = centerX - sampleSize; x < centerX + sampleSize; x++) {
          if (x >= 0 && x < width && y >= 0 && y < height) {
            final int index = y * width + x;
            if (index < planeData.length) {
              final double yy = planeData[index].toDouble();
              final double u = index + 1 < planeData.length
                  ? planeData[index + 1].toDouble()
                  : 0;
              final double v = index + 2 < planeData.length
                  ? planeData[index + 2].toDouble()
                  : 0;
              final double r = yy + 1.402 * (v - 128);
              final double g = yy - 0.344136 * (u - 128) - 0.714136 * (v - 128);
              final double b = yy + 1.772 * (u - 128);
              totalRed += r.clamp(0, 255);
              totalGreen += g.clamp(0, 255);
              totalBlue += b.clamp(0, 255);
              pixelCount++;
            }
          }
        }
      }
      if (pixelCount > 0) {
        return {
          'red': totalRed / pixelCount,
          'green': totalGreen / pixelCount,
          'blue': totalBlue / pixelCount,
        };
      }
    } catch (_) {}
    return null;
  }

  void _analyzeSignalQuality() {
    if (_redValues.length < 30) return;
    final double amp = _calculateSignalAmplitude();
    final double noise = _calculateNoiseLevel();
    final List<int> peaks = _detectPeaks();
    _signalQuality = _calculateOverallQuality(amp, noise, peaks.length);
    _hasStableSignal = _signalQuality > 0.7 && noise < _maxNoiseThreshold;
    _detectedPeaks = peaks.length;
    _signalQualityHistory.add(_signalQuality);
    if (_signalQualityHistory.length > 30) {
      _signalQualityHistory.removeAt(0);
    }
  }

  double _calculateSignalAmplitude() {
    if (_redValues.isEmpty) return 0.0;
    double minVal = _redValues.first;
    double maxVal = _redValues.first;
    for (final v in _redValues) {
      if (v < minVal) minVal = v;
      if (v > maxVal) maxVal = v;
    }
    return maxVal - minVal;
  }

  double _calculateNoiseLevel() {
    if (_redValues.length < 20) return 1.0;
    double mean = 0.0;
    for (final v in _redValues) mean += v;
    mean /= _redValues.length;
    double variance = 0.0;
    for (final v in _redValues) {
      final d = v - mean;
      variance += d * d;
    }
    variance /= _redValues.length;
    return (math.sqrt(variance) / (mean + 1e-6)).clamp(0.0, 5.0);
  }

  List<int> _detectPeaks() {
    if (_redValues.length < 10) return <int>[];
    final List<int> peaks = <int>[];
    const int window = 5;
    for (int i = window; i < _redValues.length - window; i++) {
      bool isPeak = true;
      final double current = _redValues[i];
      for (int j = i - window; j <= i + window; j++) {
        if (j != i && _redValues[j] >= current) {
          isPeak = false;
          break;
        }
      }
      if (isPeak) peaks.add(i);
    }
    return peaks;
  }

  double _calculateOverallQuality(double amplitude, double noise, int peakCnt) {
    final double ampScore = (amplitude / _minSignalAmplitude).clamp(0.0, 1.0);
    final double noiseScore = (1.0 - (noise / _maxNoiseThreshold)).clamp(
      0.0,
      1.0,
    );
    final double peakScore = (peakCnt / _minRequiredPeaks).clamp(0.0, 1.0);
    return 0.4 * ampScore + 0.3 * noiseScore + 0.3 * peakScore;
  }

  void _updateQualityTrend() {
    _qualityTrend.add(_signalQuality);
    if (_qualityTrend.length > 600) _qualityTrend.removeAt(0);
    if (_qualityTrend.isNotEmpty) {
      _averageQuality =
          _qualityTrend.reduce((a, b) => a + b) / _qualityTrend.length;
    }
    if (_signalQuality >= _targetSignalQuality) {
      _consecutiveGoodQuality++;
      _consecutivePoorQuality = 0;
    } else {
      _consecutivePoorQuality++;
      _consecutiveGoodQuality = 0;
    }
  }

  bool _shouldContinueMeasurement() {
    // Chặn theo thời gian thực để không vượt quá 40s nếu FPS thấp
    if (_measureStartAt != null) {
      final elapsedSec = DateTime.now().difference(_measureStartAt!).inSeconds;
      if (elapsedSec >= 40) return false;
    }
    if (_measurementCount < _minFramesRequired) return true;
    if (_measurementCount >= _maxFramesAllowed) return false;
    _updateQualityTrend();
    if (_consecutiveGoodQuality >= 180 &&
        _averageQuality >= _targetSignalQuality) {
      return false;
    }
    if (_measurementCount >= _minFramesRequired &&
        _consecutivePoorQuality >= 300) {
      return _measurementCount < _maxFramesAllowed;
    }
    if (_measurementCount < _requiredMeasurements) return true;
    return false;
  }

  void _updateLiveBPM({required double fps}) {
    final int windowSize = math.min(300, _redValues.length);
    final int startIdx = math.max(0, _redValues.length - windowSize);
    final List<double> redWin = _redValues.sublist(startIdx);
    final List<double> greenWin = _greenValues.sublist(startIdx);
    final res = _hrAnalyzer.analyze(redWin, greenWin, fps: fps);
    if (res.bpm > 0 && res.confidence > 0.3) {
      _liveBpm = res.bpm;
      if (mounted && _measurementCount % 15 == 0) setState(() {});
    }
  }

  // Returns (bpm, confidence)
  _SimpleTuple _analyzeWindowBpm(
    List<double> red,
    List<double> green,
    double fps,
  ) {
    final r = _hrAnalyzer.analyze(red, green, fps: fps);
    return _SimpleTuple(r.bpm, r.confidence);
  }

  void _finishMeasurementAndShow() async {
    // giữ lại cho tương thích cũ; gọi _finishMeasurement
    await _finishMeasurement();
  }

  Future<void> _finishMeasurement() async {
    // dừng đếm ngay
    _isMeasuring = false;
    // đảm bảo tắt stream và đèn sau chút
    await Future.delayed(const Duration(milliseconds: 200));
    // chất lượng bắt buộc trước khi tính BPM cuối
    if (_signalQuality < 0.5 || _detectedPeaks < _minRequiredPeaks) {
      _showInsufficientDataDialog();
      await _stopCamera();
      return;
    }
    // Compute final BPM via multi-window median
    final List<int> results = <int>[];
    for (final int windowSize in <int>[300, 450, 600, 750]) {
      if (_redValues.length >= windowSize) {
        final int start = _redValues.length - windowSize;
        final List<double> redWin = _redValues.sublist(start);
        final List<double> greenWin = _greenValues.sublist(start);
        final r = _analyzeWindowBpm(redWin, greenWin, 30.0);
        if (r.item1 > 0 && r.item2 > 0.2) results.add(r.item1);
      }
    }
    if (results.isEmpty) {
      // Fallback: FFT over entire collected data similar to measuring.dart
      if (_redValues.isNotEmpty) {
        final List<double> fft = _performFFT(_redValues);
        final double domFreq = _findDominantFrequency(fft, 30.0);
        int bpm = (domFreq * 60).round();
        bpm = bpm.clamp(40, 200);
        _finalBpm = bpm;
      } else {
        _finalBpm = 72;
      }
    } else {
      results.sort();
      int bpm = results[results.length ~/ 2];
      if (bpm < 40 || bpm > 200) {
        final valid = results.where((b) => b >= 40 && b <= 200).toList();
        bpm = valid.isEmpty
            ? 72
            : (valid.reduce((a, b) => a + b) / valid.length).round();
      }
      _finalBpm = bpm;
    }
    if (mounted) setState(() {});
    // Dừng camera sau khi hiển thị kết quả để giữ kết quả trên UI
    await _stopCamera();
  }

  // FFT fallback helpers similar to the reference implementation
  List<double> _performFFT(List<double> data) {
    final int n = data.length;
    final List<double> fft = List<double>.filled(n, 0.0);
    for (int k = 0; k < n; k++) {
      double real = 0.0;
      double imag = 0.0;
      for (int j = 0; j < n; j++) {
        final double angle = -2 * math.pi * k * j / n;
        real += data[j] * math.cos(angle);
        imag += data[j] * math.sin(angle);
      }
      fft[k] = math.sqrt(real * real + imag * imag);
    }
    return fft;
  }

  double _findDominantFrequency(List<double> fft, double fps) {
    double maxMagnitude = 0.0;
    int peakIndex = 1;
    // Focus on heart rate frequency range (0.67–3.33 Hz)
    final int minIndex = (0.67 * fft.length / fps).round();
    final int maxIndex = (3.33 * fft.length / fps).round();
    for (int i = minIndex; i < math.min(maxIndex, fft.length ~/ 2); i++) {
      if (fft[i] > maxMagnitude) {
        maxMagnitude = fft[i];
        peakIndex = i;
      }
    }
    final double frequency = peakIndex * fps / fft.length;
    if (frequency < 0.67 || frequency > 3.33) return 1.2; // default ~72 BPM
    return frequency;
  }

  void _showInsufficientDataDialog() {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Insufficient Quality Data'),
        content: const Text(
          'Not enough high-quality data was collected. Please try again with a steady finger fully covering the camera and stable lighting.',
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Try Again'),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}

class _SimpleTuple {
  final int item1; // bpm
  final double item2; // confidence
  _SimpleTuple(this.item1, this.item2);
}
