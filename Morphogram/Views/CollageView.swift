//
//  CollageView.swift
//  Morphogram
//
//  Created by Osman Tufekci on 14.03.2025.
//

import SwiftUI
import PhotosUI

struct CollageView: View {
    @State private var collageType: CollageType = .dual
    @State private var collageItems: [CollageItem] = []
    @State private var editingItemIndex: Int? = nil
    
    init(collageItems: [CollageItem] = []) {
        self._collageItems = State(initialValue: collageItems)
        self._collageType = State(initialValue: CollageType(with: collageItems.count))
    }
    
    enum CollageType: String, CaseIterable {
        case dual = "2'li"
        case quad = "4'lü"
        
        init(with count: Int) {
            if count == 4 {
                self = .quad
            } else {
                self = .dual
            }
        }
        
        var count: Int {
            switch self {
            case .dual: return 2
            case .quad: return 4
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Kolaj tipi seçici
            Picker("Kolaj Tipi", selection: $collageType) {
                ForEach(CollageType.allCases, id: \.self) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .onChange(of: collageType) { _, newType in
                editingItemIndex = nil
            }
            
            // Kolaj görünümü
            ZStack {
                collageGridView
                    .aspectRatio(1, contentMode: .fit)
                    .background(Color.black)
                    .cornerRadius(12)
                    .padding(.horizontal)
            }
         
            Spacer()
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: {
                    editingItemIndex = nil
                    collageItems = []
                }) {
                    Image(systemName: "arrow.counterclockwise")
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
    }
    
    var collageGridView: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            
            ZStack {
                // Arka plan
                Color.black
                
                // Kolaj ızgarası
                if collageType == .dual {
                    HStack(spacing: 2) {
                        collageItemView(index: 0, size: CGSize(width: width/2 - 1, height: height))
                        collageItemView(index: 1, size: CGSize(width: width/2 - 1, height: height))
                    }
                } else {
                    VStack(spacing: 2) {
                        HStack(spacing: 2) {
                            collageItemView(index: 0, size: CGSize(width: width/2 - 1, height: height/2 - 1))
                            collageItemView(index: 1, size: CGSize(width: width/2 - 1, height: height/2 - 1))
                        }
                        HStack(spacing: 2) {
                            collageItemView(index: 2, size: CGSize(width: width/2 - 1, height: height/2 - 1))
                            collageItemView(index: 3, size: CGSize(width: width/2 - 1, height: height/2 - 1))
                        }
                    }
                }
            }
        }
    }
    
    func collageItemView(index: Int, size: CGSize) -> some View {
        let item = index <= collageItems.count-1 ? collageItems[index] : nil
        
        return ZStack {
            Color.gray.opacity(0.3)
            
            if let item = item, let image = item.image {
                ZStack {
                    // Fotoğraf
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: size.width, height: size.height)
                        .clipped()
                        .contentShape(Rectangle())
                    
                    // Sürükleme için şeffaf katman
                    Color.clear
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    if let itemIndex = collageItems.firstIndex(where: { $0.id == item.id }) {
                                        var updatedItem = collageItems[itemIndex]
                                        let translation = CGSize(
                                            width: value.translation.width / size.width,
                                            height: value.translation.height / size.height
                                        )
                                        updatedItem.offset = CGSize(
                                            width: updatedItem.offset.width + translation.width,
                                            height: updatedItem.offset.height + translation.height
                                        )
                                        collageItems[itemIndex] = updatedItem
                                    }
                                }
                        )
                }
                .onTapGesture {
                    withAnimation {
                        if let editingItemIndex, editingItemIndex == index {
                            self.editingItemIndex = nil
                        } else {
                            editingItemIndex = index
                        }
                    }
                }
                .overlay {
                    if let editIndex = editingItemIndex, editIndex == index {
                        HStack(spacing: 20) {
                            PhotosPicker(
                                selection: Binding<PhotosPickerItem?>(
                                    get: { nil },
                                    set: { newValue in
                                        if let newValue = newValue {
                                            loadImage(from: newValue, at: index)
                                            self.editingItemIndex = nil
                                        }
                                    }
                                ),
                                matching: .images
                            ) {
                                VStack {
                                    Image(systemName: "photo")
                                        .font(.system(size: 30))
                                    Text("Değiştir")
                                        .font(.caption)
                                }
                                .foregroundColor(.white)
                            }
                        }
                        .padding(30)
                        .background(Color.gray.opacity(0.8))
                        .cornerRadius(20)
                    }
                }
            } else {
                PhotosPicker(
                    selection: Binding<PhotosPickerItem?>(
                        get: { nil },
                        set: { newValue in
                            if let newValue = newValue {
                                loadImage(from: newValue, at: index)
                            }
                        }
                    ),
                    matching: .images
                ) {
                    Image(systemName: "plus.viewfinder")
                        .font(.system(size: 35))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .frame(width: size.width, height: size.height)
    }
    
    func loadImage(from item: PhotosPickerItem, at index: Int) {
        item.loadTransferable(type: Data.self) { result in
            switch result {
            case .success(let data):
                if let data = data, let image = UIImage(data: data) {
                    DispatchQueue.main.async {
                        let newItem = CollageItem(image: image)
                        
                        // Eğer seçilen indeks mevcut öğelerden büyükse, yeni öğeler ekle
                        while collageItems.count <= index {
                            collageItems.append(CollageItem(image: nil))
                        }
                        
                        // Seçilen indeksteki öğeyi güncelle
                        collageItems[index] = newItem
                    }
                }
            case .failure:
                print("Fotoğraf yüklenemedi")
            }
        }
    }
}

struct CollageItem: Identifiable {
    let id = UUID()
    var image: UIImage?
    var offset: CGSize = .zero
    var scale: CGFloat = 1.0
}

#Preview {
    CollageView()
}
