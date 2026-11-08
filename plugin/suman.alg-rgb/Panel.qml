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

  // ---- Driver state ----------------------------------------------------
  property string currentColor:      "#ffffff"
  property int    currentBrightness: 1
  property bool   powered:           true
  property bool   driverPresent:     true

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
    runAlgRgb(["color", hex, String(root.currentBrightness)])
  }

  function applyBrightness(level) {
    root.currentBrightness = level
    runAlgRgb(["brightness", String(level)])
  }

  function togglePower() {
    runAlgRgb(root.powered ? ["off"] : ["on"])
  }

  Component.onCompleted: root.refresh()

  // ---- Popup surface ---------------------------------------------------
  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root
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
            title: root.powered ? "Keyboard Backlight" : "Backlight Off"
            meta: root.driverPresent
              ? (root.powered ? root.currentColor.toUpperCase() : "STANDBY")
              : "DRIVER NOT LOADED"

            iconComponent: Component {
              Rectangle {
                implicitWidth:  Style.font.display
                implicitHeight: Style.font.display
                radius:         height / 2
                color:          root.powered ? root.currentColor : "transparent"
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

          // ---- Color presets -------------------------------------------
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

              // 8×2 swatch grid: 16 warm, eye-easy aesthetic colors in natural spectrum order
              Grid {
                id: swatchGrid
                width: parent.width
                columns: 8
                spacing: Style.space(6)

                readonly property var colors: [
                  { hex: "#d46a6a", name: "Terracotta"   },
                  { hex: "#ff7f3f", name: "Flesh"        },
                  { hex: "#ff7f00", name: "Warm Orange"  },
                  { hex: "#e0af68", name: "Amber Sand"   },
                  { hex: "#ded885", name: "Buttercream"  },
                  { hex: "#87a96b", name: "Matcha Green" },
                  { hex: "#98d7c2", name: "Sage Mint"    },
                  { hex: "#167d7f", name: "Deep Teal"    },
                  { hex: "#29a0b1", name: "Ocean Cyan"   },
                  { hex: "#6b8cae", name: "Denim Blue"   },
                  { hex: "#d3d9e9", name: "Bluish White" },
                  { hex: "#a29dc6", name: "Periwinkle"   },
                  { hex: "#8976a2", name: "Muted Violet" },
                  { hex: "#8c5670", name: "Plum Mauve"   },
                  { hex: "#f8c0c8", name: "Blossom Rose" },
                  { hex: "#e8e4dc", name: "Warm White"   }
                ]

                Repeater {
                  model: swatchGrid.colors

                  delegate: Rectangle {
                    id: swatch
                    required property var modelData
                    required property int index

                    readonly property real swatchSize: Math.floor((swatchGrid.width - swatchGrid.spacing * 7) / 8)
                    width:  swatchSize
                    height: swatchSize
                    radius: swatchSize / 2

                    color: swatch.modelData.hex

                    readonly property bool isActive:
                      root.currentColor.toLowerCase() === swatch.modelData.hex.toLowerCase()

                    border.width: isActive ? 2 : 1
                    border.color: isActive
                      ? (root.bar ? root.bar.foreground : "#ffffff")
                      : Qt.rgba(root.bar ? root.bar.foreground.r : 1,
                                root.bar ? root.bar.foreground.g : 1,
                                root.bar ? root.bar.foreground.b : 1,
                                0.2)

                    scale: swatchMouse.containsMouse ? 1.15 : 1.0
                    Behavior on scale {
                      NumberAnimation {
                        duration: Style.duration(100)
                        easing.type: Easing.OutCubic
                      }
                    }

                    PanelToolTip {
                      visible: swatchMouse.containsMouse
                      text: swatch.modelData.name
                      fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
                    }

                    MouseArea {
                      id: swatchMouse
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onClicked: root.applyColor(swatch.modelData.hex)
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
