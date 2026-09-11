import SwiftUI

enum InboxFilter: Hashable {
    case inProgress
    case completed
}

@MainActor
struct WorkInboxView: View {
    let hub: WorkHub
    let companion: CompanionStore
    var timer: FocusTimer?
    var compact: Bool = false

    @State private var filter: InboxFilter = .inProgress
    @State private var draftTitle = ""
    @State private var draftKind: WorkKind = .task
    @State private var draftGoalTarget = 3
    @State private var draftRoutineSteps = ""

    private var l: L { companion.l }
    private var today: String { hub.todayKey }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("", selection: $filter) {
                Text(l.inboxInProgress).tag(InboxFilter.inProgress)
                Text(l.inboxCompleted).tag(InboxFilter.completed)
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            if !compact {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        TextField(l.newItemTitle, text: $draftTitle)
                            .textFieldStyle(.roundedBorder)
                        Picker("", selection: $draftKind) {
                            Text(l.workKindLabel(.task)).tag(WorkKind.task)
                            Text(l.workKindLabel(.habit)).tag(WorkKind.habit)
                            Text(l.workKindLabel(.routine)).tag(WorkKind.routine)
                            Text(l.workKindLabel(.goal)).tag(WorkKind.goal)
                        }
                        .frame(width: 110)
                        Button(l.addTask) {
                            let title = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !title.isEmpty else { return }
                            let steps = draftRoutineSteps
                                .split(separator: ",")
                                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                                .filter { !$0.isEmpty }
                                .map { RoutineStep(title: String($0)) }
                            _ = hub.addNative(
                                title: title,
                                kind: draftKind,
                                subtasks: draftKind == .routine ? steps : [],
                                goalTarget: draftKind == .goal ? max(1, draftGoalTarget) : nil)
                            draftTitle = ""
                            draftRoutineSteps = ""
                        }
                        .disabled(draftTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    if draftKind == .goal {
                        Stepper(value: $draftGoalTarget, in: 1...99) {
                            Text(l.goalTargetLabel(draftGoalTarget))
                                .font(.caption)
                        }
                    }
                    if draftKind == .routine {
                        TextField(l.routineStepsPlaceholder, text: $draftRoutineSteps)
                            .textFieldStyle(.roundedBorder)
                    }
                }
            }

            let rows = hub.inbox(status: filter == .inProgress ? .inProgress : .completed)
                + (filter == .inProgress ? hub.inbox(status: .todo) : [])
            if rows.isEmpty {
                Text(l.inboxEmpty)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(rows) { item in
                            WorkItemRow(
                                item: item,
                                today: today,
                                l: l,
                                compact: compact,
                                onComplete: { Task { await hub.complete(item, companion: companion) } },
                                onAssignTimer: timer.map { t in { t.assign(item); t.start() } },
                                onToggleStep: { stepID in
                                    Task { await hub.toggleRoutineStep(item, stepID: stepID, companion: companion) }
                                },
                                onIncrementGoal: { hub.incrementGoal(item, companion: companion) }
                            )
                        }
                    }
                }
            }
        }
    }
}

@MainActor
private struct WorkItemRow: View {
    let item: WorkItem
    let today: String
    let l: L
    var compact: Bool
    var onComplete: () -> Void
    var onAssignTimer: (() -> Void)?
    var onToggleStep: (UUID) -> Void
    var onIncrementGoal: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(l.workKindLabel(item.kind))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(item.title)
                    .font(.callout.weight(.semibold))
                    .lineLimit(compact ? 1 : 2)
                Spacer()
                if item.displayStatus(today: today) != .completed {
                    Button(l.markDone, action: onComplete)
                        .controlSize(.small)
                    if let onAssignTimer {
                        Button(l.timerAssign, action: onAssignTimer)
                            .controlSize(.small)
                    }
                }
            }
            if item.kind == .goal {
                Text("\((item.goalProgress ?? 0))/\(item.goalTarget ?? 0)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                if item.displayStatus(today: today) != .completed {
                    Button("+1", action: onIncrementGoal)
                        .controlSize(.mini)
                }
            }
            if item.kind == .routine, !compact {
                ForEach(item.subtasks) { step in
                    Button {
                        onToggleStep(step.id)
                    } label: {
                        HStack {
                            Image(systemName: step.isDone ? "checkmark.circle.fill" : "circle")
                            Text(step.title)
                        }
                        .font(.caption)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(8)
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
