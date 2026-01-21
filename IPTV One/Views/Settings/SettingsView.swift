//
//  SettingsView.swift
//  IPTV One
//
//  Created by Robin Nap on 21/01/2026.
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @Bindable var playlistManager: PlaylistManager
    
    @Environment(\.modelContext) private var modelContext
    @Query private var playlists: [Playlist]
    
    @State private var showingAddPlaylist = false
    
    var body: some View {
        ZStack {
            Color.darkBackground.ignoresSafeArea()
            
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 24) {
                    // Playlists Section
                    playlistsSection
                    
                    // App Info Section
                    appInfoSection
                }
                .padding(16)
            }
        }
        .navigationTitle("Settings")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .sheet(isPresented: $showingAddPlaylist) {
            AddPlaylistView { playlist in
                modelContext.insert(playlist)
                Task {
                    await playlistManager.loadPlaylist(playlist)
                }
            }
        }
    }
    
    private var playlistsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Playlists")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                
                Spacer()
                
                Button {
                    showingAddPlaylist = true
                } label: {
                    Label("Add", systemImage: "plus")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.primaryAccent)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            
            if playlists.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "list.bullet.rectangle")
                        .font(.system(size: 32))
                        .foregroundStyle(.secondary)
                    
                    Text("No Playlists")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                    
                    Text("Add an M3U playlist to get started")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .background(Color.darkCardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                VStack(spacing: 1) {
                    ForEach(playlists) { playlist in
                        PlaylistRow(
                            playlist: playlist,
                            isLoading: playlistManager.isLoading
                        ) {
                            Task {
                                await playlistManager.loadPlaylist(playlist)
                            }
                        } onDelete: {
                            modelContext.delete(playlist)
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }
    
    private var appInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("About")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
            
            VStack(spacing: 0) {
                infoRow(title: "Version", value: "1.0.0")
                Divider().background(Color.white.opacity(0.1))
                infoRow(title: "Build", value: "1")
            }
            .background(Color.darkCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    private func infoRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 15))
                .foregroundStyle(.white)
            
            Spacer()
            
            Text(value)
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

struct PlaylistRow: View {
    let playlist: Playlist
    let isLoading: Bool
    let onRefresh: () -> Void
    let onDelete: () -> Void
    
    @State private var showingDeleteConfirmation = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 20))
                .foregroundStyle(Color.primaryAccent)
                .frame(width: 40, height: 40)
                .background(Color.primaryAccent.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(playlist.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                
                HStack(spacing: 8) {
                    if let lastUpdated = playlist.lastUpdated {
                        Text("Updated \(lastUpdated.relativeTimeString())")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Not synced")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            Spacer()
            
            // Actions
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(0.8)
                } else {
                    Button(action: onRefresh) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 16))
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
                
                Button {
                    showingDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 16))
                        .foregroundStyle(.red)
                        .frame(width: 36, height: 36)
                        .background(Color.red.opacity(0.15))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(Color.darkCardBackground)
        .confirmationDialog("Delete Playlist", isPresented: $showingDeleteConfirmation) {
            Button("Delete", role: .destructive, action: onDelete)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete \"\(playlist.name)\"? This will remove all channels, movies, and series from this playlist.")
        }
    }
}

// MARK: - Add Playlist View

struct AddPlaylistView: View {
    var onAdd: (Playlist) -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var url = ""
    @State private var username = ""
    @State private var password = ""
    @State private var useCredentials = false
    
    var isValid: Bool {
        !name.isEmpty && !url.isEmpty && URL(string: url) != nil
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.darkBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Name
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Playlist Name")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.secondary)
                            
                            TextField("My Playlist", text: $name)
                                .textFieldStyle(IPTVTextFieldStyle())
                        }
                        
                        // URL
                        VStack(alignment: .leading, spacing: 8) {
                            Text("M3U URL")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.secondary)
                            
                            TextField("http://example.com/playlist.m3u", text: $url)
                                .textFieldStyle(IPTVTextFieldStyle())
                                #if os(iOS)
                                .keyboardType(.URL)
                                .autocapitalization(.none)
                                #endif
                        }
                        
                        // Credentials toggle
                        Toggle(isOn: $useCredentials) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Use Credentials")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(.white)
                                
                                Text("Some providers require username and password")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .tint(.primaryAccent)
                        .padding(16)
                        .background(Color.darkCardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        
                        // Credentials fields
                        if useCredentials {
                            VStack(alignment: .leading, spacing: 16) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Username")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(.secondary)
                                    
                                    TextField("Username", text: $username)
                                        .textFieldStyle(IPTVTextFieldStyle())
                                        #if os(iOS)
                                        .autocapitalization(.none)
                                        #endif
                                }
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Password")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(.secondary)
                                    
                                    SecureField("Password", text: $password)
                                        .textFieldStyle(IPTVTextFieldStyle())
                                }
                            }
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Add Playlist")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let playlist = Playlist(
                            name: name,
                            url: url,
                            username: useCredentials ? username : nil,
                            password: useCredentials ? password : nil
                        )
                        onAdd(playlist)
                        dismiss()
                    }
                    .disabled(!isValid)
                }
            }
            .animation(.smoothSpring, value: useCredentials)
        }
    }
}

struct IPTVTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.darkCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .foregroundStyle(.white)
    }
}

#Preview {
    NavigationStack {
        SettingsView(playlistManager: PlaylistManager())
    }
    .modelContainer(for: [Playlist.self], inMemory: true)
}
