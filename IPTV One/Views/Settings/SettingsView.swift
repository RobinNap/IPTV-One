//
//  SettingsView.swift
//  IPTV One
//
//  Created by Robin Nap on 21/01/2026.
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @Bindable var sourceManager: SourceManager
    
    @Environment(\.modelContext) private var modelContext
    @Query private var sources: [Source]
    
    @State private var showingAddSource = false
    @State private var showingError = false
    
    var body: some View {
        ZStack {
            Color.darkBackground.ignoresSafeArea()
            
            if sourceManager.isLoading {
                LoadingView(
                    message: sourceManager.loadingMessage,
                    progress: sourceManager.loadingProgress
                )
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 24) {
                        // Sources Section
                        sourcesSection
                        
                        // App Info Section
                        appInfoSection
                    }
                    .padding(16)
                }
            }
        }
        .navigationTitle("Settings")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .sheet(isPresented: $showingAddSource) {
            AddSourceView { source in
                modelContext.insert(source)
                Task {
                    await sourceManager.loadSource(source)
                }
            }
        }
        .alert("Error Loading Source", isPresented: $showingError) {
            Button("OK") {
                sourceManager.clearError()
            }
        } message: {
            Text(sourceManager.errorMessage ?? "An unknown error occurred")
        }
        .onChange(of: sourceManager.errorMessage) { _, newValue in
            if newValue != nil {
                showingError = true
            }
        }
    }
    
    private var sourcesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Sources")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                
                Spacer()
                
                Button {
                    showingAddSource = true
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
            
            if sources.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "list.bullet.rectangle")
                        .font(.system(size: 32))
                        .foregroundStyle(.secondary)
                    
                    Text("No Sources")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                    
                    Text("Add an M3U source or Xtream Codes account to get started")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .background(Color.darkCardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                VStack(spacing: 1) {
                    ForEach(sources) { source in
                        SourceRow(
                            source: source,
                            isLoading: sourceManager.isLoading
                        ) {
                            Task {
                                await sourceManager.loadSource(source)
                            }
                        } onDelete: {
                            modelContext.delete(source)
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

struct SourceRow: View {
    let source: Source
    let isLoading: Bool
    let onRefresh: () -> Void
    let onDelete: () -> Void
    
    @State private var showingDeleteConfirmation = false
    
    private var contentCount: String {
        let channels = source.channelsList.count
        let movies = source.moviesList.count
        let series = source.seriesList.count
        
        var parts: [String] = []
        if channels > 0 { parts.append("\(channels) channels") }
        if movies > 0 { parts.append("\(movies) movies") }
        if series > 0 { parts.append("\(series) series") }
        
        return parts.isEmpty ? "No content" : parts.joined(separator: ", ")
    }
    
    private var sourceTypeIcon: String {
        source.sourceType == .xtream ? "server.rack" : "doc.text"
    }
    
    private var sourceTypeLabel: String {
        source.sourceType == .xtream ? "Xtream" : "M3U"
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: sourceTypeIcon)
                .font(.system(size: 20))
                .foregroundStyle(Color.primaryAccent)
                .frame(width: 40, height: 40)
                .background(Color.primaryAccent.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(source.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                
                HStack(spacing: 6) {
                    Text(sourceTypeLabel)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.primaryAccent.opacity(0.3))
                        .clipShape(Capsule())
                    
                    Text(contentCount)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                
                HStack(spacing: 8) {
                    if let lastUpdated = source.lastUpdated {
                        Text("Updated \(lastUpdated.relativeTimeString())")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Not synced")
                            .font(.system(size: 11))
                            .foregroundStyle(.orange)
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
        .confirmationDialog("Delete Source", isPresented: $showingDeleteConfirmation) {
            Button("Delete", role: .destructive, action: onDelete)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete \"\(source.name)\"? This will remove all channels, movies, and series from this source.")
        }
    }
}

// MARK: - Add Source View

enum SourceInputType: String, CaseIterable {
    case m3u = "M3U URL"
    case xtream = "Xtream"
}

struct AddSourceView: View {
    var onAdd: (Source) -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var sourceInputType: SourceInputType = .m3u
    @State private var name = ""
    @State private var url = ""
    @State private var serverURL = ""
    @State private var username = ""
    @State private var password = ""
    
    var isValid: Bool {
        switch sourceInputType {
        case .m3u:
            return !name.isEmpty && !url.isEmpty && URL(string: url) != nil
        case .xtream:
            return !name.isEmpty && !serverURL.isEmpty && !username.isEmpty && !password.isEmpty
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.darkBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Source Type Picker
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Source Type")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.secondary)
                            
                            Picker("Source Type", selection: $sourceInputType) {
                                ForEach(SourceInputType.allCases, id: \.self) { type in
                                    Text(type.rawValue).tag(type)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                        
                        // Name
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Source Name")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.secondary)
                            
                            TextField("My IPTV", text: $name)
                                .textFieldStyle(IPTVTextFieldStyle())
                        }
                        
                        // Input fields based on type
                        if sourceInputType == .m3u {
                            m3uFields
                        } else {
                            xtreamFields
                        }
                        
                        // Help text
                        helpText
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Add Source")
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
                        addSource()
                    }
                    .disabled(!isValid)
                }
            }
            .animation(.smoothSpring, value: sourceInputType)
        }
    }
    
    private var m3uFields: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("M3U URL")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
            
            TextField("http://example.com/playlist.m3u", text: $url)
                .textFieldStyle(IPTVTextFieldStyle())
                #if os(iOS)
                .keyboardType(.URL)
                .autocapitalization(.none)
                .autocorrectionDisabled()
                #endif
        }
    }
    
    private var xtreamFields: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Server URL")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
                
                TextField("http://server.com:port", text: $serverURL)
                    .textFieldStyle(IPTVTextFieldStyle())
                    #if os(iOS)
                    .keyboardType(.URL)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                    #endif
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Username")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
                
                TextField("Username", text: $username)
                    .textFieldStyle(IPTVTextFieldStyle())
                    #if os(iOS)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
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
    }
    
    private var helpText: some View {
        Group {
            if sourceInputType == .m3u {
                Text("Enter the full M3U URL from your IPTV provider. The URL usually ends with .m3u or includes parameters like type=m3u_plus")
            } else {
                Text("Enter your Xtream credentials. The server URL is usually in the format http://server.com:port (without /player_api.php)")
            }
        }
        .font(.system(size: 12))
        .foregroundStyle(.secondary)
        .padding(.top, 8)
    }
    
    private func addSource() {
        let source: Source
        
        switch sourceInputType {
        case .m3u:
            source = Source(
                name: name,
                url: url,
                sourceType: .m3u
            )
        case .xtream:
            source = Source(
                name: name,
                url: serverURL,
                username: username,
                password: password,
                sourceType: .xtream
            )
        }
        
        onAdd(source)
        dismiss()
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
        SettingsView(sourceManager: SourceManager())
    }
    .modelContainer(for: [Source.self], inMemory: true)
}
