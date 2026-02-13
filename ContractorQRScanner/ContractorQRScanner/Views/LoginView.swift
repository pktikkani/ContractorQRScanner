import SwiftUI

struct LoginView: View {
    @ObservedObject var session: SessionManager
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showPassword = false
    @FocusState private var focusedField: Field?

    private enum Field { case email, password }

    var body: some View {
        ZStack {
            // Background
            AppTheme.background.ignoresSafeArea()

            // Subtle gradient orbs
            Circle()
                .fill(AppTheme.primary.opacity(0.06))
                .frame(width: 300, height: 300)
                .offset(x: -100, y: -280)
            Circle()
                .fill(AppTheme.secondary.opacity(0.08))
                .frame(width: 250, height: 250)
                .offset(x: 150, y: 320)

            ScrollView {
                VStack(spacing: 32) {
                    Spacer().frame(height: 60)

                    // Logo
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(AppTheme.primary.opacity(0.10))
                                .frame(width: 100, height: 100)

                            ZStack {
                                RoundedRectangle(cornerRadius: 18)
                                    .fill(AppTheme.primaryGradient)
                                    .frame(width: 72, height: 72)
                                    .shadow(color: AppTheme.primaryShadow, radius: 16)

                                Image(systemName: "shield.checkered")
                                    .font(.system(size: 32, weight: .semibold))
                                    .foregroundColor(AppTheme.textOnPrimary)
                            }
                        }

                        VStack(spacing: 6) {
                            Text("CAMS Scanner")
                                .font(.title.weight(.bold))
                                .foregroundColor(AppTheme.textPrimary)

                            Text("Guard Access Terminal")
                                .font(.subheadline)
                                .foregroundColor(AppTheme.textSecondary)
                        }
                    }

                    // Login form
                    VStack(spacing: 20) {
                        // Email field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Email")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(AppTheme.textSecondary)

                            HStack(spacing: 12) {
                                Image(systemName: "envelope.fill")
                                    .font(.subheadline)
                                    .foregroundColor(AppTheme.primary.opacity(0.6))
                                    .frame(width: 20)

                                TextField("guard@company.com", text: $email)
                                    .textContentType(.emailAddress)
                                    .keyboardType(.emailAddress)
                                    .autocapitalization(.none)
                                    .disableAutocorrection(true)
                                    .focused($focusedField, equals: .email)
                                    .submitLabel(.next)
                                    .onSubmit { focusedField = .password }
                            }
                            .padding(14)
                            .background(AppTheme.cardBackground)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(
                                        focusedField == .email ? AppTheme.primary : AppTheme.secondary.opacity(0.5),
                                        lineWidth: 1
                                    )
                            )
                        }

                        // Password field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Password")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(AppTheme.textSecondary)

                            HStack(spacing: 12) {
                                Image(systemName: "lock.fill")
                                    .font(.subheadline)
                                    .foregroundColor(AppTheme.primary.opacity(0.6))
                                    .frame(width: 20)

                                if showPassword {
                                    TextField("Enter password", text: $password)
                                        .focused($focusedField, equals: .password)
                                        .submitLabel(.go)
                                        .onSubmit { login() }
                                } else {
                                    SecureField("Enter password", text: $password)
                                        .focused($focusedField, equals: .password)
                                        .submitLabel(.go)
                                        .onSubmit { login() }
                                }

                                Button(action: { showPassword.toggle() }) {
                                    Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                                        .font(.subheadline)
                                        .foregroundColor(AppTheme.textSecondary)
                                }
                            }
                            .padding(14)
                            .background(AppTheme.cardBackground)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(
                                        focusedField == .password ? AppTheme.primary : AppTheme.secondary.opacity(0.5),
                                        lineWidth: 1
                                    )
                            )
                        }

                        // Error message
                        if let error = errorMessage {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .font(.caption)
                                Text(error)
                                    .font(.caption.weight(.medium))
                            }
                            .foregroundColor(AppTheme.danger)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(AppTheme.danger.opacity(0.08))
                            )
                        }

                        // Sign In button
                        Button(action: login) {
                            HStack(spacing: 10) {
                                if isLoading {
                                    ProgressView()
                                        .tint(AppTheme.textOnPrimary)
                                } else {
                                    Image(systemName: "arrow.right.circle.fill")
                                    Text("Sign In")
                                        .font(.headline)
                                }
                            }
                            .foregroundColor(AppTheme.textOnPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                isFormValid
                                    ? AnyShapeStyle(AppTheme.primaryGradient)
                                    : AnyShapeStyle(AppTheme.secondary)
                            )
                            .cornerRadius(14)
                            .shadow(color: isFormValid ? AppTheme.primaryShadow : .clear, radius: 12, y: 6)
                        }
                        .disabled(!isFormValid || isLoading)
                    }
                    .padding(24)
                    .background(
                        RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                            .fill(AppTheme.cardBackground)
                            .shadow(color: AppTheme.cardShadow, radius: 20, y: 8)
                    )
                    .padding(.horizontal, 24)

                    // Footer
                    Text("Contractor Access Management System")
                        .font(.caption2)
                        .foregroundColor(AppTheme.textSecondary.opacity(0.6))

                    Spacer().frame(height: 40)
                }
            }
        }
        .onTapGesture { focusedField = nil }
    }

    private var isFormValid: Bool {
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !password.isEmpty
    }

    private func login() {
        guard isFormValid, !isLoading else { return }
        focusedField = nil
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let response = try await APIClient.shared.scannerLogin(
                    email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                    password: password
                )

                let assignedSite: AssignedSite?
                if let site = response.assignedSite {
                    assignedSite = AssignedSite(
                        siteID: site.siteID,
                        siteCode: site.siteCode,
                        siteName: site.siteName
                    )
                } else {
                    assignedSite = nil
                }

                await MainActor.run {
                    // Store HMAC key before other calls so subsequent requests are signed
                    KeychainHelper.save(key: "hmac_signing_key", value: response.hmacKey)

                    session.saveLogin(
                        token: response.token,
                        guardName: response.guardName,
                        scannerID: response.scannerID,
                        assignedSite: assignedSite
                    )
                }

                // Pre-download offline bundle if site is already assigned
                if assignedSite != nil, let token = session.token {
                    if let bundle = try? await APIClient.shared.fetchOfflineBundle(token: token) {
                        OfflineValidationCache.shared.storeOfflineBundle(contractors: bundle.contractors)
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
                return
            }

            await MainActor.run {
                isLoading = false
            }
        }
    }
}
