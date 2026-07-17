import SwiftUI

struct UploadToastOverlay: View {
    let tasks: [FileUploadTask]

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(Array(tasks.enumerated()), id: \.element.id) { index, task in
                    UploadTaskRow(task: task)

                    if index < tasks.count - 1 {
                        Divider()
                            .padding(.leading, 44)  // Still perfectly aligned!
                    }
                }
            }
        }
        .frame(height: min(CGFloat(tasks.count) * 61, 300))
        // 1. MATERIAL UPGRADE: Replaced solid color with a native blur
        .background(.regularMaterial)
        .cornerRadius(16)  // Slightly rounder corners fit the floating look better
        .shadow(color: Color.black.opacity(0.15), radius: 10, y: 4)  // Softer, wider shadow
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
        // 4. TRANSITION UPGRADE: Makes the toast slide up gracefully
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: tasks)
    }
}

struct UploadTaskRow: View {
    let task: FileUploadTask

    var body: some View {
        HStack(spacing: 12) {
            // 2. DYNAMIC ICON UPGRADE
            Image(systemName: iconForFile.name)
                .foregroundColor(iconForFile.color)
                .font(.title2)  // Slightly larger icon to anchor the row
                .frame(width: 24)  // Forces the icons to align perfectly on the left

            VStack(alignment: .leading, spacing: 2) {
                Text(task.fileName)
                    // 3. TYPOGRAPHY UPGRADE: Footnote is slightly larger than caption
                    .font(.footnote)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Text(statusText)
                    .font(.caption)
                    .foregroundColor(task.state.isError ? .red : .secondary)  // Highlight errors
                    .lineLimit(1)
            }

            Spacer()
            stateIndicator
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Dynamic Icon Helper
    private var iconForFile: (name: String, color: Color) {
        let ext = (task.fileName as NSString).pathExtension.lowercased()
        switch ext {
        case "jpg", "jpeg", "png", "heic": return ("photo.fill", .blue)
        case "pdf": return ("doc.fill", .red)
        case "xlsx", "xls", "csv": return ("chart.bar.doc.fill", .green)
        case "doc", "docx", "txt": return ("doc.text.fill", .gray)
        default: return ("doc.fill", .gray)
        }
    }

    // MARK: - State Indicators
    @ViewBuilder
    private var stateIndicator: some View {
        switch task.state {
        case .pending:
            ProgressView()
        case .compressing:
            ProgressView().tint(.blue)
        case .uploading(let progress):
            CircularProgressView(progress: progress)
                .frame(width: 24, height: 24)
        case .generatingThumbnail:
            CircularProgressView(progress: 1)
                .frame(width: 24, height: 24)
        case .success:
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.title3)
        case .error(_):
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
                .font(.title3)
        }
    }

    private var statusText: String {
        switch task.state {
        case .pending: return "Waiting..."
        case .compressing: return "Compressing..."
        case .uploading(let progress): return "\(Int(progress * 100))%"
        case .generatingThumbnail: return "Finishing up..."
        case .success: return "Done"
        case .error(let message): return message
        }
    }
}

// MARK: - Helper Extension
extension UploadState {
    var isError: Bool {
        if case .error = self { return true }
        return false
    }
}
