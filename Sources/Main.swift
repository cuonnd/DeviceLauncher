import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Keep running in menu bar even if window is closed!
        return false
    }
}

@main
struct DeviceLauncherApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        // Main Dashboard Window
        WindowGroup(id: "dashboard") {
            MainView()
                .frame(minWidth: 780, minHeight: 520)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            SidebarCommands()
        }

        // Menu Bar Extra
        MenuBarExtra("Device Launcher", systemImage: "laptopcomputer.and.iphone") {
            MenuBarView {
                openMainWindow()
            }
        }
        .menuBarExtraStyle(.window)
    }

    private func openMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        openWindow(id: "dashboard")
    }
}
