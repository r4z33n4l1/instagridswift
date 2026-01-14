//
//  PlansListView.swift
//  InstaGridswift
//

import SwiftUI
import SwiftData

struct PlansListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Plan.updatedAt, order: .reverse) private var plans: [Plan]
    @State private var showCreateSheet = false

    var body: some View {
        NavigationStack {
            Group {
                if plans.isEmpty {
                    EmptyStateView(
                        icon: "square.grid.3x3",
                        title: "No plans yet",
                        subtitle: "Create your first plan to start organizing your feed",
                        buttonTitle: "Create First Plan",
                        action: { showCreateSheet = true }
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(plans) { plan in
                                NavigationLink(value: plan) {
                                    PlanCard(plan: plan)
                                }
                                .buttonStyle(.plain)
                                .transition(.asymmetric(
                                    insertion: .scale(scale: 0.9).combined(with: .opacity),
                                    removal: .scale(scale: 0.9).combined(with: .opacity)
                                ))
                            }
                        }
                        .padding()
                    }
                    .transition(.opacity)
                }
            }
            .animation(.smoothSpring, value: plans.isEmpty)
            .animation(.smoothSpring, value: plans.count)
            .navigationTitle("InstaGrid")
            .navigationDestination(for: Plan.self) { plan in
                PlanEditorView(plan: plan)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        HapticService.impact(.light)
                        showCreateSheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .symbolRenderingMode(.hierarchical)
                    }
                    .accessibilityLabel("Create new plan")
                }
            }
            .sheet(isPresented: $showCreateSheet) {
                CreatePlanSheet()
            }
        }
    }
}

#Preview {
    PlansListView()
        .modelContainer(for: [Plan.self, PlanImage.self], inMemory: true)
}
