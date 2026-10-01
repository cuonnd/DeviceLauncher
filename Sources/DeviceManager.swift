import Foundation
import Combine
import AppKit

@MainActor
public class DeviceManager: ObservableObject {
    public static let shared = DeviceManager()

    @Published public var iosDevices: [IOSDevice] = []
    @Published public var androidDevices: [AndroidAVD] = []
    @Published public var doctorItems: [DoctorItem] = []
    @Published public var logs: [CommandLogEntry] = []
    @Published public var isBusy: Bool = false
    @Published public var busyMessage: String = ""
    @Published public var latestLogMessage: String = ""

    // Available metadata for creation
    @Published public var availableIOSDeviceTypes: [IOSDeviceType] = []
    @Published public var availableIOSRuntimes: [IOSRuntime] = []
    @Published public var availableAndroidSystemImages: [AndroidSystemImage] = []
    @Published public var availableAndroidDeviceProfiles: [AndroidDeviceProfile] = []

    // Version & Updates
    public let appVersion: String = "1.2.0"
    @Published public var updateAvailable: String? = nil
    @Published public var updateDownloadUrl: String? = nil
    @Published public var updateReleaseNotes: String? = nil

    // Discovered paths
    @Published public var javaHome: String = ""
    @Published public var androidHome: String = ""
    @Published public var emulatorPath: String = ""
    @Published public var sdkmanagerPath: String = ""
    @Published public var avdmanagerPath: String = ""
    @Published public var adbPath: String = ""
    @Published public var simctlPath: String = "/usr/bin/xcrun"

    private var autoRefreshTimer: Timer?

    public init() {
        detectEnvironment()
        Task {
            await refreshAll()
        }
        setupPeriodicRefresh()
    }

