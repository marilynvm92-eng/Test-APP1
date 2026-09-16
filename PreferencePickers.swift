import SwiftUI

struct CountryPicker: View {
    @Binding var selection: String
    @State private var query = ""
    private var countries: [Country] {
        Country.all.filter { query.isEmpty || $0.name.localizedStandardContains(query) || $0.id.localizedStandardContains(query) }
    }
    var body: some View {
        List(countries) { country in
            Button { selection = country.id } label: {
                HStack {
                    Text(country.flag).font(.title2).accessibilityHidden(true)
                    Text(country.name).foregroundStyle(.primary)
                    Spacer()
                    if selection == country.id { Image(systemName: "checkmark.circle.fill").foregroundStyle(.indigo) }
                }.padding(.vertical, 6)
            }.accessibilityAddTraits(selection == country.id ? .isSelected : [])
        }
        .searchable(text: $query, prompt: "Buscar país")
        .overlay { if countries.isEmpty { ContentUnavailableView.search(text: query) } }
        .navigationTitle("Tu país")
    }
}

struct CategoryPicker: View {
    @Binding var selection: Set<NewsCategory>
    var minimumOne = false
    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 12)], spacing: 12) {
            ForEach(NewsCategory.allCases) { category in
                let selected = selection.contains(category)
                Button {
                    if selected {
                        if !minimumOne || selection.count > 1 { selection.remove(category) }
                    } else { selection.insert(category) }
                } label: {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Image(systemName: category.symbol).font(.title2)
                            Spacer()
                            Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                        }
                        Text(category.title).font(.headline)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .foregroundStyle(selected ? Color.white : Color.primary)
                    .background(selected ? Color.indigo : Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
                }.buttonStyle(.plain).accessibilityAddTraits(selected ? .isSelected : [])
            }
        }.padding()
    }
}
