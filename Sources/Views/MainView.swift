import SwiftUI

public enum NavigationTab: String, Hashable, CaseIterable {
    case ios = "iOS Simulators"
    case android = "Android Emulators"
    case doctor = "Chuẩn đoán & Setup"
    case logs = "Nhật ký Lệnh"

    var icon: String {
        switch self {
        case .ios: return "apple.logo"
        case .android: return "smartphone"
        case .doctor: return "stethoscope"
        case .logs: return "terminal"
        }
    }
}

public struct MainView: View {
    @ObservedObject var manager = DeviceManager.shared
    @State private var selectedTab: NavigationTab = .ios

    public init() {}

    public var body: some View {
        NavigationSplitView {
            List(NavigationTab.allCases, id: \.self, selection: $selectedTab) { tab in
                NavigationLink(value: tab) {
                    HStack {
                        Label(tab.rawValue, systemImage: tab.icon)
                        Spacer()
                        if tab == .ios && !manager.iosDevices.isEmpty {
                            Text("\(manager.iosDevices.count)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        } else if tab == .android && !manager.androidDevices.isEmpty {
                            Text("\(manager.androidDevices.count)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 280)
            .safeAreaInset(edge: .bottom) {
                VStack(alignment: .leading, spacing: 8) {
                    Divider()
                    if manager.isBusy {
                        HStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)
                            Text(manager.busyMessage)
                                .font(.caption2)
                                .lineLimit(2)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 6)
                    } else {
                        Button {
                            Task { await manager.refreshAll() }
                        } label: {
                            Label("Làm mới danh sách", systemImage: "arrow.clockwise")
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal)
                        .padding(.bottom, 6)
                    }
                }
            }
        } detail: {
            Group {
                switch selectedTab {
                case .ios:
                    IOSView()
                case .android:
                    AndroidView()
                case .doctor:
                    DoctorView()
                case .logs:
                    LogsView()
                }
            }
            .frame(minWidth: 550, minHeight: 450)
        }
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                Button {
                    Task { await manager.autoSetupAllLatest() }
                } label: {
                    Label("Tự động Setup", systemImage: "sparkles")
                        .foregroundColor(.orange)
                }
                .help("Tự động kiểm tra và cài đặt/tạo bản Simulator và Emulator mới nhất")

                Button {
                    Task { await manager.refreshAll() }
                } label: {
                    Label("Làm mới", systemImage: "arrow.clockwise")
                }
            }
        }
    }
}
