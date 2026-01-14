//
//  CreatePlanSheet.swift
//  InstaGridswift
//

import SwiftUI
import SwiftData

struct CreatePlanSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var planName = ""
    @FocusState private var isNameFocused: Bool

    private var isValidName: Bool {
        !planName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Create New Plan")
                    .font(.title2.bold())
                    .padding(.top)

                TextField("Plan name", text: $planName)
                    .textFieldStyle(.roundedBorder)
                    .focused($isNameFocused)
                    .submitLabel(.done)
                    .onSubmit(createPlan)
                    .padding(.horizontal)
                    .accessibilityLabel("Plan name")
                    .accessibilityHint("Enter a name for your new plan")

                HStack(spacing: 16) {
                    Button("Cancel") {
                        HapticService.impact(.light)
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Cancel")

                    Button("Create") {
                        createPlan()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.primaryAccent)
                    .disabled(!isValidName)
                    .accessibilityLabel("Create plan")
                    .accessibilityHint(isValidName ? "Creates a new plan with this name" : "Enter a plan name first")
                }

                Spacer()
            }
            .presentationDetents([.height(220)])
            .presentationDragIndicator(.visible)
            .onAppear {
                isNameFocused = true
            }
        }
    }

    private func createPlan() {
        let trimmedName = planName.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        HapticService.impact(.medium)
        let newPlan = Plan(name: trimmedName)
        modelContext.insert(newPlan)
        HapticService.notification(.success)
        dismiss()
    }
}

#Preview {
    CreatePlanSheet()
}
