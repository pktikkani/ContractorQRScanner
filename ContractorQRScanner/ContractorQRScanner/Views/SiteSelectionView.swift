import SwiftUI

struct SiteSelectionView: View {
    @ObservedObject var session: SessionManager
    @State private var sites: [SiteItem] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedSiteID: String?
    @State private var isAssigning = false

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(AppTheme.primary.opacity(0.10))
                            .frame(width: 72, height: 72)

                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(AppTheme.primary)
                    }

                    Text("Select Your Site")
                        .font(.title2.weight(.bold))
                        .foregroundColor(AppTheme.textPrimary)

                    Text("Welcome, \(session.guardName)")
                        .font(.subheadline)
                        .foregroundColor(AppTheme.textSecondary)
                }
                .padding(.top, 40)
                .padding(.bottom, 24)

                if isLoading {
                    Spacer()
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(AppTheme.primary)
                    Text("Loading sites...")
                        .font(.subheadline)
                        .foregroundColor(AppTheme.textSecondary)
                        .padding(.top, 12)
                    Spacer()
                } else if let error = errorMessage {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(AppTheme.warning)

                        Text(error)
                            .font(.subheadline)
                            .foregroundColor(AppTheme.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)

                        Button("Retry") { loadSites() }
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(AppTheme.primary)
                    }
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(sites) { site in
                                SiteRow(
                                    site: site,
                                    isSelected: selectedSiteID == site.id,
                                    onTap: { selectedSiteID = site.id }
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 100)
                    }
                }

                // Assign button
                if !isLoading && errorMessage == nil {
                    VStack(spacing: 0) {
                        Divider()
                        Button(action: assignSite) {
                            HStack(spacing: 10) {
                                if isAssigning {
                                    ProgressView()
                                        .tint(AppTheme.textOnPrimary)
                                } else {
                                    Image(systemName: "checkmark.circle.fill")
                                    Text("Assign & Continue")
                                        .font(.headline)
                                }
                            }
                            .foregroundColor(AppTheme.textOnPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                selectedSiteID != nil
                                    ? AnyShapeStyle(AppTheme.primaryGradient)
                                    : AnyShapeStyle(AppTheme.secondary)
                            )
                            .cornerRadius(14)
                        }
                        .disabled(selectedSiteID == nil || isAssigning)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                    }
                    .background(AppTheme.cardBackground)
                }
            }
        }
        .task { loadSites() }
    }

    private func loadSites() {
        guard let token = session.token else { return }
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let result = try await APIClient.shared.listSites(token: token)
                await MainActor.run {
                    sites = result
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to load sites: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }

    private func assignSite() {
        guard let token = session.token, let siteID = selectedSiteID else { return }
        guard let site = sites.first(where: { $0.id == siteID }) else { return }
        isAssigning = true

        Task {
            do {
                try await APIClient.shared.assignSite(token: token, siteID: siteID)

                let assigned = AssignedSite(
                    siteID: site.id,
                    siteCode: site.siteCode,
                    siteName: site.siteName
                )

                await MainActor.run {
                    session.saveAssignedSite(assigned)
                    isAssigning = false
                }

                // Pre-download offline bundle
                if let bundle = try? await APIClient.shared.fetchOfflineBundle(token: token) {
                    OfflineValidationCache.shared.storeOfflineBundle(contractors: bundle.contractors)
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to assign site: \(error.localizedDescription)"
                    isAssigning = false
                }
            }
        }
    }
}

// MARK: - Site Row

struct SiteRow: View {
    let site: SiteItem
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isSelected ? AppTheme.primary.opacity(0.12) : AppTheme.surfaceBackground)
                        .frame(width: 44, height: 44)

                    Image(systemName: "building.2.fill")
                        .font(.subheadline)
                        .foregroundColor(isSelected ? AppTheme.primary : AppTheme.textSecondary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(site.siteName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(AppTheme.textPrimary)

                    Text(site.siteCode)
                        .font(.caption)
                        .foregroundColor(AppTheme.textSecondary)

                    if !site.address.isEmpty {
                        Text(site.address)
                            .font(.caption2)
                            .foregroundColor(AppTheme.textSecondary.opacity(0.7))
                            .lineLimit(1)
                    }
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(AppTheme.primary)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(AppTheme.cardBackground)
                    .shadow(color: AppTheme.cardShadow, radius: isSelected ? 12 : 6, y: isSelected ? 4 : 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(isSelected ? AppTheme.primary.opacity(0.4) : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}
