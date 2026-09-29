import SwiftUI

struct CommanderLiveSummaryCard: View {
    let state: CommanderLiveViewState

    var body: some View {
        let snapshot = state.effectiveSnapshot
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Circle()
                    .fill(statusColor(snapshot?.state))
                    .frame(width: 10, height: 10)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Code Commander")
                        .font(.headline)
                    Text(statusTitle(snapshot?.state))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(statusColor(snapshot?.state))
                }
                Spacer(minLength: 0)
                Text(connectionTitle(state.connection))
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(connectionColor(state.connection))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(connectionColor(state.connection).opacity(0.10), in: Capsule())
            }

            if let activity = state.activities.values.sorted(by: { $0.startedAt < $1.startedAt }).first {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    HStack(spacing: 8) {
                        Image(systemName: "bolt.fill")
                            .foregroundStyle(.green)
                        Text(activity.tool)
                            .font(.subheadline.monospaced())
                        Spacer(minLength: 0)
                        Text(elapsed(from: activity.startedAt, to: context.date))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                metadata(snapshot)
            }
        }
        .padding(16)
        .ios27ContentSurface(radius: 24, elevated: snapshot?.state == .active)
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private func metadata(_ snapshot: CommanderSnapshot?) -> some View {
        HStack(spacing: 12) {
            if let version = snapshot?.version {
                Label(version, systemImage: "shippingbox.fill")
            }
            if let last = snapshot?.lastActivity {
                Label(last.formatted(date: .omitted, time: .standard), systemImage: "clock.fill")
            }
            if let sessions = snapshot?.activeSessions {
                Label("\(sessions)", systemImage: "terminal.fill")
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private func elapsed(from start: Date, to end: Date) -> String {
        String(format: "%.1f s", max(0, end.timeIntervalSince(start)))
    }
}

struct CommanderLiveDetailView: View {
    let model: RunnerControlModel

    var body: some View {
        Group {
            if let snapshot = model.commanderLiveState.effectiveSnapshot {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        CommanderLiveSummaryCard(state: model.commanderLiveState)

                        IOS27SectionHeader(title: "Live", subtitle: "Sanitisierte Echtzeitdaten")
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 145), spacing: 12)], spacing: 12) {
                            IOS27StatusCard(
                                title: "Vorgänge",
                                value: "\(snapshot.activeCount)",
                                symbol: "bolt.horizontal.circle.fill",
                                tint: snapshot.activeCount > 0 ? .green : .blue
                            )
                            if let sessions = snapshot.activeSessions {
                                IOS27StatusCard(
                                    title: "Sessions",
                                    value: "\(sessions)",
                                    symbol: "terminal.fill",
                                    tint: .blue
                                )
                            }
                            if let searches = snapshot.activeSearches {
                                IOS27StatusCard(
                                    title: "Searches",
                                    value: "\(searches)",
                                    symbol: "magnifyingglass.circle.fill",
                                    tint: .cyan
                                )
                            }
                            if let uptime = snapshot.uptimeSeconds {
                                IOS27StatusCard(
                                    title: "Uptime",
                                    value: formatUptime(uptime),
                                    symbol: "clock.arrow.circlepath",
                                    tint: .purple
                                )
                            }
                            if let cpu = snapshot.cpuPercent {
                                IOS27StatusCard(
                                    title: "CPU",
                                    value: "\(Int(cpu.rounded())) %",
                                    symbol: "cpu.fill",
                                    tint: cpu >= 85 ? .red : .blue
                                )
                            }
                            if let memory = snapshot.memoryPercent {
                                IOS27StatusCard(
                                    title: "RAM",
                                    value: "\(Int(memory.rounded())) %",
                                    symbol: "memorychip.fill",
                                    tint: memory >= 85 ? .red : .purple
                                )
                            }
                        }

                        if !model.commanderLiveState.activities.isEmpty {
                            IOS27SectionHeader(title: "Aktiv", subtitle: "Keine Argumente oder Ausgaben werden übertragen")
                            VStack(spacing: 0) {
                                ForEach(model.commanderLiveState.activities.values.sorted(by: { $0.startedAt < $1.startedAt })) { activity in
                                    HStack(spacing: 12) {
                                        Image(systemName: "bolt.fill")
                                            .foregroundStyle(.green)
                                            .frame(width: 24)
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(activity.tool).font(.subheadline.monospaced().weight(.semibold))
                                            Text(activity.startedAt.formatted(date: .omitted, time: .standard))
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer(minLength: 0)
                                    }
                                    .padding(.vertical, 10)
                                }
                            }
                            .padding(.horizontal, 14)
                            .ios27ContentSurface(radius: 24)
                        }

                        IOS27SectionHeader(title: "Sicherheit")
                        Text("Live werden ausschließlich Toolname, Zeit, Dauer und Statusmetadaten übertragen. Pfade, Befehle, Argumente, Ausgaben, Tokens und Dateiinhalte bleiben außerhalb der App.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .padding(14)
                            .ios27ContentSurface(radius: 20)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
                .ios27ScrollBottomClearance()
            } else {
                ContentUnavailableView {
                    Label("Kein Commander-Status", systemImage: "terminal")
                } description: {
                    Text("Es liegt noch kein autoritativer Commander-Live-Snapshot vor.")
                }
            }
        }
        .background(IOS27HomeBackground(style: .neutral))
        .navigationTitle("Code Commander")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func formatUptime(_ seconds: Double) -> String {
        let hours = max(0, Int(seconds / 3_600))
        let days = hours / 24
        return days > 0 ? "\(days) T \(hours % 24) Std" : "\(hours) Std"
    }
}

private func statusTitle(_ state: CommanderRuntimeState?) -> String {
    switch state ?? .unknown {
    case .active: "Arbeitet gerade"
    case .idle: "Bereit"
    case .degraded: "Status eingeschränkt"
    case .offline: "Offline"
    case .unknown: "Status unbekannt"
    }
}

private func statusColor(_ state: CommanderRuntimeState?) -> Color {
    switch state ?? .unknown {
    case .active, .idle: .green
    case .degraded: .orange
    case .offline: .red
    case .unknown: .secondary
    }
}

private func connectionTitle(_ state: CommanderLiveConnectionState) -> String {
    switch state {
    case .live: "LIVE"
    case .unconfigured: "SETUP"
    case .connecting, .syncing: "SYNC"
    case .reconnecting: "RECONNECT"
    case .degraded: "DEGRADED"
    case .disconnected: "OFFLINE"
    }
}

private func connectionColor(_ state: CommanderLiveConnectionState) -> Color {
    switch state {
    case .live: .green
    case .unconfigured: .orange
    case .connecting, .syncing, .reconnecting: .orange
    case .degraded: .orange
    case .disconnected: .secondary
    }
}
