import SwiftUI
import UniformTypeIdentifiers

public struct IOSView: View {
    @ObservedObject var manager = DeviceManager.shared
    @State private var showingCreateSheet = false
    @State private var showingRuntimesSheet = false
    @State private var isSelectionMode = false
    @State private var selectedDeviceIds: Set<String> = []
    @State private var showingBulkDeleteAlert = false

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Header bar
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("iOS Simulators")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text(isSelectionMode ? "Đã chọn \(selectedDeviceIds.count) / \(manager.iosDevices.count) thiết bị" : "\(manager.iosDevices.count) thiết bị • \(manager.iosDevices.filter { $0.isBooted }.count) đang chạy")
                        .font(.caption)
                        .foregroundColor(isSelectionMode ? .orange : .secondary)
                }

                Spacer()

                if isSelectionMode {
                    Button(selectedDeviceIds.count == manager.iosDevices.count ? "Bỏ chọn tất cả" : "Chọn tất cả") {
                        if selectedDeviceIds.count == manager.iosDevices.count {
                            selectedDeviceIds.removeAll()
                        } else {
                            selectedDeviceIds = Set(manager.iosDevices.map { $0.udid })
                        }
                    }
                    .buttonStyle(.bordered)

                    Button {
                        showingBulkDeleteAlert = true
                    } label: {
                        Label("Xoá (\(selectedDeviceIds.count))", systemImage: "trash.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .disabled(selectedDeviceIds.isEmpty || manager.isBusy)

                    Button("Xong") {
                        isSelectionMode = false
                        selectedDeviceIds.removeAll()
                    }
                    .buttonStyle(.bordered)
                } else {
                    if !manager.iosDevices.isEmpty {
                        Button {
                            isSelectionMode = true
                        } label: {
                            Label("Chọn nhiều", systemImage: "checklist")
                        }
                        .buttonStyle(.bordered)
                    }

                    Button {
                        showingRuntimesSheet = true
                    } label: {
                        Label("Kho iOS Runtime", systemImage: "arrow.down.circle")
                    }
                    .buttonStyle(.bordered)
                    .help("Xem và tải thêm các bản iOS Runtime (iOS 18, 17, 16...) để chạy các dòng máy cũ")

                    Button {
                        Task { await manager.openSimulatorApp() }
                    } label: {
                        Label("Mở App", systemImage: "arrow.up.forward.app")
                    }
                    .buttonStyle(.bordered)

                    Button {
                        showingCreateSheet = true
                    } label: {
                        Label("Tạo Mới", systemImage: "plus.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                }
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
                            IOSDeviceCard(
                                device: dev,
                                isSelectionMode: isSelectionMode,
                                isSelected: selectedDeviceIds.contains(dev.udid),
                                onToggleSelect: {
                                    if selectedDeviceIds.contains(dev.udid) {
                                        selectedDeviceIds.remove(dev.udid)
                                    } else {
                                        selectedDeviceIds.insert(dev.udid)
                                    }
                                }
                            )
                        }
                    }
                    .padding()
                }
            }
        }
        .sheet(isPresented: $showingCreateSheet) {
            CreateIOSDeviceSheet(isPresented: $showingCreateSheet)
        }
        .sheet(isPresented: $showingRuntimesSheet) {
            IOSRuntimesManagerSheet(isPresented: $showingRuntimesSheet)
        }
        .alert("Xác nhận xoá nhiều Simulator?", isPresented: $showingBulkDeleteAlert) {
            Button("Xoá \(selectedDeviceIds.count) thiết bị", role: .destructive) {
                let idsToDelete = Array(selectedDeviceIds)
                Task {
                    await manager.deleteMultipleIOSDevices(udids: idsToDelete)
                    selectedDeviceIds.removeAll()
                    isSelectionMode = false
                }
            }
            Button("Huỷ", role: .cancel) {}
        } message: {
            Text("Bạn có chắc chắn muốn xoá \(selectedDeviceIds.count) thiết bị iOS đã chọn? Dữ liệu của các thiết bị này sẽ bị xoá vĩnh viễn.")
        }
    }
}

struct IOSDeviceCard: View {
    let device: IOSDevice
    var isSelectionMode: Bool = false
    var isSelected: Bool = false
    var onToggleSelect: () -> Void = {}

    @ObservedObject var manager = DeviceManager.shared
    @State private var showingDeleteAlert = false

