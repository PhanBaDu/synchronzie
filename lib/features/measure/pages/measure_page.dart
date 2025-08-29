import 'package:auto_route/auto_route.dart';
import 'package:flutter/cupertino.dart';
import 'package:synchronzie/shared/colors/colors.dart';
import 'package:synchronzie/shared/permissions/camera_permission.dart';
import 'package:synchronzie/features/measure/widgets/camera_overlay.dart';
import 'package:synchronzie/features/measure/widgets/progress_ring.dart';
import 'package:flutter/services.dart';
import 'dart:async';

@RoutePage()
class MeasurePage extends StatefulWidget {
  const MeasurePage({super.key});

  @override
  State<MeasurePage> createState() => _MeasurePageState();
}

class _MeasurePageState extends State<MeasurePage>
    with SingleTickerProviderStateMixin {
  bool _isRunning = false;
  bool _isToggling = false;
  late final AnimationController _progressController;
  int measurementDurationSeconds = 35; // dễ dàng thay đổi thời gian đo
  static const MethodChannel _hr = MethodChannel('heart_rate_plugin');
  bool _fingerOnLens = false;
  Timer? _pollTimer;

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
      await _hr.invokeMethod('startCamera');
      if (!mounted) return;
      setState(() {
        _isRunning = true;
      });
      _progressController
        ..reset()
        ..forward();
      _pollTimer?.cancel();
      _pollTimer = Timer.periodic(Duration(milliseconds: 300), (_) async {
        try {
          final res = await _hr.invokeMethod('isFingerDetected');
          final on = res == true;
          if (mounted && on != _fingerOnLens) {
            setState(() {
              _fingerOnLens = on;
            });
          }
        } catch (_) {}
      });
    } catch (_) {}
    _isToggling = false;
  }

  Future<void> _stopCamera() async {
    if (_isToggling) return;
    _isToggling = true;
    _pollTimer?.cancel();
    _pollTimer = null;
    try {
      _progressController.stop();
      _progressController.reset();
    } catch (_) {}
    try {
      await _hr.invokeMethod('stopCamera');
    } catch (_) {}
    if (mounted) {
      setState(() {
        _isRunning = false;
        _fingerOnLens = false;
      });
    }
    _isToggling = false;
  }

  @override
  Future<void> dispose() async {
    _pollTimer?.cancel();
    _pollTimer = null;
    try {
      await _hr.invokeMethod('stopCamera');
    } catch (_) {}
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
                          controller: null,
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
                            if (!_isRunning) {
                              await _startCamera();
                            } else {
                              await _stopCamera();
                            }
                          },
                          child: Text(
                            !_isRunning ? "Start" : "Stop",
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
                Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text(
                    !_isRunning
                        ? 'Nhấn Start để bật camera và đo'
                        : (_fingerOnLens
                              ? 'Đã nhận ngón tay – đang đo...'
                              : 'Hãy đặt ngón tay lên camera sau để bắt đầu đo'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _fingerOnLens
                          ? AppColors.primary
                          : AppColors.mutedForeground,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
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
