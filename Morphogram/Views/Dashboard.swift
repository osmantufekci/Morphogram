import SwiftUI
import SwiftData

struct Dashboard: View {
    
    @EnvironmentObject var router: NavigationManager
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Project.lastPhotoDate) private var allProjects: [Project]
    
    var body: some View {
            ZStack {
                VStack {
                    if allProjects.isEmpty {
                        Text("Hiç proje oluşturulmadı.")
                            .font(.title)
                        Button("Yeni Proje Ekle") {
                            router.navigate(AddProjectView())
                        }
                        .buttonStyle(.bordered)
                        Spacer()
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
                    }
                }
                
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: {
                            router.navigate(AddPhotoView())
                        }) {
                            Image(systemName: "plus")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .frame(width: 54, height: 54)
                                .background(Color.blue)
                                .clipShape(Circle())
                                .shadow(radius: 4)
                        }
                        .opacity(allProjects.isEmpty ? 0 : 1)
                        .padding(.trailing, 20)
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationTitle("Morphogram")
            .navigationBarTitleDisplayMode(.automatic)
    }
}

extension Dashboard {
    private func deleteProject(_ project: Project) {
        // Önce projeye ait tüm fotoğrafları sil
        for photo in project.photos {
            if let fileName = photo.fileName {
                ImageManager.shared.deleteImage(fileName: fileName)
            }
            modelContext.delete(photo)
        }
        
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
