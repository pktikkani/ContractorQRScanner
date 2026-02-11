import SwiftUI

struct ScannerView: View {
    @State private var scanState: ScanState = .scanning
    @State private var validationResult: ValidationResponse?
    @State private var errorMessage: String?
    @State private var scannerActive = true

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
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(AppTheme.primaryGradient)
                    .frame(width: 48, height: 48)
                    .shadow(color: AppTheme.primary.opacity(0.5), radius: 10)

                Image(systemName: "qrcode.viewfinder")
                    .font(.title2.weight(.semibold))
                    .foregroundColor(.white)
            }

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
                    .shadow(color: (scanState == .scanning ? AppTheme.success : AppTheme.primary).opacity(0.8), radius: 4)

                Text(scanState == .scanning ? "Ready" : "Busy")
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(scanState == .scanning ? AppTheme.success : AppTheme.primary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill((scanState == .scanning ? AppTheme.success : AppTheme.primary).opacity(0.15))
            )
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }

    // MARK: - Scanning View

    private var scanningView: some View {
        VStack(spacing: 16) {
            ZStack {
                if scannerActive {
                    QRScannerCamera { code in
                        handleScannedCode(code)
                    }
                }

                scanFrameOverlay
            }
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .padding(.horizontal, 20)

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
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppTheme.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(AppTheme.primary.opacity(0.2), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 20)
        }
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
                    .fill(AppTheme.primary.opacity(0.1))
                    .frame(width: 120, height: 120)

                Circle()
                    .fill(AppTheme.primary.opacity(0.2))
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
                    .fill(AppTheme.success.opacity(0.15))
                    .frame(width: 160, height: 160)

                Circle()
                    .fill(AppTheme.successGradient)
                    .frame(width: 120, height: 120)
                    .shadow(color: AppTheme.success.opacity(0.6), radius: 30)

                Image(systemName: "checkmark")
                    .font(.system(size: 56, weight: .bold))
                    .foregroundColor(.white)
            }

            Text("ACCESS GRANTED")
                .font(.system(size: 32, weight: .black))
                .foregroundColor(AppTheme.success)

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
                                    .shadow(color: AppTheme.success.opacity(0.4), radius: 10)

                                ZStack {
                                    Circle()
                                        .fill(AppTheme.success)
                                        .frame(width: 28, height: 28)

                                    Image(systemName: "checkmark")
                                        .font(.caption.weight(.bold))
                                        .foregroundColor(.white)
                                }
                            }
                        }
                        .padding(.bottom, 4)
                    } else {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(AppTheme.warning)
                                .font(.caption)
                            Text("No photo on file")
                                .font(.caption.weight(.medium))
                                .foregroundColor(AppTheme.warning)
                        }
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
                        .overlay(
                            RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                                .strokeBorder(AppTheme.success.opacity(0.3), lineWidth: 1)
                        )
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
                    .fill(AppTheme.danger.opacity(0.15))
                    .frame(width: 160, height: 160)

                Circle()
                    .fill(AppTheme.dangerGradient)
                    .frame(width: 120, height: 120)
                    .shadow(color: AppTheme.danger.opacity(0.6), radius: 30)

                Image(systemName: "xmark")
                    .font(.system(size: 56, weight: .bold))
                    .foregroundColor(.white)
            }

            Text("ACCESS DENIED")
                .font(.system(size: 32, weight: .black))
                .foregroundColor(AppTheme.danger)

            if let reason = result.reason {
                Text(reason)
                    .font(.body.weight(.medium))
                    .foregroundColor(AppTheme.danger.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(AppTheme.danger.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(AppTheme.danger.opacity(0.3), lineWidth: 1)
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
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(AppTheme.primaryGradient)
            .cornerRadius(14)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }

    // MARK: - Error View

    private var errorView: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(AppTheme.warning.opacity(0.15))
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
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(AppTheme.primaryGradient)
                .cornerRadius(14)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }

    // MARK: - Actions

    private func handleScannedCode(_ code: String) {
        scannerActive = false
        scanState = .validating

        Task {
            do {
                let result = try await APIClient.shared.validateQRCode(qrData: code)
                validationResult = result
                scanState = .result

                // Auto-reset after 8 seconds
                try? await Task.sleep(nanoseconds: 8_000_000_000)
                if scanState == .result {
                    resetScanner()
                }
            } catch {
                errorMessage = error.localizedDescription
                scanState = .error

                try? await Task.sleep(nanoseconds: 5_000_000_000)
                if scanState == .error {
                    resetScanner()
                }
            }
        }
    }

    private func resetScanner() {
        withAnimation(.easeInOut(duration: 0.3)) {
            scanState = .scanning
            validationResult = nil
            errorMessage = nil
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
                    .fill(AppTheme.primary.opacity(0.15))
                    .frame(width: 36, height: 36)

                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(AppTheme.primary)
            }

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
