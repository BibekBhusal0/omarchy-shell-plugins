import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "bibek.ytdl"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  property var ytdlService: null
  readonly property var barIdentity: hostWidget || root

  readonly property color foreground: Color.popups.text
  readonly property color activeColor: Color.accent
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  property string inputUrl: ""
  property string selectedQuality: "best"
  property bool showHistory: false
  property int selectedAction: 0
  property bool cursorActive: true
  property bool inputAutoFilled: false

  readonly property bool installed: ytdlService ? ytdlService.installed : false
  readonly property bool hasClipboardUrl: ytdlService && ytdlService.clipboardUrl !== ""
  readonly property var activeDownloads: ytdlService ? filterActive(ytdlService.downloads) : []
  readonly property var queuedDownloads: ytdlService ? filterQueued(ytdlService.downloads) : []
  readonly property var historyItems: ytdlService ? ytdlService.history : []

  onActiveDownloadsChanged: {
    console.log("[ytdl:panel] activeDownloads changed, count:", activeDownloads.length)
    for (var i = 0; i < activeDownloads.length; i++) {
      var d = activeDownloads[i]
      console.log("[ytdl:panel]   [", i, "] id:", d.id, "title:", JSON.stringify(d.title), "progress:", d.progress, "speed:", JSON.stringify(d.speed), "eta:", JSON.stringify(d.eta), "status:", d.status)
    }
  }

  onYtdlServiceChanged: {
    console.log("[ytdl:panel] ytdlService changed:", !!ytdlService)
    if (ytdlService) {
      console.log("[ytdl:panel]   service installed:", ytdlService.installed)
      console.log("[ytdl:panel]   service downloads len:", ytdlService.downloads ? ytdlService.downloads.length : "null")
    }
  }

  onInstalledChanged: {
    console.log("[ytdl:panel] installed changed:", installed)
  }

  onOpenedChanged: {
    console.log("[ytdl:panel] opened changed:", opened)
  }

  onHasClipboardUrlChanged: {
    if (hasClipboardUrl && ytdlService) {
      inputUrl = ytdlService.clipboardUrl
      inputAutoFilled = true
    }
  }

  onInputUrlChanged: {
    if (inputUrl && urlInput.text !== inputUrl)
      urlInput.text = inputUrl
  }

  function filterActive(list) {
    var r = []
    for (var i = 0; i < list.length; i++)
      if (list[i].status === "downloading" || list[i].status === "merging")
        r.push(list[i])
    return r
  }

  function filterQueued(list) {
    var r = []
    for (var i = 0; i < list.length; i++)
      if (list[i].status === "queued") r.push(list[i])
    return r
  }

  function open() {
    selectedAction = 0
    cursorActive = true
    controller.show()
    if (ytdlService) ytdlService.checkInstallation()
    if (hasClipboardUrl && !inputUrl) {
      inputUrl = ytdlService.clipboardUrl
      inputAutoFilled = true
    }
  }

  function close() {
    controller.hide()
  }

  function toggle() {
    if (opened) close()
    else open()
  }

  function switchPanel(direction) {
    if (bar && typeof bar.switchPanelFrom === "function")
      return bar.switchPanelFrom(barIdentity, direction)
    return false
  }

  function submitUrl() {
    console.log("[ytdl] submitUrl called, inputUrl:", inputUrl, "ytdlService:", !!ytdlService)
    if (!ytdlService || !inputUrl) return
    console.log("[ytdl] calling startDownload")
    ytdlService.startDownload(inputUrl, selectedQuality)
    inputUrl = ""
    inputAutoFilled = false
  }

  Component.onCompleted: {
    if (ytdlService) ytdlService.checkInstallation()
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(420))
    contentHeight: panel.fittedContentHeight(content.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent

      onMoveRequested: function(dx, dy) {
        if (dx !== 0) root.selectedAction = (root.selectedAction + dx + 2) % 2
        else if (dy !== 0) root.selectedAction = (root.selectedAction + dy + 2) % 2
      }
      onActivateRequested: {
        if (root.selectedAction === 0) root.submitUrl()
        else root.showHistory = !root.showHistory
      }
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
    }

    Column {
      id: content
      width: parent.width
      spacing: Style.space(16)

      // Not installed state
      Column {
        visible: !root.installed && !root.ytdlService?.checkingInstallation
        width: parent.width
        spacing: Style.space(14)

        Item {
          width: parent.width
          implicitHeight: Style.space(56)

          Text {
            anchors.centerIn: parent
            // FIX: icon below
            text: "\uf16b"
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.display + Style.space(8)
          }
        }

        Column {
          width: parent.width
          spacing: Style.space(6)

          Text {
            width: parent.width
            text: "yt-dlp is not installed."
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.title
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
          }

          Text {
            width: parent.width
            text: "Install yt-dlp to download videos from YouTube and other sites."
            color: Qt.darker(root.foreground, 1.4)
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
          }
        }

        Button {
          width: parent.width
          text: root.ytdlService && root.ytdlService.installing
            ? "Installing yt-dlp\u2026"
            : "Install yt-dlp"
          // FIX: icon below
          iconText: root.ytdlService && root.ytdlService.installing ? "" : "\uf487"
          iconSpinning: root.ytdlService && root.ytdlService.installing
          fontFamily: root.fontFamily
          fontSize: Style.font.body
          iconSize: Style.font.icon
          foreground: root.foreground
          accent: root.activeColor
          verticalPadding: Style.space(14)
          bordered: true
          selected: true
          hasCursor: root.cursorActive && root.selectedAction === 0
          enabled: !(root.ytdlService && root.ytdlService.installing)
          onHovered: function(hovered) {
            if (hovered) { root.cursorActive = true; root.selectedAction = 0 }
          }
          onClicked: {
            if (root.ytdlService) {
              if (root.ytdlService.installing) return
              root.ytdlService.installInTerminal()
            }
          }
        }
      }

      // URL input section (when installed)
      Column {
        visible: root.installed
        width: parent.width
        spacing: Style.space(10)

        // Clipboard indicator
        Text {
          visible: root.hasClipboardUrl && root.inputAutoFilled
          width: parent.width
          // FIX: icon below
          text: "\uf017 Link detected from clipboard"
          color: root.activeColor
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
        }

        // URL input field
        Row {
          width: parent.width
          spacing: Style.space(8)

          Rectangle {
            width: parent.width - qualitySelector.width - downloadManualBtn.width - parent.spacing * 2
            height: Style.space(36)
            radius: Style.space(6)
            color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.06)
            border.width: 1
            border.color: urlInput.activeFocus
              ? root.activeColor
              : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.12)

            TextInput {
              id: urlInput
              anchors.fill: parent
              anchors.margins: Style.space(8)
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              clip: true
              selectByMouse: true
              selectionColor: root.activeColor
              verticalAlignment: TextInput.AlignVCenter

              property string placeholder: "Paste URL here\u2026"

              Text {
                visible: !urlInput.text && !urlInput.activeFocus
                text: urlInput.placeholder
                color: Qt.darker(root.foreground, 1.6)
                font: urlInput.font
                anchors.verticalCenter: parent.verticalCenter
              }

              Keys.onReturnPressed: root.submitUrl()
              Keys.onEnterPressed: root.submitUrl()
              onTextChanged: {
                root.inputUrl = text
                if (text) root.inputAutoFilled = false
              }
            }
          }

          Rectangle {
            id: qualitySelector
            width: Style.space(60)
            height: Style.space(36)
            radius: Style.space(6)
            color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.06)
            border.width: 1
            border.color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.12)

            property var qualities: ["best", "1080p", "720p", "480p", "audio"]
            property int currentIndex: qualities.indexOf(root.selectedQuality)

            Text {
              anchors.centerIn: parent
              text: qualitySelector.qualities[qualitySelector.currentIndex] || "best"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
            }

            MouseArea {
              anchors.fill: parent
              onClicked: {
                var next = (qualitySelector.currentIndex + 1) % qualitySelector.qualities.length
                root.selectedQuality = qualitySelector.qualities[next]
              }
            }
          }

          Button {
            id: downloadManualBtn
            // FIX: icon below
            iconText: "\uf381"
            tooltipText: "Download"
            foreground: root.foreground
            accent: root.activeColor
            iconSize: Style.font.icon
            implicitWidth: Style.space(36)
            implicitHeight: Style.space(36)
            horizontalPadding: 0
            verticalPadding: 0
            enabled: root.inputUrl !== ""
            opacity: enabled ? 1 : 0.35
            hasCursor: root.cursorActive && root.selectedAction === 0
            onHovered: function(hovered) {
              if (hovered) { root.cursorActive = true; root.selectedAction = 0 }
            }
            onClicked: root.submitUrl()
          }
        }
      }

      // Active downloads
      Column {
        visible: root.installed && root.activeDownloads.length > 0
        width: parent.width
        spacing: Style.space(8)

        Row {
          width: parent.width
          Text {
            // FIX: icon below
            text: "\uf381 Active Downloads (" + root.activeDownloads.length + ")"
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
          }
        }

        Repeater {
          model: root.activeDownloads

          Rectangle {
            width: parent.width
            height: downloadCol.implicitHeight + Style.space(14)
            radius: Style.space(6)
            color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.04)
            border.width: 1
            border.color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.08)

            Component.onCompleted: {
              console.log("[ytdl:panel] delegate created, modelData:", JSON.stringify(modelData))
            }

            Column {
              id: downloadCol
              anchors.fill: parent
              anchors.margins: Style.space(8)
              spacing: Style.space(4)

              Row {
                width: parent.width
                spacing: Style.space(6)

                Text {
                  width: parent.width - cancelBtn.width - parent.spacing
                  text: modelData.title || "Fetching title\u2026"
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.bodySmall
                  font.bold: true
                  elide: Text.ElideRight
                  maximumLineCount: 1
                }

                Text {
                  text: modelData.progress > 0 ? Math.round(modelData.progress) + "%" : ""
                  color: root.activeColor
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  font.bold: true
                  anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                  text: modelData.speed || ""
                  color: Qt.darker(root.foreground, 1.4)
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                  text: modelData.eta ? "ETA " + modelData.eta : ""
                  color: Qt.darker(root.foreground, 1.4)
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  anchors.verticalCenter: parent.verticalCenter
                }

                Rectangle {
                  id: cancelBtn
                  width: Style.space(22)
                  height: Style.space(22)
                  radius: Style.space(4)
                  color: cancelArea.containsMouse
                    ? Qt.rgba(Color.urgent.r, Color.urgent.g, Color.urgent.b, 0.2)
                    : "transparent"

                  Text {
                    anchors.centerIn: parent
                    // FIX: icon below
                    text: "\uf00d"
                    color: Color.urgent
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.bodySmall
                  }

                  MouseArea {
                    id: cancelArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                      if (ytdlService) ytdlService.cancelDownload(modelData.id)
                    }
                  }
                }
              }

              // Progress bar
              Rectangle {
                width: parent.width
                height: Style.space(4)
                radius: height / 2
                color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.1)

                Rectangle {
                  width: Math.max(height, parent.width * (modelData.progress / 100))
                  height: parent.height
                  radius: parent.radius
                  color: root.activeColor

                  Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                }
              }
            }
          }
        }
      }

      // History section
      Column {
        visible: root.installed && root.historyItems.length > 0
        width: parent.width
        spacing: Style.space(8)

        Rectangle {
          width: parent.width
          height: historyHeader.implicitHeight + Style.space(12)
          radius: Style.space(6)
          color: "transparent"

          Row {
            id: historyHeader
            anchors.fill: parent
            anchors.margins: Style.space(6)
            spacing: Style.space(8)

            Text {
              // FIX: icon below
              text: "\uf1da History (" + root.historyItems.length + ")"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              anchors.verticalCenter: parent.verticalCenter
            }

            Item { width: parent.width - clearHistoryBtn.width - historyToggle.width - historyHeader.children[0].implicitWidth - parent.spacing * 3; height: 1 }

            Rectangle {
              id: clearHistoryBtn
              width: Style.space(22)
              height: Style.space(22)
              radius: Style.space(4)
              color: clearHistoryArea.containsMouse
                ? Qt.rgba(Color.urgent.r, Color.urgent.g, Color.urgent.b, 0.2)
                : "transparent"
              anchors.verticalCenter: parent.verticalCenter

              Text {
                anchors.centerIn: parent
                // FIX: icon below
                text: "\uf1f8"
                color: Color.urgent
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
              }

              MouseArea {
                id: clearHistoryArea
                anchors.fill: parent
                hoverEnabled: true
                onClicked: {
                  if (ytdlService) ytdlService.clearHistory()
                }
              }
            }

            Rectangle {
              id: historyToggle
              width: Style.space(22)
              height: Style.space(22)
              radius: Style.space(4)
              color: historyToggleArea.containsMouse
                ? Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.1)
                : "transparent"
              anchors.verticalCenter: parent.verticalCenter

              Text {
                anchors.centerIn: parent
                text: root.showHistory ? "\uf077" : "\uf078"
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
              }

              MouseArea {
                id: historyToggleArea
                anchors.fill: parent
                hoverEnabled: true
                onClicked: root.showHistory = !root.showHistory
              }
            }
          }
        }

        Repeater {
          model: root.showHistory ? root.historyItems : []

          Rectangle {
            width: parent.width
            height: historyRow.implicitHeight + Style.space(12)
            radius: Style.space(6)
            color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.03)
            border.width: 1
            border.color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.06)

            Row {
              id: historyRow
              anchors.fill: parent
              anchors.margins: Style.space(6)
              spacing: Style.space(6)

              Text {
                // FIX: icon below
                text: modelData.status === "done" ? "\uf00c" : modelData.status === "error" ? "\uf00d" : "\uf016"
                color: modelData.status === "done" ? "#4ade80" : modelData.status === "error" ? Color.urgent : Qt.darker(root.foreground, 1.4)
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
                anchors.verticalCenter: parent.verticalCenter
              }

              Column {
                width: parent.width - parent.spacing * 2 - actionRow.width
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(2)

                Text {
                  width: parent.width
                  text: modelData.title || "Unknown"
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.bodySmall
                  font.bold: true
                  elide: Text.ElideRight
                  maximumLineCount: 1
                }

                Text {
                  width: parent.width
                  text: {
                    if (modelData.status === "done") return "Completed"
                    if (modelData.status === "error") return modelData.error || "Download failed"
                    if (modelData.status === "cancelled") return "Cancelled"
                    return modelData.status
                  }
                  color: Qt.darker(root.foreground, 1.4)
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  elide: Text.ElideRight
                  maximumLineCount: 1
                }
              }

              Row {
                id: actionRow
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(4)

                Rectangle {
                  visible: modelData.status === "done" && modelData.filepath
                  width: Style.space(24)
                  height: Style.space(24)
                  radius: Style.space(4)
                  color: playItemArea.containsMouse
                    ? Qt.rgba(root.activeColor.r, root.activeColor.g, root.activeColor.b, 0.2)
                    : "transparent"

                  Text {
                    anchors.centerIn: parent
                    // FIX: icon below
                    text: "\uf04b"
                    color: root.activeColor
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.bodySmall
                  }

                  MouseArea {
                    id: playItemArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: { if (ytdlService) ytdlService.playFile(modelData.filepath) }
                  }
                }

                Rectangle {
                  visible: modelData.status === "done" && modelData.filepath
                  width: Style.space(24)
                  height: Style.space(24)
                  radius: Style.space(4)
                  color: folderItemArea.containsMouse
                    ? Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.1)
                    : "transparent"

                  Text {
                    anchors.centerIn: parent
                    // FIX: icon below
                    text: "\uf07b"
                    color: root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.bodySmall
                  }

                  MouseArea {
                    id: folderItemArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: { if (ytdlService) ytdlService.openFolder(modelData.filepath) }
                  }
                }

                Rectangle {
                  visible: modelData.status === "error" || modelData.status === "cancelled"
                  width: Style.space(24)
                  height: Style.space(24)
                  radius: Style.space(4)
                  color: retryItemArea.containsMouse
                    ? Qt.rgba(root.activeColor.r, root.activeColor.g, root.activeColor.b, 0.2)
                    : "transparent"

                  Text {
                    anchors.centerIn: parent
                    // FIX: icon below
                    text: "\uf021"
                    color: root.activeColor
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.bodySmall
                  }

                  MouseArea {
                    id: retryItemArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: { if (ytdlService) ytdlService.retryDownload(modelData) }
                  }
                }

                Rectangle {
                  width: Style.space(24)
                  height: Style.space(24)
                  radius: Style.space(4)
                  color: removeItemArea.containsMouse
                    ? Qt.rgba(Color.urgent.r, Color.urgent.g, Color.urgent.b, 0.2)
                    : "transparent"

                  Text {
                    anchors.centerIn: parent
                    // FIX: icon below
                    text: "\uf00d"
                    color: Color.urgent
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.bodySmall
                  }

                  MouseArea {
                    id: removeItemArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: { if (ytdlService) ytdlService.removeHistoryItem(modelData.id) }
                  }
                }
              }
            }
          }
        }
      }

      // Empty state
      Column {
        visible: root.installed && root.activeDownloads.length === 0 && root.historyItems.length === 0
        width: parent.width
        spacing: Style.space(10)

        Item {
          width: parent.width
          implicitHeight: Style.space(48)

          Text {
            anchors.centerIn: parent
            // FIX: icon below
            text: "\uf381"
            color: Qt.darker(root.foreground, 1.4)
            font.family: root.fontFamily
            font.pixelSize: Style.font.display
            opacity: 0.4
          }
        }

        Text {
          width: parent.width
          text: "Paste a YouTube URL above to start downloading."
          color: Qt.darker(root.foreground, 1.4)
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          horizontalAlignment: Text.AlignHCenter
          wrapMode: Text.WordWrap
        }
      }
    }
  }
}
