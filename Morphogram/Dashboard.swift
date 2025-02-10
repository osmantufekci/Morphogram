import SwiftUI
import SwiftData

struct Dashboard: View {
    @Environment(\.modelContext) private var modelContext
    
    // Query'leri daha basit hale getiriyoruz
    @Query(sort: \Category.name) private var categories: [Category]
    @Query(sort: \Project.lastPhotoDate) private var allProjects: [Project]
    
    @State private var selectedCategory: String = "Tümü"
    @State private var showingAddProject = false
    @State private var showingAddCategory = false
    @State private var showingAddPhoto = false
    
    var filteredProjects: [Project] {
        if selectedCategory == "Tümü" {
            return allProjects.sorted { $0.lastPhotoDate > $1.lastPhotoDate }
        }
        return allProjects
            .filter { $0.categoryName == selectedCategory }
            .sorted { $0.lastPhotoDate > $1.lastPhotoDate }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                VStack {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 15) {
                            Button(action: {
                                showingAddCategory = true
                            }) {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(.blue)
                                    .font(.title)
                            }
                            
                            CategoryButton(title: "Tümü", isSelected: selectedCategory == "Tümü") {
                                selectedCategory = "Tümü"
                            }
                            
                            ForEach(categories) { category in
                                CategoryButton(title: category.name, isSelected: selectedCategory == category.name) {
                                    selectedCategory = category.name
                                }
                            }
                        }
                        .padding()
                    }
                    
                    if filteredProjects.isEmpty {
                        Text("Hiç proje oluşturulmadı.")
                            .font(.title)
                        Spacer()
                    } else {
                        List(filteredProjects) { project in
                            ProjectCard(project: project)
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
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
                            if categories.isEmpty {
                                showingAddCategory = true
                            } else {
                                showingAddPhoto = true
                            }
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
                        .padding(.trailing, 20)
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationTitle("Progress Viewerr")
        }
        .sheet(isPresented: $showingAddProject) {
            AddProjectView(modelContext: modelContext)
        }
        .sheet(isPresented: $showingAddCategory) {
            AddCategoryView(modelContext: modelContext)
        }
        .sheet(isPresented: $showingAddPhoto) {
            AddPhotoView(modelContext: modelContext)
        }
        .onAppear {
            print("Mevcut kategoriler: \(categories.map { $0.name })")
            if categories.isEmpty {
                createDefaultCategories()
            }
        }
    }
    
    private func createDefaultCategories() {
        print("Varsayılan kategoriler oluşturuluyor...")
        ["Fitness", "Bitkiler", "Sanat", "Diğer"].forEach { categoryName in
            let category = Category(name: categoryName)
            modelContext.insert(category)
            print("Kategori eklendi: \(categoryName)")
        }
        
        do {
            try modelContext.save()
            print("Kategoriler başarıyla kaydedildi")
        } catch {
            print("Kategoriler kaydedilirken hata oluştu: \(error)")
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
        
        // Projeyi kategoriden kaldır
        if let category = project.category {
            if let index = category.projects.firstIndex(of: project) {
                category.projects.remove(at: index)
            }
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
