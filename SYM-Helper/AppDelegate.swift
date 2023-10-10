//
//  AppDelegate.swift
//  SYM-Helper
//

import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }

    // quit the app if the window is closed
    func applicationShouldTerminateAfterLastWindowClosed(_ app: NSApplication) -> Bool {
        return true
    }
    
    @IBAction func showLogFolder(_ sender: Any) {
        if (FileManager.default.fileExists(atPath: Log.path!)) {
            NSWorkspace.shared.open(URL(fileURLWithPath: Log.path!))
        } else {
            _ = Alert().display(header: "Alert", message: "There are currently no log files to display.", secondButton: "")
        }
    }
}

