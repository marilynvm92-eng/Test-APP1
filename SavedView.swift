import SwiftUI

struct SavedView: View {
    @EnvironmentObject private var app: AppState
    var body: some View {
        NavigationStack {
            ScrollView {
                if app.saved.isEmpty {
                    ContentUnavailableView("Tu biblioteca empieza aquí", systemImage: "bookmark", description: Text("Guarda una noticia desde su detalle para leer el resumen después, incluso sin conexión."))
                } else {
                    LazyVStack(spacing: 20) {
                        ForEach(app.saved) { article in
                            NavigationLink { ArticleDetailView(article: article) } label: { ArticleCard(article: article) }
                                .buttonStyle(.plain)
                                .contextMenu { Button("Quitar de guardados", role: .destructive) { app.toggleSaved(article) } }
                        }
                    }.padding()
                }
            }.background(Color(uiColor: .systemGroupedBackground)).navigationTitle("Guardados")
        }
    }
}
