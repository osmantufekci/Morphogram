//
//  CollageView.swift
//  Morphogram
//
//  Created by Osman Tufekci on 14.03.2025.
//

import SwiftUI
import PhotosUI
import UIKit

struct CollageView: View {
    @State private var collageType: CollageType = .dual
    @State private var collageItems: [CollageItem] = []
    @State private var editingItemIndex: Int? = nil
    @State private var showingExportOptions = false
    @State private var exportedImage: UIImage?
    @State private var dragStartLocation: CGPoint?
    @State private var dragStartOffset: CGSize?
    @State private var scaleStartValue: CGFloat = 1.0
    @State private var scaleStartScale: CGFloat = 1.0
    @State private var temporaryOffset: CGSize?
    
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
            
            // Dışa aktarma butonu
            if !collageItems.isEmpty && collageItems.allSatisfy({ $0.image != nil }) {
                Button(action: {
                    exportCollage()
                }) {
                    Text("Kolajı Dışa Aktar")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
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
        .sheet(isPresented: $showingExportOptions) {
            if let exportedImage = exportedImage {
                VStack {
                    Image(uiImage: exportedImage)
                        .resizable()
                        .scaledToFit()
                        .padding()
                    
                    HStack {
                        Button("İptal") {
                            showingExportOptions = false
                        }
                        .padding()
                        
                        Spacer()
                        
                        Button("Kaydet") {
                            UIImageWriteToSavedPhotosAlbum(exportedImage, nil, nil, nil)
                            showingExportOptions = false
                        }
                        .padding()
                    }
                }
            }
        }
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
                        .scaleEffect(item.scale)
                        .offset(x: item.offset.width * size.width, y: item.offset.height * size.height)
                        .frame(width: size.width, height: size.height)
                        .clipped()
                        .contentShape(Rectangle())
                    
                    // Sürükleme için şeffaf katman
                    Color.clear
                        .contentShape(Rectangle())
                        .gesture(
                            SimultaneousGesture(
                                DragGesture()
                                    .onChanged { value in
                                        if let itemIndex = collageItems.firstIndex(where: { $0.id == item.id }) {
                                            // Sürükleme başlangıcında mevcut offset'i kaydet
                                            if dragStartOffset == nil {
                                                dragStartOffset = collageItems[itemIndex].offset
                                                dragStartLocation = value.startLocation
                                            }
                                            
                                            guard let startOffset = dragStartOffset, let startLocation = dragStartLocation else { return }
                                            
                                            // Toplam hareket miktarını hesapla
                                            let deltaX = (value.location.x - startLocation.x) / size.width
                                            let deltaY = (value.location.y - startLocation.y) / size.height
                                            
                                            // Yeni offset'i hesapla (başlangıç offset'ine göre)
                                            var updatedItem = collageItems[itemIndex]
                                            
                                            // Geçici offset değerini hesapla (sınırlama olmadan)
                                            let tempOffset = CGSize(
                                                width: startOffset.width + deltaX,
                                                height: startOffset.height + deltaY
                                            )
                                            
                                            // Geçici offset'i kaydet (gesture bittiğinde kullanmak için)
                                            temporaryOffset = tempOffset
                                            
                                            // Offset'i güncelle
                                            updatedItem.offset = tempOffset
                                            collageItems[itemIndex] = updatedItem
                                        }
                                    }
                                    .onEnded { _ in
                                        // Sürükleme bittiğinde sınırlara geri getir
                                        if let itemIndex = collageItems.firstIndex(where: { $0.id == item.id }), let tempOffset = temporaryOffset {
                                            var updatedItem = collageItems[itemIndex]
                                            withAnimation(.snappy) {
                                                // Offset'i sınırla
                                                if let image = updatedItem.image {
                                                    updatedItem.offset = calculateSafeOffset(
                                                        for: image,
                                                        with: updatedItem.scale,
                                                        currentOffset: tempOffset,
                                                        in: size
                                                    )
                                                }
                                                collageItems[itemIndex] = updatedItem
                                            }
                                        }
                                        
                                        // Sürükleme değişkenlerini sıfırla
                                        dragStartOffset = nil
                                        dragStartLocation = nil
                                        temporaryOffset = nil
                                    },
                                MagnificationGesture()
                                    .onChanged { value in
                                        if let itemIndex = collageItems.firstIndex(where: { $0.id == item.id }) {
                                            // Zoom başlangıcında mevcut scale'i kaydet
                                            if value.magnitude == 1.0 {
                                                scaleStartValue = 1.0
                                                scaleStartScale = collageItems[itemIndex].scale
                                            }
                                            
                                            var updatedItem = collageItems[itemIndex]
                                            // Yeni scale'i hesapla (başlangıç scale'ine göre)
                                            let newScale = max(1.0, min(3.0, scaleStartScale * value.magnitude))
                                            updatedItem.scale = newScale
                                            collageItems[itemIndex] = updatedItem
                                        }
                                    }
                                    .onEnded { _ in
                                        // Zoom bittiğinde offset'i sınırla
                                        if let itemIndex = collageItems.firstIndex(where: { $0.id == item.id }) {
                                            var updatedItem = collageItems[itemIndex]
                                            
                                            // Offset'i sınırla
                                            if let image = updatedItem.image {
                                                updatedItem.offset = calculateSafeOffset(
                                                    for: image,
                                                    with: updatedItem.scale,
                                                    currentOffset: updatedItem.offset,
                                                    in: size
                                                )
                                            }
                                            
                                            collageItems[itemIndex] = updatedItem
                                        }
                                        
                                        // Zoom değişkenlerini sıfırla
                                        scaleStartValue = 1.0
                                        scaleStartScale = 1.0
                                    }
                            )
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
                        VStack(spacing: 10) {
                            HStack(spacing: 10) {
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
                                
                                Button(action: {
                                    if let itemIndex = collageItems.firstIndex(where: { $0.id == item.id }) {
                                        var updatedItem = collageItems[itemIndex]
                                        updatedItem.scale = 1.0
                                        updatedItem.offset = .zero
                                        collageItems[itemIndex] = updatedItem
                                    }
                                }) {
                                    VStack {
                                        Image(systemName: "arrow.counterclockwise")
                                            .font(.system(size: 30))
                                        Text("Sıfırla")
                                            .font(.caption)
                                    }
                                    .foregroundColor(.white)
                                }
                            }
                            
                            HStack(spacing: 20) {
                                Button(action: {
                                    if let itemIndex = collageItems.firstIndex(where: { $0.id == item.id }) {
                                        var updatedItem = collageItems[itemIndex]
                                        updatedItem.scale = max(1.0, updatedItem.scale - 0.1)
                                        
                                        // Offset'i sınırla
                                        if let image = updatedItem.image {
                                            updatedItem.offset = calculateSafeOffset(
                                                for: image,
                                                with: updatedItem.scale,
                                                currentOffset: updatedItem.offset,
                                                in: size
                                            )
                                        }
                                        
                                        collageItems[itemIndex] = updatedItem
                                    }
                                }) {
                                    VStack {
                                        Image(systemName: "minus.magnifyingglass")
                                            .font(.system(size: 30))
                                        Text("Küçült")
                                            .font(.caption)
                                    }
                                    .foregroundColor(.white)
                                }
                                
                                Button(action: {
                                    if let itemIndex = collageItems.firstIndex(where: { $0.id == item.id }) {
                                        var updatedItem = collageItems[itemIndex]
                                        updatedItem.scale = min(3.0, updatedItem.scale + 0.1)
                                        
                                        // Offset'i sınırla
                                        if let image = updatedItem.image {
                                            updatedItem.offset = calculateSafeOffset(
                                                for: image,
                                                with: updatedItem.scale,
                                                currentOffset: updatedItem.offset,
                                                in: size
                                            )
                                        }
                                        
                                        collageItems[itemIndex] = updatedItem
                                    }
                                }) {
                                    VStack {
                                        Image(systemName: "plus.magnifyingglass")
                                            .font(.system(size: 30))
                                        Text("Büyüt")
                                            .font(.caption)
                                    }
                                    .foregroundColor(.white)
                                }
                            }
                        }
                        .padding(20)
                        .background(.ultraThinMaterial.opacity(0.8))
                        .cornerRadius(10)
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
    
    // Kolajı dışa aktarma işlevi
    func exportCollage() {
        // Kolaj boyutunu belirle
        let size = CGSize(width: 1000, height: 1000)
        
        // Yeni bir UIGraphicsImageRenderer oluştur
        let renderer = UIGraphicsImageRenderer(size: size)
        
        // Kolaj görüntüsünü oluştur
        let exportedImage = renderer.image { context in
            // Arka plan rengini çiz
            UIColor.black.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            
            // Kolaj tipine göre düzen oluştur
            if collageType == .dual {
                // İki fotoğraflı düzen
                let itemWidth = size.width / 2
                let itemHeight = size.height
                
                // İlk fotoğraf
                if collageItems.count > 0, let image = collageItems[0].image {
                    drawImage(image, at: CGRect(x: 0, y: 0, width: itemWidth - 1, height: itemHeight),
                              scale: collageItems[0].scale, offset: collageItems[0].offset, context: context.cgContext)
                }
                
                // İkinci fotoğraf
                if collageItems.count > 1, let image = collageItems[1].image {
                    drawImage(image, at: CGRect(x: itemWidth + 1, y: 0, width: itemWidth - 1, height: itemHeight),
                              scale: collageItems[1].scale, offset: collageItems[1].offset, context: context.cgContext)
                }
            } else {
                // Dört fotoğraflı düzen
                let itemWidth = size.width / 2
                let itemHeight = size.height / 2
                
                // İlk fotoğraf
                if collageItems.count > 0, let image = collageItems[0].image {
                    drawImage(image, at: CGRect(x: 0, y: 0, width: itemWidth - 1, height: itemHeight - 1),
                              scale: collageItems[0].scale, offset: collageItems[0].offset, context: context.cgContext)
                }
                
                // İkinci fotoğraf
                if collageItems.count > 1, let image = collageItems[1].image {
                    drawImage(image, at: CGRect(x: itemWidth + 1, y: 0, width: itemWidth - 1, height: itemHeight - 1),
                              scale: collageItems[1].scale, offset: collageItems[1].offset, context: context.cgContext)
                }
                
                // Üçüncü fotoğraf
                if collageItems.count > 2, let image = collageItems[2].image {
                    drawImage(image, at: CGRect(x: 0, y: itemHeight + 1, width: itemWidth - 1, height: itemHeight - 1),
                              scale: collageItems[2].scale, offset: collageItems[2].offset, context: context.cgContext)
                }
                
                // Dördüncü fotoğraf
                if collageItems.count > 3, let image = collageItems[3].image {
                    drawImage(image, at: CGRect(x: itemWidth + 1, y: itemHeight + 1, width: itemWidth - 1, height: itemHeight - 1),
                              scale: collageItems[3].scale, offset: collageItems[3].offset, context: context.cgContext)
                }
            }
        }
        
        self.exportedImage = exportedImage
        showingExportOptions = true
    }
    
    // Belirli bir görüntüyü çizme işlevi
    func drawImage(_ image: UIImage, at rect: CGRect, scale: CGFloat, offset: CGSize, context: CGContext) {
        // Görüntünün orijinal boyutları
        let imageSize = image.size
        
        // Hedef dikdörtgenin boyutları
        let targetWidth = rect.width
        let targetHeight = rect.height
        
        // Görüntünün hedef dikdörtgene sığdırılması için ölçeklendirme faktörü
        let widthRatio = targetWidth / imageSize.width
        let heightRatio = targetHeight / imageSize.height
        let baseScaleFactor = max(widthRatio, heightRatio)
        
        // Kullanıcının uyguladığı ölçeklendirme
        let userScale = scale
        
        // Toplam ölçeklendirme faktörü
        let totalScale = baseScaleFactor * userScale
        
        // Ölçeklendirilmiş görüntü boyutları
        let scaledWidth = imageSize.width * totalScale
        let scaledHeight = imageSize.height * totalScale
        
        // Görüntünün merkezi (offset ile ayarlanmış)
        let centerX = rect.midX + (offset.width * rect.width)
        let centerY = rect.midY + (offset.height * rect.height)
        
        // Görüntünün çizileceği dikdörtgen
        let drawRect = CGRect(
            x: centerX - (scaledWidth / 2),
            y: centerY - (scaledHeight / 2),
            width: scaledWidth,
            height: scaledHeight
        )
        
        // Kırpma alanını ayarla
        context.saveGState()
        context.clip(to: rect)
        
        // Görüntüyü çiz
        image.draw(in: drawRect)
        
        // Kırpma alanını sıfırla
        context.restoreGState()
    }
    
    // Belirli bir kolaj öğesini kırpma işlevi (artık kullanılmıyor, drawImage ile değiştirildi)
    func cropImage(_ image: UIImage, with scale: CGFloat, offset: CGSize, size: CGSize) -> UIImage? {
        let scale = max(1.0, scale)
        
        // Orijinal görüntü boyutları
        let originalWidth = image.size.width
        let originalHeight = image.size.height
        
        // Ölçeklendirilmiş görüntü boyutları
        let scaledWidth = originalWidth * scale
        let scaledHeight = originalHeight * scale
        
        // Kırpma alanının merkezi (offset ile ayarlanmış)
        let centerX = (scaledWidth / 2) + (offset.width * size.width)
        let centerY = (scaledHeight / 2) + (offset.height * size.height)
        
        // Kırpma alanının boyutları
        let cropWidth = originalWidth
        let cropHeight = originalHeight
        
        // Kırpma alanının başlangıç noktası
        let cropX = centerX - (cropWidth / 2)
        let cropY = centerY - (cropHeight / 2)
        
        // Kırpma alanı
        let cropRect = CGRect(x: cropX, y: cropY, width: cropWidth, height: cropHeight)
        
        // Görüntüyü kırpma
        if let cgImage = image.cgImage?.cropping(to: cropRect) {
            return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
        }
        
        return nil
    }
    
    // Offset'i sınırla ve güvenli bir değer döndür
    func calculateSafeOffset(for image: UIImage, with scale: CGFloat, currentOffset: CGSize, in size: CGSize) -> CGSize {
        // Görüntünün orijinal boyutları
        let imageSize = image.size
        
        // Hedef dikdörtgenin boyutları
        let targetWidth = size.width
        let targetHeight = size.height
        
        // Görüntünün hedef dikdörtgene sığdırılması için ölçeklendirme faktörü
        let widthRatio = targetWidth / imageSize.width
        let heightRatio = targetHeight / imageSize.height
        let baseScaleFactor = max(widthRatio, heightRatio)
        
        // Toplam ölçeklendirme faktörü
        let totalScale = baseScaleFactor * scale
        
        // Ölçeklendirilmiş görüntü boyutları
        let scaledWidth = imageSize.width * totalScale
        let scaledHeight = imageSize.height * totalScale
        
        // İzin verilen maksimum offset (görüntünün kenarları çerçevenin içinde kalacak şekilde)
        let maxOffsetX = max(0, (scaledWidth - targetWidth) / (2 * targetWidth))
        let maxOffsetY = max(0, (scaledHeight - targetHeight) / (2 * targetHeight))
        
        // Offset'i sınırla
        return CGSize(
            width: max(-maxOffsetX, min(maxOffsetX, currentOffset.width)),
            height: max(-maxOffsetY, min(maxOffsetY, currentOffset.height))
        )
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
