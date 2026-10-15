import SwiftUI

struct RootView: View {
    let userID: UUID
    @ObservedObject var auth: AuthSessionStore
    @StateObject private var health = HealthDataController()
    @StateObject private var journal: JournalController
    @State private var showingCoach = false

    init(userID: UUID, auth: AuthSessionStore) {
        self.userID = userID
        self.auth = auth
        _journal = StateObject(wrappedValue: JournalController.live(userID: userID))
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            TabView {
                NavigationStack { TodayView(health: health) }
                    .tabItem { Label("Hoy", systemImage: "house.fill") }
                NavigationStack { TrendsView(health: health) }
                    .tabItem { Label("Tendencias", systemImage: "chart.xyaxis.line") }
                NavigationStack { JournalView(journal: journal) }
                    .tabItem { Label("Diario", systemImage: "square.and.pencil") }
                NavigationStack { SleepView(health: health) }
                    .tabItem { Label("Sueño", systemImage: "moon.stars.fill") }
                NavigationStack { ProfileView(health: health, auth: auth) }
                    .tabItem { Label("Perfil", systemImage: "person.crop.circle") }
            }

            Button { showingCoach = true } label: {
                Image(systemName: "sparkles")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(PulseStyle.background)
                    .frame(width: 52, height: 52)
                    .background(PulseStyle.mint, in: Circle())
                    .shadow(color: PulseStyle.mint.opacity(0.2), radius: 16, y: 7)
            }
            .buttonStyle(PulsePressButtonStyle())
            .padding(.trailing, 17)
            .padding(.bottom, 72)
            .accessibilityLabel("Abrir Coach BioPulse")
        }
        .tint(PulseStyle.mint)
        .preferredColorScheme(.dark)
        .task { await health.reload() }
        .sheet(isPresented: $showingCoach) {
            CoachPreviewView(auth: auth, health: health, journal: journal)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }
}