    var body: some View {
        HStack(spacing: 16) {
            if isSelectionMode {
                Button(action: onToggleSelect) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundColor(isSelected ? .blue : .secondary)
                }
                .buttonStyle(.plain)
            }

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
    @State private var showingRuntimesSheet = false
    @State private var errorMessage: String? = nil
    @State private var showingErrorAlert = false

    var selectedDeviceType: IOSDeviceType? {
        manager.availableIOSDeviceTypes.first(where: { $0.identifier == selectedDeviceTypeId })
    }

    var selectedRuntime: IOSRuntime? {
        manager.availableIOSRuntimes.first(where: { $0.identifier == selectedRuntimeId })
    }

    var isCompatible: Bool {
        guard let dt = selectedDeviceType, let rt = selectedRuntime else { return true }
        return dt.isCompatible(withRuntimeVersion: rt.version)
    }

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
                            let compatible = dt.isCompatible(withRuntimeVersion: selectedRuntime?.version ?? "26")
                            Text(compatible ? dt.name : "\(dt.name) ⚠️ (Yêu cầu iOS ≤ \(dt.maxMajorVersion ?? 16))")
                                .tag(dt.identifier)
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
                    Button("Kho iOS Runtime...") {
                        showingRuntimesSheet = true
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

            if !isCompatible, let dt = selectedDeviceType, let maxMajor = dt.maxMajorVersion {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.title3)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(dt.name) không tương thích với \(selectedRuntime?.name ?? "bản iOS này")")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.orange)
                            Text("\(dt.name) là dòng máy đời cũ, chỉ hỗ trợ tối đa iOS \(maxMajor). Để tạo và khởi động máy này, bạn cần cài đặt thêm iOS \(maxMajor) Runtime.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Button("Mở Kho iOS Runtime để tải iOS \(maxMajor)...") {
                        showingRuntimesSheet = true
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    .controlSize(.small)
                }
                .padding(10)
                .background(Color.orange.opacity(0.12))
                .cornerRadius(8)
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
                        let res = await manager.createCustomIOSDevice(name: name, deviceType: devType, runtime: runtime)
                        if res.success {
                            isPresented = false
                        } else {
                            errorMessage = res.error
                            showingErrorAlert = true
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || !isCompatible || manager.isBusy)
            }
        }
        .padding(24)
        .frame(width: 500, height: isCompatible ? 400 : 470)
        .onAppear {
            if let first = manager.availableIOSDeviceTypes.first {
                selectedDeviceTypeId = first.identifier
            }
            if let firstRt = manager.availableIOSRuntimes.first {
                selectedRuntimeId = firstRt.identifier
            }
        }
        .sheet(isPresented: $showingRuntimesSheet) {
            IOSRuntimesManagerSheet(isPresented: $showingRuntimesSheet)
        }
        .alert("Không thể tạo iOS Simulator", isPresented: $showingErrorAlert) {
            Button("Đóng", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Đã xảy ra lỗi khi tạo Simulator.")
        }
    }
}

// MARK: - iOS Runtimes Manager Sheet

struct IOSRuntimesManagerSheet: View {
    @Binding var isPresented: Bool
    @ObservedObject var manager = DeviceManager.shared

    @State private var errorMessage: String? = nil
    @State private var showingErrorAlert = false
    @State private var successMessage: String? = nil
    @State private var showingSuccessAlert = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Kho iOS Simulator Runtimes")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Quản lý và tải thêm các phiên bản iOS (iOS 18, 17, 16...) để chạy các dòng thiết bị cũ (iPhone 8, X, v.v.).")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
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

            ScrollView {
                VStack(spacing: 12) {
                    ForEach(manager.availableDownloadableIOSRuntimes) { rt in
                        HStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(rt.isInstalled ? Color.green.opacity(0.15) : Color.gray.opacity(0.12))
                                    .frame(width: 40, height: 40)
                                Image(systemName: rt.isInstalled ? "checkmark.circle.fill" : "arrow.down.circle")
                                    .font(.title3)
                                    .foregroundColor(rt.isInstalled ? .green : .secondary)
                            }

                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 8) {
                                    Text(rt.name)
                                        .font(.headline)
                                    Text(rt.sizeDescription)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Text(rt.compatibleDevicesDescription)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            if rt.isInstalled {
                                Text("Đã cài đặt")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.green)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Color.green.opacity(0.1))
                                    .cornerRadius(8)
                            } else {
                                Button {
                                    Task {
                                        let res = await manager.downloadSpecificIOSRuntime(version: rt.buildVersion)
                                        if res.success {
                                            successMessage = "Đã cài đặt thành công \(rt.name)!"
                                            showingSuccessAlert = true
                                        } else {
                                            errorMessage = res.error
                                            showingErrorAlert = true
                                        }
                                    }
                                } label: {
                                    Label("Tải về", systemImage: "arrow.down")
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.blue)
                                .disabled(manager.isBusy)
                            }
                        }
                        .padding(12)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(10)
                    }
                }
                .padding(.vertical, 4)
            }

            Divider()

            HStack {
                Button {
                    let panel = NSOpenPanel()
                    panel.allowsMultipleSelection = false
                    panel.canChooseDirectories = false
                    panel.canChooseFiles = true
                    panel.message = "Chọn file iOS Simulator Runtime (.dmg hoặc .simruntime) đã tải:"
                    if let dmgType = UTType(filenameExtension: "dmg") {
                        panel.allowedContentTypes = [dmgType, UTType(filenameExtension: "simruntime") ?? .data]
                    }
                    if panel.runModal() == .OK, let url = panel.url {
                        Task {
                            let res = await manager.addIOSRuntimeFromFile(path: url.path)
                            if res.success {
                                successMessage = "Đã nạp runtime thành công từ \(url.lastPathComponent)!"
                                showingSuccessAlert = true
                            } else {
                                errorMessage = res.error
                                showingErrorAlert = true
                            }
                        }
                    }
                } label: {
                    Label("Nạp file .dmg thủ công...", systemImage: "folder.badge.plus")
                }
                .buttonStyle(.bordered)
                .disabled(manager.isBusy)

                Button {
                    Task { await manager.openXcodeSettings() }
                } label: {
                    Label("Mở Xcode Settings", systemImage: "gearshape")
                }
                .buttonStyle(.bordered)
                .help("Mở Xcode -> Settings -> Platforms để tải trực tiếp từ Apple")

                Spacer()

                Button("Đóng") {
                    isPresented = false
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(24)
        .frame(width: 580, height: 460)
        .alert("Lỗi tải / cài đặt Runtime", isPresented: $showingErrorAlert) {
            Button("Đóng", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Đã xảy ra lỗi.")
        }
        .alert("Thành công", isPresented: $showingSuccessAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(successMessage ?? "")
        }
    }
}
