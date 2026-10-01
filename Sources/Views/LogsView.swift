import SwiftUI

public struct LogsView: View {
    @ObservedObject var manager = DeviceManager.shared

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Nhật ký Lệnh & Tiến trình (Terminal Logs)")
                    .font(.headline)
                Spacer()

                Button {
                    let text = manager.logs.map { "\($0.command)\n\($0.output)" }.joined(separator: "\n---\n")
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                } label: {
                    Label("Sao chép tất cả", systemImage: "doc.on.doc")
                }
                .buttonStyle(.bordered)
                .disabled(manager.logs.isEmpty)

                Button {
                    manager.logs.removeAll()
                } label: {
                    Label("Xoá logs", systemImage: "trash")
                }
                .buttonStyle(.bordered)
                .disabled(manager.logs.isEmpty)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            if manager.logs.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "terminal")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("Chưa có lệnh nào được chạy")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(manager.logs) { entry in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("$ \(entry.command)")
                                        .font(.system(.subheadline, design: .monospaced))
                                        .fontWeight(.semibold)
                                        .foregroundColor(entry.isError ? .red : .primary)
                                    Spacer()
                                    Text(entry.timestamp, style: .time)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }

                                if !entry.output.isEmpty {
                                    Text(entry.output)
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundColor(.secondary)
                                        .textSelection(.enabled)
                                        .padding(8)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(Color.black.opacity(0.15))
                                        .cornerRadius(6)
                                }
                            }
                            .padding(10)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(8)
                        }
                    }
                    .padding()
                }
            }
        }
    }
}
