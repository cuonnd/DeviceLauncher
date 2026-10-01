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

## 📺 Video Hướng Dẫn Cài Đặt & Sử Dụng

> 🎬 **Xem video hướng dẫn chi tiết trên YouTube:**  
> 👉 [**Hướng dẫn cài đặt & sử dụng DeviceLauncher trên macOS (YouTube)**](https://www.youtube.com) *(Cập nhật link video của bạn tại đây)*

---

## 🛠️ Hướng dẫn cài đặt chi tiết từng bước (A - Z)

### 📥 Bước 1: Tải ứng dụng
Tải gói ứng dụng đã build sẵn từ mục Releases:
- 🔗 **Link tải trực tiếp:** [**DeviceLauncher-v1.0.0.zip**](https://github.com/cuonnd/DeviceLauncher/releases/download/v1.0.0/DeviceLauncher-v1.0.0.zip)

---

### 📂 Bước 2: Cài đặt vào máy Mac
1. Mở file `DeviceLauncher-v1.0.0.zip` vừa tải về trong thư mục **Downloads**.
2. Kéo icon **`DeviceLauncher.app`** vào thư mục **Applications** (Ứng dụng) của máy Mac.

---

### 🛡️ Bước 3: Mở ứng dụng lần đầu (Xử lý lỗi Gatekeeper)

> [!IMPORTANT]
> Vì ứng dụng chưa đăng ký chứng chỉ thương mại trả phí của Apple ($99/năm), macOS sẽ hiển thị cảnh báo bảo mật Gatekeeper:  
> **`“DeviceLauncher” is damaged and can’t be opened. You should move it to the Trash.`**  
> Đây là cơ chế cách ly file internet (`com.apple.quarantine`) của macOS, không phải app bị lỗi!

Bạn chọn **1 trong 3 cách sau** để vượt qua cảnh báo này (chỉ cần làm duy nhất 1 lần):

#### ⚡ Cách A: Chạy file `.command` có sẵn (Nhanh & không cần gõ lệnh)
1. Trong thư mục vừa giải nén, nhấp đúp (Double-click) vào file **`Bypass_Gatekeeper.command`**.
2. Một cửa sổ Terminal sẽ hiện lên thông báo gỡ cách ly thành công và tự động mở app.

#### ⌨️ Cách B: Dùng lệnh 1 dòng trong Terminal
Mở ứng dụng **Terminal** trên Mac (bấm `Command + Space`, gõ `Terminal`), sau đó dán dòng lệnh sau và nhấn `Enter`:
```bash
xattr -cr /Applications/DeviceLauncher.app
```
Sau đó bạn có thể mở ứng dụng bình thường từ **Launchpad** hoặc thư mục **Applications**.

#### ⚙️ Cách C: Mở qua Cài đặt hệ thống (System Settings)
1. Giữ phím `Control` và bấm chuột vào `DeviceLauncher.app` -> chọn **Open**.
2. Nếu macOS vẫn chặn: Vào **Cài đặt hệ thống (System Settings)** ➔ **Quyền riêng tư & Bảo mật (Privacy & Security)** ➔ Cuộn xuống mục *Bảo mật* và bấm nút **"Open Anyway"** (Vẫn mở).

---

### 🚀 Bước 4: Thiết lập môi trường & Bật máy ảo

1. **Khởi chạy ứng dụng**:
   - Khi mở lên, bạn sẽ thấy icon điện thoại & máy tính ở **góc phải thanh Menu Bar** trên cùng màn hình.
   - Bấm vào icon này để mở danh sách nhanh hoặc bấm **"Mở Bảng Điều Khiển Chi Tiết..."** để mở giao diện quản lý đầy đủ.

2. **Tự động Setup nếu máy chưa có Simulator/Emulator**:
   - Bấm vào tab **"Chuẩn đoán & Setup"** (hình ống nghe bác sĩ 🩺).
   - Bấm nút **"🚀 Tự động Setup Bản Mới Nhất"** (Auto-Setup):
     - App sẽ tự động kiểm tra biến môi trường Java & Android SDK.
     - Tự động tạo thiết bị **iPhone 17 Pro** (iOS 26.3) nếu chưa có.
     - Tự động tải Android System Image và tạo máy ảo **Pixel 9 Pro (API 37)**.

3. **Bật thiết bị**:
   - Chỉ cần 1 click vào nút **"Bật & Mở"** (cho iOS) hoặc **"Bật Emulator"** (cho Android). Thiết bị sẽ khởi động và sẵn sàng dùng ngay!

---

### 💻 Dành cho lập trình viên (CLI & Tự build từ mã nguồn)

#### 1. Dùng lệnh nhanh `sim.sh` trong Terminal:
```bash
./sim.sh ios      # Bật ngay iOS Simulator (iPhone 17 Pro)
./sim.sh android  # Bật ngay Android Emulator (Pixel 9 Pro API 37)
./sim.sh setup    # Tự động setup bản mới nhất cho cả iOS và Android nếu thiếu
./sim.sh list     # Xem danh sách máy ảo hiện có
./sim.sh app      # Mở giao diện App đồ họa
```

#### 2. Tự build App từ mã nguồn:
```bash
git clone https://github.com/cuonnd/DeviceLauncher.git
cd DeviceLauncher
chmod +x build.sh sim.sh
./build.sh --install --run
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
