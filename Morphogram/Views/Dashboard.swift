import SwiftUI
import SwiftData

struct Dashboard: View {
    
    @EnvironmentObject var router: NavigationManager
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Project.lastPhotoDate) private var allProjects: [Project]
    @State private var showingHistoryPopover = false
    @State private var animationHistory: [AnimationHistoryItem] = []
    
    var body: some View {
            ZStack {
                VStack {
                    if allProjects.isEmpty {
                        VStack(spacing: 20) {
                            Spacer()
                            Image(systemName: "photo.stack")
                                .font(.system(size: 60))
                                .foregroundColor(.gray)
                            
                            Text("Henüz hiç projen yok.")
                                .font(.title2)
                                .fontWeight(.medium)
                            
                            Text("Başlamak için yeni proje oluşturabilirsin")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                            
                            Button(action: {
                                router.navigate(AddProjectView())
                            }) {
                                Label("Yeni Proje Ekle", systemImage: "plus.circle.fill")
                                    .font(.headline)
                            }
                            .buttonStyle(.bordered)
                            .padding(.top, 10)
                            Spacer()
                        }
                    } else {
                        HStack {
                            Spacer()
                            Button(action: {
                                router.navigate(AddProjectView())
                            }) {
                                Label("Yeni Proje", systemImage: "plus")
                            }
                            
                        }
                        .padding(.horizontal)
                        
                        List(allProjects) { project in
                            Button {
                                router.navigate(
                                    ProjectPhotosGridView(project: project)
                                        .environmentObject(router)
                                )
                            } label: {
                                ProjectCard(project: project)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button {
                                    router.navigate(AddProjectView(project: project))
                                } label: {
                                    Image(systemName: "gear")
                                }
                                .tint(.blue)
                                
                                Button(role: .destructive) {
                                    deleteProject(project)
                                } label: {
                                    Image(systemName: "trash")
                                }
                            }
                            .listRowSeparator(.hidden)
                        }
                        .listStyle(.plain)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button {
                                    loadAnimationHistory()
                                    showingHistoryPopover = true
                                } label: {
                                    Image(systemName: "clock.arrow.circlepath")
                                }
                                .popover(isPresented: $showingHistoryPopover) {
                                    AnimationHistoryView(history: $animationHistory)
                                        .presentationCompactAdaptation(.popover)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Morphogram")
            .navigationBarTitleDisplayMode(.automatic)
    }
}

extension Dashboard {
    private func loadAnimationHistory() {
        let fileManager = FileManager.default
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let historyDirectory = documentsDirectory.appendingPathComponent("AnimationHistory", isDirectory: true)
        
        do {
            // Klasör yoksa oluştur
            if !fileManager.fileExists(atPath: historyDirectory.path) {
                try fileManager.createDirectory(at: historyDirectory, withIntermediateDirectories: true)
                animationHistory = []
                return
            }
            
            // Klasördeki dosyaları listele
            let fileURLs = try fileManager.contentsOfDirectory(at: historyDirectory, includingPropertiesForKeys: [.creationDateKey, .fileSizeKey], options: .skipsHiddenFiles)
            
            // Dosyaları tarihe göre sırala (en yeniden en eskiye)
            let sortedFiles = try fileURLs.sorted { (url1, url2) -> Bool in
                let date1 = try url1.resourceValues(forKeys: [.creationDateKey]).creationDate ?? Date.distantPast
                let date2 = try url2.resourceValues(forKeys: [.creationDateKey]).creationDate ?? Date.distantPast
                return date1 > date2
            }
            
            // AnimationHistoryItem'lara dönüştür
            animationHistory = sortedFiles.compactMap { url in
                do {
                    let attributes = try fileManager.attributesOfItem(atPath: url.path)
                    let creationDate = attributes[.creationDate] as? Date ?? Date()
                    let fileSize = attributes[.size] as? Int ?? 0
                    let isGIF = url.pathExtension.lowercased() == "gif"
                    
                    return AnimationHistoryItem(
                        url: url,
                        name: url.deletingPathExtension().lastPathComponent,
                        date: creationDate,
                        type: isGIF ? .gif : .video,
                        size: fileSize
                    )
                } catch {
                    print("Dosya bilgileri alınamadı: \(error)")
                    return nil
                }
            }
        } catch {
            print("Geçmiş yüklenirken hata: \(error)")
            animationHistory = []
        }
    }
    
    private func deleteProject(_ project: Project) {
        // Önce projeye ait tüm fotoğrafları sil
        for photo in project.photos {
            if let fileName = photo.fileName {
                ImageManager.shared.deleteImage(fileName: fileName)
            }
            modelContext.delete(photo)
        }
        
        Task {
            await CalendarManager.shared.removeAllEvents(forProject: project)
        }
        NotificationManager.shared.cancelNotifications(for: project)
        // Projeyi sil
        modelContext.delete(project)
        
        // Değişiklikleri kaydet
        do {
            try modelContext.save()
            print("Proje ve fotoğrafları başarıyla silindi")
        } catch {
            print("Proje silinirken hata oluştu: \(error)")
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Project.self, ProjectPhoto.self, configurations: config)
    return Dashboard()
        .modelContainer(container)
        .environmentObject(NavigationManager.shared)
}
