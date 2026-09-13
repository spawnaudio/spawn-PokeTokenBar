import SwiftUI

/// Compact glance (Focus) or full today header (Usage). Provider split is generic —
/// no per-providerID branches here.
@MainActor
struct TodayUsageSummary: View {
    @Environment(UsageStore.self) private var store
    @Environment(CompanionStore.self) private var companion
    var compact: Bool = false
    var showsRefresh: Bool = false
    var onTap: (() -> Void)? = nil

    private var l: L { companion.l }
    private var weekTokens: Int { store.weekTotalTokens }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 8 : 6) {
            HStack {
                PopoverSectionLabel(text: l.todayUsageSection)
                Spacer()
                if showsRefresh {
                    Button {
                        Task { await store.refresh() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .tahoeButtonStyle(.accessory)
                    .buttonBorderShape(.circle)
                    .controlSize(.small)
                    .help(l.refreshNow)
                    .accessibilityLabel(l.refreshNow)
                }
            }
            Group {
                if let onTap {
                    Button(action: onTap) { totals }
                        .buttonStyle(.plain)
                } else {
                    totals
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var totals: some View {
        VStack(alignment: .leading, spacing: compact ? 8 : 6) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(TokenFormatter.compact(store.todayTotalTokens))
                    .font(.system(size: compact ? 28 : 28, weight: .bold, design: .rounded))
                    .monospacedDigit()
                if weekTokens > 0 {
                    Text("/ \(TokenFormatter.compact(weekTokens))")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Spacer()
                if store.showsCost {
                    UsageCostText(cost: store.todayUsageCost, l: l)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            if weekTokens > 0 {
                HStack(spacing: 8) {
                    MutedProgressBar(value: Double(store.todayTotalTokens), total: Double(weekTokens))
                    Text(TokenFormatter.percent(Double(store.todayTotalTokens) / Double(weekTokens) * 100))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .monospacedDigit()
                }
            }
            ForEach(store.snapshots) { snap in
                if let today = snap.today {
                    providerShareRow(snapshot: snap, today: today)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func providerShareRow(snapshot: ProviderSnapshot, today: DailyUsage) -> some View {
        let total = store.todayTotalTokens
        let share = total > 0 ? Double(today.totalTokens) / Double(total) * 100 : 0
        return HStack {
            Text(snapshot.displayName)
                .font(.callout.weight(.semibold))
            Spacer()
            Text(TokenFormatter.compact(today.totalTokens))
                .font(.callout)
                .monospacedDigit()
            Text(TokenFormatter.percent(share))
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .frame(width: 40, alignment: .trailing)
        }
    }
}

@MainActor
struct UsageTabView: View {
    @Environment(UsageStore.self) private var store
    @Environment(CompanionStore.self) private var companion
    @Environment(PopoverNavigation.self) private var nav

    private var l: L { companion.l }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                totalsCard
                providerStatusBanner
                if selectedProviderHasLimits {
                    limitsSection
                        .popoverCard()
                }
                TimeXPView(store: store, companion: companion, compact: true)
                    .popoverCard()
            }
        }
        .frame(minHeight: 420)
    }

    private var totalsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                PopoverSectionLabel(text: l.todayUsageSection)
                Spacer()
                Button {
                    Task { await store.refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .tahoeButtonStyle(.accessory)
                .buttonBorderShape(.circle)
                .controlSize(.small)
                .help(l.refreshNow)
            }
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(TokenFormatter.compact(store.todayTotalTokens))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text(TokenFormatter.grouped(store.todayTotalTokens))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                Spacer()
                if store.showsCost {
                    UsageCostText(cost: store.todayUsageCost, l: l)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            if let updated = store.lastUpdated {
                (Text("\(l.updated) ") + Text(updated, style: .relative))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            if store.lastErrorDescription != nil {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                    .help(store.lastErrorDescription ?? "")
            }
            if store.weekTotalTokens > 0 || store.monthTotalTokens > 0 {
                HStack(spacing: 14) {
                    periodLabel(l.thisWeek, tokens: store.weekTotalTokens, cost: store.showsCost ? store.weekUsageCost : nil)
                    periodLabel(l.thisMonth, tokens: store.monthTotalTokens, cost: store.showsCost ? store.monthUsageCost : nil)
                    Spacer()
                }
            }
            MonthDailyTrend(series: store.monthDailyTotals,
                            showsCost: store.showsCost,
                            today: LocalUsageReader.todayKey(),
                            l: l)
            if store.snapshots.count > 1 {
                ProviderTabBar(
                    snapshots: store.snapshots,
                    selectedID: selectedSnapshot?.providerID,
                    onSelect: { nav.providerID = $0 })
            }
            if let snap = selectedSnapshot, let today = snap.today {
                providerRow(snapshot: snap, today: today)
            }
        }
        .popoverCard()
    }

    private var selectedSnapshot: ProviderSnapshot? {
        store.snapshot(preferring: nav.providerID)
    }

    private func periodLabel(_ name: String, tokens: Int, cost: UsageCost?) -> some View {
        HStack(spacing: 4) {
            Text(name)
                .font(.caption)
                .foregroundStyle(.tertiary)
            Text(TokenFormatter.compact(tokens))
                .font(.caption.weight(.semibold))
                .monospacedDigit()
            if let cost {
                UsageCostText(cost: cost, l: l)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func providerRow(snapshot: ProviderSnapshot, today: DailyUsage) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(snapshot.displayName)
                    .font(.callout.weight(.semibold))
                Spacer()
                Text(TokenFormatter.compact(today.totalTokens))
                    .font(.callout)
                    .monospacedDigit()
                if snapshot.reportsCost {
                    UsageCostText(cost: today.usageCost, l: l)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            HStack(spacing: 10) {
                tokenTypeLabel(l.tokenInput, today.inputTokens)
                tokenTypeLabel(l.tokenOutput, today.outputTokens)
                tokenTypeLabel(l.tokenCacheWrite, today.cacheCreationTokens)
                tokenTypeLabel(l.tokenCacheRead, today.cacheReadTokens)
            }
            if let models = today.models, models.count > 1 {
                ForEach(models.sorted(by: { $0.value > $1.value }), id: \.key) { model, tokens in
                    HStack(spacing: 6) {
                        Text(model.split(separator: "/").last.map(String.init) ?? model)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                        Text(TokenFormatter.compact(tokens))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .monospacedDigit()
                    }
                }
            }
        }
        .padding(.top, 2)
    }

    private func tokenTypeLabel(_ name: String, _ value: Int) -> some View {
        HStack(spacing: 3) {
            Text(name)
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Text(TokenFormatter.compact(value))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }

    /// Official limits for the selected provider only (Gemini has none → omit).
    private var selectedProviderHasLimits: Bool {
        switch selectedSnapshot?.providerID {
        case "claude_code": return !store.disableKeychainAccess || store.limits != nil || store.limitsAuthExpired
        case "codex": return store.codexLimits?.hasVisibleLimit == true
        case "antigravity": return !store.disableKeychainAccess || store.antigravityLimits?.hasVisibleLimit == true || store.antigravityLimitsAuthExpired
        default: return false
        }
    }

    @ViewBuilder
    private var providerStatusBanner: some View {
        if let id = selectedSnapshot?.providerID,
           let status = store.providerStatus(for: id), status.indicator.hasIssue {
            HStack(spacing: 6) {
                Circle().fill(statusColor(status.indicator)).frame(width: 7, height: 7)
                Text(l.providerStatusLabel(status.indicator))
                    .font(.caption).fontWeight(.medium)
                if !status.description.isEmpty {
                    Text(status.description)
                        .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer()
            }
            .popoverCard()
        }
    }

    private func statusColor(_ indicator: ProviderStatusIndicator) -> Color {
        switch indicator {
        case .operational:         return .green
        case .minor, .maintenance: return .yellow
        case .major:               return .orange
        case .critical:            return .red
        case .unknown:             return .gray
        }
    }

    @ViewBuilder
    private var limitsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            PopoverSectionLabel(text: l.limitsOfficial)
            if selectedSnapshot?.providerID == "claude_code", store.limitsAuthExpiry == .sessionKey {
                sessionKeyExpiredNotice
            } else if selectedSnapshot?.providerID == "claude_code", store.limitsAuthExpired {
                claudeAuthExpiredNotice
            } else if selectedSnapshot?.providerID == "claude_code",
                      !store.disableKeychainAccess,
                      store.limits == nil || store.claudeLimitsStale {
                claudeLimitsRefreshRow
            }
            if selectedSnapshot?.providerID == "claude_code", let limits = store.limits {
                if let plan = limits.planDisplay {
                    Text(l.plan(plan))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                if let account = limits.accountDisplay {
                    Text(l.limitsAccount(account))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                VStack(alignment: .leading, spacing: 8) {
                    limitRow(name: l.fiveHourSession, window: limits.fiveHour)
                    forecastRow
                    limitRow(name: l.weekly, window: limits.sevenDay)
                    limitRow(name: l.weeklyOpus, window: limits.sevenDayOpus)
                    limitRow(name: l.weeklySonnet, window: limits.sevenDaySonnet)
                    ForEach(Array(limits.scopedLimitEntries.enumerated()), id: \.offset) { _, entry in
                        limitRow(
                            name: l.claudeLimitEntry(kind: entry.kind, model: entry.scope?.model?.displayName),
                            window: LimitWindow(utilization: entry.percent, resetsAt: entry.resetsAt))
                    }
                    if let block = store.snapshots.first(where: { $0.providerID == "claude_code" })?.activeBlock,
                       let end = block.endDate {
                        HStack {
                            Text(l.claudeCurrentBlock)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(TokenFormatter.compact(block.totalTokens))
                                .font(.caption)
                                .monospacedDigit()
                            Spacer()
                            (Text("\(l.reset) ") + Text(end, style: .relative))
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                .opacity(store.limitsAuthExpired ? 0.5 : 1)
            }
            if selectedSnapshot?.providerID == "codex",
               let codexStatus = store.codexLimits, codexStatus.hasVisibleLimit {
                let buckets = codexStatus.visibleSnapshots
                codexMetaRow(codexStatus)
                ForEach(Array(buckets.enumerated()), id: \.offset) { _, bucket in
                    if buckets.count > 1 {
                        Text(bucket.bucketDisplayName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.top, 2)
                    }
                    codexLimitRow(name: l.codexWindow(bucket.primary?.windowDurationMins), window: bucket.primary)
                    codexLimitRow(name: l.codexWindow(bucket.secondary?.windowDurationMins), window: bucket.secondary)
                    codexSpendLimitRow(bucket.individualLimit)
                }
            }
            if selectedSnapshot?.providerID == "antigravity" {
                antigravityLimitsContent
            }
        }
    }

    @ViewBuilder
    private var antigravityLimitsContent: some View {
        if store.antigravityLimitsAuthExpired {
            antigravityAuthExpiredNotice
        } else if !store.disableKeychainAccess && (store.antigravityLimits == nil || store.antigravityLimitsStale) {
            antigravityRefreshRow
        }
        if let status = store.antigravityLimits, status.hasVisibleLimit {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(status.groups.enumerated()), id: \.offset) { _, group in
                    VStack(alignment: .leading, spacing: 4) {
                        let groupTitle = group.displayName.localizedCaseInsensitiveContains("gemini")
                            ? l.antigravityGeminiGroup
                            : (group.displayName.localizedCaseInsensitiveContains("claude") ? l.antigravityThirdPartyGroup : group.displayName)
                        Text(groupTitle)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        ForEach(group.buckets, id: \.bucketId) { bucket in
                            antigravityBucketRow(bucket)
                        }
                    }
                }
            }
            .opacity(store.antigravityLimitsAuthExpired ? 0.5 : 1)
        }
    }

    @ViewBuilder
    private func antigravityBucketRow(_ bucket: AntigravityQuotaBucket) -> some View {
        let name = l.antigravityWindow(window: bucket.window, bucketId: bucket.bucketId)
        quotaRow(name: name, utilization: bucket.usedPercent, reset: bucket.resetDate)
    }

    @ViewBuilder
    private var antigravityRefreshRow: some View {
        HStack(spacing: 6) {
            if store.antigravityLimits == nil {
                Text(l.limitsTapToLoad)
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                (Text(l.staleLimits) + Text(" · ") + Text(store.antigravityLimitsUpdatedAt ?? Date(), style: .relative))
                    .font(.caption).foregroundStyle(.orange)
            }
            Spacer()
            Button {
                Task { await store.refreshAntigravityLimitsFromKeychain() }
            } label: {
                if store.isRefreshingAntigravityLimits {
                    ProgressView().controlSize(.small)
                } else {
                    Text(l.refresh)
                }
            }
            .tahoeButtonStyle(.regular)
            .controlSize(.small)
            .disabled(store.isRefreshingAntigravityLimits)
        }
    }

    @ViewBuilder
    private var antigravityAuthExpiredNotice: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text(l.antigravityAuthExpiredTitle)
                    .font(.caption).fontWeight(.medium)
            }
            Text(l.antigravityAuthExpiredHint)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Button(l.retry) {
                Task { await store.refreshAntigravityLimitsFromKeychain() }
            }
            .tahoeButtonStyle(.prominent)
            .controlSize(.mini)
            .padding(.top, 2)
        }
        .padding(8)
        .background(Color.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func limitPercentText(_ utilization: Double) -> String {
        let text = TokenFormatter.percent(store.limitDisplayPercent(utilization))
        return store.limitDisplayMode == .remaining ? l.percentRemaining(text) : text
    }

    private static let resetClockWindow: TimeInterval = 6 * 3600

    private func resetClockSuffix(_ reset: Date) -> Text {
        let f = DateFormatter()
        f.locale = companion.language.displayLocale
        let nearby = Calendar.current.isDateInToday(reset)
            || reset.timeIntervalSinceNow <= Self.resetClockWindow
        f.setLocalizedDateFormatFromTemplate(nearby ? "HHmm" : "EEEEdHHmm")
        return Text(" (\(f.string(from: reset)))")
    }

    private func resetLabel(_ reset: Date) -> Text {
        Text("\(reset, style: .relative)") + resetClockSuffix(reset)
    }

    @ViewBuilder
    private func limitRow(name: String, window: LimitWindow?) -> some View {
        if let window, let utilization = window.utilization {
            quotaRow(name: name, utilization: utilization, reset: window.resetDate)
        }
    }

    /// All quota types share the same trailing percentage alignment.
    private func quotaRow(name: String, utilization: Double, reset: Date?,
                          detail: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(name).font(.callout)
                Spacer()
                if let detail {
                    Text(detail)
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                if let reset {
                    resetLabel(reset)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                Text(limitPercentText(utilization))
                    .font(.callout)
                    .monospacedDigit()
                    .foregroundStyle(limitColor(utilization))
            }
            LimitProgressBar(usedPercent: utilization, tint: limitColor(utilization))
        }
    }

    @ViewBuilder
    private func codexMetaRow(_ status: CodexRateLimitStatus) -> some View {
        let planType = status.rateLimits.planType ?? status.visibleSnapshots.first?.planType
        let reached = status.visibleSnapshots.contains { $0.rateLimitReachedType != nil }
        if planType != nil || reached || store.codexLimitsStale {
            HStack(spacing: 8) {
                if let plan = planType {
                    Text(l.plan(plan))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                if reached {
                    Text(l.limitReached)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                if store.codexLimitsStale {
                    staleBadge(updatedAt: store.codexLimitsUpdatedAt)
                }
            }
        }
    }

    @ViewBuilder
    private var sessionKeyExpiredNotice: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "key.slash.fill")
                    .foregroundStyle(.orange)
                Text(l.sessionKeyExpiredTitle)
                    .font(.caption).fontWeight(.semibold)
                Spacer()
                Button(l.settings) { nav.openSessionKeySettings() }
                    .tahoeButtonStyle(.regular)
                    .controlSize(.small)
            }
            Text(l.sessionKeyExpiredNoticeHint)
                .font(.caption2).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(8)
        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var claudeAuthExpiredNotice: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text(l.claudeAuthExpiredTitle)
                    .font(.caption).fontWeight(.semibold)
                Spacer()
                Button {
                    Task { await store.refreshLimitTokenFromKeychain() }
                } label: {
                    if store.isRefreshingLimitToken {
                        ProgressView().controlSize(.small)
                    } else {
                        Text(l.retry)
                    }
                }
                .tahoeButtonStyle(.prominent)
                .controlSize(.small)
                .disabled(store.isRefreshingLimitToken)
            }
            Text(l.claudeAuthExpiredHint)
                .font(.caption2).foregroundStyle(.secondary)
        }
        .padding(8)
        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    @ViewBuilder
    private var claudeLimitsRefreshRow: some View {
        HStack(spacing: 6) {
            if store.limits == nil {
                Text(l.limitsTapToLoad)
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                (Text(l.staleLimits) + Text(" · ") + Text(store.limitsUpdatedAt ?? Date(), style: .relative))
                    .font(.caption).foregroundStyle(.orange)
            }
            Spacer()
            Button {
                Task { await store.refreshLimitTokenFromKeychain() }
            } label: {
                if store.isRefreshingLimitToken {
                    ProgressView().controlSize(.small)
                } else {
                    Text(l.refresh)
                }
            }
            .tahoeButtonStyle(.regular)
            .controlSize(.small)
            .disabled(store.isRefreshingLimitToken)
        }
    }

    @ViewBuilder
    private func staleBadge(updatedAt: Date?) -> some View {
        if let updatedAt {
            (Text(l.staleLimits) + Text(" · ") + Text(updatedAt, style: .relative))
                .font(.caption)
                .foregroundStyle(.orange)
        }
    }

    @ViewBuilder
    private func codexLimitRow(name: String, window: CodexRateLimitWindow?) -> some View {
        if let window {
            quotaRow(name: name, utilization: Double(window.usedPercent), reset: window.resetDate)
        }
    }

    @ViewBuilder
    private func codexSpendLimitRow(_ limit: CodexSpendControlLimit?) -> some View {
        if let limit {
            quotaRow(name: l.personalSpendLimit,
                     utilization: Double(limit.usedPercent),
                     reset: limit.resetDate,
                     detail: "\(limit.used) / \(limit.limit)")
        }
    }

    @ViewBuilder
    private var forecastRow: some View {
        if let forecast = store.fiveHourForecast {
            HStack(spacing: 4) {
                Image(systemName: forecast.beforeReset
                    ? "exclamationmark.triangle.fill" : "checkmark.circle")
                    .font(.caption2)
                Text(forecast.beforeReset
                    ? l.forecastReach(Self.timeFormatter.string(from: forecast.depletionDate))
                    : l.forecastNoReach)
                    .font(.caption)
            }
            .foregroundStyle(forecast.beforeReset ? AnyShapeStyle(.orange) : AnyShapeStyle(.tertiary))
            .padding(.leading, 2)
        }
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    private func limitColor(_ utilization: Double) -> Color {
        if utilization >= store.critThreshold { return .red }
        if utilization >= store.warnThreshold { return .orange }
        return .green
    }
}

/// Horizontal provider chips. Capsule text stays one line; overflow scrolls.
@MainActor
struct ProviderTabBar: View {
    let snapshots: [ProviderSnapshot]
    let selectedID: String?
    let onSelect: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(snapshots) { snap in
                    let isSelected = snap.providerID == selectedID
                    Button { onSelect(snap.providerID) } label: {
                        Text(snap.displayName)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                            .font(.caption.weight(isSelected ? .semibold : .regular))
                            .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                    }
                    .controlSize(.small)
                    .linearSegmentChrome(selected: isSelected)
                }
            }
        }
        .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
    }
}

/// Text and fill describe the same quantity; warning colors still represent actual usage.
@MainActor
struct LimitProgressBar: View {
    let usedPercent: Double
    let tint: Color
    @Environment(UsageStore.self) private var store

    var body: some View {
        ProgressView(value: min(100, max(0, store.limitDisplayPercent(usedPercent))), total: 100)
            .tint(tint)
            .controlSize(.small)
    }
}
