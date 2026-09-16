import SwiftUI

struct ArticleImage: View {
    let url: URL?
    var height: CGFloat = 200
    var body: some View {
        GeometryReader { geometry in
            AsyncImage(url: url?.scheme == "https" ? url : nil) { phase in
                if let image = phase.image { image.resizable().scaledToFill() }
                else {
                    ZStack {
                        LinearGradient(colors: [.indigo.opacity(0.2), .teal.opacity(0.15)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        Image(systemName: "newspaper").font(.largeTitle).foregroundStyle(.secondary)
                    }
                }
            }.frame(width: geometry.size.width, height: height).clipped()
        }.frame(height: height).accessibilityHidden(true)
    }
}

struct ArticleCard: View {
    let article: NewsArticle
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ArticleImage(url: article.imageURL)
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label(article.category.title, systemImage: article.category.symbol).foregroundStyle(.indigo)
                    Spacer()
                    if article.isBreakingNews { Text("ÚLTIMA HORA").foregroundStyle(.red).font(.caption2.bold()) }
                }.font(.caption.bold())
                Text(article.title).font(.title3.bold()).foregroundStyle(.primary).fixedSize(horizontal: false, vertical: true)
                Text(article.source).font(.caption).foregroundStyle(.secondary)
                HStack {
                    Text(article.publishedAt, style: .relative)
                    Spacer()
                    Text(article.country.map { Country(id: $0).name } ?? "Internacional")
                }.font(.caption).foregroundStyle(.secondary)
            }.padding(18)
        }
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22))
        .clipShape(RoundedRectangle(cornerRadius: 22))
    }
}

struct NewsListContent: View {
    @ObservedObject var model: NewsListViewModel
    let retry: () async -> Void
    var body: some View {
        if model.loading {
            ProgressView("Cargando noticias…").frame(maxWidth: .infinity).padding(60)
        } else if model.articles.isEmpty {
            if let message = model.errorMessage {
                ContentUnavailableView {
                    Label("No pudimos cargar las noticias", systemImage: "wifi.exclamationmark")
                } description: { Text(message) } actions: {
                    Button("Intentar nuevamente") { Task { await retry() } }.buttonStyle(.borderedProminent)
                }
            } else {
                ContentUnavailableView("Sin resultados", systemImage: "newspaper", description: Text("Prueba otro tema o una búsqueda diferente."))
            }
        } else {
            if let date = model.cacheDate {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Mostrando noticias guardadas en caché", systemImage: "wifi.slash")
                    Text("Actualizadas \(date.formatted(date: .abbreviated, time: .shortened))")
                    Text(model.errorMessage ?? "")
                    Button("Intentar nuevamente") { Task { await retry() } }
                }.font(.caption).padding().frame(maxWidth: .infinity, alignment: .leading)
                    .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
            }
            ForEach(model.articles) { article in
                NavigationLink { ArticleDetailView(article: article) } label: { ArticleCard(article: article) }.buttonStyle(.plain)
            }
        }
    }
}
