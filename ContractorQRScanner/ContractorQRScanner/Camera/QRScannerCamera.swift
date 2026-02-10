import SwiftUI
@preconcurrency import AVFoundation

struct QRScannerCamera: UIViewRepresentable {
    let onCodeScanned: @MainActor (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onCodeScanned: onCodeScanned)
    }

    @MainActor
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .black

        let coordinator = context.coordinator

        DispatchQueue.global(qos: .userInitiated).async {
            let session = AVCaptureSession()
            session.sessionPreset = .high
            coordinator.session = session

            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                  let input = try? AVCaptureDeviceInput(device: device) else {
                return
            }

            if session.canAddInput(input) {
                session.addInput(input)
            }

            let output = AVCaptureMetadataOutput()
            if session.canAddOutput(output) {
                session.addOutput(output)
                output.setMetadataObjectsDelegate(coordinator, queue: .main)
                output.metadataObjectTypes = [.qr]
            }

            let previewLayer = AVCaptureVideoPreviewLayer(session: session)
            previewLayer.videoGravity = .resizeAspectFill
            coordinator.previewLayer = previewLayer

            DispatchQueue.main.async {
                previewLayer.frame = view.bounds
                view.layer.addSublayer(previewLayer)
            }

            session.startRunning()
        }

        return view
    }

    @MainActor
    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.previewLayer?.frame = uiView.bounds
    }

    class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        nonisolated(unsafe) var onCodeScanned: (@MainActor (String) -> Void)
        nonisolated(unsafe) var session: AVCaptureSession?
        nonisolated(unsafe) var previewLayer: AVCaptureVideoPreviewLayer?
        nonisolated(unsafe) var lastScannedTime: Date = .distantPast

        init(onCodeScanned: @escaping @MainActor (String) -> Void) {
            self.onCodeScanned = onCodeScanned
        }

        nonisolated func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
            guard Date().timeIntervalSince(lastScannedTime) > 2 else { return }

            guard let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
                  object.type == .qr,
                  let value = object.stringValue,
                  !value.isEmpty else { return }

            lastScannedTime = Date()

            let callback = onCodeScanned
            DispatchQueue.main.async {
                let generator = UIImpactFeedbackGenerator(style: .heavy)
                generator.impactOccurred()
                callback(value)
            }
        }
    }
}
