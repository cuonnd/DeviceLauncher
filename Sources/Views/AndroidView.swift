import SwiftUI

public struct AndroidView: View {
    @ObservedObject var manager = DeviceManager.shared

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Header bar
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Android Emulators")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("\(manager.androidDevices.count) máy ảo AVD • \(manager.androidDevices.filter { $0.isRunning }.count) đang chạy")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button {
                    Task { await manager.openAndroidStudio() }
                } label: {
                    Label("Mở Android Studio", systemImage: "arrow.up.forward.app")
                }
                .buttonStyle(.bordered)

                Button {
                    Task { await manager.createLatestAndroidAVD() }
                } label: {
                    Label("Tạo Pixel 9 Pro (API 37)", systemImage: "plus.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // AVD list
            if manager.androidDevices.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "candybarphone")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("Chưa có máy ảo Android AVD nào")
                        .font(.headline)
                    Text("Bấm nút bên dưới để tự động tạo máy ảo Pixel 9 Pro mới nhất chạy Android API 37.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

                    Button("Tạo Pixel 9 Pro (API 37) Ngay") {
                        Task { await manager.createLatestAndroidAVD() }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(manager.androidDevices) { avd in
                            AndroidAVDCard(avd: avd)
                        }
                    }
                    .padding()
                }
            }
        }
    }
}

struct AndroidAVDCard: View {
    let avd: AndroidAVD
    @ObservedObject var manager = DeviceManager.shared

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(avd.isRunning ? Color.green.opacity(0.15) : Color.gray.opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: "smartphone")
                    .font(.system(size: 20))
                    .foregroundColor(avd.isRunning ? .green : .secondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(avd.displayName)
                        .font(.headline)
                        .fontWeight(.semibold)

                    HStack(spacing: 4) {
                        Circle()
                            .fill(avd.isRunning ? Color.green : Color.gray)
                            .frame(width: 7, height: 7)
                        Text(avd.isRunning ? "Đang chạy" : "Đã dừng")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(avd.isRunning ? .green : .secondary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(avd.isRunning ? Color.green.opacity(0.12) : Color.gray.opacity(0.1))
                    .cornerRadius(12)
                }

                HStack(spacing: 12) {
                    if !avd.device.isEmpty {
                        Label(avd.device, systemImage: "macbook.and.iphone")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    if !avd.target.isEmpty {
                        Label(avd.target, systemImage: "cpu")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            HStack(spacing: 8) {
                if avd.isRunning {
                    Button {
                        Task { await manager.stopAndroidAVD(avd) }
                    } label: {
                        Label("Tắt", systemImage: "stop.fill")
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                } else {
                    Button {
                        Task { await manager.launchAndroidAVD(avd) }
                    } label: {
                        Label("Bật Emulator", systemImage: "play.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                }

                Menu {
                    Button("Khởi động nguội (Cold Boot)") {
                        Task { await manager.launchAndroidAVD(avd, coldBoot: true) }
                    }
                    Button("Xoá dữ liệu & Khởi động lại (Wipe Data)") {
                        Task { await manager.launchAndroidAVD(avd, wipeData: true) }
                    }
                    Divider()
                    Button("Sao chép tên AVD") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(avd.name, forType: .string)
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .menuStyle(.borderlessButton)
                .frame(width: 28)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
                .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(avd.isRunning ? Color.green.opacity(0.3) : Color.gray.opacity(0.15), lineWidth: 1)
        )
    }
}
