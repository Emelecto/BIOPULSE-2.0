import SwiftUI
import UserNotifications

struct PersonalizationSettingsView: View {
    @ObservedObject var personal: PersonalContextStore
    @State private var notificationMessage: String?

    private let weekdaySymbols = Calendar.current.weekdaySymbols

    var body: some View {
        ScreenShell(title: "Personalizar", subtitle: "Tu ritmo, tus prioridades") {
            StatusPanel(
                symbol: "slider.horizontal.3",
                title: "Sin una puntuación única",
                message: "Elige qué te interesa explorar. BioPulse no te penaliza por descansar, no registrar datos o dejar el reloj en casa."
            )

            SectionHeading(title: "Mi enfoque", subtitle: "Puedes cambiarlo cuando quieras")
            Picker("Enfoque", selection: Binding(
                get: { personal.preferences.focus },
                set: { value in personal.updatePreferences { $0.focus = value } }
            )) {
                ForEach(PersonalFocus.allCases) { focus in
                    Label(focus.title, systemImage: focus.symbol).tag(focus)
                }
            }
            .pickerStyle(.menu)
            .padding(15).pulseSurface()

            SectionHeading(title: "Nivel de detalle", subtitle: "La procedencia sigue visible en ambos modos")
            Picker("Lectura", selection: Binding(
                get: { personal.preferences.readingLevel },
                set: { value in personal.updatePreferences { $0.readingLevel = value } }
            )) {
                ForEach(PersonalReadingLevel.allCases) { level in Text(level.title).tag(level) }
            }
            .pickerStyle(.segmented)
            .padding(15).pulseSurface()
            Text(personal.preferences.readingLevel == .simple
                 ? "La vista sencilla prioriza explicaciones claras y límites."
                 : "La vista técnica añade cobertura, ventanas y valores de procedencia disponible.")
                .font(.caption).foregroundStyle(PulseStyle.secondary)

            SectionHeading(title: "Rituales", subtitle: "Avisos locales y opcionales")
            SleepReminderControls(personal: personal)
            VStack(alignment: .leading, spacing: 12) {
                Toggle(isOn: Binding(
                    get: { personal.preferences.dailyReminderEnabled },
                    set: { enableDailyReminder($0) }
                )) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Recordatorio diario")
                        Text("Una invitación opcional a registrar tu día.").font(.caption).foregroundStyle(PulseStyle.secondary)
                    }
                }
                .tint(PulseStyle.mint)

                if personal.preferences.dailyReminderEnabled {
                    DatePicker("Hora", selection: hourBinding(for: .daily), displayedComponents: .hourAndMinute)
                        .datePickerStyle(.compact)
                }

                Rectangle().fill(.white.opacity(0.12)).frame(height: 1)

                Toggle(isOn: Binding(
                    get: { personal.preferences.weeklySummaryReminderEnabled },
                    set: { enableWeeklyReminder($0) }
                )) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Recordatorio semanal")
                        Text("Te avisa para revisar el resumen en la app.").font(.caption).foregroundStyle(PulseStyle.secondary)
                    }
                }
                .tint(PulseStyle.mint)

                if personal.preferences.weeklySummaryReminderEnabled {
                    Picker("Día del resumen", selection: Binding(
                        get: { personal.preferences.weeklySummaryWeekday },
                        set: { value in personal.updatePreferences { $0.weeklySummaryWeekday = value } }
                    )) {
                        ForEach(1...7, id: \.self) { weekday in
                            Text(weekdaySymbols[weekday - 1]).tag(weekday)
                        }
                    }
                    DatePicker("Hora", selection: hourBinding(for: .weekly), displayedComponents: .hourAndMinute)
                        .datePickerStyle(.compact)
                }
            }
            .padding(16).pulseSurface()

            SectionHeading(title: "Horario silencioso", subtitle: "Los avisos se omiten dentro de esta ventana")
            VStack(spacing: 8) {
                DatePicker("Desde", selection: hourBinding(for: .quietStart), displayedComponents: .hourAndMinute)
                DatePicker("Hasta", selection: hourBinding(for: .quietEnd), displayedComponents: .hourAndMinute)
                Text("El horario usa la zona local del iPhone. Si una hora elegida cae en silencio, BioPulse no programa ese aviso.")
                    .font(.caption).foregroundStyle(PulseStyle.secondary).frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(16).pulseSurface()

            if let notificationMessage {
                PulseFeedback(message: notificationMessage, isError: false)
                    .fixedSize(horizontal: false, vertical: true)
            }

            StatusPanel(
                symbol: "bell.badge",
                title: "Notificaciones bajo tu control",
                message: "Los recordatorios se guardan en este dispositivo. Puedes apagarlos aquí o desde Ajustes de iOS; no necesitan enviar datos de salud a la nube."
            )
        }
        .onChange(of: personal.preferences) { _, _ in
            Task { await scheduleNotifications() }
        }
    }

    private enum HourField {
        case daily
        case weekly
        case quietStart
        case quietEnd
    }

    private func hourBinding(for field: HourField) -> Binding<Date> {
        Binding(
            get: {
                let hour: Int
                switch field {
                case .daily: hour = personal.preferences.dailyReminderHour
                case .weekly: hour = personal.preferences.weeklySummaryHour
                case .quietStart: hour = personal.preferences.quietStartHour
                case .quietEnd: hour = personal.preferences.quietEndHour
                }
                return Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: .now) ?? .now
            },
            set: { date in
                let hour = Calendar.current.component(.hour, from: date)
                personal.updatePreferences { preferences in
                    switch field {
                    case .daily: preferences.dailyReminderHour = hour
                    case .weekly: preferences.weeklySummaryHour = hour
                    case .quietStart: preferences.quietStartHour = hour
                    case .quietEnd: preferences.quietEndHour = hour
                    }
                }
            }
        )
    }

    private func enableDailyReminder(_ enabled: Bool) {
        Task {
            guard await prepareNotifications(ifEnabling: enabled) else { return }
            personal.updatePreferences { $0.dailyReminderEnabled = enabled }
            if !enabled { notificationMessage = "Recordatorio diario desactivado." }
        }
    }

    private func enableWeeklyReminder(_ enabled: Bool) {
        Task {
            guard await prepareNotifications(ifEnabling: enabled) else { return }
            personal.updatePreferences { $0.weeklySummaryReminderEnabled = enabled }
            if !enabled { notificationMessage = "Recordatorio semanal desactivado." }
        }
    }

    private func prepareNotifications(ifEnabling enabled: Bool) async -> Bool {
        guard enabled else { return true }
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
            guard granted else {
                notificationMessage = "No se activó: permite las notificaciones de BioPulse en Ajustes de iOS si quieres usarlas."
                return false
            }
            return true
        } catch {
            notificationMessage = "No fue posible solicitar permiso para las notificaciones. Puedes intentarlo desde Ajustes de iOS."
            return false
        }
    }

    private func scheduleNotifications() async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["biopulse.daily.checkin", "biopulse.weekly.summary"])

        let settings = await center.notificationSettings()
        let canNotify = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
        guard canNotify else { return }

        var skippedForQuietHours = false
        if personal.preferences.dailyReminderEnabled {
            if isQuiet(personal.preferences.dailyReminderHour) {
                skippedForQuietHours = true
            } else {
                var components = DateComponents()
                components.hour = personal.preferences.dailyReminderHour
                await addNotification(
                    identifier: "biopulse.daily.checkin",
                    title: "Una pausa BioPulse",
                    body: "Si te sirve, registra cómo sientes tu energía hoy. Es opcional.",
                    components: components,
                    repeats: true,
                    using: center
                )
            }
        }

        if personal.preferences.weeklySummaryReminderEnabled {
            if isQuiet(personal.preferences.weeklySummaryHour) {
                skippedForQuietHours = true
            } else {
                var components = DateComponents()
                components.weekday = personal.preferences.weeklySummaryWeekday
                components.hour = personal.preferences.weeklySummaryHour
                await addNotification(
                    identifier: "biopulse.weekly.summary",
                    title: "Tu revisión semanal BioPulse",
                    body: "Cuando quieras, revisa las señales y el contexto disponibles en la app.",
                    components: components,
                    repeats: true,
                    using: center
                )
            }
        }

        if skippedForQuietHours {
            notificationMessage = "Un aviso quedó sin programar porque su hora cae dentro del horario silencioso. Ajusta las horas para activarlo."
        } else if personal.preferences.dailyReminderEnabled || personal.preferences.weeklySummaryReminderEnabled {
            notificationMessage = "Tus recordatorios opcionales quedaron configurados en este dispositivo."
        }
    }

    private func isQuiet(_ hour: Int) -> Bool {
        let start = personal.preferences.quietStartHour
        let end = personal.preferences.quietEndHour
        guard start != end else { return false }
        if start < end { return hour >= start && hour < end }
        return hour >= start || hour < end
    }

    private func addNotification(
        identifier: String,
        title: String,
        body: String,
        components: DateComponents,
        repeats: Bool,
        using center: UNUserNotificationCenter
    ) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: repeats)
        do {
            try await center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
        } catch {
            notificationMessage = "No se pudo programar un recordatorio. Revisa los permisos en Ajustes de iOS."
        }
    }
}
