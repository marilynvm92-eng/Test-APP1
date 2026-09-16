import SwiftUI
import SafariServices

struct BrowserLink: Identifiable { let id = UUID(); let url: URL }

struct SafariView: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController { SFSafariViewController(url: url) }
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

struct ArticleDetailView: View {
    @EnvironmentObject private var app: AppState
    let article: NewsArticle
    @State private var link: BrowserLink?
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                ArticleImage(url: article.imageURL, height: 260).clipShape(RoundedRectangle(cornerRadius: 22))
                Label(article.category.title, systemImage: article.category.symbol).font(.subheadline.bold()).foregroundStyle(.indigo)
                Text(article.title).font(.system(.largeTitle, design: .serif, weight: .bold))
                VStack(alignment: .leading, spacing: 6) {
                    Text(article.source).font(.headline)
                    Text(article.publishedAt.formatted(date: .long, time: .shortened)).font(.subheadline).foregroundStyle(.secondary)
                }
                Text(article.description).font(.body).lineSpacing(6)
                if article.id.hasPrefix("demo-") {
                    Text("Contenido ficticio: el enlace abre una página de ejemplo.").font(.caption).foregroundStyle(.secondary)
                }
                if let url = article.safeArticleURL {
                    Button { link = BrowserLink(url: url) } label: {
                        Label("Leer noticia completa", systemImage: "safari").frame(maxWidth: .infinity).padding(.vertical, 8)
                    }.buttonStyle(.borderedProminent)
                    Text("La publicación completa pertenece a su fuente original.").font(.caption).foregroundStyle(.secondary)
                }
            }.padding()
        }.navigationTitle("Noticia").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if let url = article.safeArticleURL { ShareLink(item: url) { Label("Compartir", systemImage: "square.and.arrow.up") } }
                    Button { app.toggleSaved(article) } label: {
                        Label(app.isSaved(article) ? "Quitar de guardados" : "Guardar", systemImage: app.isSaved(article) ? "bookmark.fill" : "bookmark")
                    }
                }
            }.sheet(item: $link) { SafariView(url: $0.url).ignoresSafeArea() }
    }
}
