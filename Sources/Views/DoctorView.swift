import SwiftUI

public struct DoctorView: View {
    @ObservedObject var manager = DeviceManager.shared

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Hero Banner: 1-Click Auto Setup
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "sparkles")
                            .font(.system(size: 28))
                            .foregroundColor(.orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Tự động Setup Thiết bị Mới Nhất")
                                .font(.title3)
                                .fontWeight(.bold)
                            Text("Tự động phát hiện thiếu thiết bị hoặc cấu hình, tự động tạo iPhone 17 Pro & Android Pixel 9 Pro.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        Spacer()

                        Button {
                            Task { await manager.autoSetupAllLatest() }
                        } label: {
                            Label("Chạy Tự Động Setup", systemImage: "bolt.fill")
                                .font(.headline)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                        .disabled(manager.isBusy)
                    }
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.orange.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.orange.opacity(0.25), lineWidth: 1.5)
                        )
                )

                // Environment Paths Summary
                VStack(alignment: .leading, spacing: 10) {
                    Text("Đường dẫn môi trường phát hiện được")
                        .font(.headline)

                    VStack(spacing: 8) {
                        PathRow(label: "JAVA_HOME", path: manager.javaHome, defaultIcon: "cup.and.saucer.fill")
                        PathRow(label: "ANDROID_HOME", path: manager.androidHome, defaultIcon: "folder.fill")
                        PathRow(label: "Emulator", path: manager.emulatorPath, defaultIcon: "terminal.fill")
                        PathRow(label: "Xcode Simctl", path: manager.simctlPath, defaultIcon: "apple.logo")
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(12)
                }

                // Diagnostic Checklist
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Chuẩn đoán Môi trường (Doctor Checks)")
                            .font(.headline)
                        Spacer()
                        Button {
                            Task {
                                manager.detectEnvironment()
                                await manager.runDoctorCheck()
                            }
                        } label: {
                            Label("Kiểm tra lại", systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(.bordered)
                    }

                    ForEach(manager.doctorItems) { item in
                        DoctorItemCard(item: item)
                    }
                }
            }
            .padding()
        }
    }
}

struct PathRow: View {
    let label: String
    let path: String
    let defaultIcon: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: defaultIcon)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .frame(width: 20)

            Text(label)
                .font(.subheadline)
                .fontWeight(.medium)
                .frame(width: 140, alignment: .leading)

            Text(path.isEmpty ? "Chưa thiết lập" : path)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(path.isEmpty ? .secondary : .primary)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()

            if !path.isEmpty {
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(path, forType: .string)
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.caption)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct DoctorItemCard: View {
    let item: DoctorItem
    @ObservedObject var manager = DeviceManager.shared

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: statusIcon)
                    .foregroundColor(statusColor)
                    .font(.system(size: 16, weight: .bold))
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(item.title)
                        .font(.headline)
                    Text("[\(item.category)]")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.15))
                        .cornerRadius(4)
                }

                Text(item.message)
                    .font(.subheadline)
                    .foregroundColor(.primary)

                if !item.detail.isEmpty {
                    Text(item.detail)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if item.canAutoFix {
                Button("Khắc phục ngay") {
                    Task {
                        if item.id == "android_avd" {
                            await manager.createLatestAndroidAVD()
                        } else if item.id == "ios_sim" {
                            await manager.createLatestIOSSimulator()
                        } else {
                            await manager.autoSetupAllLatest()
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(statusColor.opacity(0.2), lineWidth: 1)
        )
    }

    var statusColor: Color {
        switch item.status {
        case .ok: return .green
        case .warning: return .orange
        case .error: return .red
        case .loading: return .blue
        }
    }

    var statusIcon: String {
        switch item.status {
        case .ok: return "checkmark"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.circle.fill"
        case .loading: return "arrow.triangle.2.circlepath"
        }
    }
}
