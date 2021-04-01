//
//  AppDelegate.swift
//  FanFan
//
//  Created by Guilherme Rambo on 26/03/21.
//

import Cocoa
import SwiftUI
import Combine

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    var window: NSWindow!

    #if !arch(x86_64)
    lazy var engine = FanSimulationEngine()
    
    let loadMonitor = SystemLoadMonitor()
    
    private var cancellables = Set<AnyCancellable>()
    
    private let audioController = AudioController()
    
    private var statusItem: NSStatusItem?
    #endif
    
    private var isFirstRun: Bool {
        get {
            !UserDefaults.standard.bool(forKey: "FirstRunDone")
        }
        set {
            UserDefaults.standard.setValue(!newValue, forKey: "FirstRunDone")
        }
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        #if arch(x86_64)
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        
        if processIsTranslated() == 1 {
            alert.messageText = "Rosetta?!"
            alert.informativeText = "Why are you trying to run me under Rosetta? That's illegal!"
        } else {
            alert.messageText = "Intel Mac Detected"
            alert.informativeText = "Your Mac can already make plenty of fan noise on its own, you don't need me."
        }
        
        alert.addButton(withTitle: "OK")
        alert.runModal()
        NSApp.terminate(nil)
        #else
        if !showDebugViewIfNeeded() {
            loadMonitor.$currentLoad
                .assign(to: \.intensity, on: engine)
                .store(in: &cancellables)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.audioController.setSystemVolumeToValue(0.7)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.audioController.setSystemVolumeToValue(0.7)
            }
        }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem?.button?.image = NSImage(named: .init("StatusIcon"))
        statusItem?.button?.target = self
        statusItem?.button?.action = #selector(statusItemClicked)
        statusItem?.button?.toolTip = "FanFan"
        
        if isFirstRun {
            let alert = NSAlert()
            alert.messageText = "Welcome to FanFan!"
            alert.informativeText = "FanFan runs in the Menu Bar and uses its state of the art Fan Simulation Engine* to simulate the soothing sound of a computer fan, depending on the current load on your system, so that you can remember the good old days of Intel.\n\n* Patent pending"
            alert.addButton(withTitle: "OK")
            alert.runModal()
            isFirstRun = false
        }
        
        self.engine.start()
        
        #endif
    }
    
    #if !arch(x86_64)
    func showDebugViewIfNeeded() -> Bool {
        guard UserDefaults.standard.bool(forKey: "FFShowDebugView") else { return false }
        
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        
        let contentView = DebugView()
            .environmentObject(engine)

        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 300),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.center()
        window.setFrameAutosaveName("Main Window")
        window.contentView = NSHostingView(rootView: contentView)
        window.makeKeyAndOrderFront(nil)
        
        return true
    }
    
    @objc private func statusItemClicked(_ sender: NSButton) {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "About FanFan", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Quit FanFan", action: #selector(NSApplication.terminate), keyEquivalent: ""))
        menu.popUp(positioning: nil, at: CGPoint(x: sender.frame.midX, y: sender.frame.maxY), in: sender)
    }
    #endif

}


@objcMembers class FanFanApplication: NSApplication {

    override func orderFrontStandardAboutPanel(_ sender: Any?) {
        let rawStr = "Learn More"
        let str = NSMutableAttributedString(string: rawStr)

        guard let licensesURL = Bundle.main.url(forResource: "Readme", withExtension: "html") else {
            assertionFailure("Missing Readme.html in main app bundle")
            return
        }

        str.addAttributes([.link : licensesURL], range: NSRange(location: 0, length: rawStr.count))

        orderFrontStandardAboutPanel(options: [
            .credits: str
        ])
    }

}
