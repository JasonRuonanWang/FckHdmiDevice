import Cocoa

// 手动创建 App 和 Delegate，不用 NSApplicationMain 那套黑盒
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate

// 对于菜单栏应用，LSUIElement 已经在 Info.plist 里设置了，这里不用管 Dock 了
// 如果你想保险一点，也可以加一行：
// app.setActivationPolicy(.accessory)

app.run()
