import SwiftUI
import SwiftData

struct Dashboard: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Project.lastPhotoDate) private var allProjects: [Project]
    
    @State private var projectToEdit: Project?
    @State private var showingAddProject = false
    @State private var showingAddPhoto = false
    
    var body: some View {
        NavigationView {
            ZStack {
                VStack {
                    if allProjects.isEmpty {
                        Text("Hiç proje oluşturulmadı.")
                            .font(.title)
                        Button("Yeni Proje Ekle") {
                            showingAddProject = true
                        }
                        .buttonStyle(.bordered)
                        Spacer()
                    } else {
                        HStack {
                            Spacer()
                            Button(action: {
                                showingAddProject = true
                            }) {
                                Label("Yeni Proje", systemImage: "plus")
                            }
                            
                        }
                        .padding(.horizontal)
                        
                        List(allProjects) { project in
                            ProjectCard(project: project)
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button {
                                        projectToEdit = project
                                    } label: {
                                        Label("Ayarlar", systemImage: "gear")
                                    }
                                    .tint(.blue)
                                    
                                    Button(role: .destructive) {
                                        deleteProject(project)
                                    } label: {
                                        Label("Sil", systemImage: "trash")
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
                            showingAddPhoto = true
                        }) {
                            Image(systemName: "plus")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .frame(width: 60, height: 60)
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
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(item: $projectToEdit) { project in
            AddProjectView(project: project)
        }
        .sheet(isPresented: $showingAddProject) {
            AddProjectView()
        }
        .sheet(isPresented: $showingAddPhoto) {
            AddPhotoView()
        }
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
}
