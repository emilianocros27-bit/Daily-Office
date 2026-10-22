import SwiftUI
import AppKit
import Combine

@main struct DailyOfficeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    var body: some Scene { Settings { EmptyView() } }
}
@MainActor final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let store = OfficeStore()
    var dock: NSPanel!; var chats: [String:NSWindow] = [:]; var preferences: NSWindow?; var mainWindow: NSWindow?
    var statusItem: NSStatusItem!; var observer: AnyCancellable?
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let appRoot = Bundle.main.bundleURL.deletingLastPathComponent().standardizedFileURL.path
        // La carpeta de instalación no debe aparecer como proyecto del usuario.
        store.data.projects.removeAll { $0.path == appRoot || URL(fileURLWithPath: $0.path).lastPathComponent.lowercased() == "daily office" }
        if store.data.projectPath == appRoot || URL(fileURLWithPath: store.data.projectPath).lastPathComponent.lowercased() == "daily office" { store.data.projectPath = "" }
        store.openChat = { [weak self] in self?.open($0) }
        store.showSettings = { [weak self] in self?.settings() }
        store.showDock = { [weak self] in self?.dock.orderFrontRegardless() }
        store.hideDock = { [weak self] in self?.dock.orderOut(nil) }
        dock = NSPanel(contentRect:NSRect(x:0,y:0,width:640,height:190),styleMask:[.borderless,.nonactivatingPanel],backing:.buffered,defer:false)
        dock.isFloatingPanel = true; dock.level = .statusBar; dock.isOpaque = false; dock.backgroundColor = .clear; dock.hasShadow = false
        dock.collectionBehavior = [.canJoinAllSpaces,.fullScreenAuxiliary]; dock.isMovableByWindowBackground = true
        dock.contentView = NSHostingView(rootView:DockView(store:store))
        dock.setFrameAutosaveName("daily-dock-bottom-right-v3")
        if !dock.setFrameUsingName("daily-dock-bottom-right-v3"), let screen = NSScreen.main { dock.setFrameOrigin(NSPoint(x:screen.visibleFrame.maxX-664,y:screen.visibleFrame.minY+58)) }
        if store.data.dockEnabled { dock.orderFrontRegardless() }
        statusItem = NSStatusBar.system.statusItem(withLength:NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName:"circle.grid.2x2",accessibilityDescription:"Daily Office")
        let menu = NSMenu()
        menu.addItem(withTitle:"Mostrar dock",action:#selector(reveal),keyEquivalent:"")
        menu.addItem(withTitle:"Ocultar dock",action:#selector(hideDock),keyEquivalent:"")
        menu.addItem(.separator())
        for a in store.data.agents { let item = menu.addItem(withTitle:a.name,action:#selector(openFromMenu(_:)),keyEquivalent:""); item.representedObject = a.id }
        menu.addItem(.separator()); menu.addItem(withTitle:"Pausar / activar equipo",action:#selector(togglePause),keyEquivalent:"")
        menu.addItem(withTitle:"Configuración…",action:#selector(settings),keyEquivalent:",")
        menu.addItem(withTitle:"Salir de Daily Office",action:#selector(quit),keyEquivalent:"q")
        for item in menu.items { item.target = self }; statusItem.menu = menu
        observer = store.$notice.compactMap { $0 }.receive(on:RunLoop.main).sink { [weak self] message in
            let alert = NSAlert(); alert.messageText = "Daily Office"; alert.informativeText = message; alert.runModal(); self?.store.notice = nil
        }
        for id in store.data.openAgents { open(id) }
        main()
        if ProcessInfo.processInfo.arguments.contains("--smoke-test") { open("design"); DispatchQueue.main.asyncAfter(deadline:.now()+3) { NSApp.terminate(nil) } }
    }
    func open(_ id: String) {
        if let window = chats[id] { window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps:true); return }
        let a = store.agent(id)
        let window = NSWindow(contentRect:NSRect(x:0,y:0,width:480,height:650),styleMask:[.titled,.closable,.resizable,.miniaturizable,.fullSizeContentView],backing:.buffered,defer:false)
        window.title = a.name; window.titlebarAppearsTransparent = true; window.isReleasedWhenClosed = false; window.level = .floating
        window.contentView = NSHostingView(rootView:ChatView(store:store,id:id)); window.center(); window.setFrameAutosaveName("agent-\(id)"); window.delegate = self
        chats[id] = window
        if !store.data.openAgents.contains(id) { store.data.openAgents.append(id) }
        window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps:true)
    }
    func windowWillClose(_ notification: Notification) {
        if let window = notification.object as? NSWindow, let id = chats.first(where:{$0.value === window})?.key { chats.removeValue(forKey:id); store.data.openAgents.removeAll { $0 == id } }
    }
    @objc func reveal() { dock.orderFrontRegardless() }
    @objc func hideDock() { dock.orderOut(nil) }
    @objc func openFromMenu(_ sender: NSMenuItem) { if let id = sender.representedObject as? String { open(id) } }
    @objc func togglePause() { store.pause() }
    @objc func settings() {
        if preferences == nil {
            let w = NSWindow(contentRect:NSRect(x:0,y:0,width:800,height:660),styleMask:[.titled,.closable],backing:.buffered,defer:false)
            w.title = "Daily Office"; w.titlebarAppearsTransparent = true; w.isReleasedWhenClosed = false; w.contentView = NSHostingView(rootView:SettingsView(store:store)); w.center(); preferences = w
        }
        preferences?.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps:true)
    }
    func main() {
        if mainWindow == nil {
            let w = NSWindow(contentRect:NSRect(x:0,y:0,width:900,height:600),styleMask:[.titled,.closable,.resizable,.miniaturizable],backing:.buffered,defer:false)
            w.title = "Daily Office"; w.titlebarAppearsTransparent = true; w.isReleasedWhenClosed = false; w.contentView = NSHostingView(rootView:MainView(store:store)); w.center(); mainWindow = w
        }
        mainWindow?.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps:true)
    }
    @objc func quit() { NSApp.terminate(nil) }
    func applicationWillTerminate(_ notification: Notification) { store.save(); for id in store.busy { store.stop(id) } }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}
