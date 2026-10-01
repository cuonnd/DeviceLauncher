import SwiftUI
import AppKit

public struct MenuBarView: View {
    @ObservedObject var manager = DeviceManager.shared
    var openMainWindow: () -> Void

    public init(openMainWindow: @escaping () -> Void) {
        self.openMainWindow = openMainWindow
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack {
                Image(systemName: "laptopcomputer.and.iphone")
                    .foregroundColor(.blue)
                Text("Device Launcher")
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
                if manager.isBusy {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Button {
                        Task { await manager.refreshAll() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)

            // Update Notification Banner
            if let newVersion = manager.updateAvailable {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .foregroundColor(.orange)
                    Text("Có bản mới \(newVersion)!")
                        .font(.caption2)
                        .fontWeight(.bold)
                    Spacer()
                    Button("Cập nhật") {
                        Task { await manager.performAutoUpdate() }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    .controlSize(.mini)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.orange.opacity(0.12))
                .cornerRadius(6)
                .padding(.horizontal, 10)
            }

            Divider()

            // iOS Section
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("🍏 iOS Simulators")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button("Mở App") {
                        Task { await manager.openSimulatorApp() }
                    }
                    .font(.caption2)
                    .buttonStyle(.link)
                }
                .padding(.horizontal, 12)

                if manager.iosDevices.isEmpty {
                    Text("Chưa có thiết bị nào")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 12)
                } else {
                    ForEach(manager.iosDevices.prefix(4)) { dev in
                        HStack {
                            Circle()
                                .fill(dev.isBooted ? Color.green : Color.gray)
                                .frame(width: 8, height: 8)
                            Text(dev.name)
                                .font(.system(size: 13, weight: .medium))
                                .lineLimit(1)
                            Spacer()
                            if dev.isBooted {
                                Button("Tắt") {
                                    Task { await manager.shutdownIOSDevice(dev) }
                                }
                                .buttonStyle(.bordered)
                                .tint(.red)
                                .controlSize(.mini)
                            } else {
                                Button("Bật") {
                                    Task { await manager.bootIOSDevice(dev) }
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.blue)
                                .controlSize(.mini)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 2)
                    }
                }
            }

            Divider()

            // Android Section
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("🤖 Android Emulators")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button("Mở Studio") {
                        Task { await manager.openAndroidStudio() }
                    }
                    .font(.caption2)
                    .buttonStyle(.link)
                }
                .padding(.horizontal, 12)

                if manager.androidDevices.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Chưa có máy ảo AVD nào")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Button("Tạo Pixel 9 Pro (API 37)") {
                            Task { await manager.createLatestAndroidAVD() }
                        }
                        .buttonStyle(.link)
                        .font(.caption)
                    }
                    .padding(.horizontal, 12)
                } else {
                    ForEach(manager.androidDevices.prefix(4)) { avd in
                        HStack {
                            Circle()
                                .fill(avd.isRunning ? Color.green : Color.gray)
                                .frame(width: 8, height: 8)
                            Text(avd.displayName)
                                .font(.system(size: 13, weight: .medium))
                                .lineLimit(1)
                            Spacer()
                            if avd.isRunning {
                                Button("Tắt") {
                                    Task { await manager.stopAndroidAVD(avd) }
                                }
                                .buttonStyle(.bordered)
                                .tint(.red)
                                .controlSize(.mini)
                            } else {
                                Button("Bật") {
                                    Task { await manager.launchAndroidAVD(avd) }
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.green)
                                .controlSize(.mini)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 2)
                    }
                }
            }

            Divider()

            // Bottom Actions
            VStack(spacing: 4) {
                Button {
                    openMainWindow()
                } label: {
                    HStack {
                        Label("Mở Bảng Điều Khiển Chi Tiết...", systemImage: "macwindow")
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)

                Button {
                    Task { await manager.autoSetupAllLatest() }
                } label: {
                    HStack {
                        Label("Tự động Setup Bản Mới Nhất", systemImage: "sparkles")
                            .foregroundColor(.orange)
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)

                Divider()

                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    HStack {
                        Label("Thoát", systemImage: "power")
                            .foregroundColor(.red)
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
            }
            .padding(.bottom, 8)
        }
        .frame(width: 280)
    }
}
