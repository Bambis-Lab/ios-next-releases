import SwiftUI

enum AppTab: String, CaseIterable, Identifiable {
    case home
    case rooms
    case chat
    case media
    case system

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: "Zuhause"
        case .rooms: "Räume"
        case .chat: "Chat"
        case .media: "Medien"
        case .system: "System"
        }
    }

    var icon: String {
        switch self {
        case .home: "house.fill"
        case .rooms: "square.grid.2x2.fill"
        case .chat: "message.fill"
        case .media: "play.tv.fill"
        case .system: "ellipsis.circle.fill"
        }
    }
}

struct AppShellView: View {
    let appModel: AppModel
    let chatModel: ChatModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var selectedTab: AppTab?
    @State private var navigationResetTokens: [AppTab: UUID] = Dictionary(
        uniqueKeysWithValues: AppTab.allCases.map { ($0, UUID()) }
    )

    init(appModel: AppModel, chatModel: ChatModel, initialTab: AppTab = .home) {
        self.appModel = appModel
        self.chatModel = chatModel
        _selectedTab = State(initialValue: initialTab)
    }

    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                tabletShell
            } else {
                phoneShell
            }
        }
        .tint(.accentColor)
        .overlay(alignment: .bottom) {
            if JarvisEngine.shared.state.isListening {
                JarvisListeningPill(engine: JarvisEngine.shared)
                    .padding(.horizontal, 16)
                    .padding(.bottom, horizontalSizeClass == .regular ? 22 : 62)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    .allowsHitTesting(false)
            }
        }
        .animation(.easeOut(duration: 0.18), value: JarvisEngine.shared.state.isListening)
        .alert("Aktion fehlgeschlagen", isPresented: errorBinding) {
            Button("OK") { appModel.dismissActionError() }
        } message: {
            Text(appModel.lastActionError ?? "Unbekannter Fehler")
        }
    }

    private var phoneShell: some View {
        TabView(selection: selectedTabBinding) {
            ForEach(AppTab.allCases) { tab in
                NavigationStack {
                    content(for: tab)
                }
                .id(navigationResetTokens[tab])
                .tabItem { Label(tab.title, systemImage: tab.icon) }
                .tag(tab)
                .accessibilityIdentifier("app-tab-\(tab.rawValue)")
            }
        }
    }

    private var tabletShell: some View {
        NavigationSplitView {
            List(AppTab.allCases, selection: selectedTabOptionalBinding) { tab in
                Label(tab.title, systemImage: tab.icon)
                    .tag(tab)
                    .accessibilityIdentifier("app-tab-\(tab.rawValue)")
            }
            .navigationTitle("iOS Next")
        } detail: {
            NavigationStack {
                content(for: selectedTab ?? .home)
            }
            .id(navigationResetTokens[selectedTab ?? .home])
        }
        .navigationSplitViewStyle(.balanced)
    }

    @ViewBuilder
    private func content(for tab: AppTab) -> some View {
        switch tab {
        case .home: HomeView(appModel: appModel)
        case .rooms: RoomsView(appModel: appModel)
        case .chat: ChatView(appModel: appModel, chatModel: chatModel)
        case .media: MediaView(appModel: appModel)
        case .system: SystemView(appModel: appModel)
        }
    }

    private var selectedTabBinding: Binding<AppTab> {
        Binding(
            get: { selectedTab ?? .home },
            set: { select($0) }
        )
    }

    private var selectedTabOptionalBinding: Binding<AppTab?> {
        Binding(
            get: { selectedTab },
            set: { value in
                if let value {
                    select(value)
                } else {
                    selectedTab = nil
                }
            }
        )
    }

    private func select(_ tab: AppTab) {
        if selectedTab != tab {
            IOSNextFeedbackCenter.shared.play(.selection)
        }
        selectedTab = tab
        navigationResetTokens[tab] = UUID()
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { appModel.lastActionError != nil },
            set: { if !$0 { appModel.dismissActionError() } }
        )
    }
}
