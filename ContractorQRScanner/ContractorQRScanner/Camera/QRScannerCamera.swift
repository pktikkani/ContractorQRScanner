import SwiftUI
@preconcurrency import AVFoundation

enum CameraState: Equatable {
    case initializing
    case running
    case permissionDenied
    case failed(String)
}

struct QRScannerCamera: UIViewRepresentable {
    let onCodeScanned: @MainActor (String) -> Void
    let onStateChanged: @MainActor (CameraState) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onCodeScanned: onCodeScanned, onStateChanged: onStateChanged)
    }

    @MainActor
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .black

        let coordinator = context.coordinator

        DispatchQueue.global(qos: .userInitiated).async {
            // Check camera permission first
            let status = AVCaptureDevice.authorizationStatus(for: .video)
            switch status {
            case .authorized:
                coordinator.setupSession(in: view)

            case .notDetermined:
                AVCaptureDevice.requestAccess(for: .video) { granted in
                    if granted {
                        coordinator.setupSession(in: view)
                    } else {
                        let cb = coordinator.onStateChanged
                        DispatchQueue.main.async { cb(.permissionDenied) }
                    }
                }

            case .denied, .restricted:
                let cb = coordinator.onStateChanged
                DispatchQueue.main.async { cb(.permissionDenied) }

            @unknown default:
                let cb = coordinator.onStateChanged
                DispatchQueue.main.async { cb(.failed("Unknown camera authorization status")) }
            }
        }

        return view
    }

    @MainActor
    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.previewLayer?.frame = uiView.bounds
    }

    @MainActor
    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        let session = coordinator.session
        let previewLayer = coordinator.previewLayer
        coordinator.session = nil
        coordinator.previewLayer = nil
        previewLayer?.removeFromSuperlayer()
        DispatchQueue.global(qos: .userInitiated).async {
            guard let session = session, session.isRunning else { return }
            session.stopRunning()
        }
    }

    class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        nonisolated(unsafe) var onCodeScanned: (@MainActor (String) -> Void)
        nonisolated(unsafe) var onStateChanged: (@MainActor (CameraState) -> Void)
        nonisolated(unsafe) var session: AVCaptureSession?
        nonisolated(unsafe) var previewLayer: AVCaptureVideoPreviewLayer?
        nonisolated(unsafe) var lastScannedTime: Date = .distantPast
        let metadataQueue = DispatchQueue(label: "com.pragmatic.scanner.metadata")

        init(
            onCodeScanned: @escaping @MainActor (String) -> Void,
            onStateChanged: @escaping @MainActor (CameraState) -> Void
        ) {
            self.onCodeScanned = onCodeScanned
            self.onStateChanged = onStateChanged
        }

        func setupSession(in view: UIView) {
            let session = AVCaptureSession()
            session.sessionPreset = .high
            self.session = session

            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
                let cb = onStateChanged
                DispatchQueue.main.async { cb(.failed("No camera available")) }
                return
            }

            guard let input = try? AVCaptureDeviceInput(device: device) else {
                let cb = onStateChanged
                DispatchQueue.main.async { cb(.failed("Cannot access camera")) }
                return
            }

            if session.canAddInput(input) {
                session.addInput(input)
            }

            let output = AVCaptureMetadataOutput()
            if session.canAddOutput(output) {
                session.addOutput(output)
                output.setMetadataObjectsDelegate(self, queue: metadataQueue)
                output.metadataObjectTypes = [.qr]
            }

            let previewLayer = AVCaptureVideoPreviewLayer(session: session)
            previewLayer.videoGravity = .resizeAspectFill
            self.previewLayer = previewLayer

            let stateCb = onStateChanged
            DispatchQueue.main.async {
                previewLayer.frame = view.bounds
                view.layer.addSublayer(previewLayer)
                stateCb(.running)
            }

            session.startRunning()
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
