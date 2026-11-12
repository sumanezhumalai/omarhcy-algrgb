pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Ui
import qs.Commons
import qs.Commons as Commons

// ALG RGB keyboard backlight control panel.
// Popout attached to the bar icon, matching official Omarchy aesthetics.
Panel {
  id: root
  moduleName: "suman.alg-rgb"
  ipcTarget:  ""
  manageIpc:  false

  property var anchorItem: null
  property var hostWidget: null

  // Identity anchor for Omarchy Bar Popout management.
  // Using hostWidget (BarWidget) ensures the system tray knows its drawer
  // must hold open (bar.traySectionPopoutOpen === true) while this panel is open.
  readonly property var barIdentity: hostWidget || root

  // ---- Driver state ----------------------------------------------------
  property string currentColor:      "#ffffff"
  property int    currentBrightness: 1
  property bool   powered:           true
  property bool   driverPresent:     true

  // Dynamic theme state
  property bool   isDynamic:         false
  property color  themeColor:        Commons.Color.accent

  // Night light & color tracking (received from BarWidget)
  property bool   isNightLight:      false
  property int    sunsetTemp:        6000
  property string baseColor:         "#ffffff"
  property string effectiveColor:    "#ffffff"

  function colorToHex(c) {
    if (!c) return "#ffffff"
    var s = String(c).trim().toLowerCase()
    if (s.indexOf("#") === 0) {
      if (s.length === 9) return "#" + s.substring(3)
      if (s.length === 7) return s
    }
    return "#ffffff"
  }

  // Re-read status whenever the panel opens
  onOpenedChanged: {
    if (opened) {
      root.refresh()
    }
  }

  function refresh() {
    if (!statusProc.running) {
      statusProc.running = true
    }
    if (root.hostWidget && typeof root.hostWidget.refresh === "function") {
      root.hostWidget.refresh()
    }
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
  }

  // ---- Commands --------------------------------------------------------
  Process {
    id: cmdProc
    running: false
    stdout: StdioCollector { waitForEnd: true }
    onExited: function(exitCode) {
      root.refresh()
      if (root.hostWidget && typeof root.hostWidget.refresh === "function") {
        root.hostWidget.refresh()
      }
    }
  }

  function runAlgRgb(args) {
    cmdProc.command = ["alg-rgb"].concat(args)
    cmdProc.running = false
    cmdProc.running = true
  }

  function applyColor(hex) {
    root.currentColor = hex
    root.baseColor = hex
    runAlgRgb(["color", hex, String(root.currentBrightness)])
  }

  function applyBrightness(level) {
    root.currentBrightness = level
    runAlgRgb(["brightness", String(level)])
  }

  function togglePower() {
    runAlgRgb(root.powered ? ["off"] : ["on"])
  }

  function applyDynamic() {
    root.isDynamic = true
    root.baseColor = root.colorToHex(root.themeColor)
    if (root.hostWidget && typeof root.hostWidget.setDynamicMode === "function") {
      root.hostWidget.setDynamicMode(true)
    } else {
      root.applyColor(root.baseColor)
    }
  }

  function applyPreset(hex) {
    root.isDynamic = false
    root.baseColor = hex
    if (root.hostWidget && typeof root.hostWidget.setBaseColor === "function") {
      root.hostWidget.setBaseColor(hex)
    } else {
      root.applyColor(hex)
    }
  }

  Component.onCompleted: root.refresh()

  // ---- Popup surface ---------------------------------------------------
  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    centerOnBar: false
    contentWidth: panel.fittedContentWidth(Style.space(340))
    contentHeight: panel.fittedContentHeight(panel.loadedContentHeight)

    content: Component {
      Item {
        id: panelContent
        implicitWidth:  Style.space(340)
        implicitHeight: mainColumn.implicitHeight + Style.space(8)

        Column {
          id: mainColumn
          width: parent.width
          spacing: Style.space(10)

          // ---- Hero: color preview + power switch -----------------------
          PanelHero {
            width: parent.width
            foreground: root.bar ? root.bar.foreground : Commons.Color.foreground
            fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
            title: root.powered
              ? (root.isNightLight
                  ? (root.isDynamic ? "Night Light · Dynamic" : "Night Light Backlight")
                  : (root.isDynamic ? "Theme Backlight" : "Keyboard Backlight"))
              : "Backlight Off"
            meta: root.driverPresent
              ? (root.powered
                  ? (root.isNightLight
                      ? (root.sunsetTemp + "K NIGHT LIGHT · " + (root.isDynamic ? "DYNAMIC" : root.baseColor.toUpperCase()))
                      : (root.isDynamic ? ("DYNAMIC · " + root.currentColor.toUpperCase()) : root.currentColor.toUpperCase()))
                  : "STANDBY")
              : "DRIVER NOT LOADED"

            iconComponent: Component {
              Rectangle {
                implicitWidth:  Style.font.display
                implicitHeight: Style.font.display
                radius:         height / 2
                color:          root.powered ? (root.isNightLight ? (root.effectiveColor || root.currentColor) : root.currentColor) : "transparent"
                border.width:   root.powered ? 0 : 2
                border.color:   root.bar
                  ? Qt.rgba(root.bar.foreground.r, root.bar.foreground.g, root.bar.foreground.b, 0.3)
                  : "#555"
              }
            }

            trailingControl: Component {
              ToggleSwitch {
                foreground: root.bar ? root.bar.foreground : Commons.Color.foreground
                accent:     Commons.Color.accent
                checked:    root.powered
                onToggled:  root.togglePower()
              }
            }
          }

          PanelSeparator {
            foreground: root.bar ? root.bar.foreground : Commons.Color.foreground
          }

          // ---- Brightness slider ---------------------------------------
          Item {
            width: parent.width
            implicitHeight: brCol.implicitHeight

            Column {
              id: brCol
              anchors {
                left:  parent.left
                right: parent.right
                leftMargin:  Style.space(6)
                rightMargin: Style.space(6)
              }
              spacing: Style.space(6)

              Row {
                width: parent.width

                PanelSectionHeader {
                  text: "Brightness"
                  foreground: root.bar ? root.bar.foreground : Commons.Color.foreground
                  fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
                }

                Item {
                  width: Math.max(0, parent.width - parent.children[0].implicitWidth - brLevelText.implicitWidth)
                  height: 1
                }

                Text {
                  id: brLevelText
                  textFormat: Text.PlainText
                  text: root.currentBrightness + " / 4"
                  color: root.bar ? root.bar.foreground : Commons.Color.foreground
                  font.family: root.bar ? root.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.caption
                  font.bold: true
                  opacity: 0.7
                  anchors.verticalCenter: parent.verticalCenter
                }
              }

              PanelSlider {
                id: brSlider
                bar:       root.bar
                width:     parent.width
                minimum:   1
                maximum:   4
                step:      1
                integer:   true
                tickCount: 4
                value:     root.currentBrightness

                onMoved:    function(v) { root.applyBrightness(Math.round(v)) }
                onReleased: function(v) { root.applyBrightness(Math.round(v)) }
              }
            }
          }

          PanelSeparator {
            foreground: root.bar ? root.bar.foreground : Commons.Color.foreground
          }

          // ---- Curated Color Options (Dynamic + 4 Warm Presets) ---------
          Item {
            width: parent.width
            implicitHeight: colorCol.implicitHeight

            Column {
              id: colorCol
              anchors {
                left:  parent.left
                right: parent.right
                leftMargin:  Style.space(6)
                rightMargin: Style.space(6)
              }
              spacing: Style.space(8)

              PanelSectionHeader {
                text: "Colors"
                foreground: root.bar ? root.bar.foreground : Commons.Color.foreground
                fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
              }

              Row {
                id: optionsRow
                width: parent.width
                spacing: Style.space(6)

                readonly property real itemWidth: Math.floor((optionsRow.width - optionsRow.spacing * 4) / 5)
                readonly property real swatchSize: Math.min(itemWidth, Style.space(38))

                // 1. Dynamic Omarchy Theme Swatch
                Item {
                  id: dynamicItem
                  width: optionsRow.itemWidth
                  implicitHeight: dynamicCol.implicitHeight

                  Column {
                    id: dynamicCol
                    width: parent.width
                    spacing: Style.space(6)

                    Item {
                      width: parent.width
                      height: optionsRow.swatchSize

                      Rectangle {
                        id: dynamicSwatch
                        width:  optionsRow.swatchSize
                        height: optionsRow.swatchSize
                        radius: optionsRow.swatchSize / 2
                        anchors.horizontalCenter: parent.horizontalCenter

                        color: root.themeColor

                        border.width: root.isDynamic ? 2 : 1
                        border.color: root.isDynamic
                          ? (root.bar ? root.bar.foreground : "#ffffff")
                          : Qt.rgba(root.bar ? root.bar.foreground.r : 1,
                                    root.bar ? root.bar.foreground.g : 1,
                                    root.bar ? root.bar.foreground.b : 1,
                                    0.25)

                        scale: dynamicMouse.containsMouse ? 1.12 : 1.0
                        Behavior on scale {
                          NumberAnimation {
                            duration: Style.duration(100)
                            easing.type: Easing.OutCubic
                          }
                        }

                        // Theme palette icon inside dynamic swatch
                        Text {
                          anchors.centerIn: parent
                          textFormat: Text.PlainText
                          text: "\uf53f"
                          font.family: root.bar ? root.bar.fontFamily : Style.font.family
                          font.pixelSize: Style.font.caption
                          color: {
                            var tc = root.themeColor
                            var lum = 0.299 * tc.r + 0.587 * tc.g + 0.114 * tc.b
                            return lum > 0.6 ? "#1a1a1a" : "#ffffff"
                          }
                        }

                        PanelToolTip {
                          visible: dynamicMouse.containsMouse
                          text: "Dynamic · Omarchy Theme"
                          fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
                        }

                        MouseArea {
                          id: dynamicMouse
                          anchors.fill: parent
                          hoverEnabled: true
                          cursorShape: Qt.PointingHandCursor
                          onClicked: root.applyDynamic()
                        }
                      }
                    }

                    Text {
                      width: parent.width
                      horizontalAlignment: Text.AlignHCenter
                      textFormat: Text.PlainText
                      text: "Dynamic"
                      color: root.bar ? root.bar.foreground : Commons.Color.foreground
                      font.family: root.bar ? root.bar.fontFamily : Style.font.family
                      font.pixelSize: Style.font.caption
                      font.bold: root.isDynamic
                      opacity: root.isDynamic ? 1.0 : 0.6
                      elide: Text.ElideRight
                    }
                  }
                }

                // 2–5. Four Curated Warm Aesthetic Presets
                Repeater {
                  model: [
                    { hex: "#ff7f3f", name: "Flesh",       label: "Flesh"  },
                    { hex: "#ff7f00", name: "Warm Orange", label: "Orange" },
                    { hex: "#e0af68", name: "Amber Sand",  label: "Amber"  },
                    { hex: "#ded885", name: "Buttercream", label: "Cream"  }
                  ]

                  delegate: Item {
                    id: presetItem
                    required property var modelData
                    required property int index

                    width: optionsRow.itemWidth
                    implicitHeight: presetCol.implicitHeight

                    readonly property bool isActive:
                      !root.isDynamic && (root.baseColor.toLowerCase() === presetItem.modelData.hex.toLowerCase() ||
                                          (!root.isNightLight && root.currentColor.toLowerCase() === presetItem.modelData.hex.toLowerCase()))

                    Column {
                      id: presetCol
                      width: parent.width
                      spacing: Style.space(6)

                      Item {
                        width: parent.width
                        height: optionsRow.swatchSize

                        Rectangle {
                          id: presetSwatch
                          width:  optionsRow.swatchSize
                          height: optionsRow.swatchSize
                          radius: optionsRow.swatchSize / 2
                          anchors.horizontalCenter: parent.horizontalCenter

                          color: presetItem.modelData.hex

                          border.width: presetItem.isActive ? 2 : 1
                          border.color: presetItem.isActive
                            ? (root.bar ? root.bar.foreground : "#ffffff")
                            : Qt.rgba(root.bar ? root.bar.foreground.r : 1,
                                      root.bar ? root.bar.foreground.g : 1,
                                      root.bar ? root.bar.foreground.b : 1,
                                      0.25)

                          scale: presetMouse.containsMouse ? 1.12 : 1.0
                          Behavior on scale {
                            NumberAnimation {
                              duration: Style.duration(100)
                              easing.type: Easing.OutCubic
                            }
                          }

                          PanelToolTip {
                            visible: presetMouse.containsMouse
                            text: presetItem.modelData.name + " (" + presetItem.modelData.hex.toUpperCase() + ")"
                            fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
                          }

                          MouseArea {
                            id: presetMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.applyPreset(presetItem.modelData.hex)
                          }
                        }
                      }

                      Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        textFormat: Text.PlainText
                        text: presetItem.modelData.label
                        color: root.bar ? root.bar.foreground : Commons.Color.foreground
                        font.family: root.bar ? root.bar.fontFamily : Style.font.family
                        font.pixelSize: Style.font.caption
                        font.bold: presetItem.isActive
                        opacity: presetItem.isActive ? 1.0 : 0.6
                        elide: Text.ElideRight
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
