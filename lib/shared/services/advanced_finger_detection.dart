import 'dart:math';

/// Advanced Finger Detection Service
///
/// Sử dụng phân tích RGB nâng cao để detect ngón tay với độ chính xác cao
class AdvancedFingerDetection {
  static const int _detectionHistorySize = 30;
  static const int _requiredConsecutiveDetections = 3; // Giảm từ 5 xuống 3
  static const double _fingerDetectionThreshold = 0.4; // Giảm từ 0.5 xuống 0.4
  static const double _stabilityThreshold = 0.5; // Giảm từ 0.6 xuống 0.5

  List<Map<String, double>> _rgbHistory = [];
  List<double> _detectionConfidence = [];
  int _consecutiveDetections = 0;
  bool _fingerDetected = false;
  bool _isStable = false;
  int _stableFrameCount = 0;

  /// Detect finger from RGB values
  bool detectFinger(Map<String, double> rgbValues) {
    _rgbHistory.add(rgbValues);
    if (_rgbHistory.length > _detectionHistorySize) {
      _rgbHistory.removeAt(0);
    }

    // Simple fallback detection for immediate response
    final simpleDetected = _simpleFingerDetection(rgbValues);

    if (_rgbHistory.length < 5) {
      return simpleDetected; // Use simple detection for first few frames
    }

    final confidence = _calculateFingerConfidence();
    _detectionConfidence.add(confidence);

    if (_detectionConfidence.length > _detectionHistorySize) {
      _detectionConfidence.removeAt(0);
    }

    final detected = simpleDetected || confidence > _fingerDetectionThreshold;

    if (detected) {
      _consecutiveDetections++;
    } else {
      _consecutiveDetections = 0;
    }

    _fingerDetected = _consecutiveDetections >= _requiredConsecutiveDetections;

    // Check stability
    _updateStability();

    return _fingerDetected;
  }

  /// Simple finger detection for immediate response
  bool _simpleFingerDetection(Map<String, double> rgbValues) {
    final red = rgbValues['red']!;
    final green = rgbValues['green']!;
    final blue = rgbValues['blue']!;

    final total = red + green + blue;
    final redFraction = red / total;
    final brightness = total / 3;

    // Simple criteria: reddish and moderate brightness
    return redFraction > 0.35 && brightness > 30 && brightness < 200;
  }

  /// Calculate finger detection confidence (0.0 - 1.0)
  double _calculateFingerConfidence() {
    if (_rgbHistory.length < 10) return 0.0;

    // 1. Color Analysis
    final colorScore = _analyzeColorPattern();

    // 2. Brightness Analysis
    final brightnessScore = _analyzeBrightnessPattern();

    // 3. Stability Analysis
    final stabilityScore = _analyzeStability();

    // 4. Edge Detection (simplified)
    final edgeScore = _analyzeEdges();

    // Weighted combination
    final totalScore =
        (0.4 * colorScore +
        0.3 * brightnessScore +
        0.2 * stabilityScore +
        0.1 * edgeScore);

    return totalScore.clamp(0.0, 1.0);
  }

  /// Analyze color pattern for finger detection
  double _analyzeColorPattern() {
    // Calculate average RGB
    double avgRed = 0, avgGreen = 0, avgBlue = 0;
    for (final rgb in _rgbHistory) {
      avgRed += rgb['red']!;
      avgGreen += rgb['green']!;
      avgBlue += rgb['blue']!;
    }
    avgRed /= _rgbHistory.length;
    avgGreen /= _rgbHistory.length;
    avgBlue /= _rgbHistory.length;

    // Convert to HSV for better skin detection
    final hsv = _rgbToHsv(avgRed, avgGreen, avgBlue);
    final hue = hsv[0];
    final saturation = hsv[1];

    // Skin tone detection (hue range for skin)
    double skinScore = 0.0;
    if (hue >= 0 && hue <= 45) {
      // Red-yellow range
      skinScore = 1.0 - (hue / 45);
    } else if (hue >= 315 && hue <= 360) {
      // Red range
      skinScore = 1.0 - ((360 - hue) / 45);
    }

    // Red dominance check
    final total = avgRed + avgGreen + avgBlue;
    final redFraction = avgRed / total;
    final redDominance = (redFraction - 0.33) * 3; // Normalize to 0-1

    // Saturation check (skin should have moderate saturation)
    final saturationScore = (saturation - 0.2) / 0.6; // 0.2-0.8 range

    return (skinScore * 0.5 + redDominance * 0.3 + saturationScore * 0.2).clamp(
      0.0,
      1.0,
    );
  }

