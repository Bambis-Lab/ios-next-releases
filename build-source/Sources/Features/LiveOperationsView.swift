import SwiftUI

struct LiveOperationsView: View {
    @State private var model = LiveOperationsModel()

    var body: some View {
        Group {
            if model.connectionState == .unconfigured {
                ContentUnavailableView {
                    Label("Live Operations nicht eingerichtet", systemImage: "waveform.path.ecg")
                } description: {
                    Text("Verbinde einen read-only Live-Relay für MCP und SentinelX. Tokens, Prompts, Befehle und Ausgaben werden nicht dargestellt.")
                } actions: {
                    Button("Einrichten") { model.isPresentingConfiguration = true }
                        .buttonStyle(.glassProminent)
                }
            } else {
                dashboard
            }
        }
        .background(IOS27HomeBackground(style: .neutral))
        .navigationTitle("Live Operations")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Konfigurieren", systemImage: "gearshape") {
                    model.isPresentingConfiguration = true
                }
                .labelStyle(.iconOnly)
            }
        }
        .task { model.startIfNeeded() }
        .onDisappear { model.stop() }
        .sheet(isPresented: $model.isPresentingConfiguration) {
            LiveOperationsConfigurationView(model: model)
        }
        .alert("Live Operations", isPresented: Binding(
            get: { model.lastError != nil },
            set: { if !$0 { model.lastError = nil } }
        )) {
            Button("OK") { model.lastError = nil }
        } message: {
            Text(model.lastError ?? "Unbekannter Fehler")
        }
    }

    private var dashboard: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                connectionHero

                IOS27SectionHeader(title: "Quellen", subtitle: "MCP und Windows-PC über SentinelX")
                sourceCard(.mcp, state: model.mcpState)
                sourceCard(.sentinelX, state: model.sentinelXState)

                if !model.activeOperations.isEmpty {
                    IOS27SectionHeader(title: "Aktiv", subtitle: "Laufzeiten werden lokal aktualisiert")
                    VStack(spacing: 0) {
                        ForEach(model.activeOperations) { operation in
                            NavigationLink {
                                LiveOperationDetailView(operation: operation)
                            } label: {
                                operationRow(operation, isActive: true)
                            }
                            .buttonStyle(.plain)
                            if operation.id != model.activeOperations.last?.id {
                                Divider().padding(.leading, 48)
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .ios27ContentSurface(radius: 24)
                }

                if !model.recentOperations.isEmpty {
                    IOS27SectionHeader(title: "Zuletzt", subtitle: "Maximal 50 Vorgänge im Speicher")
                    VStack(spacing: 0) {
                        ForEach(model.recentOperations.prefix(20)) { operation in
                            NavigationLink {
                                LiveOperationDetailView(operation: operation)
                            } label: {
                                operationRow(operation, isActive: false)
                            }
                            .buttonStyle(.plain)
                            if operation.id != model.recentOperations.prefix(20).last?.id {
                                Divider().padding(.leading, 48)
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .ios27ContentSurface(radius: 24)
                }

                privacyCard
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .ios27ScrollBottomClearance()
    }

    private var connectionHero: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Circle()
                    .fill(connectionColor)
                    .frame(width: 11, height: 11)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Live Operations")
                        .font(.title2.bold())
                    Text(connectionTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(connectionColor)
                }
                Spacer()
                Text("\(model.activeOperations.count) aktiv")
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            Text("Event-Push für MCP · SentinelX-Metriken gedrosselt · keine Roh-Logs")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .ios27ContentSurface(radius: 28, elevated: model.connectionState == .live)
    }

    private func sourceCard(_ source: LiveOperationSourceKind, state: LiveOperationsSourceState) -> some View {
        let activeCount = state.activeOperations.count
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: source == .mcp ? "point.3.connected.trianglepath.dotted" : "desktopcomputer")
                    .font(.headline)
                    .foregroundStyle(state.online ? Color.green : Color.secondary)
                    .frame(width: 38, height: 38)
                    .background((state.online ? Color.green : Color.secondary).opacity(0.10), in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(source == .mcp ? "MCP" : sentinelHost(state))
                        .font(.headline)
                    Text(state.online ? "Online" : "Offline")
                        .font(.caption)
                        .foregroundStyle(state.online ? .green : .secondary)
                }
                Spacer()
                Text("\(activeCount) aktiv")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            if source == .sentinelX {
                HStack(spacing: 8) {
                    metricPill("CPU", state.metrics["cpu_percent"])
                    metricPill("RAM", state.metrics["memory_percent"])
                    metricPill("Disk", state.metrics["disk_percent"])
                }
            }
        }
        .padding(16)
        .ios27ContentSurface(radius: 24)
    }

    @ViewBuilder
    private func metricPill(_ label: String, _ value: LiveMetricValue?) -> some View {
        if let value {
            Text("\(label) \(value.displayText)%")
                .font(.caption2.monospacedDigit().weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .background(Color.primary.opacity(0.055), in: Capsule())
        }
    }

    private func operationRow(_ operation: LiveOperation, isActive: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: operation.source == .mcp ? "bolt.fill" : "desktopcomputer")
                .foregroundStyle(isActive ? .green : operation.state == .failed ? .red : .blue)
                .frame(width: 32, height: 32)
            VStack(alignment: .leading, spacing: 3) {
                Text(operation.title)
                    .font(.subheadline.monospaced().weight(.semibold))
                    .lineLimit(1)
                Text(operationContext(operation))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            if isActive {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text(elapsed(operation, now: context.date))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            } else {
                Text(operation.state.rawValue.uppercased())
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(operation.state == .failed ? .red : .secondary)
            }
        }
        .padding(.vertical, 10)
    }

    private var privacyCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Read-only Telemetrie", systemImage: "lock.shield.fill")
                .font(.subheadline.weight(.semibold))
            Text("Die Live-Ansicht akzeptiert nur sanitisierte Statusdaten. Tokens, Prompts, Tool-Argumente, komplette Befehle, stdout/stderr und Dateiinhalte gehören nicht in den Live-Stream.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .ios27ContentSurface(radius: 20)
    }

    private var connectionTitle: String {
        switch model.connectionState {
        case .unconfigured: "Nicht eingerichtet"
        case .connecting: "Verbinde …"
        case .syncing: "Synchronisiere …"
        case .live: "LIVE"
        case .reconnecting: "Verbinde neu …"
        case .degraded: "Status eingeschränkt"
        case .offline: "Offline"
        }
    }

    private var connectionColor: Color {
        switch model.connectionState {
        case .live: .green
        case .connecting, .syncing, .reconnecting: .orange
        case .degraded: .orange
        case .offline, .unconfigured: .secondary
        }
    }

    private func sentinelHost(_ state: LiveOperationsSourceState) -> String {
        state.sourceMetadata["host"]?.displayText ?? "Windows PC · SentinelX"
    }

    private func operationContext(_ operation: LiveOperation) -> String {
        [operation.source.title, operation.host, operation.repository, operation.workspace]
            .compactMap { $0 }
            .joined(separator: " · ")
    }

    private func elapsed(_ operation: LiveOperation, now: Date) -> String {
        let interval = max(0, now.timeIntervalSince(operation.startedAt))
        if interval < 60 { return String(format: "%.0f s", interval) }
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

private struct LiveOperationDetailView: View {
    let operation: LiveOperation

    var body: some View {
        List {
            Section("Vorgang") {
                LabeledContent("Quelle", value: operation.source.title)
                LabeledContent("Status", value: operation.state.rawValue)
                LabeledContent("Typ", value: operation.kind)
                LabeledContent("Name", value: operation.title)
            }
            Section("Kontext") {
                if let host = operation.host { LabeledContent("Host", value: host) }
                if let repository = operation.repository { LabeledContent("Repository", value: repository) }
                if let workspace = operation.workspace { LabeledContent("Workspace", value: workspace) }
                LabeledContent("Gestartet", value: operation.startedAt.formatted(date: .omitted, time: .standard))
                if let completedAt = operation.completedAt {
                    LabeledContent("Beendet", value: completedAt.formatted(date: .omitted, time: .standard))
                }
                if let durationMS = operation.durationMS {
                    LabeledContent("Dauer", value: String(format: "%.2f s", Double(durationMS) / 1000))
                }
            }
            Section("Datenschutz") {
                Text("Keine Argumente, Prompts, Rohbefehle oder Ausgaben werden in dieser Ansicht übertragen.")
            }
        }
        .iosNextManagementBackground()
        .navigationTitle(operation.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct LiveOperationsConfigurationView: View {
    @Environment(\.dismiss) private var dismiss
    let model: LiveOperationsModel
    @State private var endpoint = ""
    @State private var token = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Live Relay") {
                    TextField("https://live-relay.example/", text: $endpoint)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                    SecureField("Read-only Live-Token", text: $token)
                }
                Section {
                    Label("Production akzeptiert ausschließlich HTTPS/WSS.", systemImage: "lock.fill")
                    Label("Ein Token kann nur den sanitisierten Live-Stream lesen.", systemImage: "eye.fill")
                } header: {
                    Text("Sicherheit")
                }
                if let errorMessage {
                    Section { Text(errorMessage).foregroundStyle(.red) }
                }
                Section {
                    Button("Konfiguration entfernen", role: .destructive) {
                        model.removeConfiguration()
                        dismiss()
                    }
                }
            }
            .navigationTitle("Live Operations")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") {
                        do {
                            try model.configure(endpoint: endpoint, token: token)
                            dismiss()
                        } catch {
                            errorMessage = error.localizedDescription
                        }
                    }
                    .disabled(endpoint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || token.isEmpty)
                }
            }
        }
    }
}
