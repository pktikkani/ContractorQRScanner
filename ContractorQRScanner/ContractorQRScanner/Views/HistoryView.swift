import SwiftUI

struct HistoryView: View {
    @State private var historyManager = ScanHistoryManager.shared
    @State private var searchText = ""
    @State private var filterResult: String? = nil
    @State private var showClearConfirmation = false

    private var filteredEntries: [ScanHistoryEntry] {
        var results = historyManager.entries

        if let filter = filterResult {
            results = results.filter { $0.result == filter }
        }

        if !searchText.isEmpty {
            results = results.filter {
                $0.contractorName.localizedCaseInsensitiveContains(searchText) ||
                ($0.company?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                ($0.email?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }

        return results
    }

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                filterBar
                    .padding(.top, 8)

                if filteredEntries.isEmpty {
                    emptyState
                } else {
                    logList
                }
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

                Image(systemName: "clock.arrow.circlepath")
                    .font(.title2.weight(.semibold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Scan History")
                    .font(.title2.weight(.bold))
                    .foregroundColor(AppTheme.textPrimary)

                Text("\(historyManager.entries.count) scans recorded")
                    .font(.caption)
                    .foregroundColor(AppTheme.textSecondary)
            }

            Spacer()

            if !historyManager.entries.isEmpty {
                Button {
                    showClearConfirmation = true
                } label: {
                    Image(systemName: "trash")
                        .font(.body)
                        .foregroundColor(AppTheme.danger)
                        .padding(10)
                        .background(
                            Circle()
                                .fill(AppTheme.danger.opacity(0.15))
                        )
                }
                .accessibilityLabel("Clear history")
                .accessibilityHint("Double tap to delete all scan history")
                .alert("Clear History", isPresented: $showClearConfirmation) {
                    Button("Cancel", role: .cancel) {}
                    Button("Clear All", role: .destructive) {
                        historyManager.clearHistory()
                    }
                } message: {
                    Text("This will permanently delete all scan history.")
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(AppTheme.textSecondary)
                    .font(.subheadline)
                    .accessibilityHidden(true)

                TextField("Search by name, company...", text: $searchText)
                    .font(.subheadline)
                    .foregroundColor(AppTheme.textPrimary)
                    .accessibilityLabel("Search scan history")

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(AppTheme.textSecondary)
                            .font(.subheadline)
                    }
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppTheme.cardBackground)
            )
            .padding(.horizontal, 20)

            HStack(spacing: 8) {
                FilterChip(label: "All", isSelected: filterResult == nil) {
                    filterResult = nil
                }
                FilterChip(label: "Granted", isSelected: filterResult == "granted") {
                    filterResult = "granted"
                }
                FilterChip(label: "Denied", isSelected: filterResult == "denied") {
                    filterResult = "denied"
                }

                Spacer()

                Text("\(filteredEntries.count) results")
                    .font(.caption)
                    .foregroundColor(AppTheme.textSecondary)
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Log List

    private var logList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(filteredEntries) { entry in
                    ScanLogRow(entry: entry)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 20)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "clock")
                .font(.system(size: 48))
                .foregroundColor(AppTheme.textSecondary.opacity(0.5))

            Text(historyManager.entries.isEmpty ? "No Scans Yet" : "No Results")
                .font(.title3.weight(.semibold))
                .foregroundColor(AppTheme.textSecondary)

            Text(historyManager.entries.isEmpty
                 ? "Scan history will appear here after your first QR code scan."
                 : "Try adjusting your search or filter.")
                .font(.subheadline)
                .foregroundColor(AppTheme.textSecondary.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()
        }
    }
}

// MARK: - Scan Log Row

struct ScanLogRow: View {
    let entry: ScanHistoryEntry

    private var isGranted: Bool { entry.result == "granted" }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill((isGranted ? AppTheme.success : AppTheme.danger).opacity(0.15))
                    .frame(width: 40, height: 40)

                Image(systemName: isGranted ? "checkmark.shield.fill" : "xmark.shield.fill")
                    .font(.body)
                    .foregroundColor(isGranted ? AppTheme.success : AppTheme.danger)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(entry.contractorName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(AppTheme.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    if let company = entry.company {
                        Text(company)
                            .font(.caption)
                            .foregroundColor(AppTheme.textSecondary)
                            .lineLimit(1)
                    }

                    if entry.company != nil && entry.reason != nil {
                        Circle()
                            .fill(AppTheme.textSecondary)
                            .frame(width: 3, height: 3)
                    }

                    if let reason = entry.reason, !isGranted {
                        Text(reason)
                            .font(.caption)
                            .foregroundColor(AppTheme.danger.opacity(0.8))
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(isGranted ? "Granted" : "Denied")
                    .font(.caption2.weight(.bold))
                    .foregroundColor(isGranted ? AppTheme.success : AppTheme.danger)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill((isGranted ? AppTheme.success : AppTheme.danger).opacity(0.15))
                    )

                Text(entry.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(AppTheme.textSecondary)

                if !Calendar.current.isDateInToday(entry.timestamp) {
                    Text(entry.timestamp, style: .date)
                        .font(.caption2)
                        .foregroundColor(AppTheme.textSecondary.opacity(0.7))
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(AppTheme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(
                            (isGranted ? AppTheme.success : AppTheme.danger).opacity(0.1),
                            lineWidth: 1
                        )
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(entry.contractorName), \(isGranted ? "Granted" : "Denied")\(entry.company.map { ", \($0)" } ?? "")\(!isGranted && entry.reason != nil ? ", \(entry.reason!)" : "")")
    }
}

// MARK: - Filter Chip

struct FilterChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundColor(isSelected ? .white : AppTheme.textSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(isSelected ? AppTheme.primary : AppTheme.cardBackground)
                )
        }
        .accessibilityLabel("Filter: \(label)")
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityHint("Double tap to filter by \(label.lowercased())")
    }
}
