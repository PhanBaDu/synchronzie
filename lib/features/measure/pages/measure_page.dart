import 'package:auto_route/auto_route.dart';
import 'package:flutter/cupertino.dart';
import 'package:synchronzie/shared/colors/colors.dart';
import 'package:synchronzie/shared/permissions/camera_permission.dart';
import 'package:camera/camera.dart';
import 'package:synchronzie/features/measure/widgets/camera_overlay.dart';
import 'package:synchronzie/features/measure/widgets/progress_ring.dart';
import 'package:synchronzie/shared/services/finger_detection_service.dart';

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
  // cấu hình detector: màu-only, fps cao, ngưỡng lỏng nhưng vẫn nhạy
  final FingerDetectionService _detector = FingerDetectionService(
    config: FingerDetectionConfig(
      throttleMs: 66, // ~15fps
      sampleStep: 10,
      redDominanceThreshold: 1.40,
      minRedLuma: 60,
      coverageThreshold: 0.80,
      requireTemporalValidation:
          false, // bỏ kiểm tra biến thiên để không tự ngắt
    ),
  );

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
        ResolutionPreset.low,
        enableAudio: false,
      );
      await controller.initialize();
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
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
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
    _isToggling = false;
  }

  // Xử lý khung hình để ước lượng tỷ lệ đỏ trung bình (phát hiện ngón tay)
  void _onCameraImage(CameraImage image) {
    // Bỏ qua nếu đã stop hoặc đang toggle
    if (_controller == null || !_streaming) return;
    final ctrl = _controller!;
    if (!ctrl.value.isInitialized) return;
    if (!_detector.shouldProcessNow()) return;

    final result = _detector.analyze(image);
    final bool detected = result.detected;

    if (detected != _fingerOn) {
      _fingerOn = detected;
      if (mounted) {
        setState(() {});
      }
    }

    // Điều khiển tiến trình đo
    if (_fingerOn) {
      // Khi trở lại trạng thái hợp lệ, đảm bảo forward dùng duration gốc
      if (_progressController.reverseDuration != null) {
        _progressController.reverseDuration = null;
      }
      if (!_progressController.isAnimating && _progressController.value < 1.0) {
        _progressController.forward();
      }
    } else {
      // Khi không hợp lệ: chạy lùi nhanh về 0 thay vì reset tức thì
      final double v = _progressController.value;
      if (v > 0.0) {
        final int totalMs = measurementDurationSeconds * 1000;
        final int remainingMs = (totalMs * v).toInt();
        int reverseMs;
        if (remainingMs <= 5000) {
          // Khi còn dưới 5s: chậm lại để mượt (400–800ms tuỳ phần còn lại)
          reverseMs = (remainingMs * 0.5).toInt(); // 50% của phần còn lại
          if (reverseMs < 400) reverseMs = 400;
          if (reverseMs > 1500) reverseMs = 1500;
        } else {
          // Phần còn lại dài: tụt nhanh để phản hồi tốt (150–600ms)
          reverseMs = ((remainingMs) * 0.12).toInt();
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
