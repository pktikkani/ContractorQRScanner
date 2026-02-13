import SwiftUI
import PostHog

struct ScannerView: View {
    @State private var scanState: ScanState = .scanning
    @State private var validationResult: ValidationResponse?
    @State private var errorMessage: String?
    @State private var scannerActive = true
    @State private var cameraState: CameraState = .initializing
    @State private var scanMode: String = "entry" // "entry" or "exit"
    @StateObject private var networkMonitor = NetworkMonitor.shared
    @State private var showEmergencyOverride = false
    @State private var lastScannedCode = ""
    @ObservedObject private var languageManager = LanguageManager.shared

    enum ScanState {
        case scanning
        case validating
        case result
        case error
    }

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                    .padding(.bottom, 8)

                // Entry/Exit mode toggle
                HStack(spacing: 0) {
                    Button(action: { withAnimation(.easeInOut(duration: 0.2)) { scanMode = "entry" } }) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.right.circle.fill")
                            Text("Entry")
                                .font(.subheadline.weight(.semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(scanMode == "entry" ? AppTheme.success : Color.clear)
                                .padding(3)
                        )
                        .foregroundColor(scanMode == "entry" ? AppTheme.textOnPrimary : AppTheme.textSecondary)
                    }

                    Button(action: { withAnimation(.easeInOut(duration: 0.2)) { scanMode = "exit" } }) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.left.circle.fill")
                            Text("Exit")
                                .font(.subheadline.weight(.semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(scanMode == "exit" ? AppTheme.danger : Color.clear)
                                .padding(3)
                        )
                        .foregroundColor(scanMode == "exit" ? AppTheme.textOnPrimary : AppTheme.textSecondary)
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(AppTheme.surfaceBackground)
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Scan mode: \(scanMode == "entry" ? "Entry" : "Exit")")

                // Network status indicator
                if !networkMonitor.isConnected {
                    HStack(spacing: 8) {
                        Image(systemName: "wifi.slash")
                            .font(.caption)
                            .foregroundColor(AppTheme.warning)
                        Text("Offline — Using cached validations")
                            .font(.caption.weight(.medium))
                            .foregroundColor(AppTheme.warning)
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(AppTheme.warning.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
                    .accessibilityLabel("Network status: Offline, using cached validations")
                }

                switch scanState {
                case .scanning:
                    scanningView
                case .validating:
                    validatingView
                case .result:
                    resultView
                case .error:
                    errorView
                }

                Spacer(minLength: 0)

                // Emergency override button
                Button(action: { showEmergencyOverride = true }) {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.shield.fill")
                        Text("Emergency Override")
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundColor(AppTheme.warning)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 24)
                    .background(
                        Capsule()
                            .fill(AppTheme.cardBackground)
                            .shadow(color: AppTheme.cardShadow, radius: 8, y: 4)
                    )
                    .overlay(
                        Capsule()
                            .strokeBorder(AppTheme.warning.opacity(0.3), lineWidth: 1)
                    )
                }
                .padding(.bottom, 16)
                .accessibilityLabel("Emergency Override")
                .accessibilityHint("Manually grant or deny access without QR scan")
            }
        }
        .sheet(isPresented: $showEmergencyOverride) {
            EmergencyOverrideSheet(
                onSubmit: { granted, reason in
                    let entry = ScanHistoryEntry(
                        id: UUID(),
                        timestamp: Date(),
                        contractorName: "Emergency Override",
                        company: nil,
                        email: nil,
                        result: granted ? "granted" : "denied",
                        reason: "OVERRIDE: \(reason)",
                        scanMode: scanMode
                    )
                    ScanHistoryManager.shared.addEntry(entry)
                    showEmergencyOverride = false
                },
                onCancel: { showEmergencyOverride = false }
            )
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(AppTheme.primaryGradient)
                    .frame(width: 48, height: 48)
                    .shadow(color: AppTheme.primaryShadow, radius: 10)

                Image(systemName: "qrcode.viewfinder")
                    .font(.title2.weight(.semibold))
                    .foregroundColor(AppTheme.textOnPrimary)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text("Access Scanner")
                    .font(.title2.weight(.bold))
                    .foregroundColor(AppTheme.textPrimary)

                Text("Scan contractor QR codes for entry")
                    .font(.caption)
                    .foregroundColor(AppTheme.textSecondary)
            }

            Spacer()

            HStack(spacing: 6) {
                Circle()
                    .fill(scanState == .scanning ? AppTheme.success : AppTheme.primary)
                    .frame(width: 8, height: 8)
                    .accessibilityHidden(true)

                Text(scanState == .scanning ? "Ready" : "Busy")
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(scanState == .scanning ? AppTheme.success : AppTheme.primary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill((scanState == .scanning ? AppTheme.success : AppTheme.primary).opacity(0.12))
            )
            .accessibilityLabel("Scanner status: \(scanState == .scanning ? "Ready" : "Busy")")

            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    languageManager.toggleLanguage()
                }
            }) {
                Text(languageManager.isArabic ? "EN" : "AR")
                    .font(.caption2.weight(.bold))
                    .foregroundColor(AppTheme.textOnPrimary)
                    .frame(width: 36, height: 28)
                    .background(AppTheme.primary)
                    .cornerRadius(8)
            }
            .accessibilityLabel("Switch language")
            .accessibilityHint("Currently \(languageManager.isArabic ? "Arabic" : "English")")
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }

    // MARK: - Scanning View

    private var scanningView: some View {
        VStack(spacing: 16) {
            ZStack {
                if scannerActive {
                    QRScannerCamera(
                        onCodeScanned: { code in
                            handleScannedCode(code)
                        },
                        onStateChanged: { state in
                            cameraState = state
                        }
                    )
                }

                switch cameraState {
                case .initializing:
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.white)
                        Text("Starting camera...")
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black)

                case .permissionDenied:
                    cameraPermissionView

                case .failed(let message):
                    cameraErrorView(message: message)

                case .running:
                    scanFrameOverlay
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
            .shadow(color: AppTheme.cardShadow, radius: 20, y: 8)
            .padding(.horizontal, 20)

            if cameraState == .running {
                HStack(spacing: 10) {
                    Image(systemName: "viewfinder")
                        .foregroundColor(AppTheme.primary)

                    Text("Position QR code within the frame")
                        .font(.subheadline)
                        .foregroundColor(AppTheme.textSecondary)
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 20)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(AppTheme.cardBackground)
                        .shadow(color: AppTheme.cardShadow, radius: 10, y: 4)
                )
                .padding(.horizontal, 20)
            }
        }
    }

    private var cameraPermissionView: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.fill")
                .font(.system(size: 48))
                .foregroundColor(AppTheme.warning)

            Text("Camera Access Required")
                .font(.title3.weight(.bold))
                .foregroundColor(.white)

            Text("Camera permission is needed to scan QR codes. Please enable it in Settings.")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button(action: {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }) {
                Text("Open Settings")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(AppTheme.textOnPrimary)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 12)
                    .background(AppTheme.primaryGradient)
                    .cornerRadius(12)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Camera permission required. Open Settings to enable camera access.")
    }

    private func cameraErrorView(message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(AppTheme.danger)

            Text("Camera Unavailable")
                .font(.title3.weight(.bold))
                .foregroundColor(.white)

            Text(message)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Camera error: \(message)")
    }

    private var scanFrameOverlay: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height) * 0.65

            ZStack {
                Color.black.opacity(0.4)
                    .reverseMask {
                        RoundedRectangle(cornerRadius: 12)
                            .frame(width: size, height: size)
                    }

                // Corner brackets using Canvas
                Canvas { context, canvasSize in
                    let cx = canvasSize.width / 2
                    let cy = canvasSize.height / 2
                    let half = size / 2
                    let len: CGFloat = 30
                    let lw: CGFloat = 4

                    let corners: [(CGPoint, CGPoint, CGPoint)] = [
                        // Top-left
                        (CGPoint(x: cx - half, y: cy - half + len), CGPoint(x: cx - half, y: cy - half), CGPoint(x: cx - half + len, y: cy - half)),
                        // Top-right
                        (CGPoint(x: cx + half - len, y: cy - half), CGPoint(x: cx + half, y: cy - half), CGPoint(x: cx + half, y: cy - half + len)),
                        // Bottom-right
                        (CGPoint(x: cx + half, y: cy + half - len), CGPoint(x: cx + half, y: cy + half), CGPoint(x: cx + half - len, y: cy + half)),
                        // Bottom-left
                        (CGPoint(x: cx - half + len, y: cy + half), CGPoint(x: cx - half, y: cy + half), CGPoint(x: cx - half, y: cy + half - len)),
                    ]

                    for (start, corner, end) in corners {
                        var path = Path()
                        path.move(to: start)
                        path.addLine(to: corner)
                        path.addLine(to: end)
                        context.stroke(path, with: .color(AppTheme.primary), lineWidth: lw)
                    }
                }

                ScanningLine()
                    .frame(width: size - 20, height: size)
            }
        }
        .frame(height: UIScreen.main.bounds.height * 0.5)
    }

    // MARK: - Validating View

    private var validatingView: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(AppTheme.primary.opacity(0.08))
                    .frame(width: 120, height: 120)

                Circle()
                    .fill(AppTheme.primary.opacity(0.15))
                    .frame(width: 90, height: 90)

                ProgressView()
                    .scaleEffect(2)
                    .tint(AppTheme.primary)
            }

            Text("Validating Access...")
                .font(.title2.weight(.bold))
                .foregroundColor(AppTheme.textPrimary)

            Text("Checking permissions and schedule")
                .font(.subheadline)
                .foregroundColor(AppTheme.textSecondary)

            Spacer()
        }
    }

    // MARK: - Result View

    private var resultView: some View {
        VStack(spacing: 0) {
            if let result = validationResult {
                if result.isGranted {
                    accessGrantedView(result)
                } else {
                    accessDeniedView(result)
                }
            }
        }
    }

    private func accessGrantedView(_ result: ValidationResponse) -> some View {
        ScrollView {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(AppTheme.success.opacity(0.10))
                    .frame(width: 160, height: 160)

                Circle()
                    .fill(AppTheme.successGradient)
                    .frame(width: 120, height: 120)
                    .shadow(color: AppTheme.success.opacity(0.3), radius: 20)

                Image(systemName: "checkmark")
                    .font(.system(size: 56, weight: .bold))
                    .foregroundColor(AppTheme.textOnPrimary)
            }

            Text("ACCESS GRANTED")
                .font(.system(size: 32, weight: .black))
                .foregroundColor(AppTheme.success)
                .accessibilityAddTraits(.isHeader)

            if let contractor = result.contractor {
                VStack(spacing: 16) {
                    // Contractor Photo for Visual Verification
                    if let photoUrl = contractor.photoUrl,
                       !photoUrl.isEmpty,
                       let data = Data(base64Encoded: photoUrl
                           .replacingOccurrences(of: "data:image/jpeg;base64,", with: "")
                           .replacingOccurrences(of: "data:image/png;base64,", with: "")
                           .replacingOccurrences(of: "data:image/jpg;base64,", with: "")),
                       let uiImage = UIImage(data: data) {

                        VStack(spacing: 8) {
                            Text("VERIFY IDENTITY")
                                .font(.caption.weight(.bold))
                                .foregroundColor(AppTheme.primary)
                                .tracking(1.5)

                            ZStack(alignment: .bottomTrailing) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 100, height: 100)
                                    .clipShape(Circle())
                                    .overlay(
                                        Circle()
                                            .strokeBorder(AppTheme.success, lineWidth: 3)
                                    )
                                    .shadow(color: AppTheme.success.opacity(0.2), radius: 10)

                                ZStack {
                                    Circle()
                                        .fill(AppTheme.success)
                                        .frame(width: 28, height: 28)

                                    Image(systemName: "checkmark")
                                        .font(.caption.weight(.bold))
                                        .foregroundColor(AppTheme.textOnPrimary)
                                }
                            }
                        }
                        .padding(.bottom, 4)
                    } else {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(AppTheme.warning)
                                .font(.caption)
                                .accessibilityHidden(true)
                            Text("No photo on file")
                                .font(.caption.weight(.medium))
                                .foregroundColor(AppTheme.warning)
                        }
                        .accessibilityLabel("Warning: No photo on file for identity verification")
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(AppTheme.warning.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .strokeBorder(AppTheme.warning.opacity(0.3), lineWidth: 1)
                                )
                        )
                    }

                    DetailRow(icon: "person.fill", label: "Name", value: contractor.fullName)

                    if let company = contractor.company {
                        DetailRow(icon: "building.2.fill", label: "Company", value: company)
                    }

                    if let email = contractor.email, !email.isEmpty {
                        DetailRow(icon: "envelope.fill", label: "Email", value: email)
                    }
                }
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                        .fill(AppTheme.cardBackground)
                        .shadow(color: AppTheme.success.opacity(0.10), radius: 16, y: 6)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                        .strokeBorder(AppTheme.success.opacity(0.2), lineWidth: 1)
                )
                .padding(.horizontal, 20)
            }

            scanNextButton
        }
        .padding(.top, 20)
        }
    }

    private func accessDeniedView(_ result: ValidationResponse) -> some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(AppTheme.danger.opacity(0.10))
                    .frame(width: 160, height: 160)

                Circle()
                    .fill(AppTheme.dangerGradient)
                    .frame(width: 120, height: 120)
                    .shadow(color: AppTheme.danger.opacity(0.3), radius: 20)

                Image(systemName: "xmark")
                    .font(.system(size: 56, weight: .bold))
                    .foregroundColor(AppTheme.textOnPrimary)
            }

            Text("ACCESS DENIED")
                .font(.system(size: 32, weight: .black))
                .foregroundColor(AppTheme.danger)
                .accessibilityAddTraits(.isHeader)

            if let reason = result.reason {
                Text(reason)
                    .font(.body.weight(.medium))
                    .foregroundColor(AppTheme.danger)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(AppTheme.danger.opacity(0.08))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(AppTheme.danger.opacity(0.2), lineWidth: 1)
                            )
                    )
                    .padding(.horizontal, 20)
            }

            Spacer()
            scanNextButton
        }
    }

    private var scanNextButton: some View {
        Button {
            resetScanner()
        } label: {
            HStack {
                Image(systemName: "qrcode.viewfinder")
                Text("Scan Next")
            }
            .font(.headline)
            .foregroundColor(AppTheme.textOnPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(AppTheme.primary)
            .cornerRadius(16)
            .shadow(color: AppTheme.primaryShadow, radius: 12, y: 6)
        }
        .accessibilityLabel("Scan Next")
        .accessibilityHint("Double tap to scan another QR code")
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }

    // MARK: - Error View

    private var errorView: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(AppTheme.warning.opacity(0.10))
                    .frame(width: 120, height: 120)

                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(AppTheme.warning)
            }

            Text("Validation Failed")
                .font(.title2.weight(.bold))
                .foregroundColor(AppTheme.textPrimary)

            if let error = errorMessage {
                Text(error)
                    .font(.subheadline)
                    .foregroundColor(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Spacer()

            Button {
                resetScanner()
            } label: {
                HStack {
                    Image(systemName: "arrow.counterclockwise")
                    Text("Try Again")
                }
                .font(.headline)
                .foregroundColor(AppTheme.textOnPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(AppTheme.primary)
                .cornerRadius(16)
                .shadow(color: AppTheme.primaryShadow, radius: 12, y: 6)
            }
            .accessibilityLabel("Try Again")
            .accessibilityHint("Double tap to retry scanning")
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }

    // MARK: - Actions

    /// Max QR age (seconds) before scanner blocks locally without hitting API
    private static let maxQRAgeAtScan: TimeInterval = 60

    private func handleScannedCode(_ code: String) {
        // Skip if same QR code scanned again (already validated/expired)
        guard code != lastScannedCode else { return }
        lastScannedCode = code
        scannerActive = false

        // Local stale precheck — decode QR timestamp and block if too old
        if let payloadData = Data(base64Encoded: code),
           let json = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any],
           let ts = json["timestamp"] as? Int64 {
            let qrAge = Date().timeIntervalSince1970 - TimeInterval(ts)
            if qrAge > Self.maxQRAgeAtScan {
                PostHogSDK.shared.capture("stale_blocked_locally", properties: [
                    "qr_age_seconds": Int(qrAge),
                    "threshold_seconds": Int(Self.maxQRAgeAtScan),
                    "app": "scanner"
                ])
                PostHogSDK.shared.flush()

                validationResult = ValidationResponse(
                    status: "denied",
                    contractor: nil,
                    reason: "QR code is stale (\(Int(qrAge))s old). Ask the contractor to refresh their QR code."
                )
                scanState = .result

                Task {
                    try? await Task.sleep(nanoseconds: 8_000_000_000)
                    if scanState == .result { resetScanner() }
                }
                return
            }
        }

        scanState = .validating

        Task {
            do {
                let result = try await APIClient.shared.validateQRCode(qrData: code, scanMode: scanMode)
                validationResult = result
                scanState = .result

                // Cache granted results for offline use
                if result.isGranted, let contractor = result.contractor {
                    OfflineValidationCache.shared.cacheGrantedValidation(
                        contractorId: contractor.id,
                        response: result
                    )
                }

                // Save to scan history
                let historyEntry = ScanHistoryEntry(from: result, scanMode: scanMode)
                ScanHistoryManager.shared.addEntry(historyEntry)

                // Auto-reset after 8 seconds
                try? await Task.sleep(nanoseconds: 8_000_000_000)
                if scanState == .result {
                    resetScanner()
                }
            } catch {
                // Attempt offline validation before showing error
                if let offlineResult = OfflineValidationCache.shared.attemptOfflineValidation(qrData: code) {
                    validationResult = offlineResult
                    scanState = .result

                    let historyEntry = ScanHistoryEntry(from: offlineResult, scanMode: scanMode)
                    ScanHistoryManager.shared.addEntry(historyEntry)

                    try? await Task.sleep(nanoseconds: 8_000_000_000)
                    if scanState == .result {
                        resetScanner()
                    }
                } else {
                    errorMessage = error.localizedDescription
                    scanState = .error

                    try? await Task.sleep(nanoseconds: 5_000_000_000)
                    if scanState == .error {
                        resetScanner()
                    }
                }
            }
        }
    }

    private func resetScanner() {
        withAnimation(.easeInOut(duration: 0.3)) {
            scanState = .scanning
            validationResult = nil
            errorMessage = nil
            lastScannedCode = ""
            cameraState = .initializing
            scannerActive = true
        }
    }
}

