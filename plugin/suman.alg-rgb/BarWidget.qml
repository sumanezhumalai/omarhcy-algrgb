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

  // Dynamic theme tracking & base color
  property bool   isDynamic: false
  property string baseColor: "#ffffff"
  property string effectiveColor: "#ffffff"
  readonly property color themeColor: Commons.Color.accent

  // Night light tracking (hyprsunset directly)
  property bool   isNightLight: false
  property int    sunsetTemp: 6000

  function colorToHex(c) {
    if (!c) return "#ffffff"
    var s = String(c).trim().toLowerCase()
    if (s.indexOf("#") === 0) {
      if (s.length === 9) return "#" + s.substring(3)
      if (s.length === 7) return s
    }
    return "#ffffff"
  }

  // Chromatic adaptation filter for hyprsunset night light.
  // 3250K CTM multiplier from hyprsunset: R*1.0, G*0.7200783, B*0.48282114
  // Scales smoothly if temperature varies between 1000K and 6000K.
  function applyNightLightFilter(hex, temp) {
    if (!hex || hex.length !== 7 || hex.charAt(0) !== '#') return hex
    var k = (temp && temp > 1000 && temp < 6000) ? temp : 3250
    var t = (6000 - k) / (6000 - 3250) // 1.0 at 3250K, 0.0 at 6000K
    var gMult = Math.max(0.1, Math.min(1.0, 1.0 - t * (1.0 - 0.7200783)))
    var bMult = Math.max(0.1, Math.min(1.0, 1.0 - t * (1.0 - 0.48282114)))

    var r = parseInt(hex.substring(1, 3), 16) || 0
    var g = parseInt(hex.substring(3, 5), 16) || 0
    var b = parseInt(hex.substring(5, 7), 16) || 0

    var rOut = Math.min(255, Math.max(0, Math.round(r * 1.0)))
    var gOut = Math.min(255, Math.max(0, Math.round(g * gMult)))
    var bOut = Math.min(255, Math.max(0, Math.round(b * bMult)))

    function pad(n) { var s = n.toString(16); return s.length === 1 ? "0" + s : s }
    return "#" + pad(rOut) + pad(gOut) + pad(bOut)
  }

  function computeEffectiveColor() {
    var base = root.isDynamic ? root.colorToHex(root.themeColor) : (root.baseColor || "#ffffff")
    if (root.isNightLight) {
      return root.applyNightLightFilter(base, root.sunsetTemp)
    }
    return base
  }

  function updateBacklight(force) {
    if (!root.driverPresent || !root.powered) return
    var eff = root.computeEffectiveColor()
    root.effectiveColor = eff
    if (force || root.currentColor.toLowerCase() !== eff.toLowerCase()) {
      root.runCmd(["color", eff, String(root.currentBrightness)])
    }
  }

  // React to system-wide theme changes live
  onThemeColorChanged: {
    if (root.isDynamic) {
      root.baseColor = root.colorToHex(root.themeColor)
      root.updateBacklight(false)
    }
    root.injectPanel()
  }

  onIsNightLightChanged: {
    root.updateBacklight(true)
    root.injectPanel()
  }

  onSunsetTempChanged: {
    if (root.isNightLight) {
      root.updateBacklight(true)
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
      if (root.isDynamic) {
        root.baseColor = root.colorToHex(root.themeColor)
      }
      root.updateBacklight(false)
      root.injectPanel()
    }
    onFileChanged: reload()
  }

  // Persisted base color file (~/.config/alg-rgb/base_color)
  FileView {
    id: baseColorFile
    path: Quickshell.env("HOME") + "/.config/alg-rgb/base_color"
    watchChanges: true
    printErrors: false
    onLoaded: {
      var c = (text() || "").trim().toLowerCase()
      if (c.indexOf("#") === 0 && (c.length === 7 || c.length === 9)) {
        root.baseColor = root.colorToHex(c)
        if (!root.isDynamic) {
          root.updateBacklight(false)
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

  function setBaseColor(hex) {
    root.isDynamic = false
    root.baseColor = hex
    var cmd = "mkdir -p \"$HOME/.config/alg-rgb\" && printf '%s' static > \"$HOME/.config/alg-rgb/mode\" && printf '%s' \"" + hex + "\" > \"$HOME/.config/alg-rgb/base_color\""
    setModeProc.command = ["sh", "-c", cmd]
    setModeProc.running = false
    setModeProc.running = true
    root.updateBacklight(true)
    root.injectPanel()
  }

  function setDynamicMode(dynamicEnabled) {
    root.isDynamic = dynamicEnabled
    if (dynamicEnabled) {
      root.baseColor = root.colorToHex(root.themeColor)
    }
    var modeStr = dynamicEnabled ? "dynamic" : "static"
    var cmd = "mkdir -p \"$HOME/.config/alg-rgb\" && printf '%s' " + modeStr + " > \"$HOME/.config/alg-rgb/mode\""
    setModeProc.command = ["sh", "-c", cmd]
    setModeProc.running = false
    setModeProc.running = true
    root.updateBacklight(true)
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
    target.baseColor = root.baseColor
    target.effectiveColor = root.effectiveColor
    target.isDynamic = root.isDynamic
    target.themeColor = root.themeColor
    target.isNightLight = root.isNightLight
    target.sunsetTemp = root.sunsetTemp
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

  // ---- Status & Hyprsunset Poller ---------------------------------------
  function refresh() {
    if (!statusProc.running) {
      statusProc.running = true
    }
    if (!sunsetProc.running) {
      sunsetProc.running = true
    }
  }

  Timer {
    id: pollTimer
    interval: 2000
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

    if ((!root.baseColor || root.baseColor === "#ffffff") && !root.isNightLight && root.currentColor) {
      if (!root.isDynamic) {
        root.baseColor = root.currentColor
      }
    }
    root.injectPanel()
  }

  // Probes hyprsunset directly via hyprctl or running process
  Process {
    id: sunsetProc
    command: ["sh", "-c", "hyprctl hyprsunset temperature 2>/dev/null || pgrep -a hyprsunset 2>/dev/null || true"]
    running: false
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.parseSunset(text)
    }
  }

  function parseSunset(text) {
    var raw = (text || "").trim()
    var temp = 0
    if (raw !== "") {
      if (raw.indexOf("--identity") !== -1 || raw.indexOf(" -i") !== -1) {
        temp = 6500
      } else {
        // 1. Explicit flag or label (e.g. -t 3250 or temperature: 3250)
        var m = raw.match(/(?:temperature[:\s=]+|-t\s+|--temperature\s+)([1-5][0-9]{3})/i)
        if (m && m[1]) {
          temp = parseInt(m[1])
        } else {
          // 2. Pure number like "3250" or "3250K"
          var m2 = raw.match(/^([1-9][0-9]{3,4})k?$/i)
          if (m2 && m2[1]) {
            temp = parseInt(m2[1])
          } else {
            // 3. Fallback: match any 4-digit number
            var m3 = raw.match(/\b([1-9][0-9]{3,4})\b/)
            if (m3 && m3[1]) {
              temp = parseInt(m3[1])
            }
          }
        }
      }
    }

    var active = (temp > 1000 && temp < 6000)
    var effectiveTemp = active ? temp : (temp >= 6000 ? temp : 6000)

    if (root.isNightLight !== active || (active && root.sunsetTemp !== effectiveTemp)) {
      root.isNightLight = active
      root.sunsetTemp = effectiveTemp
    }
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
    text: "\uf11c"

    // Keep the icon pure white matching all other status icons in the bar
    useActiveColor: false
    foreground: "#ffffff"

    // Dim the icon when backlight is off or driver is missing (standard Omarchy pattern)
    dimmed: !root.powered || !root.driverPresent

    tooltipText: root.driverPresent
      ? (root.powered
          ? ("ALG RGB · " + (root.isNightLight ? (root.sunsetTemp + "K Night Light · ") : "")
              + (root.isDynamic ? "Dynamic (" + root.baseColor.toUpperCase() + ")" : root.baseColor.toUpperCase())
              + " · Brightness " + root.currentBrightness + "/4")
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
