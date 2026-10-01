import SwiftUI

public struct IOSView: View {
    @ObservedObject var manager = DeviceManager.shared

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Header bar
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("iOS Simulators")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("\(manager.iosDevices.count) thiết bị • \(manager.iosDevices.filter { $0.isBooted }.count) đang chạy")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button {
                    Task { await manager.openSimulatorApp() }
                } label: {
                    Label("Mở Simulator App", systemImage: "arrow.up.forward.app")
                }
                .buttonStyle(.bordered)

                Button {
                    Task { await manager.createLatestIOSSimulator() }
                } label: {
                    Label("Tạo iPhone 17 Pro", systemImage: "plus.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // Device list
            if manager.iosDevices.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "iphone.slash")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("Chưa có thiết bị iOS Simulator nào")
                        .font(.headline)
                    Text("Bấm nút bên dưới để tạo thiết bị iPhone 17 Pro với iOS runtime hiện có.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Tạo iPhone 17 Pro Ngay") {
                        Task { await manager.createLatestIOSSimulator() }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(manager.iosDevices) { dev in
                            IOSDeviceCard(device: dev)
                        }
                    }
                    .padding()
                }
            }
        }
    }
}

struct IOSDeviceCard: View {
    let device: IOSDevice
    @ObservedObject var manager = DeviceManager.shared

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(device.isBooted ? Color.green.opacity(0.15) : Color.gray.opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: device.iconName)
                    .font(.system(size: 20))
                    .foregroundColor(device.isBooted ? .green : .secondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(device.name)
                        .font(.headline)
                        .fontWeight(.semibold)

                    HStack(spacing: 4) {
                        Circle()
                            .fill(device.isBooted ? Color.green : Color.gray)
                            .frame(width: 7, height: 7)
                        Text(device.isBooted ? "Đang chạy (Booted)" : "Đã tắt (Shutdown)")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(device.isBooted ? .green : .secondary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(device.isBooted ? Color.green.opacity(0.12) : Color.gray.opacity(0.1))
                    .cornerRadius(12)
                }

                HStack(spacing: 12) {
                    if let runtime = device.runtime {
                        Label(runtime, systemImage: "apple.logo")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Text("UDID: \(device.udid.prefix(8))...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            HStack(spacing: 8) {
                if device.isBooted {
                    Button {
                        Task { await manager.shutdownIOSDevice(device) }
                    } label: {
                        Label("Tắt", systemImage: "stop.fill")
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)

                    Button {
                        Task { await manager.openSimulatorApp() }
                    } label: {
                        Label("Mở UI", systemImage: "macwindow")
                    }
                    .buttonStyle(.bordered)
                } else {
                    Button {
                        Task { await manager.bootIOSDevice(device) }
                    } label: {
                        Label("Bật & Mở", systemImage: "play.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                }

                Menu {
                    Button("Xoá dữ liệu (Erase All)") {
                        Task { await manager.eraseIOSDevice(device) }
                    }
                    Button("Sao chép UDID") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(device.udid, forType: .string)
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
                .stroke(device.isBooted ? Color.green.opacity(0.3) : Color.gray.opacity(0.15), lineWidth: 1)
        )
    }
}
