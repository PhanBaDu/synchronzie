import 'dart:math';

/// Heart rate analysis using signal processing on camera-derived color channels.
///
/// Pipeline:
/// - Detrend and normalize the signal
/// - Light band-pass via moving-average highpass + smoothing lowpass
/// - Hann window and zero-padding
/// - Spectrum magnitude via DFT (sufficient for small N)
/// - Peak search in 40–200 BPM band with quadratic interpolation
/// - SNR and autocorrelation consistency for confidence score
class HeartRateAnalyzer {
  // Primary target band: 50–150 BPM (more reliable)
  static const double _primaryMinHz = 50.0 / 60.0; // 0.833 Hz
  static const double _primaryMaxHz = 150.0 / 60.0; // 2.5 Hz
  // Fallback wider band: 40–200 BPM
  static const double _fallbackMinHz = 40.0 / 60.0; // 0.667 Hz
  static const double _fallbackMaxHz = 200.0 / 60.0; // 3.333 Hz
  static const double _ln10 = 2.302585092994046; // natural log of 10

  HeartRateResult analyze(
    List<double> red,
    List<double> green, {
    double fps = 30.0,
  }) {
    // Primary band first
    var redRes = _analyzeSingle(
      red,
      fps,
      channel: 'red',
      minHz: _primaryMinHz,
      maxHz: _primaryMaxHz,
    );
    var greenRes = _analyzeSingle(
      green,
      fps,
      channel: 'green',
      minHz: _primaryMinHz,
      maxHz: _primaryMaxHz,
    );

    // Pick the better channel by confidence, then SNR
    HeartRateResult best = redRes.confidence >= greenRes.confidence
        ? redRes
        : greenRes;
    if ((redRes.confidence - greenRes.confidence).abs() < 0.05) {
      best = redRes.snr >= greenRes.snr ? redRes : greenRes;
    }
    // If low confidence, try fallback wider band
    if (best.confidence < 0.5) {
      final redFb = _analyzeSingle(
        red,
        fps,
        channel: 'red',
        minHz: _fallbackMinHz,
        maxHz: _fallbackMaxHz,
      );
      final greenFb = _analyzeSingle(
        green,
        fps,
        channel: 'green',
        minHz: _fallbackMinHz,
        maxHz: _fallbackMaxHz,
      );
      HeartRateResult bestFb = redFb.confidence >= greenFb.confidence
          ? redFb
          : greenFb;
      if ((redFb.confidence - greenFb.confidence).abs() < 0.05) {
        bestFb = redFb.snr >= greenFb.snr ? redFb : greenFb;
      }
      if (bestFb.confidence > best.confidence) {
        best = bestFb;
      }
    }
    return best;
  }

  HeartRateResult _analyzeSingle(
    List<double> samples,
    double fps, {
    required String channel,
    required double minHz,
    required double maxHz,
  }) {
    if (samples.isEmpty) {
      return HeartRateResult.invalid(channel: channel);
    }

    // 1) Detrend
    final detrended = _detrend(samples, window: max(5, (fps ~/ 2)));

    // 2) Normalize
    final normalized = _normalize(detrended);

    // 3) Light band-pass (highpass via moving-average subtraction, then smooth)
    final highPassed = _highpass(normalized, window: max(7, (fps ~/ 2)));
    final bandLimited = _movingAverage(highPassed, window: max(3, (fps ~/ 10)));

    // 4) Window + zero-pad to next pow2
    final windowed = _hannWindow(bandLimited);
    final n = _nextPow2(windowed.length);
    final padded = List<double>.filled(n, 0.0);
    for (int i = 0; i < windowed.length; i++) padded[i] = windowed[i];

    // 5) Spectrum via DFT magnitude
    final spectrum = _dftMagnitude(padded);

    // 6) Peak search in HR band
    final minIndex = max(1, (minHz * n / fps).round());
    final maxIndex = min(n ~/ 2 - 1, (maxHz * n / fps).round());
    if (minIndex >= maxIndex) {
      return HeartRateResult.invalid(channel: channel);
    }

    int kMax = minIndex;
    double maxMag = 0;
    for (int k = minIndex; k <= maxIndex; k++) {
      if (spectrum[k] > maxMag) {
        maxMag = spectrum[k];
        kMax = k;
      }
    }

    // Quadratic interpolation around peak (parabolic peak)
    double refinedK = kMax.toDouble();
    if (kMax > minIndex && kMax < maxIndex) {
      final m1 = log(spectrum[kMax - 1] + 1e-9);
      final m2 = log(spectrum[kMax] + 1e-9);
      final m3 = log(spectrum[kMax + 1] + 1e-9);
      final denom = (m1 - 2 * m2 + m3);
      if (denom.abs() > 1e-9) {
        final delta = 0.5 * (m1 - m3) / denom;
        refinedK = kMax + delta.clamp(-0.5, 0.5);
      }
    }

    final frequencyHz = refinedK * fps / n;
    double bpm = (frequencyHz * 60.0).clamp(40.0, 200.0);

    // 7) SNR estimate in band
    final snr = _estimateSNR(spectrum, kMax, minIndex, maxIndex);

    // 8) Autocorrelation consistency
    final acConf = _autocorrConfidence(bandLimited, fps);

    // 9) Confidence aggregation
    final conf = _combineConfidence(snr, acConf);

    return HeartRateResult(
      bpm: bpm.round(),
      confidence: conf,
      snr: snr,
      selectedChannel: channel,
    );
  }