  /// Analyze brightness pattern
  double _analyzeBrightnessPattern() {
    if (_rgbHistory.length < 15) return 0.0;

    // Calculate brightness for each frame
    final brightness = _rgbHistory.map((rgb) {
      return (rgb['red']! + rgb['green']! + rgb['blue']!) / 3;
    }).toList();

    // Check for consistent moderate brightness (finger should block some light)
    final avgBrightness =
        brightness.reduce((a, b) => a + b) / brightness.length;

    // Finger should reduce brightness moderately
    if (avgBrightness < 20 || avgBrightness > 180) return 0.0;

    // Calculate brightness consistency
    double variance = 0.0;
    for (final b in brightness) {
      variance += pow(b - avgBrightness, 2);
    }
    variance /= brightness.length;
    final stdDev = sqrt(variance);

    // Lower variance = more consistent = better finger detection
    final consistencyScore = (1.0 - (stdDev / 50)).clamp(0.0, 1.0);

    // Brightness drop score
    final brightnessScore = (1.0 - (avgBrightness / 200)).clamp(0.0, 1.0);

    return (consistencyScore * 0.6 + brightnessScore * 0.4);
  }

  /// Analyze stability of detection
  double _analyzeStability() {
    if (_detectionConfidence.length < 10) return 0.0;

    // Calculate variance of recent confidence scores
    final recentConfidence = _detectionConfidence.take(10).toList();
    final avgConfidence =
        recentConfidence.reduce((a, b) => a + b) / recentConfidence.length;

    double variance = 0.0;
    for (final c in recentConfidence) {
      variance += pow(c - avgConfidence, 2);
    }
    variance /= recentConfidence.length;
    final stdDev = sqrt(variance);

    // Lower variance = more stable = better detection
    return (1.0 - (stdDev / 0.5)).clamp(0.0, 1.0);
  }

  /// Analyze edges (simplified)
  double _analyzeEdges() {
    if (_rgbHistory.length < 5) return 0.0;

    // Calculate color changes between consecutive frames
    double totalChange = 0.0;
    for (int i = 1; i < _rgbHistory.length; i++) {
      final prev = _rgbHistory[i - 1];
      final curr = _rgbHistory[i];

      final redChange = (curr['red']! - prev['red']!).abs();
      final greenChange = (curr['green']! - prev['green']!).abs();
      final blueChange = (curr['blue']! - prev['blue']!).abs();

      totalChange += redChange + greenChange + blueChange;
    }

    final avgChange = totalChange / (_rgbHistory.length - 1);

    // Finger should have moderate change (not too static, not too dynamic)
    if (avgChange < 5 || avgChange > 50) return 0.0;

    return (avgChange / 50).clamp(0.0, 1.0);
  }

  /// Update stability state
  void _updateStability() {
    if (_fingerDetected && _detectionConfidence.isNotEmpty) {
      final recentConfidence = _detectionConfidence.take(10).toList();
      final avgConfidence =
          recentConfidence.reduce((a, b) => a + b) / recentConfidence.length;

      if (avgConfidence >= _stabilityThreshold) {
        _stableFrameCount++;
      } else {
        _stableFrameCount = 0;
      }

      _isStable = _stableFrameCount >= 5;
    } else {
      _stableFrameCount = 0;
      _isStable = false;
    }
  }

  /// Convert RGB to HSV
  List<double> _rgbToHsv(double r, double g, double b) {
    r = r.clamp(0.0, 255.0) / 255.0;
    g = g.clamp(0.0, 255.0) / 255.0;
    b = b.clamp(0.0, 255.0) / 255.0;

    final maxC = max(r, max(g, b));
    final minC = min(r, min(g, b));
    final delta = maxC - minC;

    double h = 0.0;
    if (delta != 0) {
      if (maxC == r) {
        h = 60 * (((g - b) / delta) % 6);
      } else if (maxC == g) {
        h = 60 * (((b - r) / delta) + 2);
      } else {
        h = 60 * (((r - g) / delta) + 4);
      }
    }
    if (h < 0) h += 360;

    final s = maxC == 0 ? 0.0 : delta / maxC;
    final v = maxC;

    return [h, s, v];
  }

  /// Get current detection confidence
  double get detectionConfidence {
    if (_detectionConfidence.isEmpty) return 0.0;
    return _detectionConfidence.last;
  }

  /// Get average confidence over recent frames
  double get averageConfidence {
    if (_detectionConfidence.isEmpty) return 0.0;
    final recent = _detectionConfidence.take(10).toList();
    return recent.reduce((a, b) => a + b) / recent.length;
  }

  /// Get current finger detection state
  bool get isFingerDetected => _fingerDetected;

  /// Get stability state
  bool get isStable => _isStable;

  /// Get detailed status for debugging
  Map<String, dynamic> get detailedStatus {
    return {
      'fingerDetected': _fingerDetected,
      'isStable': _isStable,
      'confidence': detectionConfidence,
      'averageConfidence': averageConfidence,
      'consecutiveDetections': _consecutiveDetections,
      'stableFrameCount': _stableFrameCount,
      'historySize': _rgbHistory.length,
    };
  }

  /// Reset detection state
  void reset() {
    _rgbHistory.clear();
    _detectionConfidence.clear();
    _consecutiveDetections = 0;
    _fingerDetected = false;
    _isStable = false;
    _stableFrameCount = 0;
  }

  /// Force enable finger detection (for testing)
  void forceEnable() {
    _fingerDetected = true;
    _consecutiveDetections = _requiredConsecutiveDetections;
  }
}
