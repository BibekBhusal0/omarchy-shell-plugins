import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

Column {
  id: root

  property var timerService: null
  property color foreground: Color.popups.text
  property color activeColor: Color.accent
  property string fontFamily: Style.font.family
  property string progressBarStyle: "linear"
  property bool updateAvailable: false
  property bool cursorActive: false
  property int selectedAction: 0

  readonly property bool resetVisible: timerService ? timerService.active : false
  readonly property bool addTimeVisible: timerService ? (timerService.active && timerService.hasAddMinutesFeature) : false

  signal updateRequested
  signal infoRequested
  signal actionHovered(int index, bool hovered)

  function actionCount() {
    var count = 2;
    if (!!root.timerService && !root.timerService.stopped)
      count += 1;
    if (root.resetVisible)
      count += 1;
    if (root.addTimeVisible)
      count += 1;
    return count;
  }

  width: parent.width
  spacing: Style.space(18)

  Column {
    visible: root.updateAvailable
    width: parent.width
    spacing: Style.space(8)

    Row {
      width: parent.width
      spacing: Style.space(8)

      Text {
        text: ""
        color: root.activeColor
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
      }

      Text {
        text: "Update available"
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
        anchors.verticalCenter: parent.verticalCenter
      }

      Item {
        width: 1
        height: 1
        Layout.fillWidth: true
      }

      Button {
        text: "Update"
        iconText: "󰚰"
        foreground: root.foreground
        accent: root.activeColor
        fontFamily: root.fontFamily
        fontSize: Style.font.bodySmall
        onClicked: root.updateRequested()
      }
    }

    Rectangle {
      width: parent.width
      height: 1
      color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.08)
    }
  }

  LinearFace {
    width: parent.width
    visible: root.progressBarStyle !== "circular"
    timerService: root.timerService
    foreground: root.foreground
    activeColor: root.activeColor
    fontFamily: root.fontFamily
  }

  CircularFace {
    width: parent.width
    visible: root.progressBarStyle === "circular"
    timerService: root.timerService
    foreground: root.foreground
    activeColor: root.activeColor
    fontFamily: root.fontFamily
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
        InfoPair {
          icon: ""
          label: "Streak"
          value: (root.timerService ? root.timerService.currentStreak : 0) + "d"
          foreground: root.foreground
          fontFamily: root.fontFamily
        }
        InfoPair {
          icon: "󰓾"
          label: "Goal"
          value: root.timerService ? root.timerService.dailyGoal : "—"
          foreground: root.foreground
          fontFamily: root.fontFamily
        }
      }

      Column {
        width: (parent.width - parent.spacing) / 2
        spacing: Style.spacing.labelGap
        InfoPair {
          icon: ""
          label: "Sessions today"
          value: root.timerService ? String(root.timerService.sessionsToday) : "0"
          foreground: root.foreground
          fontFamily: root.fontFamily
        }
        InfoPair {
          icon: "󰔟"
          label: "Focused today"
          value: root.timerService ? root.timerService.focusedToday : "—"
          foreground: root.foreground
          fontFamily: root.fontFamily
        }
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
      iconText: root.timerService && root.timerService.paused ? "" : "󰏤"
      tooltipText: root.timerService && root.timerService.paused ? "Resume session" : "Pause session"
      foreground: root.foreground
      accent: root.activeColor
      iconSize: Style.font.iconLarge
      horizontalPadding: 0
      verticalPadding: 0
      enabled: !!root.timerService && !root.timerService.stopped
      opacity: enabled ? 1 : 0.35
      hasCursor: root.cursorActive && root.selectedAction === 0
      onHovered: function (value) {
        root.actionHovered(0, value);
      }
      onClicked: if (root.timerService)
        root.timerService.togglePause()
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
      onHovered: function (value) {
        root.actionHovered(1, value);
      }
      onClicked: if (root.timerService)
        root.timerService.skip()
    }

    Button {
      id: resetButton
      visible: root.resetVisible
      implicitWidth: actions.buttonSize
      implicitHeight: actions.buttonSize
      width: actions.buttonSize
      height: actions.buttonSize
      iconText: "󰑖"
      tooltipText: "Reset session"
      foreground: root.foreground
      accent: root.activeColor
      iconSize: Style.font.iconLarge
      horizontalPadding: 0
      verticalPadding: 0
      enabled: root.resetVisible
      opacity: enabled ? 1 : 0.35
      hasCursor: root.cursorActive && root.selectedAction === 2
      onHovered: function (value) {
        root.actionHovered(2, value);
      }
      onClicked: if (root.timerService)
        root.timerService.stop()
    }

    Button {
      id: addTimeButton
      visible: root.addTimeVisible
      implicitWidth: actions.buttonSize
      implicitHeight: actions.buttonSize
      width: actions.buttonSize
      height: actions.buttonSize
      iconText: "󰐖"
      tooltipText: "Add 5 minutes"
      foreground: root.foreground
      accent: root.activeColor
      iconSize: Style.font.iconLarge
      horizontalPadding: 0
      verticalPadding: 0
      enabled: root.addTimeVisible
      opacity: enabled ? 1 : 0.35
      hasCursor: root.cursorActive && root.selectedAction === (root.resetVisible ? 3 : 2)
      onHovered: function (value) {
        root.actionHovered(root.resetVisible ? 3 : 2, value);
      }
      onClicked: if (root.timerService)
        root.timerService.addMinutes(5)
    }
  }

  Item {
    width: parent.width
    height: Style.space(28)

    Button {
      anchors.centerIn: parent
      implicitWidth: Style.space(28)
      implicitHeight: Style.space(28)
      iconText: ""
      tooltipText: "Info and settings"
      foreground: root.foreground
      accent: root.activeColor
      iconSize: Style.font.body
      horizontalPadding: 0
      verticalPadding: 0
      hasCursor: root.cursorActive && root.selectedAction === root.actionCount() - 1
      onHovered: function (value) {
        root.actionHovered(root.actionCount() - 1, value);
      }
      onClicked: root.infoRequested()
    }
  }

  component InfoPair: Row {
    property string icon: ""
    property string label: ""
    property string value: ""
    property color foreground: Color.popups.text
    property string fontFamily: Style.font.family

    width: parent.width
    spacing: Style.space(8)

    Text {
      id: iconText
      visible: icon !== ""
      text: icon
      color: foreground
      opacity: 0.6
      font.family: fontFamily
      font.pixelSize: Style.font.bodySmall
    }
    InfoLabel {
      text: label
      foreground: parent.foreground
      fontFamily: parent.fontFamily
    }
    Item {
      width: Math.max(0, parent.width - parent.children[0].implicitWidth - parent.children[1].implicitWidth - parent.children[3].implicitWidth - parent.spacing * 3)
      height: 1
    }
    InfoValue {
      text: value
      foreground: parent.foreground
      fontFamily: parent.fontFamily
    }
  }

  component InfoLabel: Text {
    property color foreground: Color.popups.text
    property string fontFamily: Style.font.family

    color: foreground
    opacity: 0.6
    font.family: fontFamily
    font.pixelSize: Style.font.bodySmall
  }

  component InfoValue: Text {
    property color foreground: Color.popups.text
    property string fontFamily: Style.font.family

    color: foreground
    font.family: fontFamily
    font.pixelSize: Style.font.bodySmall
  }

  component LinearFace: Column {
    property var timerService: null
    property color foreground: Color.popups.text
    property color activeColor: Color.accent
    property string fontFamily: Style.font.family

    width: parent.width
    spacing: Style.space(12)

    Item {
      width: parent.width
      implicitHeight: Math.max(heroIcon.implicitHeight, heroLabels.implicitHeight, heroTime.implicitHeight)

      Text {
        id: heroIcon
        text: timerService ? timerService.icon : ""
        color: foreground
        font.family: fontFamily
        font.pixelSize: Style.font.display
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
      }

      Column {
        id: heroLabels
        anchors.left: heroIcon.right
        anchors.leftMargin: Style.space(14)
        anchors.right: heroTime.left
        anchors.rightMargin: Style.space(10)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(2)

        Text {
          text: timerService ? timerService.sessionLabel : "Work"
          color: foreground
          font.family: fontFamily
          font.pixelSize: Style.font.title
          font.bold: true
          elide: Text.ElideRight
          width: parent.width
        }

        Text {
          text: (timerService && timerService.paused ? "Paused" : timerService && timerService.running ? "Running" : "Stopped").toUpperCase()
          color: Qt.darker(foreground, 1.4)
          font.family: fontFamily
          font.pixelSize: Style.font.caption
          font.bold: true
          font.letterSpacing: 1.2
          elide: Text.ElideRight
          width: parent.width
        }
      }

      Text {
        id: heroTime
        text: timerService ? timerService.remainingText : "25:00"
        color: foreground
        font.family: fontFamily
        font.pixelSize: Style.font.displayLarge
        font.bold: true
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
      }
    }

    Item {
      width: parent.width
      implicitHeight: Style.space(8)

      Rectangle {
        id: progressTrack
        anchors.fill: parent
        radius: height / 2
        color: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.12)
      }

      Rectangle {
        id: progressFill
        anchors.left: progressTrack.left
        anchors.verticalCenter: progressTrack.verticalCenter
        height: progressTrack.height
        radius: progressTrack.radius
        color: foreground
        width: Math.max(progressTrack.height, progressTrack.width * (timerService ? timerService.progress : 0))

        Behavior on width {
          NumberAnimation {
            duration: 320
            easing.type: Easing.OutCubic
          }
        }
      }
    }

    Row {
      anchors.horizontalCenter: parent.horizontalCenter
      spacing: Style.space(8)

      Repeater {
        model: timerService ? timerService.workSessionsBeforeLongBreak : 4

        Rectangle {
          required property int index
          readonly property int currentRound: timerService ? (timerService.completedSessions % (timerService.workSessionsBeforeLongBreak || 4)) : 0
          readonly property bool isDone: index < currentRound
          readonly property bool isCurrent: index === currentRound

          width: isCurrent ? Style.space(18) : Style.space(8)
          height: Style.space(8)
          radius: Style.space(4)
          color: isDone || (isCurrent && timerService && timerService.running) ? activeColor : Qt.rgba(foreground.r, foreground.g, foreground.b, 0.25)

          Behavior on width {
            NumberAnimation {
              duration: 150
              easing.type: Easing.OutCubic
            }
          }
          Behavior on color {
            ColorAnimation {
              duration: 150
            }
          }
        }
      }
    }
  }

  component CircularFace: Item {
    property var timerService: null
    property color foreground: Color.popups.text
    property color activeColor: Color.accent
    property string fontFamily: Style.font.family

    width: parent.width
    implicitHeight: Style.space(180)

    CircularProgress {
      anchors.centerIn: parent
      width: Math.min(parent.width, parent.height)
      height: width
      progress: timerService ? timerService.progress : 0
      trackColor: Color.muted
      fillColor: foreground
      strokeWidth: Math.max(5, Style.spaceReal(7))
    }

    Column {
      anchors.centerIn: parent
      spacing: Style.space(5)

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: timerService ? timerService.remainingText : "25:00"
        color: foreground
        font.family: fontFamily
        font.pixelSize: Math.round(Style.font.displayLarge * 1.7)
        font.bold: true
      }

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: timerService ? timerService.sessionLabel : "Work"
        color: activeColor
        font.family: fontFamily
        font.pixelSize: Style.font.title
      }
    }
  }
}
