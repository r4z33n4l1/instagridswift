//
//  ImageStorageService.swift
//  InstaGridswift
//

import Foundation
import UIKit

actor ImageStorageService {
    static let shared = ImageStorageService()

    private var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private func plansDirectory() -> URL {
        documentsDirectory.appendingPathComponent("plans", isDirectory: true)
    }

    private func planDirectory(for planID: UUID) -> URL {
        plansDirectory().appendingPathComponent(planID.uuidString, isDirectory: true)
    }

    func initialize() throws {
        let plansDir = plansDirectory()
        if !FileManager.default.fileExists(atPath: plansDir.path) {
            try FileManager.default.createDirectory(at: plansDir, withIntermediateDirectories: true)
        }
    }

    func saveImage(_ data: Data, planID: UUID) -> String? {
        do {
            let planDir = planDirectory(for: planID)

            if !FileManager.default.fileExists(atPath: planDir.path) {
                try FileManager.default.createDirectory(at: planDir, withIntermediateDirectories: true)
            }

            let filename = "\(UUID().uuidString).jpg"
            let relativePath = "plans/\(planID.uuidString)/\(filename)"
            let fullURL = documentsDirectory.appendingPathComponent(relativePath)

            try data.write(to: fullURL)

            return relativePath
        } catch {
            print("Error saving image: \(error)")
            return nil
        }
    }

    func deleteImage(at relativePath: String) {
        let fullURL = documentsDirectory.appendingPathComponent(relativePath)
        try? FileManager.default.removeItem(at: fullURL)
    }

    func deletePlanImages(_ plan: Plan) {
        let planDir = planDirectory(for: plan.id)
        try? FileManager.default.removeItem(at: planDir)
    }
}
