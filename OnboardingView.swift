import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var app: AppState
    @State private var step = 0
    @State private var requesting = false
    var body: some View {
        NavigationStack {
            Group {
                switch step {
                case 0:
                    introduction(symbol: "newspaper.fill", title: "Tu mundo.\nTus noticias.", subtitle: "Noticias que realmente te interesan.")
                case 1: CountryPicker(selection: $app.preferences.country)
                case 2:
                    ScrollView {
                        VStack(alignment: .leading) {
                            Text("¿Qué te interesa?").font(.largeTitle.bold()).padding(.horizontal)
                            Text("Elige al menos un tema. Podrás cambiarlo después.").foregroundStyle(.secondary).padding(.horizontal)
                            CategoryPicker(selection: $app.preferences.categories)
                        }.padding(.top)
                    }.background(Color(uiColor: .systemGroupedBackground))
                default:
                    introduction(symbol: "bell.badge.fill", title: "Lo importante,\na tiempo.", subtitle: "Te avisaremos cuando ocurra algo importante relacionado con tus intereses.")
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 12) {
                    Text("Paso \(step + 1) de 4").font(.caption).foregroundStyle(.secondary)
                    Button {
                        if step < 3 { step += 1 }
                        else {
                            requesting = true
                            Task {
                                app.preferences.notificationsEnabled = await app.notifications.requestPermission()
                                finish()
                                requesting = false
                            }
                        }
                    } label: {
                        HStack {
                            if requesting { ProgressView().tint(.white) }
                            Text(step == 0 ? "Comenzar" : step == 3 ? "Activar notificaciones" : "Continuar").fontWeight(.semibold)
                        }.frame(maxWidth: .infinity).padding(.vertical, 8)
                    }.buttonStyle(.borderedProminent)
                        .disabled(requesting || (step == 2 && app.preferences.categories.isEmpty))
                    if step == 3 {
                        Button("Ahora no") { app.preferences.notificationsEnabled = false; finish() }.disabled(requesting)
                    }
                }.padding().background(.regularMaterial)
            }
            .toolbar {
                if step > 0 { ToolbarItem(placement: .topBarLeading) { Button("Atrás") { step -= 1 }.disabled(requesting) } }
            }
        }
    }
    private func finish() {
        app.preferences.notificationCategories = app.preferences.categories
        app.preferences.onboardingCompleted = true
    }
    private func introduction(symbol: String, title: String, subtitle: String) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                Image(systemName: symbol).font(.system(size: 72)).foregroundStyle(.indigo).accessibilityHidden(true)
                Text(title).font(.system(.largeTitle, design: .serif, weight: .bold))
                Text(subtitle).font(.title3).foregroundStyle(.secondary)
                Label("Tu selección, siempre a tu manera", systemImage: "slider.horizontal.3").font(.subheadline)
            }.frame(maxWidth: .infinity, alignment: .leading).padding(28).padding(.top, 48)
        }
    }
}
