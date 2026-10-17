import SwiftUI

struct RootView: View {
    private enum Tab: Hashable { case today, trends, journal, sleep, profile }
    let userID: UUID
    @ObservedObject var auth: AuthSessionStore
    @StateObject private var health = HealthDataController()
    @StateObject private var journal: JournalController
    @StateObject private var personal: PersonalContextStore
    @State private var showingCoach = false
    @State private var selectedTab: Tab = .today
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
                    TodayView(health: health, personal: personal) { selectedTab = .journal }
                        .safeAreaInset(edge: .bottom, spacing: 0) { coachDock }
                }
                    .tabItem { Label("Hoy", systemImage: "house.fill") }
                    .tag(Tab.today)
                NavigationStack { TrendsView(health: health, journal: journal, personal: personal).safeAreaInset(edge: .bottom, spacing: 0) { coachDock } }
                    .tabItem { Label("Tendencias", systemImage: "chart.xyaxis.line") }
                    .tag(Tab.trends)
                NavigationStack { JournalView(journal: journal, personal: personal).safeAreaInset(edge: .bottom, spacing: 0) { coachDock } }
                    .tabItem { Label("Diario", systemImage: "square.and.pencil") }
                    .tag(Tab.journal)
                NavigationStack { SleepView(health: health, personal: personal).safeAreaInset(edge: .bottom, spacing: 0) { coachDock } }
                    .tabItem { Label("Sueño", systemImage: "moon.stars.fill") }
                    .tag(Tab.sleep)
                NavigationStack { ProfileView(health: health, auth: auth, personal: personal).safeAreaInset(edge: .bottom, spacing: 0) { coachDock } }
                    .tabItem { Label("Perfil", systemImage: "person.crop.circle") }
                    .tag(Tab.profile)
            }
        .tint(.white)
        .preferredColorScheme(.dark)
        .task { await health.reload() }
        .sheet(isPresented: $showingCoach) {
            CoachPreviewView(auth: auth, health: health, journal: journal)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }

    private var coachDock: some View {
        HStack {
            Spacer(minLength: 0)
            Button { showingCoach = true } label: {
                Label("Coach IA", systemImage: "sparkles")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .frame(minHeight: 48)
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
            .accessibilityLabel("Abrir Coach BioPulse")
        }
        .padding(.horizontal, 22).padding(.vertical, 8)
    }
}
