import SwiftUI

/// Pet + island while a session is running. Prompts sit above the island.
@MainActor
struct SessionIslandView: View {
    @Environment(UsageStore.self) private var store
    @Environment(CompanionStore.self) private var companion
    @Environment(FocusSessionStore.self) private var session

    private var l: L { companion.l }

    var body: some View {
        if session.pomodoroSetupOpen, session.session == nil {
            PomodoroSetupIsland()
        } else if let current = session.session {
            let issue = store.linearIssue(id: current.issue.id) ?? current.issue.summary
            let clock = session.clockDisplay()
            VStack(alignment: .leading, spacing: 6) {
                if let warning = session.forfeitPrompt {
                    FocusForfeitWarningCard(warning: warning)
                        .frame(width: FloatingPetController.islandWidth)
                } else if session.resetPrompt {
                    FocusResetConfirmCard()
                        .frame(width: FloatingPetController.islandWidth)
                } else if SessionPromptSurface.showsOnOverlay(floatingPetEnabled: store.floatingPetEnabled) {
                    SessionPromptCard()
                        .frame(width: FloatingPetController.islandWidth)
                }

                if !store.floatingPetIslandFolded {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            if !current.issue.isPomodoro {
                                LinearIssueIDButton(identifier: current.issue.identifier, url: current.issue.url)
                            }
                            Text(current.issue.title)
                                .font(.caption)
                                .lineLimit(1)
                                .truncationMode(.tail)
                            Spacer(minLength: 0)
                            if !current.issue.isPomodoro {
                                NewLinearIssueButton()
                                SessionNoteButton()
                            }
                        }
                        HStack(spacing: 6) {
                            Text(clock.text)
                                .font(.system(size: 16, weight: .semibold, design: .rounded).monospacedDigit())
                            if clock.overtime {
                                Text(l.overtimeAbbrev)
                                    .font(.system(size: 9, weight: .bold))
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(Color.orange.opacity(0.2))
                                    .foregroundStyle(.orange)
                                    .clipShape(Capsule())
                            }
                            Spacer(minLength: 0)
                            Button {
                                session.togglePause()
                            } label: {
                                Image(systemName: current.userPaused || current.phase == .paused
                                      ? "play.fill" : "pause.fill")
                            }
                            .tahoeButtonStyle(.accessory)
                            .buttonBorderShape(.circle)
                            .disabled(current.phase == .awaitingChoice)
                            .help(current.userPaused || current.phase == .paused ? l.resumeTimer : l.pauseTimer)
                            if !current.issue.isPomodoro {
                                LinearIssueStatusPicker(issue: issue)
                            }
                        }
                        FocusTimerControls()
                        if session.isComposingNote, !current.issue.isPomodoro {
                            SessionNoteComposer()
                        }
                    }
                    .padding(8)
                    .frame(width: FloatingPetController.islandWidth, alignment: .leading)
                    .tahoeFloatingChrome()
                } else if session.isComposingNote {
                    SessionNoteComposer()
                        .padding(8)
                        .frame(width: FloatingPetController.islandWidth, alignment: .leading)
                        .tahoeFloatingChrome()
                }
            }
        }
    }
}

/// Duration chips + Start. Shown on the overlay before a no-issue timer begins.
@MainActor
struct PomodoroSetupIsland: View {
    @Environment(FocusSessionStore.self) private var session
    @Environment(CompanionStore.self) private var companion

    private var l: L { companion.l }

    var body: some View {
        @Bindable var session = session
        VStack(alignment: .leading, spacing: 8) {
            Text(l.pomoTimer)
                .font(.caption.weight(.semibold))
            HStack(spacing: 4) {
                ForEach(SessionXP.plannedPresets, id: \.self) { minutes in
                    let selected = session.plannedMinutes == minutes
                    Button(l.minutesValue(minutes)) {
                        session.plannedMinutes = minutes
                    }
                    .font(.caption.weight(selected ? .semibold : .regular))
                    .foregroundStyle(selected ? Color.primary : Color.secondary)
                    .linearSegmentChrome(selected: selected)
                }
            }
            HStack(spacing: 6) {
                Button(l.startPomodoro) { session.startPomodoro() }
                    .tahoeButtonStyle(.prominent)
                Button(l.cancel) { session.cancelPomodoroSetup() }
                    .tahoeButtonStyle(.accessory)
                    .foregroundStyle(.secondary)
            }
        }
        .controlSize(.mini)
        .padding(8)
        .frame(width: FloatingPetController.islandWidth, alignment: .leading)
        .tahoeFloatingChrome()
    }
}

/// Bubble button that expands the compact Linear comment field.
@MainActor
struct SessionNoteButton: View {
    var compact: Bool = true

    @Environment(FocusSessionStore.self) private var session
    @Environment(CompanionStore.self) private var companion

    private var l: L { companion.l }

    var body: some View {
        Group {
            if compact {
                Button {
                    session.toggleNoteComposer()
                } label: {
                    Image(systemName: session.isComposingNote ? "text.bubble.fill" : "text.bubble")
                }
                .tahoeButtonStyle(.accessory)
                .buttonBorderShape(.circle)
                .controlSize(.mini)
            } else {
                Button {
                    session.toggleNoteComposer()
                } label: {
                    Label(l.checkInAddNote, systemImage: session.isComposingNote ? "text.bubble.fill" : "text.bubble")
                }
                .tahoeButtonStyle(.regular)
                .controlSize(.small)
            }
        }
        .help(l.sessionNoteHelp)
    }
}

/// Compact field + Post. Shared by the overlay island and Today desk.
@MainActor
struct SessionNoteComposer: View {
    var compact: Bool = true

    @Environment(FocusSessionStore.self) private var session
    @Environment(CompanionStore.self) private var companion

    private var l: L { companion.l }
    @FocusState private var noteFieldFocused: Bool
    private var trimmedEmpty: Bool {
        session.noteDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        @Bindable var session = session
        VStack(alignment: .leading, spacing: compact ? 4 : 6) {
            HStack(spacing: 6) {
                TextField(l.checkInNotePlaceholder, text: $session.noteDraft)
                    .textFieldStyle(.roundedBorder)
                    .focused($noteFieldFocused)
                    .onSubmit { Task { await session.postSessionNote() } }
                Button(l.postNote) {
                    Task { await session.postSessionNote() }
                }
                .tahoeButtonStyle(.prominent)
                .disabled(session.isPostingNote || trimmedEmpty)
            }
            if session.notePostFailed {
                Text(l.linearCommentFailed)
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        }
        .controlSize(compact ? .mini : .small)
        .onAppear { noteFieldFocused = true }
    }
}
