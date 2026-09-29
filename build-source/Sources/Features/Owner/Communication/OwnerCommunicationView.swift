import SwiftUI

struct OwnerCommunicationView: View {
    let model: AdminControlModel
    let capabilities: OwnerCapabilityRegistry

    var body: some View {
        OwnerPage {
            VStack(alignment: .leading, spacing: IOSNextLayout.pageSpacing) {
                IOSNextSectionHeader(
                    title: "Kommunikation",
                    subtitle: "Nur technische Relay-Metriken — keine Nachrichteninhalte",
                    symbol: "bubble.left.and.bubble.right.fill"
                )

                if let chat = model.chatStatusV2 {
                    OwnerStatusRow(title: "Relay Queue", detail: "Flüchtige verschlüsselte Chunks im RAM", symbol: "square.stack.3d.up.fill", value: "\(chat.chatQueuedChunks)")
                    OwnerStatusRow(title: "Queue-Speicher", detail: "Nur aggregierte RAM-Menge", symbol: "memorychip.fill", value: ByteCountFormatter.string(fromByteCount: Int64(chat.chatQueuedBytes), countStyle: .memory))
                    OwnerStatusRow(title: "Geräte-Queues", detail: "Technische Gerätewarteschlangen", symbol: "iphone.gen3", value: "\(chat.chatDeviceQueues)")
                    OwnerStatusRow(title: "Relay-Principals", detail: "Registrierte technische Relay-Identitäten", symbol: "person.2.fill", value: "\(chat.registeredPrincipals)")
                    OwnerStatusRow(title: "Nachrichteninhalt", detail: "Owner Control erhält keine Klartextnachrichten", symbol: "lock.shield.fill", value: chat.messageContentVisibleToOwner ? "Sichtbar" : "Nicht sichtbar", tint: chat.messageContentVisibleToOwner ? .red : .green)
                    OwnerStatusRow(title: "Chat Rate Limit", detail: "Serverseitiges Limit pro Minute", symbol: "speedometer", value: "\(chat.chatRateLimitPerMinute)/min")
                    OwnerStatusRow(title: "Ephemeral TTL", detail: "Maximale In-Memory-Lebensdauer", symbol: "timer", value: "\(chat.ephemeralTTLSeconds)s")
                } else if capabilities.supports(.chatRelay), let status = model.backendStatus {
                    OwnerStatusRow(title: "Relay-Verbindung", detail: "Abgeleitet aus dem erreichbaren Owner Backend", symbol: "network", value: status.healthy ? "Online" : "Gestört", tint: status.healthy ? .green : .orange)
                    OwnerStatusRow(title: "WebSocket-Sessions", detail: "Aktive Backend-Sitzungen", symbol: "dot.radiowaves.left.and.right", value: "\(status.activeWebSocketSessions)")
                    OwnerStatusRow(title: "Queue-Chunks", detail: "Nur technische Warteschlangenmetrik", symbol: "square.stack.3d.up.fill", value: optionalCount(status.chatQueuedChunks))
                    OwnerStatusRow(title: "Queue-Speicher", detail: "Nur aggregierte RAM-Menge", symbol: "memorychip.fill", value: ByteCountFormatter.string(fromByteCount: Int64(status.chatQueuedBytes ?? 0), countStyle: .memory))
                    OwnerStatusRow(title: "Geräte-Queues", detail: "Anzahl technischer Gerätewarteschlangen", symbol: "iphone.gen3", value: optionalCount(status.chatDeviceQueues))
                } else {
                    OwnerCapabilityUnavailableView(title: "Chat Relay")
                }

                IOSNextSectionHeader(title: "Geräteidentitäten", subtitle: "Nur Public-Key-Fingerprints", symbol: "key.fill")
                if model.chatDevicesV2.isEmpty {
                    OwnerCapabilityUnavailableView(
                        title: "Public-Key-Inventar",
                        detail: "Keine Relay-Geräteidentitäten vom Owner Backend geladen. Private Schlüssel werden grundsätzlich nie angezeigt."
                    )
                } else {
                    ForEach(model.chatDevicesV2) { device in
                        OwnerStatusRow(
                            title: "\(device.userID) · \(device.deviceID)",
                            detail: "Signing: \(String(device.signingKeyFingerprint.prefix(16)))…",
                            symbol: "key.fill",
                            value: device.updatedAt.formatted(date: .abbreviated, time: .shortened),
                            tint: .indigo
                        )
                    }
                }
            }
        }
        .navigationTitle("Kommunikation")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func optionalCount(_ value: Int?) -> String {
        value.map(String.init) ?? "—"
    }
}