    private func setupPeriodicRefresh() {
        autoRefreshTimer = Timer.scheduledTimer(withTimeInterval: 8.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.quickStatusCheck()
            }
        }
    }

    // MARK: - Environment Detection

    public func detectEnvironment() {
        let fm = FileManager.default

        // Detect JAVA_HOME
        let javaCandidates = [
            "/opt/homebrew/opt/openjdk@17",
            "/opt/homebrew/opt/openjdk@21",
            "/opt/homebrew/opt/openjdk",
            "/Applications/Android Studio.app/Contents/jbr/Contents/Home",
            "/Library/Java/JavaVirtualMachines/temurin-25.jdk/Contents/Home",
            "/Library/Java/JavaVirtualMachines/temurin-21.jdk/Contents/Home",
            "/Library/Java/JavaVirtualMachines/temurin-17.jdk/Contents/Home",
            ProcessInfo.processInfo.environment["JAVA_HOME"] ?? ""
        ]
        for path in javaCandidates where !path.isEmpty {
            if fm.fileExists(atPath: "\(path)/bin/java") {
                javaHome = path
                break
            }
        }

        // Detect ANDROID_HOME
        let homeDir = fm.homeDirectoryForCurrentUser.path
        let androidCandidates = [
            "/opt/homebrew/share/android-commandlinetools",
            "\(homeDir)/Library/Android/sdk",
            "/usr/local/share/android-sdk",
            ProcessInfo.processInfo.environment["ANDROID_HOME"] ?? ""
        ]
        for path in androidCandidates where !path.isEmpty {
            if fm.fileExists(atPath: "\(path)/emulator/emulator") || fm.fileExists(atPath: "\(path)/cmdline-tools") {
                androidHome = path
                break
            }
        }

        // Detect tools inside Android SDK
        if !androidHome.isEmpty {
            let possibleEmulator = "\(androidHome)/emulator/emulator"
            if fm.fileExists(atPath: possibleEmulator) {
                emulatorPath = possibleEmulator
            }

            let possibleSdkmanager = "\(androidHome)/cmdline-tools/latest/bin/sdkmanager"
            if fm.fileExists(atPath: possibleSdkmanager) {
                sdkmanagerPath = possibleSdkmanager
            }

            let possibleAvdmanager = "\(androidHome)/cmdline-tools/latest/bin/avdmanager"
            if fm.fileExists(atPath: possibleAvdmanager) {
                avdmanagerPath = possibleAvdmanager
            }

            let possibleAdb = "\(androidHome)/platform-tools/adb"
            if fm.fileExists(atPath: possibleAdb) {
                adbPath = possibleAdb
            }
        }

        // Fallbacks
        if emulatorPath.isEmpty {
            emulatorPath = findExecutable(name: "emulator") ?? "/opt/homebrew/share/android-commandlinetools/emulator/emulator"
        }
        if sdkmanagerPath.isEmpty {
            sdkmanagerPath = findExecutable(name: "sdkmanager") ?? "/opt/homebrew/share/android-commandlinetools/cmdline-tools/latest/bin/sdkmanager"
        }
        if avdmanagerPath.isEmpty {
            avdmanagerPath = findExecutable(name: "avdmanager") ?? "/opt/homebrew/share/android-commandlinetools/cmdline-tools/latest/bin/avdmanager"
        }
        if adbPath.isEmpty {
            adbPath = findExecutable(name: "adb") ?? "/opt/homebrew/share/android-commandlinetools/platform-tools/adb"
        }
    }

    private func findExecutable(name: String) -> String? {
        let fm = FileManager.default
        let pathEnv = ProcessInfo.processInfo.environment["PATH"] ?? ""
        let extraPaths = [
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "/usr/bin",
            "/opt/homebrew/share/android-commandlinetools/emulator",
            "/opt/homebrew/share/android-commandlinetools/cmdline-tools/latest/bin",
            "/opt/homebrew/share/android-commandlinetools/platform-tools"
        ]
        let allPaths = (pathEnv.components(separatedBy: ":") + extraPaths)
        for dir in allPaths {
            let fullPath = "\(dir)/\(name)"
            if fm.isExecutableFile(atPath: fullPath) {
                return fullPath
            }
        }
        return nil
    }

    // MARK: - Process Execution

    @discardableResult
    public func executeCommand(
        _ executable: String,
        arguments: [String],
        input: String? = nil,
        customEnv: [String: String] = [:],
        background: Bool = false
    ) async -> (exitCode: Int32, stdout: String, stderr: String) {
        let cmdString = "\(executable) \(arguments.joined(separator: " "))"
        self.latestLogMessage = "Running: \(cmdString)"

        let currentJavaHome = self.javaHome
        let currentAndroidHome = self.androidHome

        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: executable)
                process.arguments = arguments

                var env = ProcessInfo.processInfo.environment
                if !currentJavaHome.isEmpty {
                    env["JAVA_HOME"] = currentJavaHome
                }
                if !currentAndroidHome.isEmpty {
                    env["ANDROID_HOME"] = currentAndroidHome
                    env["ANDROID_SDK_ROOT"] = currentAndroidHome
                }
                let extraBinDirs = [
                    "/opt/homebrew/bin",
                    "/opt/homebrew/sbin",
                    "/usr/local/bin",
                    "/usr/bin",
                    "/bin",
                    "/usr/sbin",
                    "/sbin",
                    "\(currentAndroidHome)/emulator",
                    "\(currentAndroidHome)/cmdline-tools/latest/bin",
                    "\(currentAndroidHome)/platform-tools",
                    "\(currentJavaHome)/bin"
                ]
                let currentPath = env["PATH"] ?? ""
                env["PATH"] = (extraBinDirs + [currentPath]).joined(separator: ":")

                for (k, v) in customEnv {
                    env[k] = v
                }
                process.environment = env

                if background {
                    process.standardInput = FileHandle.nullDevice
                    process.standardOutput = FileHandle.nullDevice
                    process.standardError = FileHandle.nullDevice
                    do {
                        try process.run()
                        Task { @MainActor in
                            self.appendLog(command: cmdString, output: "Đã khởi chạy nền (PID \(process.processIdentifier))", isError: false)
                        }
                        continuation.resume(returning: (0, "Started PID \(process.processIdentifier)", ""))
                    } catch {
                        Task { @MainActor in
                            self.appendLog(command: cmdString, output: "Lỗi khởi chạy: \(error.localizedDescription)", isError: true)
                        }
                        continuation.resume(returning: (1, "", error.localizedDescription))
                    }
                    return
                }

                let inPipe = Pipe()
                let outPipe = Pipe()
                let errPipe = Pipe()
                process.standardInput = inPipe
                process.standardOutput = outPipe
                process.standardError = errPipe

                do {
                    try process.run()
                    if let input = input, let data = input.data(using: .utf8) {
                        inPipe.fileHandleForWriting.write(data)
                    }
                    try? inPipe.fileHandleForWriting.close()
                    process.waitUntilExit()
                    let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
                    let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
                    let stdoutStr = String(data: outData, encoding: .utf8) ?? ""
                    let stderrStr = String(data: errData, encoding: .utf8) ?? ""
                    let exitCode = process.terminationStatus

                    Task { @MainActor in
                        let combined = stdoutStr.isEmpty ? stderrStr : (stderrStr.isEmpty ? stdoutStr : "\(stdoutStr)\n\(stderrStr)")
                        self.appendLog(command: cmdString, output: combined.trimmingCharacters(in: .whitespacesAndNewlines), isError: exitCode != 0)
                    }

                    continuation.resume(returning: (exitCode, stdoutStr, stderrStr))
                } catch {
                    Task { @MainActor in
                        self.appendLog(command: cmdString, output: error.localizedDescription, isError: true)
                    }
                    continuation.resume(returning: (1, "", error.localizedDescription))
                }
            }
        }
    }

    private func appendLog(command: String, output: String, isError: Bool) {
        let entry = CommandLogEntry(command: command, output: output, isError: isError)
        self.logs.insert(entry, at: 0)
        if self.logs.count > 100 {
            self.logs.removeLast()
        }
    }

    // MARK: - Refresh

    public func refreshAll() async {
        isBusy = true
        busyMessage = "Đang kiểm tra thiết bị & môi trường..."
        detectEnvironment()
        await fetchIOSDevices()
        await fetchAndroidAVDs()
        await fetchAvailableIOSMetadata()
        await fetchAvailableAndroidMetadata()
        await runDoctorCheck()
        await checkForUpdates()
        isBusy = false
        busyMessage = ""
    }

    public func checkForUpdates() async {
        guard let url = URL(string: "https://api.github.com/repos/cuonnd/DeviceLauncher/releases/latest") else { return }
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.setValue("DeviceLauncher-App", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return }

            struct GitHubRelease: Codable {
                let tag_name: String
                let body: String?
                let assets: [ReleaseAsset]
            }
            struct ReleaseAsset: Codable {
                let name: String
                let browser_download_url: String
            }

            let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
            let latestTag = release.tag_name.replacingOccurrences(of: "v", with: "")

            if latestTag.compare(self.appVersion, options: .numeric) == .orderedDescending {
                self.updateAvailable = release.tag_name
                self.updateReleaseNotes = release.body
                if let zipAsset = release.assets.first(where: { $0.name.hasSuffix(".zip") }) {
                    self.updateDownloadUrl = zipAsset.browser_download_url
                }
            } else {
                self.updateAvailable = nil
            }
        } catch {
            print("Check for updates failed: \(error)")
        }
    }

    public func performAutoUpdate() async {
        guard let downloadUrl = updateDownloadUrl else { return }
        isBusy = true
        busyMessage = "Đang tải bản cập nhật mới \(updateAvailable ?? "")..."

        let script = """
        TMP_ZIP="/tmp/DeviceLauncher_new.zip"
        TMP_DIR="/tmp/DeviceLauncher_extracted"
        rm -rf "$TMP_ZIP" "$TMP_DIR"
        mkdir -p "$TMP_DIR"
        curl -L -s "\(downloadUrl)" -o "$TMP_ZIP"
        unzip -q -o "$TMP_ZIP" -d "$TMP_DIR"
        if [ -d "$TMP_DIR/DeviceLauncher.app" ]; then
            pkill -f DeviceLauncher || true
            cp -R "$TMP_DIR/DeviceLauncher.app" /Applications/
            xattr -cr /Applications/DeviceLauncher.app
            open /Applications/DeviceLauncher.app
        fi
        """
        _ = await executeCommand("/bin/bash", arguments: ["-c", script])
        isBusy = false
        busyMessage = ""
    }

    public func quickStatusCheck() async {
        await fetchIOSDevices()
        await fetchAndroidAVDs()
    }

    // MARK: - iOS Simulators

    public func fetchIOSDevices() async {
        let result = await executeCommand("/usr/bin/xcrun", arguments: ["simctl", "list", "-j", "devices"])
        guard result.exitCode == 0, let data = result.stdout.data(using: .utf8) else {
            return
        }

        struct SimctlResponse: Codable {
            let devices: [String: [SimDevice]]
        }
        struct SimDevice: Codable {
            let udid: String
            let name: String
            let state: String
            let isAvailable: Bool?
            let deviceTypeIdentifier: String?
        }

        do {
            let decoded = try JSONDecoder().decode(SimctlResponse.self, from: data)
            var list: [IOSDevice] = []
            for (runtimeKey, devList) in decoded.devices {
                let runtimeName = runtimeKey.replacingOccurrences(of: "com.apple.CoreSimulator.SimRuntime.", with: "")
                    .replacingOccurrences(of: "-", with: " ")
                for d in devList {
                    let isAvail = d.isAvailable ?? true
                    if isAvail && !d.name.contains("Unavailable") {
                        list.append(IOSDevice(
                            udid: d.udid,
                            name: d.name,
                            state: d.state,
                            isAvailable: isAvail,
                            deviceTypeIdentifier: d.deviceTypeIdentifier,
                            runtime: runtimeName
                        ))
                    }
                }
            }
            self.iosDevices = list.sorted {
                if $0.isBooted != $1.isBooted { return $0.isBooted && !$1.isBooted }
                return $0.name < $1.name
            }
        } catch {
            print("Failed to decode simctl: \(error)")
        }
    }

    public func bootIOSDevice(_ device: IOSDevice) async {
        isBusy = true
        busyMessage = "Đang khởi động \(device.name)..."
        if !device.isBooted {
            _ = await executeCommand("/usr/bin/xcrun", arguments: ["simctl", "boot", device.udid])
        }
        _ = await executeCommand("/usr/bin/open", arguments: ["-a", "Simulator"])
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        await fetchIOSDevices()
        isBusy = false
        busyMessage = ""
    }

    public func shutdownIOSDevice(_ device: IOSDevice) async {
        isBusy = true
        busyMessage = "Đang tắt \(device.name)..."
        _ = await executeCommand("/usr/bin/xcrun", arguments: ["simctl", "shutdown", device.udid])
        try? await Task.sleep(nanoseconds: 800_000_000)
        await fetchIOSDevices()
        isBusy = false
        busyMessage = ""
    }

    public func eraseIOSDevice(_ device: IOSDevice) async {
        isBusy = true
        busyMessage = "Đang xóa dữ liệu \(device.name)..."
        _ = await executeCommand("/usr/bin/xcrun", arguments: ["simctl", "erase", device.udid])
        await fetchIOSDevices()
        isBusy = false
        busyMessage = ""
    }

    public func openSimulatorApp() async {
        _ = await executeCommand("/usr/bin/open", arguments: ["-a", "Simulator"])
    }

    public func createLatestIOSSimulator(name: String = "iPhone 17 Pro") async {
        isBusy = true
        busyMessage = "Đang tạo iOS Simulator mới..."
        let runtimesResult = await executeCommand("/usr/bin/xcrun", arguments: ["simctl", "list", "runtimes"])
        var targetRuntime = "com.apple.CoreSimulator.SimRuntime.iOS-26-3"
        for line in runtimesResult.stdout.components(separatedBy: "\n") {
            if line.contains("iOS") && line.contains("com.apple.CoreSimulator.SimRuntime.") {
                if let rRange = line.range(of: "com.apple.CoreSimulator.SimRuntime.[a-zA-Z0-9-]+", options: .regularExpression) {
                    targetRuntime = String(line[rRange])
                }
            }
        }
        let deviceType = "com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro"
        _ = await executeCommand("/usr/bin/xcrun", arguments: ["simctl", "create", name, deviceType, targetRuntime])
        await fetchIOSDevices()
        isBusy = false
        busyMessage = ""
    }

    public func deleteIOSDevice(_ device: IOSDevice) async {
        isBusy = true
        busyMessage = "Đang xoá thiết bị \(device.name)..."
        if device.isBooted {
            _ = await executeCommand("/usr/bin/xcrun", arguments: ["simctl", "shutdown", device.udid])
        }
        _ = await executeCommand("/usr/bin/xcrun", arguments: ["simctl", "delete", device.udid])
        await fetchIOSDevices()
        isBusy = false
        busyMessage = ""
    }

    public func deleteMultipleIOSDevices(udids: [String]) async {
        isBusy = true
        busyMessage = "Đang xoá \(udids.count) thiết bị iOS đã chọn..."
        for udid in udids {
            if let dev = iosDevices.first(where: { $0.udid == udid }), dev.isBooted {
                _ = await executeCommand("/usr/bin/xcrun", arguments: ["simctl", "shutdown", udid])
            }
            _ = await executeCommand("/usr/bin/xcrun", arguments: ["simctl", "delete", udid])
        }
        await fetchIOSDevices()
        isBusy = false
        busyMessage = ""
    }

    public func createCustomIOSDevice(name: String, deviceType: String, runtime: String) async {
        isBusy = true
        busyMessage = "Đang tạo iOS Simulator: \(name)..."
        _ = await executeCommand("/usr/bin/xcrun", arguments: ["simctl", "create", name, deviceType, runtime])
        await fetchIOSDevices()
        isBusy = false
        busyMessage = ""
    }

    public func fetchAvailableIOSMetadata() async {
        let runtimesResult = await executeCommand("/usr/bin/xcrun", arguments: ["simctl", "list", "-j", "runtimes"])
        if runtimesResult.exitCode == 0, let data = runtimesResult.stdout.data(using: .utf8) {
            struct RuntimeResponse: Codable {
                let runtimes: [RuntimeItem]
            }
            struct RuntimeItem: Codable {
                let name: String
                let identifier: String
                let version: String
                let isAvailable: Bool?
            }
            if let decoded = try? JSONDecoder().decode(RuntimeResponse.self, from: data) {
                self.availableIOSRuntimes = decoded.runtimes.compactMap {
                    if $0.isAvailable ?? true {
                        return IOSRuntime(name: $0.name, identifier: $0.identifier, version: $0.version)
                    }
                    return nil
                }
            }
        }

        let devTypesResult = await executeCommand("/usr/bin/xcrun", arguments: ["simctl", "list", "-j", "devicetypes"])
        if devTypesResult.exitCode == 0, let data = devTypesResult.stdout.data(using: .utf8) {
            struct DevTypeResponse: Codable {
                let devicetypes: [DevTypeItem]
            }
            struct DevTypeItem: Codable {
                let name: String
                let identifier: String
                let productFamily: String?
            }
            if let decoded = try? JSONDecoder().decode(DevTypeResponse.self, from: data) {
                self.availableIOSDeviceTypes = decoded.devicetypes.filter {
                    let fam = $0.productFamily ?? ""
                    return fam == "iPhone" || fam == "iPad"
                }.map {
                    IOSDeviceType(name: $0.name, identifier: $0.identifier, productFamily: $0.productFamily ?? "iPhone")
                }
            }
        }
    }

    public func downloadIOSPlatform() async {
        isBusy = true
        busyMessage = "Đang tải iOS Platform mới nhất qua xcodebuild..."
        _ = await executeCommand("/usr/bin/xcodebuild", arguments: ["-downloadPlatform", "iOS"])
        await fetchAvailableIOSMetadata()
        await fetchIOSDevices()
        isBusy = false
        busyMessage = ""
    }

    // MARK: - Android Emulators

    public func fetchAndroidAVDs() async {
        var avds: [AndroidAVD] = []
        var runningAvdNames: Set<String> = []

        // Method 1: Check running via pgrep on qemu and emulator
        let pgrepResult = await executeCommand("/usr/bin/pgrep", arguments: ["-lf", "-i", "avd"])
        for line in pgrepResult.stdout.components(separatedBy: "\n") {
            if let avdRange = line.range(of: "-avd\\s+([\\w.-]+)", options: .regularExpression) {
                let match = String(line[avdRange])
                let name = match.replacingOccurrences(of: "-avd", with: "").trimmingCharacters(in: .whitespaces)
                if !name.isEmpty {
                    runningAvdNames.insert(name)
                }
            }
        }

        // Method 2: Check via adb emu avd name
        let adbAvdResult = await executeCommand(adbPath, arguments: ["emu", "avd", "name"])
        for line in adbAvdResult.stdout.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty && trimmed != "OK" && !trimmed.contains("error") {
                runningAvdNames.insert(trimmed)
            }
        }

        // Method 3: avdmanager list avd
        let avdResult = await executeCommand(avdmanagerPath, arguments: ["list", "avd"])
        if avdResult.exitCode == 0 && !avdResult.stdout.isEmpty {
            let blocks = avdResult.stdout.components(separatedBy: "---------")
            for block in blocks {
                var name = ""
                var device = ""
                var target = ""
                var path = ""

                for line in block.components(separatedBy: "\n") {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    if trimmed.hasPrefix("Name: ") {
                        name = String(trimmed.dropFirst(6))
                    } else if trimmed.hasPrefix("Device: ") {
                        device = String(trimmed.dropFirst(8))
                    } else if trimmed.hasPrefix("Target: ") || trimmed.hasPrefix("Based on: ") {
                        target = String(trimmed.dropFirst(line.contains("Based on: ") ? 10 : 8))
                    } else if trimmed.hasPrefix("Path: ") {
                        path = String(trimmed.dropFirst(6))
                    }
                }

                if !name.isEmpty {
                    let isRunning = runningAvdNames.contains(name)
                    avds.append(AndroidAVD(name: name, device: device, target: target, path: path, isRunning: isRunning))
                }
            }
        }

        // Fallback: ~/.android/avd/*.ini
        if avds.isEmpty {
            let fm = FileManager.default
            let homeDir = fm.homeDirectoryForCurrentUser.path
            let avdDir = "\(homeDir)/.android/avd"
            if let files = try? fm.contentsOfDirectory(atPath: avdDir) {
                for file in files where file.hasSuffix(".ini") {
                    let name = String(file.dropLast(4))
                    let isRunning = runningAvdNames.contains(name)
                    avds.append(AndroidAVD(name: name, device: "Pixel", target: "Android", path: "\(avdDir)/\(name).avd", isRunning: isRunning))
                }
            }
        }

        self.androidDevices = avds.sorted {
            if $0.isRunning != $1.isRunning { return $0.isRunning && !$1.isRunning }
            return $0.name < $1.name
        }
    }

    public func launchAndroidAVD(_ avd: AndroidAVD, coldBoot: Bool = false, wipeData: Bool = false) async {
        isBusy = true
        busyMessage = "Đang khởi động \(avd.displayName)..."
        var args = ["-avd", avd.name]
        if coldBoot {
            args.append("-no-snapshot-load")
        }
        if wipeData {
            args.append("-wipe-data")
        }

        let logPath = "/tmp/emulator_\(avd.name).log"
        let bashCmd = "export ANDROID_HOME='\(self.androidHome)' ANDROID_SDK_ROOT='\(self.androidHome)' JAVA_HOME='\(self.javaHome)'; '\(self.emulatorPath)' \(args.joined(separator: " ")) > '\(logPath)' 2>&1 &"
        _ = await executeCommand("/bin/bash", arguments: ["-c", bashCmd])

        try? await Task.sleep(nanoseconds: 2_500_000_000)
        await fetchAndroidAVDs()
        isBusy = false
        busyMessage = ""
    }

    public func stopAndroidAVD(_ avd: AndroidAVD) async {
        isBusy = true
        busyMessage = "Đang tắt \(avd.displayName)..."
        _ = await executeCommand(adbPath, arguments: ["emu", "kill"])
        _ = await executeCommand("/usr/bin/pkill", arguments: ["-f", "emulator.*-avd \(avd.name)"])
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        await fetchAndroidAVDs()
        isBusy = false
        busyMessage = ""
    }

    public static func sanitizeAvdName(_ input: String) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "Pixel_Custom" }
        let mutable = NSMutableString(string: trimmed) as CFMutableString
        CFStringTransform(mutable, nil, kCFStringTransformStripDiacritics, false)
        var ascii = (mutable as String)
            .replacingOccurrences(of: "đ", with: "d")
            .replacingOccurrences(of: "Đ", with: "D")
            .replacingOccurrences(of: " ", with: "_")
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-")
        ascii = ascii.unicodeScalars.filter { allowed.contains($0) }.map { String($0) }.joined()
        if ascii.isEmpty {
            return "Pixel_Custom"
        }
        return ascii
    }

    public func createLatestAndroidAVD(name: String = "Pixel_9_Pro_API_37") async {
        isBusy = true
        let safeName = Self.sanitizeAvdName(name)
        busyMessage = "Đang kiểm tra & tạo AVD \(safeName)..."

        let sysImg = "system-images;android-37.0;google_apis_playstore_ps16k;arm64-v8a"
        let listResult = await executeCommand(sdkmanagerPath, arguments: ["--list_installed"])
        if !listResult.stdout.contains("system-images;android-") {
            busyMessage = "Đang tải System Image Android API 37 (vui lòng chờ)..."
            _ = await executeCommand(sdkmanagerPath, arguments: ["--install", sysImg], input: "y\n")
        }

        busyMessage = "Đang tạo AVD \(safeName)..."
        let createResult = await executeCommand(
            avdmanagerPath,
            arguments: [
                "create", "avd",
                "-n", safeName,
                "-k", sysImg,
                "-d", "pixel_9_pro",
                "--force"
            ],
            input: "no\n"
        )

        if createResult.exitCode != 0 {
            _ = await executeCommand(
                avdmanagerPath,
                arguments: [
                    "create", "avd",
                    "-n", safeName,
                    "-k", sysImg,
                    "--force"
                ],
                input: "no\n"
            )
        }

        await fetchAndroidAVDs()
        await runDoctorCheck()
        isBusy = false
        busyMessage = ""
    }

    public func deleteAndroidAVD(_ avd: AndroidAVD) async {
        isBusy = true
        busyMessage = "Đang xoá máy ảo \(avd.displayName)..."
        if avd.isRunning {
            await stopAndroidAVD(avd)
        }
        _ = await executeCommand(avdmanagerPath, arguments: ["delete", "avd", "-n", avd.name])

        let fm = FileManager.default
        let homeDir = fm.homeDirectoryForCurrentUser.path
        let avdIni = "\(homeDir)/.android/avd/\(avd.name).ini"
        let avdDir = "\(homeDir)/.android/avd/\(avd.name).avd"
        try? fm.removeItem(atPath: avdIni)
        try? fm.removeItem(atPath: avdDir)

        await fetchAndroidAVDs()
        isBusy = false
        busyMessage = ""
    }

    public func deleteMultipleAndroidAVDs(names: [String]) async {
        isBusy = true
        busyMessage = "Đang xoá \(names.count) máy ảo Android đã chọn..."
        let fm = FileManager.default
        let homeDir = fm.homeDirectoryForCurrentUser.path

        for name in names {
            if let avd = androidDevices.first(where: { $0.name == name }), avd.isRunning {
                await stopAndroidAVD(avd)
            }
            _ = await executeCommand(avdmanagerPath, arguments: ["delete", "avd", "-n", name])
            let avdIni = "\(homeDir)/.android/avd/\(name).ini"
            let avdDir = "\(homeDir)/.android/avd/\(name).avd"
            try? fm.removeItem(atPath: avdIni)
            try? fm.removeItem(atPath: avdDir)
        }
        await fetchAndroidAVDs()
        isBusy = false
        busyMessage = ""
    }

    @discardableResult
    public func createCustomAndroidAVD(name: String, deviceId: String, systemImage: String) async -> (success: Bool, error: String?) {
        isBusy = true
        let safeName = Self.sanitizeAvdName(name)
        busyMessage = "Đang tạo máy ảo \(safeName)..."

        var result = await executeCommand(
            avdmanagerPath,
            arguments: [
                "create", "avd",
                "-n", safeName,
                "-k", systemImage,
                "-d", deviceId,
                "--force"
            ],
            input: "no\n"
        )

        // Fallback without deviceId if device definition failed
        if result.exitCode != 0 {
            result = await executeCommand(
                avdmanagerPath,
                arguments: [
                    "create", "avd",
                    "-n", safeName,
                    "-k", systemImage,
                    "--force"
                ],
                input: "no\n"
            )
        }

        await fetchAndroidAVDs()
        isBusy = false
        busyMessage = ""

        if result.exitCode == 0 {
            return (true, nil)
        } else {
            let errMsg = !result.stderr.isEmpty ? result.stderr : (!result.stdout.isEmpty ? result.stdout : "Lỗi khi tạo AVD (exit code \(result.exitCode))")
            return (false, errMsg)
        }
    }

    public func fetchAvailableAndroidMetadata() async {
        let standardImages: [(id: String, name: String, api: String)] = [
            ("system-images;android-37.0;google_apis_playstore_ps16k;arm64-v8a", "Android 17 (API 37.0) Play Store", "37.0"),
            ("system-images;android-36;google_apis_playstore;arm64-v8a", "Android 16 (API 36.0) Play Store", "36.0"),
            ("system-images;android-35;google_apis_playstore;arm64-v8a", "Android 15 (API 35.0) Play Store", "35.0"),
            ("system-images;android-34;google_apis_playstore;arm64-v8a", "Android 14 (API 34.0) Play Store", "34.0"),
            ("system-images;android-33;google_apis_playstore;arm64-v8a", "Android 13 (API 33.0) Play Store", "33.0")
        ]

        let installedResult = await executeCommand(sdkmanagerPath, arguments: ["--list_installed"])
        let installedText = installedResult.stdout

        self.availableAndroidSystemImages = standardImages.map { item in
            let installed = installedText.contains(item.id)
            return AndroidSystemImage(packagePath: item.id, name: item.name, apiLevel: item.api, isInstalled: installed)
        }

        self.availableAndroidDeviceProfiles = [
            AndroidDeviceProfile(deviceId: "pixel_9_pro", name: "Pixel 9 Pro"),
            AndroidDeviceProfile(deviceId: "pixel_9", name: "Pixel 9"),
            AndroidDeviceProfile(deviceId: "pixel_8_pro", name: "Pixel 8 Pro"),
            AndroidDeviceProfile(deviceId: "pixel_8", name: "Pixel 8"),
            AndroidDeviceProfile(deviceId: "pixel_7_pro", name: "Pixel 7 Pro"),
            AndroidDeviceProfile(deviceId: "pixel_tablet", name: "Pixel Tablet"),
            AndroidDeviceProfile(deviceId: "pixel_fold", name: "Pixel Fold")
        ]
    }

    public func downloadAndroidSystemImage(_ packagePath: String) async {
        isBusy = true
        busyMessage = "Đang tải gói System Image (vui lòng chờ vài phút)..."
        _ = await executeCommand(sdkmanagerPath, arguments: ["--install", packagePath], input: "y\n")
        await fetchAvailableAndroidMetadata()
        isBusy = false
        busyMessage = ""
    }

    public func openAndroidStudio() async {
        _ = await executeCommand("/usr/bin/open", arguments: ["-a", "Android Studio"])
    }

    // MARK: - Doctor / Diagnostic

    public func runDoctorCheck() async {
        var items: [DoctorItem] = []
        let fm = FileManager.default

        if fm.fileExists(atPath: "/Applications/Xcode.app") {
            items.append(DoctorItem(
                id: "xcode",
                category: "iOS",
                title: "Xcode.app",
                status: .ok,
                message: "Đã cài đặt Xcode tại /Applications/Xcode.app",
                detail: "Môi trường iOS phát triển đầy đủ.",
                fixCommand: nil,
                canAutoFix: false
            ))
        } else {
            items.append(DoctorItem(
                id: "xcode",
                category: "iOS",
                title: "Xcode.app",
                status: .warning,
                message: "Chưa tìm thấy Xcode trong /Applications",
                detail: "Cài đặt Xcode từ App Store để có đầy đủ Simulator.",
                fixCommand: "open 'macappstore://apps.apple.com/app/xcode/id497799835'",
                canAutoFix: false
            ))
        }

        if !iosDevices.isEmpty {
            items.append(DoctorItem(
                id: "ios_sim",
                category: "iOS",
                title: "iOS Simulators",
                status: .ok,
                message: "Đã có \(iosDevices.count) Simulator sẵn sàng",
                detail: iosDevices.map { "\($0.name) (\($0.runtime ?? ""))" }.joined(separator: ", "),
                fixCommand: nil,
                canAutoFix: false
            ))
        } else {
            items.append(DoctorItem(
                id: "ios_sim",
                category: "iOS",
                title: "iOS Simulators",
                status: .warning,
                message: "Chưa có thiết bị iOS Simulator nào",
                detail: "Bấm 'Khắc phục ngay' để tạo iPhone 17 Pro.",
                fixCommand: "xcrun simctl create 'iPhone 17 Pro' ...",
                canAutoFix: true
            ))
        }

        if !androidHome.isEmpty && fm.fileExists(atPath: androidHome) {
            items.append(DoctorItem(
                id: "android_sdk",
                category: "Android",
                title: "Android SDK",
                status: .ok,
                message: "Android SDK tại \(androidHome)",
                detail: "Đầy đủ công cụ cmdline-tools, platform-tools.",
                fixCommand: nil,
                canAutoFix: false
            ))
        } else {
            items.append(DoctorItem(
                id: "android_sdk",
                category: "Android",
                title: "Android SDK",
                status: .error,
                message: "Không tìm thấy Android SDK",
                detail: "Cài đặt qua Homebrew: brew install --cask android-commandlinetools",
                fixCommand: "brew install --cask android-commandlinetools",
                canAutoFix: true
            ))
        }

        if !javaHome.isEmpty && fm.fileExists(atPath: "\(javaHome)/bin/java") {
            items.append(DoctorItem(
                id: "java",
                category: "Android",
                title: "Java JDK (JAVA_HOME)",
                status: .ok,
                message: "Java tìm thấy tại \(javaHome)",
                detail: "Sẵn sàng chạy avdmanager & sdkmanager.",
                fixCommand: nil,
                canAutoFix: false
            ))
        } else {
            items.append(DoctorItem(
                id: "java",
                category: "Android",
                title: "Java JDK (JAVA_HOME)",
                status: .error,
                message: "Chưa cấu hình Java JDK",
                detail: "Cần OpenJDK 17 hoặc 21 để chạy Android SDK Tools.",
                fixCommand: "brew install openjdk@17",
                canAutoFix: true
            ))
        }

        if fm.isExecutableFile(atPath: emulatorPath) {
            items.append(DoctorItem(
                id: "emulator_bin",
                category: "Android",
                title: "Android Emulator Binary",
                status: .ok,
                message: "Đã tìm thấy emulator tại \(emulatorPath)",
                detail: "Sẵn sàng khởi chạy máy ảo Android.",
                fixCommand: nil,
                canAutoFix: false
            ))
        } else {
            items.append(DoctorItem(
                id: "emulator_bin",
                category: "Android",
                title: "Android Emulator Binary",
                status: .warning,
                message: "Chưa tìm thấy công cụ emulator",
                detail: "Cài đặt qua sdkmanager: sdkmanager --install 'emulator'",
                fixCommand: "\(sdkmanagerPath) --install emulator",
                canAutoFix: true
            ))
        }

        if !androidDevices.isEmpty {
            items.append(DoctorItem(
                id: "android_avd",
                category: "Android",
                title: "Android Virtual Devices (AVD)",
                status: .ok,
                message: "Đã có \(androidDevices.count) máy ảo Android sẵn sàng",
                detail: androidDevices.map { $0.displayName }.joined(separator: ", "),
                fixCommand: nil,
                canAutoFix: false
            ))
        } else {
            items.append(DoctorItem(
                id: "android_avd",
                category: "Android",
                title: "Android Virtual Devices (AVD)",
                status: .warning,
                message: "Chưa có máy ảo Android (AVD) nào",
                detail: "Bấm 'Khắc phục ngay' để tự động tạo Pixel 9 Pro API 37.",
                fixCommand: "create-latest-avd",
                canAutoFix: true
            ))
        }

        self.doctorItems = items
    }

    // MARK: - Auto Setup Latest All

    public func autoSetupAllLatest() async {
        isBusy = true
        busyMessage = "Bắt đầu tự động thiết lập bản mới nhất..."

        detectEnvironment()

        if iosDevices.isEmpty {
            busyMessage = "Đang tạo iOS Simulator iPhone 17 Pro..."
            await createLatestIOSSimulator()
        }

        if androidDevices.isEmpty {
            busyMessage = "Đang tải & tạo Android AVD Pixel 9 Pro mới nhất..."
            await createLatestAndroidAVD()
        }

        await refreshAll()
        isBusy = false
        busyMessage = ""
    }
}
