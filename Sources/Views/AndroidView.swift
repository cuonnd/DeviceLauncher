import SwiftUI

public struct AndroidView: View {
    @ObservedObject var manager = DeviceManager.shared
    @State private var showingCreateSheet = false
    @State private var showingImagesSheet = false
    @State private var isSelectionMode = false
    @State private var selectedAvdNames: Set<String> = []
    @State private var showingBulkDeleteAlert = false

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Header bar
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Android Emulators")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text(isSelectionMode ? "Đã chọn \(selectedAvdNames.count) / \(manager.androidDevices.count) máy ảo" : "\(manager.androidDevices.count) máy ảo AVD • \(manager.androidDevices.filter { $0.isRunning }.count) đang chạy")
                        .font(.caption)
                        .foregroundColor(isSelectionMode ? .orange : .secondary)
                }

                Spacer()

                if isSelectionMode {
                    Button(selectedAvdNames.count == manager.androidDevices.count ? "Bỏ chọn tất cả" : "Chọn tất cả") {
                        if selectedAvdNames.count == manager.androidDevices.count {
                            selectedAvdNames.removeAll()
                        } else {
                            selectedAvdNames = Set(manager.androidDevices.map { $0.name })
                        }
                    }
                    .buttonStyle(.bordered)

                    Button {
                        showingBulkDeleteAlert = true
                    } label: {
                        Label("Xoá (\(selectedAvdNames.count))", systemImage: "trash.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .disabled(selectedAvdNames.isEmpty || manager.isBusy)

                    Button("Xong") {
                        isSelectionMode = false
                        selectedAvdNames.removeAll()
                    }
                    .buttonStyle(.bordered)
                } else {
                    if !manager.androidDevices.isEmpty {
                        Button {
                            isSelectionMode = true
                        } label: {
                            Label("Chọn nhiều", systemImage: "checklist")
                        }
                        .buttonStyle(.bordered)
                    }

                    Button {
                        showingImagesSheet = true
                    } label: {
                        Label("Kho System Image", systemImage: "arrow.down.circle")
                    }
                    .buttonStyle(.bordered)
                    .help("Xem và tải thêm các bản Android System Image khác (Android 36, 35, 34...)")

                    Button {
                        Task { await manager.openAndroidStudio() }
                    } label: {
                        Label("Mở Studio", systemImage: "arrow.up.forward.app")
                    }
                    .buttonStyle(.bordered)

                    Button {
                        showingCreateSheet = true
                    } label: {
                        Label("Tạo AVD Mới", systemImage: "plus.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                }
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            if !manager.brokenAndroidAVDs.isEmpty {
                VStack(spacing: 8) {
                    ForEach(manager.brokenAndroidAVDs, id: \.self) { brokenName in
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Phát hiện máy ảo không hợp lệ: \(brokenName)")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.orange)
                                Text("Máy ảo này bị lỗi cấu hình phần cứng không tồn tại. Bấm nút để dọn dẹp sạch tập tin lỗi.")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Button("Dọn dẹp") {
                                Task { await manager.deleteBrokenAVD(name: brokenName) }
                            }
                            .buttonStyle(.bordered)
                            .tint(.red)
                            .controlSize(.small)
                        }
                    }
                }
                .padding(12)
                .background(Color.orange.opacity(0.12))
                .cornerRadius(8)
                .padding(.horizontal)
                .padding(.top, 8)
            }

            // AVD list
            if manager.androidDevices.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "candybarphone")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("Chưa có máy ảo Android AVD nào")
                        .font(.headline)
                    Text("Bấm nút bên dưới để tạo nhanh máy ảo Android từ gói có sẵn trên máy hoặc tạo tuỳ chỉnh theo ý muốn.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

                    HStack(spacing: 12) {
                        Button("Tạo máy ảo AVD Nhanh") {
                            Task { await manager.createLatestAndroidAVD() }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)

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
                        ForEach(manager.androidDevices) { avd in
                            AndroidAVDCard(
                                avd: avd,
                                isSelectionMode: isSelectionMode,
                                isSelected: selectedAvdNames.contains(avd.name),
                                onToggleSelect: {
                                    if selectedAvdNames.contains(avd.name) {
                                        selectedAvdNames.remove(avd.name)
                                    } else {
                                        selectedAvdNames.insert(avd.name)
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
            CreateAndroidAVDSheet(isPresented: $showingCreateSheet)
        }
        .sheet(isPresented: $showingImagesSheet) {
            SystemImagesManagerSheet(isPresented: $showingImagesSheet)
        }
        .alert("Xác nhận xoá nhiều AVD?", isPresented: $showingBulkDeleteAlert) {
            Button("Xoá \(selectedAvdNames.count) máy ảo", role: .destructive) {
                let namesToDelete = Array(selectedAvdNames)
                Task {
                    await manager.deleteMultipleAndroidAVDs(names: namesToDelete)
                    selectedAvdNames.removeAll()
                    isSelectionMode = false
                }
            }
            Button("Huỷ", role: .cancel) {}
        } message: {
            Text("Bạn có chắc chắn muốn xoá \(selectedAvdNames.count) máy ảo Android đã chọn? Dữ liệu của các máy ảo này sẽ bị xoá vĩnh viễn.")
        }
    }
}

struct AndroidAVDCard: View {
    let avd: AndroidAVD
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
                        .foregroundColor(isSelected ? .green : .secondary)
                }
                .buttonStyle(.plain)
            }
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

                // Delete Button
                Button {
                    showingDeleteAlert = true
                } label: {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .buttonStyle(.bordered)
                .help("Xoá máy ảo AVD này")

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
        .alert("Xác nhận xoá máy ảo Android?", isPresented: $showingDeleteAlert) {
            Button("Xoá máy ảo", role: .destructive) {
                Task { await manager.deleteAndroidAVD(avd) }
            }
            Button("Huỷ", role: .cancel) {}
        } message: {
            Text("Bạn có chắc chắn muốn xoá \(avd.displayName)? Toàn bộ dữ liệu của máy ảo này sẽ bị xoá vĩnh viễn.")
        }
    }
}

// MARK: - Create Android Sheet

struct CreateAndroidAVDSheet: View {
    @Binding var isPresented: Bool
    @ObservedObject var manager = DeviceManager.shared

    @State private var name: String = "Pixel_9_Custom"
    @State private var selectedDeviceId: String = "pixel_9_pro"
    @State private var selectedPackagePath: String = ""
    @State private var errorMessage: String? = nil
    @State private var showingErrorAlert = false

    var selectedImage: AndroidSystemImage? {
        manager.availableAndroidSystemImages.first(where: { $0.packagePath == selectedPackagePath })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Tạo Android AVD Mới")
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
                Text("Tên máy ảo AVD:")
                    .font(.headline)
                TextField("Ví dụ: Pixel_9_Pro_Test", text: $name)
                    .textFieldStyle(.roundedBorder)

                let safe = DeviceManager.sanitizeAvdName(name)
                if !name.isEmpty && safe != name {
                    Text("Tên hệ thống chuẩn hoá: \(safe)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Dòng máy phần cứng (Hardware Profile):")
                    .font(.headline)
                Picker("", selection: $selectedDeviceId) {
                    ForEach(manager.availableAndroidDeviceProfiles) { profile in
                        Text(profile.name).tag(profile.deviceId)
                    }
                }
                .labelsHidden()
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Hệ điều hành Android (System Image):")
                    .font(.headline)

                Picker("", selection: $selectedPackagePath) {
                    ForEach(manager.availableAndroidSystemImages) { img in
                        Text("\(img.name) \(img.isInstalled ? "✓ [Đã có]" : "⬇ [Chưa tải]")").tag(img.packagePath)
                    }
                }
                .labelsHidden()

                if let img = selectedImage, !img.isInstalled {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text("Gói này chưa được tải về máy của bạn.")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }

                        Button {
                            Task {
                                await manager.downloadAndroidSystemImage(img.packagePath)
                            }
                        } label: {
                            HStack {
                                Image(systemName: "arrow.down.circle.fill")
                                Text("Tải gói \(img.apiLevel) về ngay")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                        .disabled(manager.isBusy)
                    }
                    .padding(10)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                }
            }

            Spacer()

            HStack {
                Button("Huỷ") {
                    isPresented = false
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("Tạo AVD") {
                    Task {
                        let res = await manager.createCustomAndroidAVD(
                            name: name,
                            deviceId: selectedDeviceId,
                            systemImage: selectedPackagePath
                        )
                        if res.success {
                            isPresented = false
                        } else {
                            errorMessage = res.error
                            showingErrorAlert = true
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .disabled(
                    name.trimmingCharacters(in: .whitespaces).isEmpty ||
                    selectedImage?.isInstalled != true ||
                    manager.isBusy
                )
            }
        }
        .padding(24)
        .frame(width: 500, height: 440)
        .onAppear {
            updateSelectionDefaults()
        }
        .task {
            if manager.availableAndroidSystemImages.isEmpty {
                await manager.fetchAvailableAndroidMetadata()
            }
            updateSelectionDefaults()
        }
        .alert("Không thể tạo máy ảo Android", isPresented: $showingErrorAlert) {
            Button("Đóng", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Đã xảy ra lỗi khi tạo AVD. Vui lòng kiểm tra lại cấu hình hoặc xem tab Terminal Logs.")
        }
    }

    private func updateSelectionDefaults() {
        if selectedDeviceId.isEmpty || !manager.availableAndroidDeviceProfiles.contains(where: { $0.deviceId == selectedDeviceId }) {
            if let firstDev = manager.availableAndroidDeviceProfiles.first {
                selectedDeviceId = firstDev.deviceId
            }
        }
        if selectedPackagePath.isEmpty || !manager.availableAndroidSystemImages.contains(where: { $0.packagePath == selectedPackagePath }) {
            if let installedImg = manager.availableAndroidSystemImages.first(where: { $0.isInstalled }) {
                selectedPackagePath = installedImg.packagePath
            } else if let first = manager.availableAndroidSystemImages.first {
                selectedPackagePath = first.packagePath
            }
        }
    }
}

// MARK: - System Images Manager Sheet

struct SystemImagesManagerSheet: View {
    @Binding var isPresented: Bool
    @ObservedObject var manager = DeviceManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Kho Android System Images")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Quản lý và tải thêm các phiên bản hệ điều hành Android (ARM64) về máy.")
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
                    ForEach(manager.availableAndroidSystemImages) { img in
                        HStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(img.isInstalled ? Color.green.opacity(0.15) : Color.gray.opacity(0.12))
                                    .frame(width: 36, height: 36)
                                Image(systemName: img.isInstalled ? "checkmark.circle.fill" : "arrow.down.circle")
                                    .foregroundColor(img.isInstalled ? .green : .secondary)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(img.name)
                                    .font(.headline)
                                Text("Gói: \(img.packagePath.prefix(45))...")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            if img.isInstalled {
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
                                    Task { await manager.downloadAndroidSystemImage(img.packagePath) }
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
                Spacer()
                Button("Đóng") {
                    isPresented = false
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(24)
        .frame(width: 540, height: 420)
    }
}