  List<double> _detrend(List<double> x, {required int window}) {
    final ma = _movingAverage(x, window: window);
    final out = List<double>.generate(x.length, (i) => x[i] - ma[i]);
    return out;
  }

  List<double> _normalize(List<double> x) {
    double mean = 0;
    for (final v in x) {
      mean += v;
    }
    mean /= x.length;
    double variance = 0;
    for (final v in x) {
      final diff = v - mean;
      variance += diff * diff;
    }
    variance /= x.length;
    final std = sqrt(max(variance, 1e-9));
    return List<double>.generate(x.length, (i) => (x[i] - mean) / std);
  }

  List<double> _highpass(List<double> x, {required int window}) {
    final ma = _movingAverage(x, window: window);
    return List<double>.generate(x.length, (i) => x[i] - ma[i]);
  }

  List<double> _movingAverage(List<double> x, {required int window}) {
    final w = max(1, window);
    final out = List<double>.filled(x.length, 0.0);
    double sum = 0;
    for (int i = 0; i < x.length; i++) {
      sum += x[i];
      if (i >= w) sum -= x[i - w];
      final count = min(i + 1, w);
      out[i] = sum / count;
    }
    return out;
  }

  List<double> _hannWindow(List<double> x) {
    final n = x.length;
    final out = List<double>.filled(n, 0.0);
    for (int i = 0; i < n; i++) {
      final w = 0.5 * (1 - cos(2 * pi * i / (n - 1)));
      out[i] = x[i] * w;
    }
    return out;
  }

  int _nextPow2(int n) {
    int p = 1;
    while (p < n) p <<= 1;
    return p;
  }

  List<double> _dftMagnitude(List<double> x) {
    final n = x.length;
    final mags = List<double>.filled(n, 0.0);
    for (int k = 0; k < n; k++) {
      double real = 0.0, imag = 0.0;
      for (int j = 0; j < n; j++) {
        final angle = -2 * pi * k * j / n;
        final v = x[j];
        real += v * cos(angle);
        imag += v * sin(angle);
      }
      mags[k] = sqrt(real * real + imag * imag);
    }
    return mags;
  }

  double _estimateSNR(
    List<double> spectrum,
    int kMax,
    int minIndex,
    int maxIndex,
  ) {
    final peakPower = spectrum[kMax] * spectrum[kMax];
    double noiseSum = 0.0;
    int noiseCount = 0;
    for (int k = minIndex; k <= maxIndex; k++) {
      if ((k - kMax).abs() <= 2) continue; // exclude peak neighborhood
      final p = spectrum[k] * spectrum[k];
      noiseSum += p;
      noiseCount++;
    }
    final noise = max(noiseSum / max(1, noiseCount), 1e-9);
    return 10 * (log(peakPower / noise) / _ln10); // dB
  }

  double _autocorrConfidence(List<double> x, double fps) {
    // Compute normalized autocorrelation in expected HR lag range
    final minLag = max(1, (fps / _fallbackMaxHz).round());
    final maxLag = min(x.length - 1, (fps / _fallbackMinHz).round());
    double best = 0.0;
    for (int lag = minLag; lag <= maxLag; lag++) {
      double num = 0.0, den1 = 0.0, den2 = 0.0;
      for (int i = 0; i + lag < x.length; i++) {
        final a = x[i];
        final b = x[i + lag];
        num += a * b;
        den1 += a * a;
        den2 += b * b;
      }
      final denom = sqrt(max(den1 * den2, 1e-9));
      final r = (num / denom).clamp(-1.0, 1.0);
      if (r > best) best = r;
    }
    // Map correlation to 0..1 confidence contribution
    return best.clamp(0.0, 1.0);
  }

  double _combineConfidence(double snrDb, double ac) {
    // Map SNR in dB to 0..1
    double snrScore;
    if (snrDb >= 8)
      snrScore = 1.0;
    else if (snrDb >= 5)
      snrScore = 0.8;
    else if (snrDb >= 3)
      snrScore = 0.6;
    else if (snrDb >= 1.5)
      snrScore = 0.4;
    else
      snrScore = 0.2;

    // Weighted combination
    return (0.65 * snrScore + 0.35 * ac).clamp(0.0, 1.0);
  }
}

class HeartRateResult {
  final int bpm;
  final double confidence; // 0..1
  final double snr; // dB
  final String selectedChannel; // 'red' or 'green'

  const HeartRateResult({
    required this.bpm,
    required this.confidence,
    required this.snr,
    required this.selectedChannel,
  });

  factory HeartRateResult.invalid({required String channel}) =>
      HeartRateResult(bpm: 0, confidence: 0, snr: 0, selectedChannel: channel);
}
