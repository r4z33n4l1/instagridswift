//
//  LaunchScreenView.swift
//  InstaGridswift
//

import SwiftUI

struct LaunchScreenView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.98, green: 0.75, blue: 0.25),
                    Color(red: 0.95, green: 0.45, blue: 0.45),
                    Color(red: 0.70, green: 0.30, blue: 0.75),
                    Color(red: 0.35, green: 0.40, blue: 0.85)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 20) {
                Image("Logo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 150, height: 150)
                    .clipShape(RoundedRectangle(cornerRadius: 32))
                    .shadow(color: .black.opacity(0.3), radius: 20, y: 10)

                Text("InstaGrid")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.2), radius: 2, y: 2)
            }
        }
    }
}

#Preview {
    LaunchScreenView()
}
