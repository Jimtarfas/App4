import AVFoundation
import SwiftUI

/// Owns the capture session for the coin camera.
@Observable
final class CameraController: NSObject, AVCapturePhotoCaptureDelegate {
    enum Status { case unknown, ready, denied, unavailable }

    private(set) var status: Status = .unknown
    private(set) var isTorchOn = false
    let session = AVCaptureSession()
    private let output = AVCapturePhotoOutput()
    private let queue = DispatchQueue(label: "camera.session")
    private var device: AVCaptureDevice?
    private var continuation: CheckedContinuation<UIImage?, Never>?

    var hasTorch: Bool { device?.hasTorch ?? false }

    func start() async {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: break
        case .notDetermined:
            guard await AVCaptureDevice.requestAccess(for: .video) else { status = .denied; return }
        default:
            status = .denied
            return
        }
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device) else {
            status = .unavailable
            return
        }
        self.device = device
        let session = session, output = output
        await withCheckedContinuation { (done: CheckedContinuation<Void, Never>) in
            queue.async {
                if session.inputs.isEmpty {
                    session.beginConfiguration()
                    session.sessionPreset = .photo
                    if session.canAddInput(input) { session.addInput(input) }
                    if session.canAddOutput(output) { session.addOutput(output) }
                    session.commitConfiguration()
                }
                if !session.isRunning { session.startRunning() }
                done.resume()
            }
        }
        configureFocus(on: device)
        status = .ready
    }

    func stop() {
        setTorch(false)
        let session = session
        queue.async { if session.isRunning { session.stopRunning() } }
    }

    func setTorch(_ on: Bool) {
        guard let device, device.hasTorch, (try? device.lockForConfiguration()) != nil else { return }
        device.torchMode = on ? .on : .off
        device.unlockForConfiguration()
        isTorchOn = on
    }

    func capture() async -> UIImage? {
        guard status == .ready else { return nil }
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            output.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
        }
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        let image = photo.fileDataRepresentation().flatMap(UIImage.init(data:))
        continuation?.resume(returning: image)
        continuation = nil
    }

    /// Coins are photographed close up, so favour near focus.
    private func configureFocus(on device: AVCaptureDevice) {
        guard (try? device.lockForConfiguration()) != nil else { return }
        if device.isFocusModeSupported(.continuousAutoFocus) { device.focusMode = .continuousAutoFocus }
        if device.isAutoFocusRangeRestrictionSupported { device.autoFocusRangeRestriction = .near }
        device.unlockForConfiguration()
    }
}

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        view.backgroundColor = .black
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}
}