// MARK: - Supporting Views

struct DetailRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(AppTheme.primary.opacity(0.10))
                    .frame(width: 36, height: 36)

                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(AppTheme.primary)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundColor(AppTheme.textSecondary)
                Text(value)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(AppTheme.textPrimary)
            }

            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}

struct ScanningLine: View {
    @State private var offset: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [AppTheme.primary.opacity(0), AppTheme.primary.opacity(0.8), AppTheme.primary.opacity(0)],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
                .frame(height: 2)
                .shadow(color: AppTheme.primary.opacity(0.5), radius: 8)
                .offset(y: offset)
                .onAppear {
                    withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                        offset = geo.size.height - 2
                    }
                }
        }
    }
}

// MARK: - Emergency Override Sheet

struct EmergencyOverrideSheet: View {
    let onSubmit: (Bool, String) -> Void
    let onCancel: () -> Void

    @State private var reason = ""
    @FocusState private var reasonFocused: Bool

    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Warning icon
                        ZStack {
                            Circle()
                                .fill(AppTheme.warning.opacity(0.10))
                                .frame(width: 80, height: 80)

                            Image(systemName: "exclamationmark.shield.fill")
                                .font(.system(size: 36))
                                .foregroundColor(AppTheme.warning)
                        }
                        .padding(.top, 8)

