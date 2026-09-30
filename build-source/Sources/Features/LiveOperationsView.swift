import SwiftUI

struct LiveOperationsView: View {
    @State private var runtime = IOSNextRuntime.shared

    private var model: LiveOperationsModel { runtime.liveOperationsModel }

    private var masterActiveOperations: [LiveOperation] {
        model.mcpState.activeOperations.values.sorted { $0.startedAt < $1.startedAt }
    }

    private var masterRecentOperations: [LiveOperation] {
        Array(model.mcpState.recentOperations
            .sorted { $0.updatedAt > $1.updatedAt }
            .prefix(20))
    }

    var body: some View {
        Group {
            if model.connectionState == .unconfigured {
                ContentUnavailableView {
                    Label("Master Runtime Live nicht eingerichtet", systemImage: "waveform.path.ecg")
                } description: {
                    Text("Verbinde den read-only Live-Relay der eigenen Master-Runtime. Tokens, Prompts, Befehle und Ausgaben werden nicht dargestellt.")
                } actions: {
                    Button("Einrichten") { model.isPresentingConfiguration = true }
                        .buttonStyle(.glassProminent)
                }
            } else {
                dashboard
            }
        }
        .background(IOS27HomeBackground(style: .neutral))
        .navigationTitle("Master Runtime Live")
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
        .sheet(isPresented: Bindable(model).isPresentingConfiguration) {
            LiveOperationsConfigurationView(model: model)
        }
        .alert("Master Runtime Live", isPresented: Binding(
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

                IOS27SectionHeader(title: "Quelle", subtitle: "Eigener MCP-/Master-Relay")
                sourceCard(state: model.mcpState)

                if !masterActiveOperations.isEmpty {
                    IOS27SectionHeader(title: "Aktiv", subtitle: "Laufzeiten werden lokal aktualisiert")
                    operationList(masterActiveOperations, active: true)
                }

                if !masterRecentOperations.isEmpty {
                    IOS27SectionHeader(title: "Zuletzt", subtitle: "Maximal 20 sichtbare Vorgänge")
                    operationList(masterRecentOperations, active: false)
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
                    Text("Master Runtime")
                        .font(.title2.bold())
                    Text(connectionTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(connectionColor)
                }
                Spacer()
                Text("\(masterActiveOperations.count) aktiv")
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            Text("Sanitisierter Event-Push · keine Roh-Logs · keine Fremd-Control-Plane")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .ios27ContentSurface(radius: 28, elevated: model.connectionState == .live)
    }

    private func sourceCard(state: LiveOperationsSourceState) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "point.3.connected.trianglepath.dotted")
                    .font(.headline)
                    .foregroundStyle(state.online ? Color.green : Color.secondary)
                    .frame(width: 38, height: 38)
                    .background((state.online ? Color.green : Color.secondary).opacity(0.10), in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text("Master MCP")
                        .font(.headline)
                    Text(state.online ? "Online" : "Offline")
                        .font(.caption)
                        .foregroundStyle(state.online ? .green : .secondary)
                }
                Spacer()
                Text("\(state.activeOperations.count) aktiv")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .ios27ContentSurface(radius: 24)
    }

    private func operationList(_ operations: [LiveOperation], active: Bool) -> some View {
        VStack(spacing: 0) {
            ForEach(operations) { operation in
                NavigationLink {
                    LiveOperationDetailView(operation: operation)
                } label: {
                    operationRow(operation, isActive: active)
                }
                .buttonStyle(.plain)
                if operation.id != operations.last?.id {
                    Divider().padding(.leading, 48)
                }
            }
        }
        .padding(.horizontal, 14)
        .ios27ContentSurface(radius: 24)
    }

    private func operationRow(_ operation: LiveOperation, isActive: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "bolt.fill")
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
            Text("Die Runtime akzeptiert nur sanitisierte Statusdaten. Tokens, Prompts, Tool-Argumente, komplette Befehle, stdout/stderr und Dateiinhalte gehören nicht in den Live-Stream.")
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
        case .connecting, .syncing, .reconnecting, .degraded: .orange
        case .offline, .unconfigured: .secondary
        }
    }

    private func operationContext(_ operation: LiveOperation) -> String {
        [operation.repository, operation.workspace, operation.host]
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
                Section("Master Live Relay") {
                    TextField("https://live-relay.example/", text: $endpoint)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                    SecureField("Read-only Live-Token", text: $token)
                }
                Section {
                    Label("Production akzeptiert ausschließlich HTTPS/WSS.", systemImage: "lock.fill")
                    Label("Das Token kann nur den sanitisierten Master-Live-Stream lesen.", systemImage: "eye.fill")
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
            .navigationTitle("Master Runtime Live")
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
