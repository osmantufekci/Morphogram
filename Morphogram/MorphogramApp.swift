//
//  MorphogramApp.swift
//  Morphogram
//
//  Created by Osman Tufekci on 10.02.2025.
//

import SwiftUI
import SwiftData

@main
struct MorphogramApp: App {
    let container: ModelContainer
    
    init() {
        do {
            let schema = Schema([
                Category.self,
                Project.self,
                ProjectPhoto.self
            ])
            
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false
            )
            
            container = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
            
            print("SwiftData container başarıyla oluşturuldu")
            if let url = container.configurations.first?.url {
                print("Veritabanı konumu: \(url.path())")
            }
            
        } catch {
            fatalError("SwiftData container oluşturulamadı: \(error)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            Dashboard()
        }
        .modelContainer(container)
    }
}
