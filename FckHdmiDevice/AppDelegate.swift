import Cocoa
import ServiceManagement
import CoreAudio

class AppDelegate: NSObject, NSApplicationDelegate {

    var statusItem: NSStatusItem?
    let audio = CoreAudioManager()

    // 避免重复注册监听
    private var didRegisterListeners = false

    // store hidden device names
    var hidden: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: "HiddenDevices") ?? []) }
        set { UserDefaults.standard.set(Array(newValue), forKey: "HiddenDevices") }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        print("🟢 App started (auto refresh)")

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem = item

        if let b = item.button {
            b.image = NSImage(systemSymbolName: "speaker.wave.2.fill",
                              accessibilityDescription: "Audio")
            b.image?.isTemplate = true   // 适配深/浅色模式
        }

        rebuildMenu()
        registerDeviceChangeListeners()
    }

    // MARK: - Launch at Login

    func isLaunchAtLoginEnabled() -> Bool {
        return SMAppService.mainApp.status == .enabled
    }

    func toggleLaunchAtLogin() {
        if isLaunchAtLoginEnabled() {
            do {
                try SMAppService.mainApp.unregister()
            } catch {
                print("❌ Failed to disable launch at login: \(error)")
            }
        } else {
            do {
                try SMAppService.mainApp.register()
            } catch {
                print("❌ Failed to enable launch at login: \(error)")
            }
        }
    }

    // MARK: - Menu

    func rebuildMenu() {
        let menu = NSMenu()

        let outputs = audio.getOutputDevices().filter { !hidden.contains($0.name) }
        let inputs  = audio.getInputDevices().filter { !hidden.contains($0.name) }

        // OUTPUT section
        if !outputs.isEmpty {
            let titleItem = NSMenuItem(title: "OUTPUT", action: nil, keyEquivalent: "")
            titleItem.isEnabled = false
            menu.addItem(titleItem)

            for dev in outputs {
                let item = NSMenuItem(title: dev.name,
                                      action: #selector(selectOutput(_:)),
                                      keyEquivalent: "")
                item.representedObject = dev
                item.target = self
                if dev.isDefault { item.state = .on }
                menu.addItem(item)
            }
        }

        if !outputs.isEmpty && !inputs.isEmpty {
            menu.addItem(NSMenuItem.separator())
        }

        // INPUT section (mic)
        if !inputs.isEmpty {
            let titleItem = NSMenuItem(title: "MIC INPUT", action: nil, keyEquivalent: "")
            titleItem.isEnabled = false
            menu.addItem(titleItem)

            for dev in inputs {
                let item = NSMenuItem(title: dev.name,
                                      action: #selector(selectInput(_:)),
                                      keyEquivalent: "")
                item.representedObject = dev
                item.target = self
                if dev.isDefault { item.state = .on }
                menu.addItem(item)
            }
        }

        menu.addItem(NSMenuItem.separator())

        // Fck off device submenu
        let hideMenu = NSMenu()
        let allNames = Set(audio.getOutputDevices().map { $0.name } +
                           audio.getInputDevices().map { $0.name })

        for name in allNames.sorted() {
            let item = NSMenuItem(title: name,
                                  action: #selector(toggleHidden(_:)),
                                  keyEquivalent: "")
            if hidden.contains(name) { item.state = .on }
            item.target = self
            hideMenu.addItem(item)
        }

        let hideItem = NSMenuItem(title: "Fck off Device", action: nil, keyEquivalent: "")
        menu.setSubmenu(hideMenu, for: hideItem)
        menu.addItem(hideItem)

        menu.addItem(NSMenuItem.separator())

        // Launch at Login
        let launchItem = NSMenuItem(title: "Launch at Login",
                                    action: #selector(toggleLaunchAtLoginItem(_:)),
                                    keyEquivalent: "")
        launchItem.target = self
        launchItem.state = isLaunchAtLoginEnabled() ? .on : .off
        menu.addItem(launchItem)

        // Quit
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))

        statusItem?.menu = menu
    }

    // MARK: - Actions

    @objc func toggleLaunchAtLoginItem(_ sender: NSMenuItem) {
        toggleLaunchAtLogin()
        rebuildMenu()
    }

    @objc func selectOutput(_ sender: NSMenuItem) {
        guard let dev = sender.representedObject as? AudioDevice else { return }
        audio.setDefaultOutput(dev.id)
        rebuildMenu()
    }

    @objc func selectInput(_ sender: NSMenuItem) {
        guard let dev = sender.representedObject as? AudioDevice else { return }
        audio.setDefaultInput(dev.id)
        rebuildMenu()
    }

    @objc func toggleHidden(_ sender: NSMenuItem) {
        let name = sender.title
        if hidden.contains(name) {
            hidden.remove(name)
        } else {
            hidden.insert(name)
        }
        rebuildMenu()
    }

    @objc func quit() {
        NSApp.terminate(nil)
    }

    // MARK: - CoreAudio listeners (auto refresh)

    func registerDeviceChangeListeners() {
        guard !didRegisterListeners else { return }
        didRegisterListeners = true

        let systemObject = AudioObjectID(kAudioObjectSystemObject)

        func addListener(_ selector: AudioObjectPropertySelector) {
            var addr = AudioObjectPropertyAddress(
                mSelector: selector,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: 0
            )

            let status = AudioObjectAddPropertyListenerBlock(systemObject,
                                                             &addr,
                                                             DispatchQueue.main) { [weak self] _, _ in
                // 设备变动 / 默认设备变化时，重建菜单
                self?.rebuildMenu()
            }
            if status != noErr {
                print("⚠️ Failed to add listener for selector \(selector): \(status)")
            }
        }

        // 设备列表变化（插拔）
        addListener(kAudioHardwarePropertyDevices)
        // 默认输出设备变化
        addListener(kAudioHardwarePropertyDefaultOutputDevice)
        // 默认输入设备变化
        addListener(kAudioHardwarePropertyDefaultInputDevice)
    }
}
