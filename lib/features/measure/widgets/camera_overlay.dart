import 'package:camera/camera.dart';
import 'package:flutter/cupertino.dart';

class CameraOverlay extends StatelessWidget {
  final CameraController? controller;
  final double size;
  final Color fallbackColor;
  final String overlayAsset;

  const CameraOverlay({
    super.key,
    required this.controller,
    required this.size,
    required this.fallbackColor,
    required this.overlayAsset,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (controller != null && controller!.value.isInitialized)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CameraPreview(controller!),
            )
          else
            Container(color: fallbackColor),
          Image.asset(
            overlayAsset,
            fit: BoxFit.cover,
            width: size,
            height: size,
          ),
        ],
      ),
    );
  }
}
