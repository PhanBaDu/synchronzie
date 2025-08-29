import 'package:camera/camera.dart';

class FingerDetectionConfig {
  final int throttleMs;
  final int sampleStep;
  final double cropStartRatio;
  final double cropEndRatio;
  final double redDominanceThreshold;
  final double minRedLuma;
  final double coverageThreshold;

  const FingerDetectionConfig({
    this.throttleMs = 200,
    this.sampleStep = 12,
    this.cropStartRatio = 0.4,
    this.cropEndRatio = 0.6,
    this.redDominanceThreshold = 1.35,
    this.minRedLuma = 60,
    this.coverageThreshold = 0.80,
  });
}

class FingerDetectionResult {
  final bool detected;
  final double coverage;
  final double avgRed;

  const FingerDetectionResult({
    required this.detected,
    required this.coverage,
    required this.avgRed,
  });
}

class FingerDetectionService {
  FingerDetectionService({this.config = const FingerDetectionConfig()});

  final FingerDetectionConfig config;
  DateTime? _lastProcessedAt;
  bool _isProcessing = false;

  bool shouldProcessNow() {
    final now = DateTime.now();
    if (_isProcessing) return false;
    if (_lastProcessedAt != null &&
        now.difference(_lastProcessedAt!).inMilliseconds < config.throttleMs) {
      return false;
    }
    _lastProcessedAt = now;
    _isProcessing = true;
    return true;
  }

  void markDone() {
    _isProcessing = false;
  }

  FingerDetectionResult analyze(CameraImage image) {
    double avgR = 0;
    int sampleCount = 0;
    int redDominantCount = 0;

    try {
      if (image.format.group == ImageFormatGroup.yuv420) {
        final width = image.width;
        final height = image.height;
        final yPlane = image.planes[0];
        final uPlane = image.planes[1];
        final vPlane = image.planes[2];

        final int yRowStride = yPlane.bytesPerRow;
        final int yPixelStride = yPlane.bytesPerPixel ?? 1;
        final int uRowStride = uPlane.bytesPerRow;
        final int uPixelStride = uPlane.bytesPerPixel ?? 1;
        final int vRowStride = vPlane.bytesPerRow;
        final int vPixelStride = vPlane.bytesPerPixel ?? 1;

        final int step = config.sampleStep;
        final int startX = (width * config.cropStartRatio).toInt();
        final int endX = (width * config.cropEndRatio).toInt();
        final int startY = (height * config.cropStartRatio).toInt();
        final int endY = (height * config.cropEndRatio).toInt();

        for (int y = startY; y < endY; y += step) {
          for (int x = startX; x < endX; x += step) {
            final int yIndex = y * yRowStride + x * yPixelStride;
            final int uvRow = (y / 2).floor();
            final int uvCol = (x / 2).floor();
            final int uIndex = uvRow * uRowStride + uvCol * uPixelStride;
            final int vIndex = uvRow * vRowStride + uvCol * vPixelStride;

            final int Y = yPlane.bytes[yIndex] & 0xFF;
            final int U = uPlane.bytes[uIndex] & 0xFF;
            final int V = vPlane.bytes[vIndex] & 0xFF;

            double C = Y - 16;
            double D = U - 128;
            double E = V - 128;
            double r = (1.164 * C + 1.596 * E);
            double g = (1.164 * C - 0.392 * D - 0.813 * E);
            double b = (1.164 * C + 2.017 * D);

            r = r.clamp(0, 255);
            g = g.clamp(0, 255);
            b = b.clamp(0, 255);

            avgR += r;
            sampleCount++;

            final double gb = ((g + b) / 2.0) + 1e-6;
            if ((r / gb) > config.redDominanceThreshold &&
                r > config.minRedLuma) {
              redDominantCount++;
            }
          }
        }
      } else if (image.format.group == ImageFormatGroup.bgra8888) {
        final bytes = image.planes[0].bytes;
        final int width = image.width;
        final int height = image.height;
        final int bytesPerRow = image.planes[0].bytesPerRow;
        final int step = config.sampleStep;
        final int startX = (width * config.cropStartRatio).toInt();
        final int endX = (width * config.cropEndRatio).toInt();
        final int startY = (height * config.cropStartRatio).toInt();
        final int endY = (height * config.cropEndRatio).toInt();

        for (int y = startY; y < endY; y += step) {
          final int rowStart = y * bytesPerRow;
          for (int x = startX; x < endX; x += step) {
            final int idx = rowStart + x * 4;
            final int b = bytes[idx] & 0xFF;
            final int g = bytes[idx + 1] & 0xFF;
            final int r = bytes[idx + 2] & 0xFF;

            avgR += r.toDouble();
            sampleCount++;

            final double gb = ((g + b) / 2.0) + 1e-6;
            if ((r / gb) > config.redDominanceThreshold &&
                r > config.minRedLuma) {
              redDominantCount++;
            }
          }
        }
      } else {
        return FingerDetectionResult(detected: false, coverage: 0, avgRed: 0);
      }
    } catch (_) {
      return FingerDetectionResult(detected: false, coverage: 0, avgRed: 0);
    } finally {
      markDone();
    }

    if (sampleCount == 0) {
      return FingerDetectionResult(detected: false, coverage: 0, avgRed: 0);
    }

    avgR /= sampleCount;
    final double coverage = redDominantCount / (sampleCount + 1e-6);
    final bool detected =
        coverage > config.coverageThreshold && avgR > config.minRedLuma;

    return FingerDetectionResult(
      detected: detected,
      coverage: coverage,
      avgRed: avgR,
    );
  }
}
