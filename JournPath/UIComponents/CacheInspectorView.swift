//
//  ContainerBrowserView.swift
//  JournPath
//
//  DEBUG-only browser for the app container. Walks Application Support,
//  Caches, Documents, and tmp — every file, whatever wrote it. No Firestore,
//  no auth, no knowledge of trips or users.
//
//  Wire it into Settings ▸ Developer:
//
//      #if DEBUG
//      NavigationLink("Browse container") { ContainerBrowserView() }
//      #endif
//

#if DEBUG

    import SwiftUI
    import UniformTypeIdentifiers
    import OSLog

    // MARK: - Model

    struct FSNode: Identifiable, Hashable {
        let url: URL
        let isDirectory: Bool
        /// Recursive for directories.
        let size: Int64
        /// Files contained, recursive. Zero for leaf files.
        let fileCount: Int
        let modified: Date

        var id: String { url.path }
        var name: String { url.lastPathComponent }

        var sizeLabel: String { size.formatted(.byteCount(style: .file)) }
    }

    // MARK: - Roots

    struct ContainerRoot: Identifiable, Hashable {
        let name: String
        let url: URL
        let symbol: String
        let note: String

        var id: String { url.path }

        static let all: [ContainerRoot] = [
            .init(
                name: "Application Support",
                url: URL.applicationSupportDirectory,
                symbol: "shippingbox",
                note: "Survives eviction. Staged uploads live in uploads/."),
            .init(
                name: "Caches",
                url: URL.cachesDirectory,
                symbol: "arrow.down.circle",
                note: "The OS may delete this under disk pressure."),
            .init(
                name: "Documents",
                url: URL.documentsDirectory,
                symbol: "doc",
                note: "User-visible if the app exposes file sharing."),
            .init(
                name: "Temporary",
                url: URL.temporaryDirectory,
                symbol: "clock",
                note: "Cleared aggressively. Nothing here is durable."),
        ]
    }

    // MARK: - Scanner

    enum ContainerScanner: Sendable {
        private static let keys: [URLResourceKey] = [
            .isDirectoryKey, .fileSizeKey, .totalFileAllocatedSizeKey, .contentModificationDateKey
        ]

        /// Immediate children, with recursive sizes for directories.
        /// Synchronous — call from a detached task.
        static func children(of directory: URL) -> [FSNode] {
            let urls =
                (try? FileManager.default.contentsOfDirectory(
                    at: directory,
                    includingPropertiesForKeys: keys,
                    options: []  // no skipsHiddenFiles: show everything
                )) ?? []

            return urls.map { url in
                let values = try? url.resourceValues(forKeys: Set(keys))
                let isDir = values?.isDirectory ?? false
                let modified = values?.contentModificationDate ?? .distantPast

                if isDir {
                    let (bytes, count) = measure(url)
                    return FSNode(
                        url: url, isDirectory: true, size: bytes,
                        fileCount: count, modified: modified)
                } else {
                    let bytes = Int64(values?.totalFileAllocatedSize ?? values?.fileSize ?? 0)
                    return FSNode(
                        url: url, isDirectory: false, size: bytes,
                        fileCount: 0, modified: modified)
                }
            }
        }

        /// Total bytes and file count beneath a directory.
        nonisolated static func measure(_ directory: URL) -> (bytes: Int64, files: Int) {
            guard
                let enumerator = FileManager.default.enumerator(
                    at: directory,
                    includingPropertiesForKeys: [.isDirectoryKey, .totalFileAllocatedSizeKey, .fileSizeKey],
                    options: []
                )
            else { return (0, 0) }

            var bytes: Int64 = 0
            var files = 0

            for case let url as URL in enumerator {
                guard
                    let values = try? url.resourceValues(
                        forKeys: [.isDirectoryKey, .totalFileAllocatedSizeKey, .fileSizeKey]
                    )
                else { continue }
                if values.isDirectory == true { continue }
                bytes += Int64(values.totalFileAllocatedSize ?? values.fileSize ?? 0)
                files += 1
            }
            return (bytes, files)
        }
    }

    // MARK: - Sorting

    enum FSSort: String, CaseIterable {
        case size = "Size"
        case name = "Name"
        case newest = "Newest"

        func apply(_ nodes: [FSNode]) -> [FSNode] {
            switch self {
            case .size: return nodes.sorted { $0.size > $1.size }
            case .name: return nodes.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            case .newest: return nodes.sorted { $0.modified > $1.modified }
            }
        }
    }

    // MARK: - Root list

    struct ContainerBrowserView: View {
        @State private var totals: [String: (bytes: Int64, files: Int)] = [:]
        @State private var isScanning = false
        @AppStorage("containerBrowser.sort") private var sortRaw = FSSort.size.rawValue

        private var sort: FSSort { FSSort(rawValue: sortRaw) ?? .size }

        var body: some View {
            List {
                Section {
                    ForEach(ContainerRoot.all) { root in
                        NavigationLink {
                            DirectoryView(url: root.url)
                        } label: {
                            rootRow(root)
                        }
                    }
                } header: {
                    HStack {
                        Text("Roots")
                        Spacer()
                        if isScanning {
                            ProgressView().controlSize(.mini)
                        } else {
                            Text(grandTotal.formatted(.byteCount(style: .file)))
                                .monospacedDigit()
                        }
                    }
                } footer: {
                    Text("Sizes are allocated bytes on disk, computed recursively.")
                }

                Section("Container") {
                    Button {
                        UIPasteboard.general.string = NSHomeDirectory()
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Copy container path")
                            Text(NSHomeDirectory())
                                .font(.caption2.monospaced())
                                .foregroundStyle(.secondary)
                                .lineLimit(3)
                                .truncationMode(.middle)
                        }
                    }
                }
            }
            .navigationTitle("Container")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { sortMenu(sortRaw: $sortRaw) }
            .task { await measureRoots() }
            .refreshable { await measureRoots() }
        }

        private func rootRow(_ root: ContainerRoot) -> some View {
            let total = totals[root.url.path]
            return VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Label(root.name, systemImage: root.symbol)
                    Spacer()
                    Text(total.map { $0.bytes.formatted(.byteCount(style: .file)) } ?? "—")
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Text(total.map { "\($0.files) files · \(root.note)" } ?? root.note)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 2)
        }

        private var grandTotal: Int64 {
            totals.values.reduce(0) { $0 + $1.bytes }
        }

        private func measureRoots() async {
            isScanning = true
            defer { isScanning = false }

            let results = await withTaskGroup(of: (String, (Int64, Int)).self) { group in
                for root in ContainerRoot.all {
                    group.addTask(priority: .userInitiated) {
                        (root.url.path, ContainerScanner.measure(root.url))
                    }
                }
                var out: [String: (bytes: Int64, files: Int)] = [:]
                for await (path, result) in group { out[path] = result }
                return out
            }
            totals = results
        }
    }

    // MARK: - Directory listing

    struct DirectoryView: View {
        let url: URL

        @State private var nodes: [FSNode] = []
        @State private var isScanning = false
        @State private var selectedFile: FSNode?
        @State private var confirmingEmpty = false
        @State private var lastError: String?
        @AppStorage("containerBrowser.sort") private var sortRaw = FSSort.size.rawValue

        private let log = Logger(
            subsystem: Bundle.main.bundleIdentifier ?? "JournPath",
            category: "container-browser")

        private var sort: FSSort { FSSort(rawValue: sortRaw) ?? .size }
        private var sorted: [FSNode] { sort.apply(nodes) }

        var body: some View {
            List {
                if let hazard {
                    Section {
                        Label(hazard, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(.orange)
                    }
                }

                Section {
                    if sorted.isEmpty {
                        Text(isScanning ? "Scanning…" : "Empty")
                            .foregroundStyle(.secondary)
                            .font(.footnote)
                    } else {
                        ForEach(sorted) { node in
                            if node.isDirectory {
                                NavigationLink {
                                    DirectoryView(url: node.url)
                                } label: {
                                    row(node)
                                }
                                .swipeActions(edge: .trailing) { deleteButton(node) }
                            } else {
                                Button {
                                    selectedFile = node
                                } label: {
                                    row(node)
                                }
                                .buttonStyle(.plain)
                                .swipeActions(edge: .trailing) { deleteButton(node) }
                            }
                        }
                    }
                } header: {
                    HStack {
                        Text(relativePath)
                            .font(.caption2.monospaced())
                            .textCase(nil)
                            .lineLimit(1)
                            .truncationMode(.head)
                        Spacer()
                        Text(totalBytes.formatted(.byteCount(style: .file)))
                            .monospacedDigit()
                    }
                }
            }
            .navigationTitle(url.lastPathComponent)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker("Sort", selection: $sortRaw) {
                            ForEach(FSSort.allCases, id: \.self) { Text($0.rawValue).tag($0.rawValue) }
                        }
                        Divider()
                        Button(role: .destructive) {
                            confirmingEmpty = true
                        } label: {
                            Label("Delete all items", systemImage: "trash")
                        }
                        .disabled(nodes.isEmpty)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .confirmationDialog(
                "Delete \(nodes.count) items in \(url.lastPathComponent)?",
                isPresented: $confirmingEmpty,
                titleVisibility: .visible
            ) {
                Button("Delete \(totalBytes.formatted(.byteCount(style: .file)))", role: .destructive) {
                    emptyDirectory()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(hazard ?? "Removes everything in this folder, including subfolders. The folder itself is kept.")
            }
            .alert(
                "Couldn't delete everything",
                isPresented: .init(get: { lastError != nil }, set: { if !$0 { lastError = nil } })
            ) {
                Button("OK", role: .cancel) { lastError = nil }
            } message: {
                Text(lastError ?? "")
            }
            .sheet(item: $selectedFile) { FileDetailView(node: $0) }
            .task(id: url) { await load() }
            .refreshable { await load() }
        }

        private var totalBytes: Int64 { nodes.reduce(0) { $0 + $1.size } }

        /// Path relative to the container, so the header isn't 90% UUID.
        private var relativePath: String {
            let home = NSHomeDirectory()
            return url.path.hasPrefix(home)
                ? String(url.path.dropFirst(home.count))
                : url.path
        }

        private func emptyDirectory() {
            let fm = FileManager.default
            var failures: [String] = []

            for node in nodes {
                do {
                    try fm.removeItem(at: node.url)
                } catch {
                    failures.append(node.name)
                    log.error("delete failed for \(node.name): \(error.localizedDescription)")
                }
            }

            log.info("emptied \(relativePath): \(nodes.count - failures.count) removed, \(failures.count) failed")

            if !failures.isEmpty {
                let names = failures.prefix(3).joined(separator: ", ")
                let more = failures.count > 3 ? " and \(failures.count - 3) more" : ""
                lastError = "\(failures.count) items couldn't be removed: \(names)\(more)."
            }

            Task { await load() }
        }

        /// Folders where emptying has consequences beyond reclaiming disk.
        private var hazard: String? {
            let path = url.standardizedFileURL.path

            if path == FileUploadCache.uploadsDir.standardizedFileURL.path {
                return "Staged uploads that haven't finished will be lost. Their file docs will point at bytes that no longer exist, and those uploads can't be retried."
            }
            if path.localizedCaseInsensitiveContains("firestore") {
                return "Firestore's local persistence lives here. Deleting it clears the offline cache and any writes that haven't synced yet."
            }
            if path.hasPrefix(FileDownloadCache.root.standardizedFileURL.path) {
                return "Downloaded files only — everything here re-downloads on next view. Safe."
            }
            return nil
        }

        private func row(_ node: FSNode) -> some View {
            HStack(spacing: 10) {
                Image(systemName: node.isDirectory ? "folder.fill" : icon(for: node.url))
                    .foregroundStyle(node.isDirectory ? .blue : .secondary)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 2) {
                    Text(node.name)
                        .font(.callout)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text(subtitle(node))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                Spacer(minLength: 8)

                Text(node.sizeLabel)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 2)
        }

        private func subtitle(_ node: FSNode) -> String {
            let when = node.modified.formatted(.relative(presentation: .numeric))
            return node.isDirectory ? "\(node.fileCount) files · \(when)" : when
        }

        private func icon(for url: URL) -> String {
            guard let type = UTType(filenameExtension: url.pathExtension) else { return "doc" }
            if type.conforms(to: .image) { return "photo" }
            if type.conforms(to: .movie) { return "film" }
            if type.conforms(to: .pdf) { return "doc.richtext" }
            if type.conforms(to: .archive) { return "doc.zipper" }
            if type.conforms(to: .text) || type.conforms(to: .json) { return "doc.plaintext" }
            return "doc"
        }

        @ViewBuilder
        private func deleteButton(_ node: FSNode) -> some View {
            Button("Delete", role: .destructive) {
                try? FileManager.default.removeItem(at: node.url)
                nodes.removeAll { $0.id == node.id }
            }
        }

        private func load() async {
            isScanning = true
            defer { isScanning = false }
            let target = url
            nodes = await Task.detached(priority: .userInitiated) {
                await ContainerScanner.children(of: target)
            }.value
        }
    }

    // MARK: - File detail

    struct FileDetailView: View {
        let node: FSNode
        @Environment(\.dismiss) private var dismiss
        @State private var preview: String?

        var body: some View {
            NavigationStack {
                List {
                    Section {
                        LabeledContent("Size", value: node.sizeLabel)
                        LabeledContent("Modified", value: node.modified.formatted(date: .abbreviated, time: .shortened))
                        if let type = UTType(filenameExtension: node.url.pathExtension) {
                            LabeledContent("Type", value: type.preferredMIMEType ?? type.identifier)
                        }
                    }

                    Section("Path") {
                        Text(node.url.path)
                            .font(.caption.monospaced())
                            .textSelection(.enabled)
                    }

                    if let preview {
                        Section("First 2 KB") {
                            Text(preview)
                                .font(.caption2.monospaced())
                                .textSelection(.enabled)
                        }
                    }

                    Section {
                        ShareLink(item: node.url) {
                            Label("Export file", systemImage: "square.and.arrow.up")
                        }
                        Button(role: .destructive) {
                            try? FileManager.default.removeItem(at: node.url)
                            dismiss()
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
                .navigationTitle(node.name)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
                .task { await loadPreview() }
            }
        }

        /// Peek at the head of the file. Staged uploads are named `.dat`
        /// regardless of content, so this is the quickest way to tell a JPEG
        /// from a PDF from a truncated write.
        private func loadPreview() async {
            let url = node.url
            preview = await Task.detached(priority: .utility) { () -> String? in
                guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
                defer { try? handle.close() }
                guard let data = try? handle.read(upToCount: 2_048), !data.isEmpty else { return nil }

                if let text = String(data: data, encoding: .utf8),
                    text.unicodeScalars.allSatisfy({ $0 == "\n" || $0 == "\t" || $0.value >= 32 })
                {
                    return text
                }
                // Binary: hex dump the first 128 bytes. Magic numbers are usually
                // enough — FFD8FF is JPEG, 25504446 is %PDF, 89504E47 is PNG.
                let hexStrings = data.prefix(128).map { String(format: "%02X", $0) }
                let pairs = await hexStrings.chunked(into: 2).map { $0.joined() }
                let lines = await pairs.chunked(into: 16).map { $0.joined(separator: " ") }
                return lines.joined(separator: "\n")
            }.value
        }
    }

    // MARK: - Shared toolbar

    @ViewBuilder
    private func sortMenu(sortRaw: Binding<String>) -> some View {
        Menu {
            Picker("Sort", selection: sortRaw) {
                ForEach(FSSort.allCases, id: \.self) { Text($0.rawValue).tag($0.rawValue) }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
        }
    }

    // MARK: - Preview

    #Preview {
        NavigationStack {
            ContainerBrowserView()
        }
    }

#endif
