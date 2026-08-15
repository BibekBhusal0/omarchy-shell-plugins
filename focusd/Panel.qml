import QtQuick
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "focusd"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  property var timerService: null
  readonly property var barIdentity: hostWidget || root

  readonly property color foreground: Color.popups.text
  readonly property color activeColor: Color.accent
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  property int selectedAction: 0
  property bool cursorActive: true

  readonly property bool stopVisible: timerService ? timerService.active : false

  function open() {
    selectedAction = 0
    cursorActive = true
    controller.show()
  }

  function close() {
    controller.hide()
  }

  function toggle() {
    if (opened) close()
    else open()
  }

  function actionCount() {
    return root.stopVisible ? 3 : 2
  }

  function selectAction(delta) {
    cursorActive = true
    if (!timerService) {
      selectedAction = 0
      return
    }
    var count = root.actionCount()
    selectedAction = ((selectedAction + delta) % count + count) % count
  }

  function activateSelected() {
    if (!timerService) return
    if (selectedAction === 0 && !timerService.stopped) timerService.togglePause()
    else if (selectedAction === 1 && !timerService.stopped) timerService.skip()
    else if (selectedAction === 2 && root.stopVisible) timerService.stop()
  }

  function actionHovered(index, hovered) {
    if (!hovered) return
    cursorActive = true
    selectedAction = index
  }

  function switchPanel(direction) {
    if (bar && typeof bar.switchPanelFrom === "function")
      return bar.switchPanelFrom(barIdentity, direction)
    return false
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(330))
    contentHeight: panel.fittedContentHeight(content.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent

      onMoveRequested: function(dx, dy) {
        if (dx !== 0) root.selectAction(dx)
        else if (dy !== 0) root.selectAction(dy)
      }
      onActivateRequested: root.activateSelected()
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: content
        width: parent.width
        spacing: Style.space(18)

        Item {
          id: timerFace
          width: parent.width
          implicitHeight: Style.space(180)

          CircularProgress {
            anchors.centerIn: parent
            width: Math.min(parent.width, parent.height)
            height: width
            progress: root.timerService ? root.timerService.progress : 0
            trackColor: Color.muted
            fillColor: root.activeColor
            strokeWidth: Math.max(5, Style.spaceReal(7))
          }

          Column {
            anchors.centerIn: parent
            spacing: Style.space(5)

            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              text: root.timerService ? root.timerService.remainingText : "25:00"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Math.round(Style.font.displayLarge * 1.7)
              font.bold: true
            }

            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              text: root.timerService ? root.timerService.sessionLabel : "Work"
              color: root.activeColor
              font.family: root.fontFamily
              font.pixelSize: Style.font.title
            }
          }
        }

        Column {
          width: parent.width
          spacing: Style.space(10)

          Row {
            width: parent.width
            spacing: Style.space(20)

            Column {
              width: (parent.width - parent.spacing) / 2
              spacing: Style.spacing.labelGap
              InfoPair { icon: "󰔟"; label: "Streak"; value: (root.timerService ? root.timerService.currentStreak : 0) + "d" }
              InfoPair { icon: "󰔟"; label: "Focused today"; value: root.timerService ? root.timerService.focusedToday : "—" }
            }

            Column {
              width: (parent.width - parent.spacing) / 2
              spacing: Style.spacing.labelGap
              InfoPair { icon: "󰓾"; label: "Goal"; value: root.timerService ? root.timerService.dailyGoal : "—" }
              InfoPair { icon: ""; label: "Sessions today"; value: root.timerService ? String(root.timerService.sessionsToday) : "0" }
            }
          }
        }

        Row {
          id: actions
          anchors.horizontalCenter: parent.horizontalCenter
          spacing: Style.space(10)
          readonly property real buttonSize: Style.space(42)

          Button {
            id: pauseButton
            implicitWidth: actions.buttonSize
            implicitHeight: actions.buttonSize
            width: actions.buttonSize
            height: actions.buttonSize
            iconText: root.timerService && root.timerService.paused ? "" : "󰏤"
            tooltipText: root.timerService && root.timerService.paused
              ? "Resume session"
              : "Pause session"
            foreground: root.foreground
            accent: root.activeColor
            iconSize: Style.font.iconLarge
            horizontalPadding: 0
            verticalPadding: 0
            enabled: !!root.timerService && !root.timerService.stopped
            opacity: enabled ? 1 : 0.35
            hasCursor: root.cursorActive && root.selectedAction === 0
            onHovered: function(value) { root.actionHovered(0, value) }
            onClicked: if (root.timerService) root.timerService.togglePause()
          }

          Button {
            id: skipButton
            implicitWidth: actions.buttonSize
            implicitHeight: actions.buttonSize
            width: actions.buttonSize
            height: actions.buttonSize
            iconText: "󰒭"
            tooltipText: "Skip to " + (root.timerService ? root.timerService.nextSessionLabel : "next session")
            foreground: root.foreground
            accent: root.activeColor
            iconSize: Style.font.iconLarge
            horizontalPadding: 0
            verticalPadding: 0
            enabled: !!root.timerService && !root.timerService.stopped
            opacity: enabled ? 1 : 0.35
            hasCursor: root.cursorActive && root.selectedAction === 1
            onHovered: function(value) { root.actionHovered(1, value) }
            onClicked: if (root.timerService) root.timerService.skip()
          }

          Button {
            id: stopButton
            implicitWidth: actions.buttonSize
            implicitHeight: actions.buttonSize
            width: actions.buttonSize
            height: actions.buttonSize
            iconText: "󰛉"
            tooltipText: "Stop session"
            foreground: root.foreground
            accent: root.activeColor
            iconSize: Style.font.iconLarge
            horizontalPadding: 0
            verticalPadding: 0
            visible: root.stopVisible
            enabled: !!root.timerService && !root.timerService.stopped
            opacity: enabled ? 1 : 0.35
            hasCursor: root.cursorActive && root.selectedAction === 2
            onHovered: function(value) { root.actionHovered(2, value) }
            onClicked: if (root.timerService) root.timerService.stop()
          }
        }
      }
    }
  }

  component InfoPair: Row {
    property string icon: ""
    property string label: ""
    property string value: ""

    width: parent.width
    spacing: Style.space(8)

    Text {
      id: iconText
      visible: icon !== ""
      text: icon
      color: root.foreground
      opacity: 0.6
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
    }
    InfoLabel { text: label }
    Item { width: Math.max(0, parent.width - parent.children[0].implicitWidth - parent.children[1].implicitWidth - parent.children[3].implicitWidth - parent.spacing * 3); height: 1 }
    InfoValue { text: value }
  }

  component InfoLabel: Text {
    color: root.foreground
    opacity: 0.6
    font.family: root.fontFamily
    font.pixelSize: Style.font.bodySmall
  }

  component InfoValue: Text {
    color: root.foreground
    font.family: root.fontFamily
    font.pixelSize: Style.font.bodySmall
  }
}
