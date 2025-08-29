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

  final FingerDetectionService _detector = FingerDetectionService(
    config: FingerDetectionConfig(throttleMs: 100),
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
        if (_streaming) {
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
      if (!_progressController.isAnimating && _progressController.value < 1.0) {
        _progressController.forward();
      }
    } else {
      if (_progressController.isAnimating) {
        _progressController.stop();
      }
      // Khi không xác thực được ngón tay, reset thời lượng về 0 để đo lại từ đầu
      if (_progressController.value > 0.0) {
        _progressController.reset();
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
