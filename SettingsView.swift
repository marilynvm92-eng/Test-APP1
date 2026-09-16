import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var app: AppState
    @State private var confirmReset = false
    var body: some View {
        NavigationStack {
            Form {
                Section("Personaliza tu lectura") {
                    NavigationLink {
                        CountryPicker(selection: $app.preferences.country)
                    } label: { LabeledContent("País", value: Country(id: app.preferences.country).name) }
                    NavigationLink {
                        ScrollView {
                            Text("Mantén al menos un tema seleccionado.").font(.subheadline).foregroundStyle(.secondary).padding(.top)
                            CategoryPicker(selection: $app.preferences.categories, minimumOne: true)
                        }.background(Color(uiColor: .systemGroupedBackground)).navigationTitle("Temas favoritos")
                    } label: { LabeledContent("Temas favoritos", value: "\(app.preferences.categories.count)") }
                    Picker("Apariencia", selection: $app.preferences.appearance) {
                        ForEach(Appearance.allCases) { Text($0.title).tag($0) }
                    }
                }
                Section { NavigationLink("Notificaciones") { NotificationSettingsView(service: app.notifications) } }
                Section("Acerca de MyNews") {
                    LabeledContent("Fuente de datos", value: app.isDemo ? "Ejemplo" : "Backend conectado")
                    Text(app.isDemo ? "Las noticias son ficticias. Las imágenes de ejemplo requieren internet." : "Los titulares y resúmenes se atribuyen a su fuente original.")
                        .font(.caption).foregroundStyle(.secondary)
                    Text("Los resúmenes guardados están disponibles sin conexión. Las imágenes y los artículos completos pueden necesitar internet.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section {
                    Button("Borrar preferencias", role: .destructive) { confirmReset = true }
                } footer: { Text("Reinicia el onboarding y cancela los avisos locales. Conserva tus noticias guardadas.") }
            }.navigationTitle("Configuración")
                .confirmationDialog("¿Borrar tus preferencias?", isPresented: $confirmReset, titleVisibility: .visible) {
                    Button("Borrar preferencias", role: .destructive) { app.resetPreferences() }
                    Button("Cancelar", role: .cancel) {}
                }
        }
    }
}

struct NotificationSettingsView: View {
    @EnvironmentObject private var app: AppState
    @ObservedObject var service: NotificationService
    @State private var requesting = false
    var body: some View {
        Form {
            Section {
                Toggle("Recibir notificaciones", isOn: Binding(get: { app.preferences.notificationsEnabled }, set: { value in
                    if !value { app.preferences.notificationsEnabled = false }
                    else {
                        requesting = true
                        Task {
                            app.preferences.notificationsEnabled = await service.requestPermission()
                            requesting = false
                        }
                    }
                })).disabled(requesting)
                if requesting { ProgressView("Solicitando permiso…") }
                if service.status == .denied {
                    Text("El permiso está desactivado en iOS.").foregroundStyle(.secondary)
                    Button("Abrir ajustes de iOS") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                    }
                }
            } footer: { Text("Para avisos de noticias: máximo 3 al día, al menos una hora entre avisos y sin repetir IDs durante 30 días.") }
            Section("Categorías que pueden avisarte") {
                ForEach(NewsCategory.allCases) { category in
                    Toggle(category.title, isOn: Binding(get: { app.preferences.notificationCategories.contains(category) }, set: { selected in
                        if selected { app.preferences.notificationCategories.insert(category) }
                        else { app.preferences.notificationCategories.remove(category) }
                    }))
                }
            }
            Section {
                Button("Enviar notificación local de prueba") { Task { await service.test(preferences: app.preferences) } }
                Text("La prueba aparece en 5 segundos. Los avisos automáticos locales se revisan al actualizar Home con noticias reales. Para avisos con la app cerrada hay que configurar el backend push.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }.navigationTitle("Notificaciones")
            .task { await service.refreshStatus() }
            .alert("Notificaciones", isPresented: Binding(get: { service.message != nil }, set: { if !$0 { service.message = nil } })) {
                Button("Aceptar") { service.message = nil }
            } message: { Text(service.message ?? "") }
    }
}
