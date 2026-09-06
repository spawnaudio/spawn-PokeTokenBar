import SwiftUI

@MainActor
struct TimeXPView: View {
    let store: UsageStore
    let companion: CompanionStore

    private var l: L { companion.l }

    var body: some View {
        @Bindable var store = store
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(l.timeXPTitle)
                    .font(.callout.weight(.semibold))
                Spacer()
                Toggle("", isOn: $store.timeOpenXPEnabled)
                    .labelsHidden()
            }

            Text(l.timeOpenXPHint)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Text(l.timeXPRewardRate)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)

            ProgressView(
                value: Double(companion.state.timeOpenAwardedToday),
                total: Double(TimeOpenXP.dailyCap))
            .tint(.orange)
            .controlSize(.small)

            infoRow(label: l.timeXPTodayAwarded, value: TokenFormatter.compact(companion.state.timeOpenAwardedToday))
            infoRow(label: l.timeXPDailyCap, value: TokenFormatter.compact(TimeOpenXP.dailyCap))
            nextAwardRow(enabled: store.timeOpenXPEnabled, lastAwardAt: companion.state.lastTimeOpenAwardAt)

            Spacer(minLength: 0)
        }
        .frame(height: 520)
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.callout.monospacedDigit())
        }
    }

    @ViewBuilder
    private func nextAwardRow(enabled: Bool, lastAwardAt: Date?) -> some View {
        HStack {
            Text(l.timeXPNextAward)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            if !enabled {
                Text(l.timeXPPaused)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else if let lastAwardAt {
                Text(lastAwardAt.addingTimeInterval(TimeOpenXP.awardIntervalSeconds), style: .relative)
                    .font(.callout.monospacedDigit())
            } else {
                Text(l.timeXPWaiting)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
