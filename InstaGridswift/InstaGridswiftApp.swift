//
//  InstaGridswiftApp.swift
//  InstaGridswift
//
//  Created by Razeen Ali on 2026-01-13.
//

import SwiftUI
import SwiftData

@main
struct InstaGridswiftApp: App {
    @State private var showLaunchScreen = true

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Plan.self,
            PlanImage.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            Group {
                if showLaunchScreen {
                    LaunchScreenView()
                } else {
                    PlansListView()
                }
            }
            .animation(.easeOut(duration: 0.4), value: showLaunchScreen)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    showLaunchScreen = false
                }
            }
        }
        .modelContainer(sharedModelContainer)
    }
}
