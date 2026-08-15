//
//  IconPickerView.swift
//  Habit
//

import SwiftUI

struct IconPickerView: View {
    @Binding var selectedSymbolName: String
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 18), count: 5)

    private var filteredCategories: [HabitIconCategory] {
        guard !query.isEmpty else { return HabitIcons.categories }
        return HabitIcons.categories.compactMap { category in
            let matches = category.symbolNames.filter { $0.localizedCaseInsensitiveContains(query) }
            guard !matches.isEmpty else { return nil }
            return HabitIconCategory(name: category.name, symbolNames: matches)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if filteredCategories.isEmpty {
                        Text("No marks match \u{201C}\(query)\u{201D}.")
                            .font(.subheadline)
                            .foregroundStyle(Color("Tertiary"))
                            .padding(.top, 30)
                            .frame(maxWidth: .infinity)
                    }

                    ForEach(filteredCategories) { category in
                        VStack(alignment: .leading, spacing: 12) {
                            categoryLabel(category.name)

                            LazyVGrid(columns: columns, spacing: 18) {
                                ForEach(category.symbolNames, id: \.self) { symbol in
                                    iconButton(symbol)
                                }
                            }
                        }
                    }
                }
                .padding(contentMargin)
            }
            .background(Color("Paper"))
            .navigationTitle("Choose a Mark")
            .searchable(text: $query, prompt: "Search marks")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .buttonStyle(.habitSecondary)
                }
            }
        }
    }

    private func categoryLabel(_ name: String) -> some View {
        Text(name.uppercased())
            .font(.caption2.weight(.semibold))
            .tracking(1.6)
            .foregroundStyle(Color("Tertiary"))
    }

    private func iconButton(_ symbol: String) -> some View {
        let isSelected = symbol == selectedSymbolName

        return Button {
            selectedSymbolName = symbol
            dismiss()
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 22))
                .foregroundStyle(isSelected ? Color("Paper") : Color("Ink"))
                .frame(width: 46, height: 46)
                .background(Circle().fill(isSelected ? Color("Ink") : Color.clear))
                .overlay(Circle().strokeBorder(Color("Rule"), lineWidth: isSelected ? 0 : 1))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    IconPickerView(selectedSymbolName: .constant("book"))
}
