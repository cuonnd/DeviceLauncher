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
    @Published public var availableDownloadableIOSRuntimes: [IOSDownloadableRuntime] = []
    @Published public var availableAndroidSystemImages: [AndroidSystemImage] = []
    @Published public var availableAndroidDeviceProfiles: [AndroidDeviceProfile] = []
    @Published public var brokenAndroidAVDs: [String] = []

    // Version & Updates
    public let appVersion: String = "1.2.2"
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
        let homeDir = fm.homeDirectoryForCurrentUser.path

        // 1. Detect JAVA_HOME
        // Try /usr/libexec/java_home first (official macOS Java locator)
        if let jhome = runQuickProcess("/usr/libexec/java_home"), !jhome.isEmpty, fm.fileExists(atPath: "\(jhome)/bin/java") {
            javaHome = jhome
        }

        if javaHome.isEmpty {
            var javaCandidates = [
                "/opt/homebrew/opt/openjdk@17",
                "/opt/homebrew/opt/openjdk@21",
                "/opt/homebrew/opt/openjdk",
                "/usr/local/opt/openjdk",
                "/Applications/Android Studio.app/Contents/jbr/Contents/Home",
                "/Applications/Android Studio.app/Contents/jre/Contents/Home",
                "\(homeDir)/Library/Java/JavaVirtualMachines",
                ProcessInfo.processInfo.environment["JAVA_HOME"] ?? ""
            ]
            if let jvms = try? fm.contentsOfDirectory(atPath: "/Library/Java/JavaVirtualMachines") {
                for jvm in jvms {
                    javaCandidates.append("/Library/Java/JavaVirtualMachines/\(jvm)/Contents/Home")
                }
            }
            if let userJvms = try? fm.contentsOfDirectory(atPath: "\(homeDir)/Library/Java/JavaVirtualMachines") {
                for jvm in userJvms {
                    javaCandidates.append("\(homeDir)/Library/Java/JavaVirtualMachines/\(jvm)/Contents/Home")
                }
            }
            for path in javaCandidates where !path.isEmpty {
                if fm.fileExists(atPath: "\(path)/bin/java") {
                    javaHome = path
                    break
                }
            }
        }

        // 2. Detect ANDROID_HOME (User Library first, then Homebrew, etc.)
        let androidCandidates = [
            "\(homeDir)/Library/Android/sdk",
            "/opt/homebrew/share/android-commandlinetools",
            "/usr/local/share/android-sdk",
            ProcessInfo.processInfo.environment["ANDROID_HOME"] ?? "",
            ProcessInfo.processInfo.environment["ANDROID_SDK_ROOT"] ?? ""
        ]
        for path in androidCandidates where !path.isEmpty {
            if fm.fileExists(atPath: "\(path)/emulator/emulator") ||
               fm.fileExists(atPath: "\(path)/cmdline-tools") ||
               fm.fileExists(atPath: "\(path)/platform-tools") {
                androidHome = path
                break
            }
        }

        // 3. Detect tools inside Android SDK
        if !androidHome.isEmpty {
            let possibleEmulator = "\(androidHome)/emulator/emulator"
            if fm.fileExists(atPath: possibleEmulator) {
                emulatorPath = possibleEmulator
            }

            let cmdlineBase = "\(androidHome)/cmdline-tools"
            let possibleSdkmanager = "\(cmdlineBase)/latest/bin/sdkmanager"
            if fm.fileExists(atPath: possibleSdkmanager) {
                sdkmanagerPath = possibleSdkmanager
            }

            let possibleAvdmanager = "\(cmdlineBase)/latest/bin/avdmanager"
            if fm.fileExists(atPath: possibleAvdmanager) {
                avdmanagerPath = possibleAvdmanager
            }

            // Fallback for versioned subfolders (e.g. cmdline-tools/13.0/bin/avdmanager)
            if (sdkmanagerPath.isEmpty || avdmanagerPath.isEmpty), let subdirs = try? fm.contentsOfDirectory(atPath: cmdlineBase) {
                for sub in subdirs.sorted().reversed() {
                    let s = "\(cmdlineBase)/\(sub)/bin/sdkmanager"
                    let a = "\(cmdlineBase)/\(sub)/bin/avdmanager"
                    if sdkmanagerPath.isEmpty && fm.fileExists(atPath: s) {
                        sdkmanagerPath = s
                    }
                    if avdmanagerPath.isEmpty && fm.fileExists(atPath: a) {
                        avdmanagerPath = a
                    }
                }
            }

            let possibleAdb = "\(androidHome)/platform-tools/adb"
            if fm.fileExists(atPath: possibleAdb) {
                adbPath = possibleAdb
            }
        }

        // Fallbacks via PATH
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

    private func runQuickProcess(_ path: String, args: [String] = []) -> String? {
        guard FileManager.default.isExecutableFile(atPath: path) else { return nil }
        let p = Process()
        p.executableURL = URL(fileURLWithPath: path)
        p.arguments = args
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = FileHandle.nullDevice
        do {
            try p.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            p.waitUntilExit()
            if p.terminationStatus == 0 {
                let out = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
                return (out?.isEmpty == false) ? out : nil
            }
        } catch {
            return nil
        }
        return nil
    }

    private func findExecutable(name: String) -> String? {
        let fm = FileManager.default
        let pathEnv = ProcessInfo.processInfo.environment["PATH"] ?? ""
        let extraPaths = [
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "/usr/bin",
            "\(androidHome)/cmdline-tools/latest/bin",
            "\(androidHome)/emulator",
            "\(androidHome)/platform-tools",
            "/opt/homebrew/share/android-commandlinetools/emulator",
            "/opt/homebrew/share/android-commandlinetools/cmdline-tools/latest/bin",
            "/opt/homebrew/share/android-commandlinetools/platform-tools"
        ]
        let allPaths = (pathEnv.components(separatedBy: ":") + extraPaths)
        for dir in allPaths where !dir.isEmpty {
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
                env["SKIP_JDK_VERSION_CHECK"] = "true"
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

                var outData = Data()
                var errData = Data()
                let group = DispatchGroup()

                group.enter()
                DispatchQueue.global(qos: .userInitiated).async {
                    outData = outPipe.fileHandleForReading.readDataToEndOfFile()
                    group.leave()
                }

                group.enter()
                DispatchQueue.global(qos: .userInitiated).async {
                    errData = errPipe.fileHandleForReading.readDataToEndOfFile()
                    group.leave()
                }

                do {
                    try process.run()
                    if let input = input, let data = input.data(using: .utf8) {
                        inPipe.fileHandleForWriting.write(data)
                    }
                    try? inPipe.fileHandleForWriting.close()

                    process.waitUntilExit()
                    group.wait()

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

    @discardableResult
    public func createCustomIOSDevice(name: String, deviceType: String, runtime: String) async -> (success: Bool, error: String?) {
        isBusy = true
        busyMessage = "Đang tạo iOS Simulator: \(name)..."
        let result = await executeCommand("/usr/bin/xcrun", arguments: ["simctl", "create", name, deviceType, runtime])
        await fetchIOSDevices()
        isBusy = false
        busyMessage = ""
        if result.exitCode == 0 {
            return (true, nil)
        } else {
            var errMsg = !result.stderr.isEmpty ? result.stderr : (!result.stdout.isEmpty ? result.stdout : "Lỗi khi tạo iOS Simulator")
            if errMsg.contains("Incompatible device") {
                errMsg = "Thiết bị này không tương thích với phiên bản iOS đã chọn. Các dòng máy cũ (như iPhone 8, iPhone 8 Plus, iPhone X, iPhone 7, iPhone 6s) chỉ hỗ trợ tối đa iOS 16 hoặc iOS 15. Bạn hãy vào 'Kho iOS Runtime' để tải thêm bản iOS tương thích."
            }
            return (false, errMsg)
        }
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
                let minRuntimeVersionString: String?
                let maxRuntimeVersionString: String?
            }
            if let decoded = try? JSONDecoder().decode(DevTypeResponse.self, from: data) {
                self.availableIOSDeviceTypes = decoded.devicetypes.filter {
                    let fam = $0.productFamily ?? ""
                    return fam == "iPhone" || fam == "iPad"
                }.map {
                    IOSDeviceType(
                        name: $0.name,
                        identifier: $0.identifier,
                        productFamily: $0.productFamily ?? "iPhone",
                        minRuntimeVersionString: $0.minRuntimeVersionString,
                        maxRuntimeVersionString: $0.maxRuntimeVersionString
                    )
                }
            }
        }

        // Standard downloadable runtimes
        let knownDownloadable: [(name: String, buildVersion: String, size: String, devices: String, matchPattern: String)] = [
            ("iOS 18.0 Universal Simulator", "18.0", "~8.4 GB", "iPhone 11 trở lên, iPad A16, iPad Air/Pro M2-M5", "18."),
            ("iOS 17.5 Universal Simulator", "17.5", "~7.3 GB", "iPhone XR, XS, 11, 12, 13, 14, 15", "17."),
            ("iOS 16.4 Universal Simulator", "16.4", "~6.2 GB", "Hỗ trợ iPhone 8, iPhone 8 Plus, iPhone X, iPad Gen 5/6", "16.4"),
            ("iOS 16.0 Universal Simulator", "16.0", "~6.2 GB", "Hỗ trợ iPhone 8, iPhone 8 Plus, iPhone X, iPad Gen 5/6", "16.0")
        ]

        self.availableDownloadableIOSRuntimes = knownDownloadable.map { item in
            let installed = self.availableIOSRuntimes.contains { $0.version.contains(item.matchPattern) }
            return IOSDownloadableRuntime(
                name: item.name,
                buildVersion: item.buildVersion,
                sizeDescription: item.size,
                compatibleDevicesDescription: item.devices,
                isInstalled: installed
            )
        }
    }

    public func downloadSpecificIOSRuntime(version: String) async -> (success: Bool, error: String?) {
        isBusy = true
        busyMessage = "Đang tải iOS \(version) Simulator qua xcodebuild (vui lòng chờ vài phút)..."
        let result = await executeCommand("/usr/bin/xcodebuild", arguments: ["-downloadPlatform", "iOS", "-buildVersion", version])
        await fetchAvailableIOSMetadata()
        await fetchIOSDevices()
        isBusy = false
        busyMessage = ""
        if result.exitCode == 0 {
            return (true, nil)
        } else {
            let errMsg = !result.stderr.isEmpty ? result.stderr : (!result.stdout.isEmpty ? result.stdout : "Không thể tải iOS \(version)")
            return (false, errMsg)
        }
    }

    public func addIOSRuntimeFromFile(path: String) async -> (success: Bool, error: String?) {
        isBusy = true
        busyMessage = "Đang cài đặt Runtime từ file \(URL(fileURLWithPath: path).lastPathComponent)..."
        let result = await executeCommand("/usr/bin/xcrun", arguments: ["simctl", "runtime", "add", path])
        await fetchAvailableIOSMetadata()
        await fetchIOSDevices()
        isBusy = false
        busyMessage = ""
        if result.exitCode == 0 {
            return (true, nil)
        } else {
            let errMsg = !result.stderr.isEmpty ? result.stderr : (!result.stdout.isEmpty ? result.stdout : "Lỗi khi nạp runtime từ file")
            return (false, errMsg)
        }
    }

    public func openXcodeSettings() async {
        _ = await executeCommand("/usr/bin/open", arguments: ["-a", "Xcode"])
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
        var rawOutput = avdResult.stdout
        if rawOutput.isEmpty && !avdResult.stderr.isEmpty {
            rawOutput = avdResult.stderr
        }

        var brokenNames: [String] = []

        if !rawOutput.isEmpty {
            var validSection = rawOutput
            if let brokenRange = rawOutput.range(of: "The following Android Virtual Devices could not be loaded:") {
                let brokenPart = String(rawOutput[brokenRange.upperBound...])
                validSection = String(rawOutput[..<brokenRange.lowerBound])

                for line in brokenPart.components(separatedBy: "\n") {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    if trimmed.hasPrefix("Name: ") {
                        let bName = String(trimmed.dropFirst(6)).trimmingCharacters(in: .whitespaces)
                        if !bName.isEmpty && !brokenNames.contains(bName) {
                            brokenNames.append(bName)
                        }
                    }
                }
            }

            let blocks = validSection.components(separatedBy: "---------")
            for block in blocks {
                var name = ""
                var device = ""
                var target = ""
                var path = ""

                for rawLine in block.components(separatedBy: "\n") {
                    let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
                    if trimmed.hasPrefix("Name: ") {
                        name = String(trimmed.dropFirst(6)).trimmingCharacters(in: .whitespaces)
                    } else if trimmed.hasPrefix("Device: ") {
                        device = String(trimmed.dropFirst(8)).trimmingCharacters(in: .whitespaces)
                    } else if trimmed.hasPrefix("Target: ") || trimmed.hasPrefix("Based on: ") {
                        target = String(trimmed.dropFirst(trimmed.contains("Based on: ") ? 10 : 8)).trimmingCharacters(in: .whitespaces)
                    } else if trimmed.hasPrefix("Path: ") {
                        path = String(trimmed.dropFirst(6)).trimmingCharacters(in: .whitespaces)
                    }
                }

                if !name.isEmpty && name != "Available Android Virtual Devices:" && !brokenNames.contains(name) {
                    let isRunning = runningAvdNames.contains(name)
                    avds.append(AndroidAVD(name: name, device: device, target: target, path: path, isRunning: isRunning))
                }
            }
        }

        self.brokenAndroidAVDs = brokenNames

        // Fallback: ~/.android/avd/*.ini
        if avds.isEmpty {
            let fm = FileManager.default
            let homeDir = fm.homeDirectoryForCurrentUser.path
            let avdDir = "\(homeDir)/.android/avd"
            if let files = try? fm.contentsOfDirectory(atPath: avdDir) {
                for file in files where file.hasSuffix(".ini") {
                    let name = String(file.dropLast(4))
                    if !brokenNames.contains(name) {
                        let isRunning = runningAvdNames.contains(name)
                        avds.append(AndroidAVD(name: name, device: "Pixel", target: "Android", path: "\(avdDir)/\(name).avd", isRunning: isRunning))
                    }
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

    public func createLatestAndroidAVD(name: String? = nil) async {
        isBusy = true
        busyMessage = "Đang kiểm tra gói System Image có sẵn..."

        // Find the best available installed system image first
        await fetchAvailableAndroidMetadata()

        let targetImage: AndroidSystemImage? = self.availableAndroidSystemImages.first(where: { $0.isInstalled })
        let bestDev = self.availableAndroidDeviceProfiles.first?.deviceId ?? "pixel_8"

        if let installedImg = targetImage {
            let avdName = name ?? "Pixel_Auto_\(installedImg.apiLevel.replacingOccurrences(of: ".", with: "_"))"
            let safeName = Self.sanitizeAvdName(avdName)
            busyMessage = "Đang tạo máy ảo \(safeName) với Android \(installedImg.apiLevel)..."
            _ = await createCustomAndroidAVD(name: safeName, deviceId: bestDev, systemImage: installedImg.packagePath)
        } else {
            // No image installed yet -> download default recommended image (Android 35 / 37)
            let fallbackPkg = "system-images;android-35;google_apis_playstore;arm64-v8a"
            busyMessage = "Chưa có System Image, đang tải Android 15 (vui lòng chờ)..."
            _ = await executeCommand("/bin/bash", arguments: ["-c", "printf 'y\\n' | '\(sdkmanagerPath)' --install '\(fallbackPkg)'"])
            await fetchAvailableAndroidMetadata()
            let avdName = name ?? "Pixel_15_Auto"
            let safeName = Self.sanitizeAvdName(avdName)
            _ = await createCustomAndroidAVD(name: safeName, deviceId: bestDev, systemImage: fallbackPkg)
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

    public func deleteBrokenAVD(name: String) async {
        isBusy = true
        busyMessage = "Đang dọn dẹp máy ảo hỏng \(name)..."
        _ = await executeCommand(avdmanagerPath, arguments: ["delete", "avd", "-n", name])
        let fm = FileManager.default
        let homeDir = fm.homeDirectoryForCurrentUser.path
        let avdIni = "\(homeDir)/.android/avd/\(name).ini"
        let avdDir = "\(homeDir)/.android/avd/\(name).avd"
        try? fm.removeItem(atPath: avdIni)
        try? fm.removeItem(atPath: avdDir)
        await fetchAndroidAVDs()
        isBusy = false
        busyMessage = ""
    }

    @discardableResult
    public func createCustomAndroidAVD(name: String, deviceId: String, systemImage: String) async -> (success: Bool, error: String?) {
        isBusy = true
        let safeName = Self.sanitizeAvdName(name)
        busyMessage = "Đang tạo máy ảo \(safeName)..."

        let fm = FileManager.default
        let homeDir = fm.homeDirectoryForCurrentUser.path
        let avdIni = "\(homeDir)/.android/avd/\(safeName).ini"

        // Parse tag and abi if present in package path
        // e.g. system-images;android-35;google_apis_playstore;arm64-v8a
        let parts = systemImage.components(separatedBy: ";")
        var tagArg: [String] = []
        var abiArg: [String] = []
        if parts.count >= 4 {
            let tag = parts[2]
            let abi = parts[3]
            tagArg = ["--tag", tag]
            abiArg = ["--abi", abi]
        }

        // Method 1: Using bash with printf 'no\n' and deviceId
        let devArgs = !deviceId.isEmpty ? ["-d", deviceId] : []
        var bashCmd = "printf 'no\\n' | '\(avdmanagerPath)' create avd -n '\(safeName)' -k '\(systemImage)' \(devArgs.joined(separator: " ")) \(tagArg.joined(separator: " ")) \(abiArg.joined(separator: " ")) -c 512M --force"
        var res = await executeCommand("/bin/bash", arguments: ["-c", bashCmd])

        // Fallback 1: If failed and deviceId was specified, retry without -d
        if !fm.fileExists(atPath: avdIni) && res.exitCode != 0 && !deviceId.isEmpty {
            bashCmd = "printf 'no\\n' | '\(avdmanagerPath)' create avd -n '\(safeName)' -k '\(systemImage)' \(tagArg.joined(separator: " ")) \(abiArg.joined(separator: " ")) -c 512M --force"
            res = await executeCommand("/bin/bash", arguments: ["-c", bashCmd])
        }

        // Fallback 2: Direct avdmanager invocation
        if !fm.fileExists(atPath: avdIni) {
            var directArgs = ["create", "avd", "-n", safeName, "-k", systemImage, "--force", "-c", "512M"]
            if !deviceId.isEmpty {
                directArgs.append(contentsOf: ["-d", deviceId])
            }
            directArgs.append(contentsOf: tagArg)
            directArgs.append(contentsOf: abiArg)
            res = await executeCommand(avdmanagerPath, arguments: directArgs, input: "no\n")
        }

        await fetchAndroidAVDs()
        isBusy = false
        busyMessage = ""

        let createdSuccessfully = fm.fileExists(atPath: avdIni) || self.androidDevices.contains(where: { $0.name == safeName })

        if createdSuccessfully {
            return (true, nil)
        } else {
            var errOutput = res.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            if errOutput.isEmpty {
                errOutput = res.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            let cleanedLines = errOutput.components(separatedBy: "\n").filter { line in
                !line.contains("This version only understands SDK XML versions") &&
                !line.contains("integer expression expected") &&
                !line.contains("Loading local repository") &&
                !line.contains("Fetch remote repository")
            }
            let meaningfulErr = cleanedLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            let finalErr = !meaningfulErr.isEmpty ? meaningfulErr : (errOutput.isEmpty ? "Lỗi không xác định khi tạo AVD (exit code \(res.exitCode))" : errOutput)
            return (false, finalErr)
        }
    }

    public func fetchAvailableAndroidMetadata() async {
        let fm = FileManager.default
        var installedImages: [AndroidSystemImage] = []
        var installedPackagePaths: Set<String> = []

        // Method 1: Scan disk directly at \(androidHome)/system-images
        let sysImgDir = "\(androidHome)/system-images"
        if let apiDirs = try? fm.contentsOfDirectory(atPath: sysImgDir) {
            for apiDir in apiDirs where !apiDir.hasPrefix(".") {
                let apiPath = "\(sysImgDir)/\(apiDir)"
                if let tagDirs = try? fm.contentsOfDirectory(atPath: apiPath) {
                    for tagDir in tagDirs where !tagDir.hasPrefix(".") {
                        let tagPath = "\(apiPath)/\(tagDir)"
                        if let abiDirs = try? fm.contentsOfDirectory(atPath: tagPath) {
                            for abiDir in abiDirs where !abiDir.hasPrefix(".") {
                                let abiPath = "\(tagPath)/\(abiDir)"
                                let sourceProp = "\(abiPath)/source.properties"
                                if fm.fileExists(atPath: sourceProp) {
                                    let pkgId = "system-images;\(apiDir);\(tagDir);\(abiDir)"
                                    installedPackagePaths.insert(pkgId)

                                    let apiNumber = apiDir.replacingOccurrences(of: "android-", with: "")
                                    var tagDisplay = tagDir.replacingOccurrences(of: "_", with: " ").capitalized
                                    if tagDir.contains("playstore") {
                                        tagDisplay = "Play Store"
                                    } else if tagDir.contains("google_apis") {
                                        tagDisplay = "Google APIs"
                                    } else if tagDir == "default" {
                                        tagDisplay = "AOSP"
                                    }

                                    let friendlyAndroidName: String
                                    switch apiNumber {
                                    case "37.0", "37": friendlyAndroidName = "Android 17"
                                    case "36.0", "36": friendlyAndroidName = "Android 16"
                                    case "35": friendlyAndroidName = "Android 15"
                                    case "34": friendlyAndroidName = "Android 14"
                                    case "33": friendlyAndroidName = "Android 13"
                                    case "32": friendlyAndroidName = "Android 12L"
                                    case "31": friendlyAndroidName = "Android 12"
                                    case "30": friendlyAndroidName = "Android 11"
                                    case "29": friendlyAndroidName = "Android 10"
                                    default: friendlyAndroidName = "Android API \(apiNumber)"
                                    }

                                    let displayName = "\(friendlyAndroidName) (API \(apiNumber)) \(tagDisplay) [\(abiDir)]"
                                    installedImages.append(AndroidSystemImage(
                                        packagePath: pkgId,
                                        name: displayName,
                                        apiLevel: apiNumber,
                                        isInstalled: true
                                    ))
                                }
                            }
                        }
                    }
                }
            }
        }

        // Method 2: Fallback to sdkmanager --list_installed
        if installedImages.isEmpty && !sdkmanagerPath.isEmpty {
            let installedResult = await executeCommand(sdkmanagerPath, arguments: ["--list_installed"])
            for line in installedResult.stdout.components(separatedBy: "\n") {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("system-images;") {
                    let parts = trimmed.components(separatedBy: "|").first?.trimmingCharacters(in: .whitespaces) ?? ""
                    if !parts.isEmpty {
                        installedPackagePaths.insert(parts)
                    }
                }
            }
        }

        // Standard candidates for quick download
        let standardCandidates: [(id: String, name: String, api: String)] = [
            ("system-images;android-37.0;google_apis_playstore_ps16k;arm64-v8a", "Android 17 (API 37.0) Play Store", "37.0"),
            ("system-images;android-36;google_apis_playstore;arm64-v8a", "Android 16 (API 36.0) Play Store", "36.0"),
            ("system-images;android-35;google_apis_playstore;arm64-v8a", "Android 15 (API 35.0) Play Store", "35.0"),
            ("system-images;android-35;google_apis;arm64-v8a", "Android 15 (API 35.0) Google APIs", "35.0"),
            ("system-images;android-34;google_apis_playstore;arm64-v8a", "Android 14 (API 34.0) Play Store", "34.0"),
            ("system-images;android-34;google_apis;arm64-v8a", "Android 14 (API 34.0) Google APIs", "34.0"),
            ("system-images;android-33;google_apis_playstore;arm64-v8a", "Android 13 (API 33.0) Play Store", "33.0"),
            ("system-images;android-31;google_apis;arm64-v8a", "Android 12 (API 31.0) Google APIs", "31.0")
        ]

        var allImages: [AndroidSystemImage] = installedImages

        for candidate in standardCandidates {
            if installedPackagePaths.contains(candidate.id) {
                if !allImages.contains(where: { $0.packagePath == candidate.id }) {
                    allImages.append(AndroidSystemImage(packagePath: candidate.id, name: candidate.name, apiLevel: candidate.api, isInstalled: true))
                }
            } else {
                allImages.append(AndroidSystemImage(packagePath: candidate.id, name: candidate.name, apiLevel: candidate.api, isInstalled: false))
            }
        }

        // Sort: installed first, then newest API level descending
        self.availableAndroidSystemImages = allImages.sorted {
            if $0.isInstalled != $1.isInstalled {
                return $0.isInstalled && !$1.isInstalled
            }
            return $0.apiLevel.localizedStandardCompare($1.apiLevel) == .orderedDescending
        }

        // Dynamically query supported devices from SDK
        let devResult = await executeCommand(avdmanagerPath, arguments: ["list", "device"])
        var profiles: [AndroidDeviceProfile] = []
        if !devResult.stdout.isEmpty {
            let blocks = devResult.stdout.components(separatedBy: "---------")
            for block in blocks {
                var devId = ""
                var devName = ""
                for line in block.components(separatedBy: "\n") {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    if trimmed.hasPrefix("id: ") && trimmed.contains("or \"") {
                        if let q1 = trimmed.range(of: "or \""), let q2 = trimmed.range(of: "\"", range: q1.upperBound..<trimmed.endIndex) {
                            devId = String(trimmed[q1.upperBound..<q2.lowerBound])
                        }
                    }
                    if trimmed.hasPrefix("Name: ") {
                        devName = String(trimmed.dropFirst(6)).trimmingCharacters(in: .whitespaces)
                    }
                }
                if !devId.isEmpty && !devName.isEmpty && (devId.hasPrefix("pixel") || devId.contains("phone") || devId.contains("tablet")) {
                    profiles.append(AndroidDeviceProfile(deviceId: devId, name: devName))
                }
            }
        }

        if profiles.isEmpty {
            profiles = [
                AndroidDeviceProfile(deviceId: "pixel_8", name: "Pixel 8"),
                AndroidDeviceProfile(deviceId: "pixel_7", name: "Pixel 7"),
                AndroidDeviceProfile(deviceId: "pixel_6", name: "Pixel 6"),
                AndroidDeviceProfile(deviceId: "medium_phone", name: "Medium Phone")
            ]
        } else {
            profiles.sort {
                $0.deviceId.localizedStandardCompare($1.deviceId) == .orderedDescending
            }
        }
        self.availableAndroidDeviceProfiles = profiles
    }

    public func downloadAndroidSystemImage(_ packagePath: String) async {
        isBusy = true
        busyMessage = "Đang tải gói System Image (vui lòng chờ vài phút)..."
        _ = await executeCommand("/bin/bash", arguments: ["-c", "printf 'y\\n' | '\(sdkmanagerPath)' --install '\(packagePath)'"])
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
