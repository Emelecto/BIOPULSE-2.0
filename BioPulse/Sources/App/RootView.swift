import SwiftUI

struct RootView: View {
    private enum Tab: Hashable { case today, trends, journal, sleep, profile }
    private enum PresentedSheet: String, Identifiable { case coach, sleepReport; var id: String { rawValue } }
    let userID: UUID
    @ObservedObject var auth: AuthSessionStore
    @StateObject private var health = HealthDataController()
    @StateObject private var journal: JournalController
    @StateObject private var personal: PersonalContextStore
    @State private var presentedSheet: PresentedSheet?
    @State private var selectedTab: Tab = .today
    @State private var showingWrapped = false
    @State private var showingPresentation = false
    @EnvironmentObject private var notificationRouter: SleepNotificationRouter
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    init(userID: UUID, auth: AuthSessionStore) {
        self.userID = userID
        self.auth = auth
        _journal = StateObject(wrappedValue: JournalController.live(userID: userID))
        _personal = StateObject(wrappedValue: PersonalContextStore(userID: userID))
    }

    var body: some View {
            TabView(selection: $selectedTab) {
                NavigationStack {
                    TodayView(health: health, personal: personal, openJournal: { selectedTab = .journal }, openWrapped: { showingWrapped = true })
                        .environment(\.pulseMotionEnabled, selectedTab == .today && !showingWrapped)
                        .safeAreaInset(edge: .bottom, spacing: 0) { coachDock }
                }
                    .tabItem { Label("Hoy", systemImage: "house.fill") }
                    .tag(Tab.today)
                NavigationStack { TrendsView(openWrapped: { showingWrapped = true }, health: health, journal: journal, personal: personal).environment(\.pulseMotionEnabled, selectedTab == .trends && !showingWrapped).safeAreaInset(edge: .bottom, spacing: 0) { coachDock } }
                    .tabItem { Label("Tendencias", systemImage: "chart.xyaxis.line") }
                    .tag(Tab.trends)
                NavigationStack { JournalView(journal: journal, personal: personal).safeAreaInset(edge: .bottom, spacing: 0) { coachDock } }
                    .tabItem { Label("Diario", systemImage: "square.and.pencil") }
                    .tag(Tab.journal)
                NavigationStack { SleepView(health: health, personal: personal).environment(\.pulseMotionEnabled, selectedTab == .sleep && !showingWrapped).safeAreaInset(edge: .bottom, spacing: 0) { coachDock } }
                    .tabItem { Label("Sueño", systemImage: "moon.stars.fill") }
                    .tag(Tab.sleep)
                NavigationStack { ProfileView(health: health, auth: auth, personal: personal, openPresentation: { showingPresentation = true }).safeAreaInset(edge: .bottom, spacing: 0) { coachDock } }
                    .tabItem { Label("Perfil", systemImage: "person.crop.circle") }
                    .tag(Tab.profile)
            }
        .buttonStyle(PulsePressButtonStyle())
        .sensoryFeedback(.selection, trigger: selectedTab)
        .fullScreenCover(isPresented: $showingWrapped) { WrappedView(health: health, personal: personal, journal: journal) }
        .fullScreenCover(isPresented: $showingPresentation) { PresentationRootView() }
        .tint(.white)
        .preferredColorScheme(.dark)
        .task {
            openSleepNotification()
            _ = await personal.scheduleSleepReminder()
            await health.reload()
        }
        .onChange(of: notificationRouter.requestedAccountID) { _, _ in openSleepNotification() }
        .onChange(of: personal.preferences) { _, _ in Task { _ = await personal.scheduleSleepReminder() } }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { _ = await personal.scheduleSleepReminder() } }
        }
        .sheet(item: $presentedSheet) { destination in
            switch destination {
            case .sleepReport:
                SleepReportEditor(personal: personal, health: health)
            case .coach:
                CoachPreviewView(auth: auth, health: health, journal: journal)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    private func openSleepNotification() {
        guard let requestedAccount = notificationRouter.requestedAccountID else { return }
        notificationRouter.requestedAccountID = nil
        guard requestedAccount == userID else { return }
        selectedTab = .sleep
        presentedSheet = .sleepReport
    }

    private var coachDock: some View {
        HStack {
            Spacer(minLength: 0)
            Button { presentedSheet = .coach } label: {
                Label(health.isCSVImported ? "Coach pausado con CSV" : "Coach IA", systemImage: health.isCSVImported ? "lock.fill" : "sparkles")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .frame(minHeight: 44)
                    .background {
                        if reduceTransparency || contrast == .increased {
                            Capsule().fill(PulseStyle.elevated)
                        } else {
                            Capsule().fill(.regularMaterial)
                        }
                    }
                    .overlay { Capsule().strokeBorder(.white.opacity(contrast == .increased ? 0.8 : 0.25), lineWidth: 1) }
                    .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
            }
            .buttonStyle(PulsePressButtonStyle())
            .disabled(health.isCSVImported)
            .accessibilityLabel("Abrir Coach BioPulse")
        }
        .padding(.horizontal, 18).padding(.vertical, 4)
    }
}
