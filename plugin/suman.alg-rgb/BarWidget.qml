import QtQuick
import Quickshell
import Quickshell.Io
import qs.Ui
import qs.Commons
import qs.Commons as Commons

// ALG RGB keyboard backlight widget for the Omarchy bar.
// Left-click toggles the control panel; right-click toggles backlight power.
BarWidget {
  id: root
  moduleName: "suman.alg-rgb"

  // Live state from the driver
  property string currentColor: "#ffffff"
  property int    currentBrightness: 1
  property bool   powered: true
  property bool   driverPresent: false

  // Dynamic theme tracking
  property bool   isDynamic: false
  readonly property color themeColor: Commons.Color.accent

  function colorToHex(c) {
    if (!c) return "#ffffff"
    var s = String(c).trim().toLowerCase()
    if (s.indexOf("#") === 0) {
      if (s.length === 9) return "#" + s.substring(3)
      if (s.length === 7) return s
    }
    return "#ffffff"
  }

  // React to system-wide theme changes live
  onThemeColorChanged: {
    if (root.isDynamic && root.driverPresent && root.powered) {
      var hex = root.colorToHex(root.themeColor)
      root.runCmd(["color", hex, String(root.currentBrightness)])
    }
    root.injectPanel()
  }

  // Persisted mode file (~/.config/alg-rgb/mode)
  FileView {
    id: modeFile
    path: Quickshell.env("HOME") + "/.config/alg-rgb/mode"
    watchChanges: true
    printErrors: false
    onLoaded: {
      var m = (text() || "").trim()
      root.isDynamic = (m === "dynamic")
      if (root.isDynamic && root.driverPresent && root.powered) {
        var hex = root.colorToHex(root.themeColor)
        if (root.currentColor.toLowerCase() !== hex.toLowerCase()) {
          root.runCmd(["color", hex, String(root.currentBrightness)])
        }
      }
      root.injectPanel()
    }
    onFileChanged: reload()
  }

  Process {
    id: setModeProc
    running: false
  }

  function setDynamicMode(dynamicEnabled) {
    root.isDynamic = dynamicEnabled
    var modeStr = dynamicEnabled ? "dynamic" : "static"
    setModeProc.command = ["sh", "-c", "mkdir -p \"$HOME/.config/alg-rgb\" && printf '%s' " + modeStr + " > \"$HOME/.config/alg-rgb/mode\""]
    setModeProc.running = false
    setModeProc.running = true

    if (dynamicEnabled && root.driverPresent && root.powered) {
      var hex = root.colorToHex(root.themeColor)
      root.runCmd(["color", hex, String(root.currentBrightness)])
    }
    root.injectPanel()
  }

  implicitWidth:  button.implicitWidth
  implicitHeight: button.implicitHeight

  // ---- Panel loader -----------------------------------------------------
  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false

  function open()        { if (panelLoader.item) panelLoader.item.open() }
  function close()       { if (panelLoader.item) panelLoader.item.close() }
  function togglePanel() { if (panelLoader.item) panelLoader.item.toggle() }

  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false
  function closeForPopoutSwitch() {
    if (panelLoader.item) panelLoader.item.closeForPopoutSwitch()
  }

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
    target.driverPresent = root.driverPresent
    target.powered = root.powered
    target.currentBrightness = root.currentBrightness
    target.currentColor = root.currentColor
    target.isDynamic = root.isDynamic
    target.themeColor = root.themeColor
  }

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  // ---- Shell IPC target -------------------------------------------------
  ShellIpc {
    target: "suman.alg-rgb"

    function open(): void    { root.open() }
    function close(): void   { root.close() }
    function show(): void    { root.open() }
    function hide(): void    { root.close() }
    function toggle(): void  { root.togglePanel() }
    function refresh(): void { root.refresh() }
  }

  // ---- Status Poller ---------------------------------------------------
  function refresh() {
    if (!statusProc.running) {
      statusProc.running = true
    }
  }

  Timer {
    id: pollTimer
    interval: 3000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  Process {
    id: statusProc
    command: ["alg-rgb", "status", "--json"]
    running: false
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.parseStatus(text)
    }
  }

  function parseStatus(text) {
    if (!text || text.trim() === "") return
    var obj = null
    try { obj = JSON.parse(text.trim()) } catch(e) {}
    if (!obj) return
    root.driverPresent     = (obj.ok === true)
    root.powered           = (obj.power === "on")
    root.currentBrightness = parseInt(obj.brightness) || 1
    root.currentColor      = obj.color || "#ffffff"
    root.injectPanel()
  }

  // ---- Command runner ---------------------------------------------------
  Process {
    id: cmdProc
    running: false
    stdout: StdioCollector { waitForEnd: true }
    onExited: function(exitCode) {
      root.refresh()
      if (panelLoader.item && typeof panelLoader.item.refresh === "function") {
        panelLoader.item.refresh()
      }
    }
  }

  function runCmd(args) {
    cmdProc.command = ["alg-rgb"].concat(args)
    cmdProc.running = false
    cmdProc.running = true
  }

  function togglePower() {
    runCmd(root.powered ? ["off"] : ["on"])
  }

  // ---- Bar icon button --------------------------------------------------
  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar

    // Native Omarchy Standard: Font Awesome keyboard icon () from JetBrainsMono Nerd Font.
    // Perfectly aligns with Omarchy's icon grid, stroke weight, optical centering,
    // and light/dark theme contrast.
    text: "\uf11c"

    // Keep the icon pure white matching all other status icons in the bar
    useActiveColor: false
    foreground: "#ffffff"

    // Dim the icon when backlight is off or driver is missing (standard Omarchy pattern)
    dimmed: !root.powered || !root.driverPresent

    tooltipText: root.driverPresent
      ? (root.powered
          ? "ALG RGB · " + (root.isDynamic ? "Dynamic (" + root.currentColor.toUpperCase() + ")" : root.currentColor.toUpperCase()) + " · Brightness " + root.currentBrightness + "/4"
          : "ALG RGB · Backlight Off (right-click to power on)")
      : "ALG RGB · Driver not loaded"

    // Active state (accent pill indicator) only when the panel is opened
    active: root.opened

    onPressed: function(btn) {
      if (btn === Qt.RightButton) {
        root.togglePower()
      } else {
        root.togglePanel()
      }
    }
  }
}
