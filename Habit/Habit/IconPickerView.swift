//
//  IconPickerView.swift
//  Habit
//

import SwiftUI

struct IconPickerView: View {
    @Binding var selectedSymbolName: String
    @Environment(\.dismiss) private var dismiss

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 18), count: 5)

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 18) {
                    ForEach(HabitIcons.all, id: \.self) { symbol in
                        let isSelected = symbol == selectedSymbolName

                        Button {
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
                .padding(contentMargin)
            }
            .background(Color("Paper"))
            .navigationTitle("Choose a Mark")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    IconPickerView(selectedSymbolName: .constant("book"))
}
