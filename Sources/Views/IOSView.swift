import SwiftUI

public struct IOSView: View {
    @ObservedObject var manager = DeviceManager.shared
    @State private var showingCreateSheet = false

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
                    showingCreateSheet = true
                } label: {
                    Label("Tạo Thiết Bị Mới", systemImage: "plus.circle.fill")
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
                    Text("Bấm nút bên dưới để tạo thiết bị iPhone mới hoặc tạo tuỳ chỉnh theo nhu cầu.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

                    HStack(spacing: 12) {
                        Button("Tạo iPhone 17 Pro Nhanh") {
                            Task { await manager.createLatestIOSSimulator() }
                        }
                        .buttonStyle(.borderedProminent)

                        Button("Tạo Tuỳ Chỉnh...") {
                            showingCreateSheet = true
                        }
                        .buttonStyle(.bordered)
                    }
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
        .sheet(isPresented: $showingCreateSheet) {
            CreateIOSDeviceSheet(isPresented: $showingCreateSheet)
        }
    }
}

struct IOSDeviceCard: View {
    let device: IOSDevice
    @ObservedObject var manager = DeviceManager.shared
    @State private var showingDeleteAlert = false

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

                // Delete Button
                Button {
                    showingDeleteAlert = true
                } label: {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .buttonStyle(.bordered)
                .help("Xoá thiết bị Simulator này")

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
        .alert("Xác nhận xoá Simulator?", isPresented: $showingDeleteAlert) {
            Button("Xoá thiết bị", role: .destructive) {
                Task { await manager.deleteIOSDevice(device) }
            }
            Button("Huỷ", role: .cancel) {}
        } message: {
            Text("Bạn có chắc chắn muốn xoá \(device.name)? Toàn bộ dữ liệu của simulator này sẽ bị xoá vĩnh viễn.")
        }
    }
}

// MARK: - Create iOS Sheet

struct CreateIOSDeviceSheet: View {
    @Binding var isPresented: Bool
    @ObservedObject var manager = DeviceManager.shared

    @State private var name: String = "iPhone 17 Pro"
    @State private var selectedDeviceTypeId: String = ""
    @State private var selectedRuntimeId: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Tạo iOS Simulator Mới")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Text("Tên thiết bị hiển thị:")
                    .font(.headline)
                TextField("Ví dụ: iPhone 17 Pro Max Test", text: $name)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Dòng máy (Device Model):")
                    .font(.headline)
                if manager.availableIOSDeviceTypes.isEmpty {
                    Text("Đang tải danh sách thiết bị...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Picker("", selection: $selectedDeviceTypeId) {
                        ForEach(manager.availableIOSDeviceTypes) { dt in
                            Text(dt.name).tag(dt.identifier)
                        }
                    }
                    .labelsHidden()
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Phiên bản hệ điều hành (iOS Runtime):")
                        .font(.headline)
                    Spacer()
                    Button("Tải thêm Runtime...") {
                        Task { await manager.downloadIOSPlatform() }
                    }
                    .font(.caption)
                    .buttonStyle(.link)
                }

                if manager.availableIOSRuntimes.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Chưa phát hiện iOS Runtime.")
                            .font(.caption)
                            .foregroundColor(.orange)
                        Button("Tải iOS Platform (xcodebuild)") {
                            Task { await manager.downloadIOSPlatform() }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                } else {
                    Picker("", selection: $selectedRuntimeId) {
                        ForEach(manager.availableIOSRuntimes) { rt in
                            Text("\(rt.name) (v\(rt.version))").tag(rt.identifier)
                        }
                    }
                    .labelsHidden()
                }
            }

            Spacer()

            HStack {
                Button("Huỷ") {
                    isPresented = false
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("Tạo Simulator") {
                    Task {
                        let devType = selectedDeviceTypeId.isEmpty ? (manager.availableIOSDeviceTypes.first?.identifier ?? "com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro") : selectedDeviceTypeId
                        let runtime = selectedRuntimeId.isEmpty ? (manager.availableIOSRuntimes.first?.identifier ?? "com.apple.CoreSimulator.SimRuntime.iOS-26-3") : selectedRuntimeId
                        await manager.createCustomIOSDevice(name: name, deviceType: devType, runtime: runtime)
                        isPresented = false
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || manager.isBusy)
            }
        }
        .padding(24)
        .frame(width: 480, height: 380)
        .onAppear {
            if let first = manager.availableIOSDeviceTypes.first {
                selectedDeviceTypeId = first.identifier
            }
            if let firstRt = manager.availableIOSRuntimes.first {
                selectedRuntimeId = firstRt.identifier
            }
        }
    }
}
