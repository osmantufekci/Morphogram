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
    @StateObject private var navigationManager = NavigationManager.shared
    
    init() {
        do {
            let schema = Schema([
                Project.self,
                ProjectPhoto.self
            ], version: .init(1, 0, 1))
            
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
            NavigationStack(path: $navigationManager.path) {
                Dashboard()
                    .navigationDestination(for: NavigationView<AnyView>.self) { page in
                        page
                    }
            }
        }
        .environmentObject(navigationManager)
        .modelContainer(container)
    }
}

#Preview {
    Dashboard()
}
