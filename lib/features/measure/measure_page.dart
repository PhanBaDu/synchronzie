import 'package:auto_route/auto_route.dart';
import 'package:flutter/cupertino.dart';
import 'package:synchronzie/shared/colors/colors.dart';
import 'package:synchronzie/shared/permissions/camera_permission.dart';
import 'package:camera/camera.dart';

@RoutePage()
class MeasurePage extends StatefulWidget {
  const MeasurePage({super.key});

  @override
  State<MeasurePage> createState() => _MeasurePageState();
}

class _MeasurePageState extends State<MeasurePage> {
  CameraController? _controller;
  bool _isToggling = false;

  @override
  void initState() {
    super.initState();
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
        ResolutionPreset.high,
        enableAudio: false,
      );
      await controller.initialize();
      await controller.setFlashMode(FlashMode.torch);
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
      });
    } catch (_) {
      // Ignore errors for now; could show a dialog if needed
    }
    _isToggling = false;
  }

  Future<void> _stopCamera() async {
    if (_isToggling) return;
    _isToggling = true;
    final controller = _controller;
    if (mounted) {
      setState(() {
        // Remove preview from tree before disposing to avoid build on disposed controller
        _controller = null;
      });
    } else {
      _controller = null;
    }
    if (controller != null) {
      try {
        if (controller.value.isInitialized) {
          await controller.setFlashMode(FlashMode.off);
        }
      } catch (_) {}
      await controller.dispose();
    }
    _isToggling = false;
  }

  @override
  void dispose() {
    final controller = _controller;
    _controller = null;
    if (controller != null) {
      controller.setFlashMode(FlashMode.off).catchError((_) {});
      controller.dispose();
    }
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
                      child: Column(
                        children: [
                          Container(
                            color: AppColors.primary,
                            width: double.infinity,
                            child: Image.asset('assets/images/heart_rate.png'),
                          ),
                        ],
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
                              width: 1,
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
                        child: Container(
                          width: 340,
                          height: 340,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.mutedForeground.withOpacity(0.1),
                              width: 4,
                            ),
                          ),
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
                if (_controller != null && _controller!.value.isInitialized)
                  Padding(
                    padding: EdgeInsets.only(top: 16, bottom: 24),
                    child: Center(
                      child: SizedBox(
                        width: 300,
                        height: 300,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: CameraPreview(_controller!),
                        ),
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
}
