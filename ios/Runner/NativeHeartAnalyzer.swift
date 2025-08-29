import AVFoundation

class NativeHeartAnalyzer: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
  private let session = AVCaptureSession()
  private let queue = DispatchQueue(label: "hr.native.queue")
  private var device: AVCaptureDevice?
  private var input: AVCaptureDeviceInput?
  private var output = AVCaptureVideoDataOutput()
  private(set) var fingerDetected: Bool = false

  func start() {
    guard !session.isRunning else { return }
    session.beginConfiguration()
    session.sessionPreset = .vga640x480

    device = AVCaptureDevice.default(for: .video)
    guard let device = device, let input = try? AVCaptureDeviceInput(device: device) else {
      session.commitConfiguration(); return
    }
    self.input = input
    if session.canAddInput(input) { session.addInput(input) }

    output.alwaysDiscardsLateVideoFrames = true
    output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
    output.setSampleBufferDelegate(self, queue: queue)
    if session.canAddOutput(output) { session.addOutput(output) }
    session.commitConfiguration()

    try? device.lockForConfiguration()
    if device.hasTorch { try? device.setTorchModeOn(level: 1.0) }
    if device.isFocusModeSupported(.locked) { device.focusMode = .locked }
    if device.isExposureModeSupported(.locked) { device.exposureMode = .locked }
    device.unlockForConfiguration()

    session.startRunning()
  }

  func stop() {
    guard session.isRunning else { return }
    session.stopRunning()
    if let device = device, device.hasTorch { try? device.lockForConfiguration(); device.torchMode = .off; device.unlockForConfiguration() }
    if let input = input { session.removeInput(input) }
    session.removeOutput(output)
  }

  func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
    guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
    CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
    let width = CVPixelBufferGetWidth(pixelBuffer)
    let height = CVPixelBufferGetHeight(pixelBuffer)
    guard let base = CVPixelBufferGetBaseAddress(pixelBuffer) else { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly); return }

    let buf = base.bindMemory(to: UInt8.self, capacity: CVPixelBufferGetDataSize(pixelBuffer))
    let stride = 4 // BGRA
    var sumR: Int = 0
    var count: Int = 0
    let step = 8 // subsample
    for y in stride(from: height/3, to: 2*height/3, by: step) {
      let row = buf + y * CVPixelBufferGetBytesPerRow(pixelBuffer)
      for x in stride(from: width/3, to: 2*width/3, by: step) {
        let p = row + x * stride
        let r = p[2]
        sumR += Int(r)
        count += 1
      }
    }
    CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
    guard count > 0 else { return }
    let avgR = Double(sumR) / Double(count)
    fingerDetected = avgR > 120.0
  }
}