                        Text("Emergency Override")
                            .font(.title2.weight(.bold))
                            .foregroundColor(AppTheme.textPrimary)

                        Text("Manually grant or deny access without a QR code scan. This action will be logged in the audit trail.")
                            .font(.subheadline)
                            .foregroundColor(AppTheme.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)

                        // Reason input
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Reason (required)")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(AppTheme.textSecondary)

                            TextEditor(text: $reason)
                                .focused($reasonFocused)
                                .frame(minHeight: 100)
                                .padding(12)
                                .background(AppTheme.cardBackground)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .strokeBorder(AppTheme.secondary, lineWidth: 1)
                                )
                                .foregroundColor(AppTheme.textPrimary)
                        }
                        .padding(.horizontal, 4)

                        // Action buttons
                        VStack(spacing: 12) {
                            Button {
                                onSubmit(true, reason)
                            } label: {
                                HStack {
                                    Image(systemName: "checkmark.shield.fill")
                                    Text("Grant Access")
                                }
                                .font(.headline)
                                .foregroundColor(AppTheme.textOnPrimary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(AppTheme.success)
                                .cornerRadius(14)
                                .shadow(color: AppTheme.success.opacity(0.25), radius: 10, y: 4)
                            }
                            .disabled(reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            .opacity(reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)

                            Button {
                                onSubmit(false, reason)
                            } label: {
                                HStack {
                                    Image(systemName: "xmark.shield.fill")
                                    Text("Deny Access")
                                }
                                .font(.headline)
                                .foregroundColor(AppTheme.textOnPrimary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(AppTheme.danger)
                                .cornerRadius(14)
                            }
                            .disabled(reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            .opacity(reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)
                        }
                    }
                    .padding(20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") { onCancel() }
                        .foregroundColor(AppTheme.primary)
                }
            }
        }
    }
}

// MARK: - Reverse Mask

extension View {
    @ViewBuilder
    func reverseMask<Mask: View>(@ViewBuilder _ mask: () -> Mask) -> some View {
        self.mask(
            ZStack {
                Rectangle()
                mask()
                    .blendMode(.destinationOut)
            }
            .compositingGroup()
        )
    }
}
