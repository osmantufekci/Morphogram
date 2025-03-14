//
//  AnimationHistoryView.swift
//  Morphogram
//
//  Created by Osman Tufekci on 14.03.2025.
//
import SwiftUI
import AVFoundation
import AVKit
import WebKit

// GIF oynatıcı
struct AnimatedGIFView: UIViewRepresentable {
    let url: URL
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.backgroundColor = .clear
        webView.isOpaque = false
        webView.scrollView.isScrollEnabled = false
        webView.contentMode = .scaleAspectFit
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        do {
            let gifData = try Data(contentsOf: url)
            uiView.load(gifData, mimeType: "image/gif", characterEncodingName: "UTF-8", baseURL: url.deletingLastPathComponent())
        } catch {
            print("GIF yüklenirken hata: \(error)")
        }
    }
}

struct AnimationHistoryItem: Identifiable {
    let id = UUID()
    let url: URL
    let name: String
    let date: Date
    let type: CreateAnimationView.AnimationType
    let size: Int
    
    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(size))
    }
    
    var thumbnail: UIImage {
        return Utility.getThumbnailImage(forUrl: url)
    }
}

struct AnimationHistoryView: View {
    @Binding var history: [AnimationHistoryItem]
    @State private var selectedItem: AnimationHistoryItem?
    @State private var showingShareSheet = false
    @State private var showingDeleteAlert = false
    @State private var errorMessage: String?
    @State private var showingError = false
    @State private var isPlaying = false
    @State private var player: AVPlayer?
    
    var body: some View {
        VStack(spacing: 0) {
            // Başlık
            HStack {
                Text("Animasyon Geçmişi")
                    .font(.headline)
                    .padding(.leading)
                
                Spacer()
                
                if !history.isEmpty {
                    Text("\(history.count) öğe")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.trailing)
                }
            }
            .padding(.vertical, 12)
            .background(Color(UIColor.secondarySystemBackground))
            
            // Önizleme alanı
            if let selectedItem = selectedItem {
                ZStack {
                    if selectedItem.type == .video {
                        AVPlayerControllerRepresented(player: $player)
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 180)
                            .shadow(radius: 2)
                            .onTapGesture {
                                isPlaying.toggle()
                                
                                if isPlaying {
                                    player?.pause()
                                } else {
                                    player?.seek(to: .zero)
                                    player?.play()
                                }
                            }
                            .onAppear {
                                player = AVPlayer(url: selectedItem.url)
                                player?.play()
                                isPlaying = true
                            }
                            .onDisappear {
                                player?.pause()
                                player = nil
                            }
                    } else {
                        // GIF için
                        AnimatedGIFView(url: selectedItem.url)
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 180)
                            .shadow(radius: 2)
                    }
                    
                    // Bilgi overlay
                    VStack {
                        Spacer()
                        HStack {
                            VStack(alignment: .leading) {
                                Text(selectedItem.name)
                                    .font(.caption)
                                    .bold()
                                    .foregroundColor(.white)
                                    .shadow(radius: 1)
                                
                                Text(selectedItem.date, style: .date)
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.8))
                                    .shadow(radius: 1)
                            }
                            
                            Spacer()
                            
                            Text(selectedItem.type.rawValue)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(selectedItem.type == .gif ? Color.orange.opacity(0.7) : Color.blue.opacity(0.7))
                                )
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [.clear, .black.opacity(0.5)]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    }
                }
                .frame(height: 180)
                .padding(.horizontal)
                .padding(.bottom, 8)
                .onTapGesture {
                    if selectedItem.type == .video {
                        if isPlaying {
                            player?.pause()
                        } else {
                            player?.play()
                        }
                        isPlaying.toggle()
                    }
                }
                // Paylaş ve Sil butonları
                HStack(spacing: 20) {
                    Button {
                        showingShareSheet = true
                    } label: {
                        Label("Paylaş", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .tint(.blue)
                    
                    Button {
                        showingDeleteAlert = true
                    } label: {
                        Label("Sil", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                    }
                    .tint(.red)
                }
                .buttonStyle(.bordered)
                .padding(.horizontal)
                .padding(.bottom, 12)
            }
            
            Divider()
            
            // Boş durum
            if history.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    
                    Text("Geçmiş Boş")
                        .font(.title3)
                        .bold()
                    
                    Text("Henüz animasyon oluşturulmamış")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                // Animasyon listesi
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(history) { item in
                            HStack(spacing: 12) {
                                // Thumbnail
                                Image(uiImage: item.thumbnail)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 50, height: 50)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.gray.opacity(0.3), lineWidth: 0.5)
                                    )
                                
                                // Bilgiler
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.name)
                                        .font(.headline)
                                        .lineLimit(1)
                                    
                                    Text(item.date, style: .date)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                // Dosya bilgileri
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text(item.type.rawValue)
                                        .font(.caption)
                                        .foregroundColor(item.type == .gif ? .orange : .blue)
                                    
                                    Text(item.formattedSize)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.trailing, 4)
                                
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(selectedItem?.id == item.id ? 
                                          Color.accentColor.opacity(0.1) : 
                                          Color(UIColor.secondarySystemBackground))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(selectedItem?.id == item.id ? Color.accentColor : Color.clear, lineWidth: 1)
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if selectedItem?.id == item.id {
                                    // Aynı öğeye tekrar tıklandığında önizlemeyi kapat
                                    if player != nil {
                                        player?.pause()
                                        player = nil
                                    }
                                    selectedItem = nil
                                } else {
                                    // Farklı öğeye tıklandığında önizlemeyi göster
                                    if player != nil {
                                        player?.pause()
                                        player = nil
                                    }
                                    selectedItem = item
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.vertical)
                }
            }
        }
        .frame(width: 350, height: 550)
        .sheet(isPresented: $showingShareSheet) {
            if let item = selectedItem {
                ShareSheet(
                    activityItems: [CustomActivityItemSource(url: item.url, projectName: item.name)],
                    onError: { message in
                        errorMessage = message
                        showingError.toggle()
                    }
                )
            }
        }
        .alert("Animasyonu Sil", isPresented: $showingDeleteAlert) {
            Button("İptal", role: .cancel) {}
            Button("Sil", role: .destructive) {
                if let item = selectedItem {
                    deleteHistoryItem(item)
                    if selectedItem?.id == item.id {
                        if player != nil {
                            player?.pause()
                            player = nil
                        }
                        selectedItem = nil
                    }
                }
            }
        } message: {
            Text("Bu animasyonu silmek istediğinize emin misiniz?")
        }
        .alert("Hata", isPresented: $showingError) {
            Button("Tamam", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "Paylaşılırken bir hata meydana geldi")
        }
        .onDisappear {
            if player != nil {
                player?.pause()
                player = nil
            }
        }
    }
    
    private func deleteHistoryItem(_ item: AnimationHistoryItem) {
        do {
            try FileManager.default.removeItem(at: item.url)
            history.removeAll { $0.id == item.id }
        } catch {
            print("Dosya silinirken hata: \(error)")
        }
    }
}
