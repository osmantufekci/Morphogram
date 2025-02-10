import SwiftUI
import SwiftData

struct Dashboard: View {
    @Environment(\.modelContext) private var modelContext
    
    @Query(sort: \Category.name) private var categories: [Category]
    @Query(sort: \Project.lastPhotoDate) private var allProjects: [Project]
    
    enum CategoryFilter: Equatable {
        case all
        case specific(Category)
    }
    
    @State private var selectedFilter: CategoryFilter = .all
    @State private var showingAddProject = false
    @State private var showingAddCategory = false
    @State private var showingAddPhoto = false
    @State private var isEditing = false
    
    var body: some View {
        NavigationView {
            ZStack {
                VStack {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 15) {
                            if categories.count > 3 {
                                CategoryButton(
                                    title: "Tümü",
                                    isSelected: selectedFilter == .all
                                ) {
                                    selectedFilter = .all
                                }
                            }
                            
                            ForEach(categories) { category in
                                ZStack(alignment: .topTrailing) {
                                    CategoryButton(
                                        title: category.name,
                                        isSelected: selectedFilter == .specific(category)
                                    ) {
                                        if !isEditing {
                                            select(category)
                                        }
                                    }
                                    .wiggle(isActive: isEditing)
                                    
                                    if isEditing {
                                        Button(action: {
                                            deleteCategory(category)
                                        }) {
                                            Image(systemName: "minus.circle.fill")
                                                .foregroundColor(.red)
                                                .background(Color.white)
                                                .clipShape(Circle())
                                        }
                                        .offset(x: 5, y: -5)
                                    }
                                }
                            }
                            
                            if !categories.isEmpty {
                                Button(action: {
                                    showingAddCategory = true
                                }) {
                                    HStack {
                                        Image(systemName: "plus.circle.fill")
                                            .foregroundColor(.blue)
                                        Text("Kategori")
                                    }
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        .padding()
                    }
                    
                    if filteredProjects.isEmpty {
                        VStack(spacing: 20) {
                            if categories.isEmpty {
                                Text("Önce bir kategori oluşturmalısınız")
                                    .foregroundColor(.gray)
                                Button("Kategori Oluştur") {
                                    showingAddCategory = true
                                }
                                .buttonStyle(.bordered)
                            } else if case .specific(let category) = selectedFilter {
                                Text("\(category.name) kategorisinde hiç proje yok")
                                    .font(.title2)
                                Button("Yeni Proje Ekle") {
                                    showingAddProject = true
                                }
                                .buttonStyle(.bordered)
                            } else {
                                Text("Hiç proje oluşturulmadı.")
                                    .font(.title)
                            }
                        }
                        Spacer()
                    } else {
                        HStack {
                            if case .specific(let category) = selectedFilter {
                                Text(category.name)
                                    .font(.headline)
                                Spacer()
                                Button(action: {
                                    showingAddProject = true
                                }) {
                                    Label("Yeni Proje", systemImage: "plus")
                                }
                            }
                        }
                        .padding(.horizontal)
                        
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
                        .opacity(categories.isEmpty ? 0 : 1)
                        .padding(.trailing, 20)
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationTitle("Progress Viewer")
            .toolbar {
                if !categories.isEmpty {
                    Button(action: {
                        isEditing.toggle()
                    }) {
                        Text(isEditing ? "Bitti" : "Düzenle")
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddProject) {
            if case .specific(let category) = selectedFilter {
                AddProjectView(category: category)
            }
        }
        .sheet(isPresented: $showingAddCategory) {
            AddCategoryView()
        }
        .sheet(isPresented: $showingAddPhoto) {
            AddPhotoView()
        }
        .onAppear {
            if !categories.isEmpty {
                select(categories[0])
            }
        }
        .onChange(of: categories) { _, newCategories in
            if let category = categories.first {
                select(category)
            }
        }
    }
}

extension Dashboard {
    var filteredProjects: [Project] {
        switch selectedFilter {
        case .all:
            return allProjects.sorted { $0.lastPhotoDate > $1.lastPhotoDate }
        case .specific(let category):
            return allProjects
                .filter { $0.category?.id == category.id }
                .sorted { $0.lastPhotoDate > $1.lastPhotoDate }
        }
    }
    
    private func select(_ category: Category) {
        selectedFilter = .specific(category)
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
    
    private func deleteCategory(_ category: Category) {
        // Önce kategoriye ait tüm projeleri ve fotoğrafları sil
        for project in category.projects {
            for photo in project.photos {
                if let fileName = photo.fileName {
                    ImageManager.shared.deleteImage(fileName: fileName)
                }
                modelContext.delete(photo)
            }
            modelContext.delete(project)
        }
        
        // Kategoriyi sil
        modelContext.delete(category)
        
        // Eğer silinen kategori seçili ise ve başka kategori varsa ilk kategoriyi seç
        if case .specific(let selectedCategory) = selectedFilter, selectedCategory.id == category.id {
            if let firstCategory = categories.first(where: { $0.id != category.id }) {
                select(firstCategory)
            } else {
                selectedFilter = .all
            }
        }
        
        // Değişiklikleri kaydet
        do {
            try modelContext.save()
            print("Kategori ve içeriği başarıyla silindi")
        } catch {
            print("Kategori silinirken hata oluştu: \(error)")
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Project.self, ProjectPhoto.self, configurations: config)
    
    return Dashboard()
        .modelContainer(container)
}
