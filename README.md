# Device Launcher for macOS 🚀

Ứng dụng macOS gọn nhẹ, tiện lợi dùng để quản lý và bật **iOS Simulator** và **Android Emulator** chỉ với 1 click, tự động phát hiện môi trường, tải và setup máy ảo bản mới nhất nếu máy tính chưa có.

---

## 🌟 Tính năng nổi bật

1. **Menu Bar Status Item (Khay hệ thống)**:
   - Thường trực trên thanh Menu Bar của macOS.
   - Bấm vào là thấy ngay danh sách máy ảo iOS và Android.
   - Bật / Tắt từng máy ảo chỉ với 1 click mà không cần mở các IDE nặng nề.

2. **Bảng điều khiển chi tiết (Dashboard Window)**:
   - **iOS Simulators**: Quản lý iPhone/iPad, xem tình trạng (Booted / Shutdown), bật Simulator App, xoá dữ liệu thiết bị (Erase).
   - **Android Emulators**: Quản lý danh sách AVD, hỗ trợ khởi động thường, Cold Boot (không nạp snapshot), hoặc Wipe Data.
   - **Chuẩn đoán & Tự động Setup (Doctor)**:
     - Tự động phát hiện Xcode, iOS Runtimes, Android SDK, OpenJDK / Java Home, Emulator binary.
     - **Nút "Tự động Setup"**: Tự động tải bản mới nhất (Android API 37 System Image) và tạo `Pixel 9 Pro (API 37)` + `iPhone 17 Pro` nếu chưa có.
   - **Nhật ký lệnh (Terminal Logs)**: Xem trực tiếp quá trình chạy lệnh `xcrun`, `avdmanager`, `emulator` trong thời gian thực.

3. **Tự động cấu hình biến môi trường**:
   - Tự động nhận diện `JAVA_HOME` từ Homebrew OpenJDK 17/21 hoặc Android Studio JBR.
   - Tự động nhận diện `ANDROID_HOME`, `emulator`, `sdkmanager`, `avdmanager`, `adb`.

4. **Kèm CLI script `sim.sh`**:
   - Cho các thao tác nhanh ngay trong Terminal.

---

## 🛠️ Hướng dẫn cài đặt & Chạy ứng dụng

### Cách 1: Tải file nén phát hành (Release)
1. Tải file **[DeviceLauncher-v1.0.0.zip](https://github.com/cuonnd/DeviceLauncher/releases/download/v1.0.0/DeviceLauncher-v1.0.0.zip)**.
2. Giải nén và kéo `DeviceLauncher.app` vào thư mục `/Applications`.
3. **Lưu ý khi mở lần đầu trên máy Mac khác (Lỗi "is damaged and can't be opened")**:
   Do app chưa đăng ký chứng chỉ trả phí với Apple ($99/năm), cơ chế Gatekeeper của macOS sẽ gắn nhãn cách ly (quarantine). Bạn chỉ cần thực hiện **1 trong các cách sau** để mở:
   - **Cách A (Nhanh nhất)**: Chạy file `Bypass_Gatekeeper.command` có sẵn trong file zip tải về.
   - **Cách B (Qua Terminal)**: Mở Terminal và gõ:
     ```bash
     xattr -cr /Applications/DeviceLauncher.app
     ```
   - **Cách C**: Chuột phải vào `DeviceLauncher.app` -> Chọn **Open** -> Chọn **Open**.

### Cách 2: Build từ mã nguồn (Source)
Chạy lệnh sau tại thư mục clone dự án:
```bash
chmod +x build.sh sim.sh
./build.sh --install --run
```

### Cách 2: Sử dụng dòng lệnh `sim.sh`
```bash
./sim.sh ios      # Bật ngay iOS Simulator
./sim.sh android  # Bật ngay Android Emulator (tự setup Pixel 9 Pro nếu chưa có)
./sim.sh setup    # Tự động setup bản mới nhất cho cả iOS và Android
./sim.sh list     # Xem danh sách máy ảo
./sim.sh app      # Mở giao diện App macOS
```

---

## 📁 Cấu trúc dự án

```
DeviceLauncher/
├── Sources/
│   ├── Main.swift            # Entrypoint SwiftUI & MenuBarExtra
│   ├── Models.swift          # Data models
│   ├── DeviceManager.swift   # Quản lý lệnh, dò tìm môi trường & tự động setup
│   └── Views/
│       ├── MainView.swift    # Giao diện chính (Sidebar)
│       ├── IOSView.swift     # Giao diện quản lý iOS
│       ├── AndroidView.swift # Giao diện quản lý Android
│       ├── DoctorView.swift  # Chuẩn đoán môi trường & Auto-setup
│       ├── MenuBarView.swift # Menu Bar popover
│       └── LogsView.swift    # Terminal logs real-time
├── Resources/
│   ├── Info.plist            # macOS App metadata
│   └── AppIcon.icns          # Icon ứng dụng macOS
├── build.sh                  # Script biên dịch Swift thành DeviceLauncher.app
├── sim.sh                    # CLI helper cho terminal
└── README.md
```
