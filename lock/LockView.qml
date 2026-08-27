import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Services.Mpris
import qs.Commons
import qs.Ui

Item {
  id: root

  property string backgroundPath: ""
  property int backgroundVersion: 0
  property bool fingerprintConfigured: false
  property bool authenticatingPassword: false
  property string failureMessage: ""
  property string forgotPasswordMessage: ""
  property int failedAttempts: 0
  property bool inputEnabled: true
  property bool loadBackground: true
  property string passwordText: ""
  property bool syncingPasswordText: false
  property string userName: Quickshell.env("USER") || Quickshell.env("LOGNAME") || "User"
  property string timeFormat: "hh:mm AP"
  property string dateFormat: "dddd, MMMM d"
  property int focusIndex: 0
  property bool mediaPopupVisible: false

  readonly property string placeholderText: "Enter Password"
  readonly property int fieldWidth: 381
  readonly property int fieldHeight: 67
  readonly property int outlineThickness: 3
  readonly property int fieldFontSize: Math.round(Style.font.heading * 1.125)
  readonly property int passwordDotFontSize: Math.round(Style.font.heading * 1.33)
  readonly property int passwordDotLetterSpacing: Math.round(Style.font.heading * 0.19)
  readonly property real fingerprintReserve: fingerprintConfigured ? Math.round(fingerprintIcon.implicitWidth + 12) : 0
  readonly property real passwordDotScale: dotMetrics.advanceWidth > 0 ? Math.min(1, (passwordInput.width - 4) / dotMetrics.advanceWidth) : 1
  readonly property bool showPasswordCursor: inputEnabled && !authenticatingPassword && failureMessage.length === 0
  readonly property bool errorState: failureMessage.length > 0
  readonly property var inputBorderSpec: errorState ? Border.surfaceSpec("lock", "border-error", Color.lock.borderError, root.outlineThickness, "border-alpha") : (passwordInput.activeFocus ? Border.surfaceSpec("lock", "border-active", Color.lock.borderActive, root.outlineThickness, "border-alpha") : Border.surfaceSpec("lock", "border", Color.lock.border, 1, "border-alpha"))

  readonly property var mprisPlayers: Mpris.players ? Mpris.players.values : []
  readonly property var activeMprisPlayer: {
    if (!mprisPlayers)
      return null;
    for (var i = 0; i < mprisPlayers.length; i++) {
      var p = mprisPlayers[i];
      if (p && p.isPlaying && (p.trackTitle || p.trackArtist))
        return p;
    }
    for (var j = 0; j < mprisPlayers.length; j++) {
      var p2 = mprisPlayers[j];
      if (p2 && (p2.trackTitle || p2.trackArtist))
        return p2;
    }
    return null;
  }
  readonly property bool hasMedia: activeMprisPlayer !== null && (activeMprisPlayer.trackTitle || activeMprisPlayer.trackArtist)
  readonly property string mediaTitle: activeMprisPlayer ? (activeMprisPlayer.trackTitle || "") : ""
  readonly property string mediaArtist: activeMprisPlayer ? (activeMprisPlayer.trackArtist || "") : ""
  readonly property string mediaArtUrl: activeMprisPlayer ? (activeMprisPlayer.trackArtUrl || "") : ""
  readonly property bool isMediaPlaying: activeMprisPlayer ? activeMprisPlayer.isPlaying : false

  property string currentTimeString: ""
  property string currentDateString: ""

  signal submitPassword(string password)
  signal passwordTextEdited(string password)
  signal clearFailureRequested
  signal wakeRequested
  signal sleepRequested
  signal shutdownRequested
  signal rebootRequested
  signal suspendRequested
  signal forgotPasswordTriggered

  function activeIndices() {
    var list = [0, 1];
    if (hasMedia) {
      list.push(2);
      if (mediaPopupVisible) {
        list.push(3, 4, 5);
      }
    }
    list.push(6, 7, 8);
    return list;
  }

  function moveFocus(delta) {
    var list = activeIndices();
    var currentPos = list.indexOf(focusIndex);
    if (currentPos === -1)
      currentPos = 0;
    var nextPos = (currentPos + delta + list.length) % list.length;
    focusIndex = list[nextPos];
    if (focusIndex === 0) {
      forcePasswordFocus();
    }
  }

  function activateFocused() {
    if (focusIndex === 0) {
      var submitted = root.passwordText;
      root.passwordTextEdited("");
      if (submitted.length > 0)
        root.submitPassword(submitted);
    } else if (focusIndex === 1) {
      handleForgotPassword();
    } else if (focusIndex === 2) {
      root.mediaPopupVisible = !root.mediaPopupVisible;
    } else if (focusIndex === 3) {
      if (root.activeMprisPlayer && root.activeMprisPlayer.canGoPrevious)
        root.activeMprisPlayer.previous();
      root.wakeRequested();
    } else if (focusIndex === 4) {
      if (!root.activeMprisPlayer)
        return;
      if (root.activeMprisPlayer.isPlaying && root.activeMprisPlayer.canPause)
        root.activeMprisPlayer.pause();
      else if (!root.activeMprisPlayer.isPlaying && root.activeMprisPlayer.canPlay)
        root.activeMprisPlayer.play();
      else if (root.activeMprisPlayer.canTogglePlaying)
        root.activeMprisPlayer.togglePlaying();
      root.wakeRequested();
    } else if (focusIndex === 5) {
      if (root.activeMprisPlayer && root.activeMprisPlayer.canGoNext)
        root.activeMprisPlayer.next();
      root.wakeRequested();
    } else if (focusIndex === 6) {
      root.suspendRequested();
    } else if (focusIndex === 7) {
      root.shutdownRequested();
    } else if (focusIndex === 8) {
      root.rebootRequested();
    }
  }

  function fileUrl(path) {
    if (!path)
      return "";
    var encoded = String(path).split("/").map(encodeURIComponent).join("/");
    return "file://" + encoded + "?v=" + backgroundVersion;
  }

  function forcePasswordFocus() {
    passwordInput.forceActiveFocus();
  }

  function clearPassword() {
    passwordTextEdited("");
  }

  function syncPasswordText() {
    if (passwordInput.text === passwordText)
      return;
    syncingPasswordText = true;
    passwordInput.text = passwordText;
    syncingPasswordText = false;
  }

  function handleForgotPassword() {
    root.wakeRequested();
    root.passwordTextEdited("");
    var nameStr = root.userName ? root.userName : "User";
    var capName = nameStr.charAt(0).toUpperCase() + nameStr.slice(1);
    root.forgotPasswordMessage = capName + " never forgots his password. You are not him, Locking down";
    forgotPasswordTriggered();
    forgotPasswordSleepTimer.restart();
  }

  onPasswordTextChanged: syncPasswordText()
  onMediaPopupVisibleChanged: {
    if (!mediaPopupVisible && focusIndex >= 3 && focusIndex <= 5)
      focusIndex = 2;
  }
  onFocusIndexChanged: {
    if (mediaPopupVisible && focusIndex !== 2 && (focusIndex < 3 || focusIndex > 5))
      mediaPopupVisible = false;
  }
  onInputEnabledChanged: {
    if (inputEnabled)
      Qt.callLater(forcePasswordFocus);
  }
  Component.onCompleted: {
    syncPasswordText();
    if (inputEnabled)
      Qt.callLater(forcePasswordFocus);
  }

  Timer {
    id: dateTimeTimer
    interval: 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: {
      var now = new Date();
      currentTimeString = Qt.formatDateTime(now, root.timeFormat);
      currentDateString = Qt.formatDateTime(now, root.dateFormat);
    }
  }

  Timer {
    id: forgotPasswordSleepTimer
    interval: 3500
    repeat: false
    onTriggered: {
      root.sleepRequested();
    }
  }

  TextMetrics {
    id: dotMetrics
    font.family: Style.font.family
    font.pixelSize: root.passwordDotFontSize
    font.letterSpacing: root.passwordDotLetterSpacing
    text: "●".repeat(passwordInput.text.length)
  }

  Rectangle {
    anchors.fill: parent
    color: Color.background
    focus: true

    Keys.onPressed: function (event) {
      root.wakeRequested();
      if (event.key === Qt.Key_Tab || event.key === Qt.Key_Down) {
        root.moveFocus(1);
        event.accepted = true;
      } else if (event.key === Qt.Key_Backtab || event.key === Qt.Key_Up) {
        root.moveFocus(-1);
        event.accepted = true;
      } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
        root.activateFocused();
        event.accepted = true;
      } else if (event.key === Qt.Key_Escape) {
        if (root.mediaPopupVisible) {
          root.mediaPopupVisible = false;
        } else {
          root.focusIndex = 0;
          root.forcePasswordFocus();
        }
        event.accepted = true;
      } else if (event.text.length > 0) {
        root.focusIndex = 0;
        root.forcePasswordFocus();
      }
    }

    Image {
      id: wallpaper
      anchors.fill: parent
      source: root.loadBackground ? root.fileUrl(root.backgroundPath) : ""
      fillMode: Image.PreserveAspectCrop
      asynchronous: true
      cache: false
      sourceSize.width: width
      sourceSize.height: height
    }

    MultiEffect {
      anchors.fill: wallpaper
      source: wallpaper
      autoPaddingEnabled: false
      blurEnabled: root.loadBackground && wallpaper.status === Image.Ready
      blur: 1.0
      blurMax: 128
      blurMultiplier: 1.6
      contrast: -0.10
    }

    Rectangle {
      anchors.fill: parent
      color: Qt.rgba(0, 0, 0, 0.35)
    }

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      onClicked: {
        root.wakeRequested();
        root.mediaPopupVisible = false;
        root.forcePasswordFocus();
      }
      onPositionChanged: root.wakeRequested()
    }

    Text {
      id: forgotPasswordMsgText
      visible: root.forgotPasswordMessage.length > 0
      anchors.top: parent.top
      anchors.topMargin: 80
      anchors.horizontalCenter: parent.horizontalCenter
      width: Math.min(root.width - 80, 720)
      text: root.forgotPasswordMessage
      color: Color.lock.textError
      font.family: Style.font.family
      font.pixelSize: Math.round(Style.font.heading * 1.6)
      font.bold: true
      horizontalAlignment: Text.AlignHCenter
      wrapMode: Text.WordWrap
    }

    Button {
      id: mediaCornerBtn
      iconText: "󰝚"
      text: root.mediaTitle
      visible: root.hasMedia
      bordered: true
      background: Color.lock.background
      foreground: Color.lock.text
      horizontalPadding: 14
      verticalPadding: 8
      anchors.bottom: parent.bottom
      anchors.bottomMargin: 40
      anchors.left: parent.left
      anchors.leftMargin: 40
      hasCursor: root.focusIndex === 2
      onClicked: {
        root.wakeRequested();
        root.mediaPopupVisible = !root.mediaPopupVisible;
      }
    }

    BorderSurface {
      id: mediaPopupCard
      visible: root.mediaPopupVisible && root.hasMedia
      width: 320
      height: mediaPopupContent.height + topPadding + bottomPadding + borderTop + borderBottom
      z: 100
      x: mediaCornerBtn.x
      y: mediaCornerBtn.y - height - 16
      color: Color.popups.background
      borderSpec: Border.surfaceSpec("popups", "border", Color.popups.border, 1, "border-alpha")
      radius: Style.cornerRadius
      topPadding: 10
      bottomPadding: 10
      leftPadding: 12
      rightPadding: 12

      Row {
        id: mediaPopupContent
        x: parent.borderLeft + parent.leftPadding
        y: parent.borderTop + parent.topPadding
        width: parent.width - parent.leftPadding - parent.rightPadding - parent.borderLeft - parent.borderRight
        spacing: 12

        BorderSurface {
          width: 72
          height: 72
          radius: Style.cornerRadius
          color: Qt.rgba(0, 0, 0, 0.3)
          anchors.verticalCenter: parent.verticalCenter

          Image {
            id: artImage
            anchors.fill: parent
            anchors.margins: 2
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            source: root.mediaArtUrl
            visible: source !== "" && status === Image.Ready
          }

          Text {
            anchors.centerIn: parent
            visible: !artImage.visible
            text: "󰝚"
            color: Color.popups.text
            font.family: Style.font.family
            font.pixelSize: Math.round(Style.font.heading * 1.1)
          }
        }

        Column {
          width: parent.width - 84
          anchors.verticalCenter: parent.verticalCenter
          spacing: 4

          Text {
            width: parent.width
            text: root.mediaTitle
            color: Color.popups.text
            font.family: Style.font.family
            font.pixelSize: Style.font.body
            font.bold: true
            elide: Text.ElideRight
          }

          Text {
            width: parent.width
            text: root.mediaArtist
            visible: root.mediaArtist.length > 0
            color: Color.popups.text
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
            elide: Text.ElideRight
          }

          Row {
            spacing: 8

            Button {
              id: mediaPrevBtn
              implicitWidth: 36
              implicitHeight: 36
              iconSize: Style.font.iconLarge
              background: "transparent"
              foreground: Color.popups.text
              horizontalPadding: 0
              verticalPadding: 0
              hasCursor: root.focusIndex === 3
              iconText: ""
              onClicked: {
                root.wakeRequested();
                if (root.activeMprisPlayer && root.activeMprisPlayer.canGoPrevious)
                  root.activeMprisPlayer.previous();
              }
            }

            Button {
              id: mediaPlayPauseBtn
              implicitWidth: 36
              implicitHeight: 36
              iconSize: Style.font.iconLarge
              background: "transparent"
              foreground: Color.popups.text
              horizontalPadding: 0
              verticalPadding: 0
              hasCursor: root.focusIndex === 4
              iconText: root.isMediaPlaying ? "󰏤" : "󰐊"
              onClicked: {
                root.wakeRequested();
                if (!root.activeMprisPlayer)
                  return;
                if (root.activeMprisPlayer.isPlaying && root.activeMprisPlayer.canPause)
                  root.activeMprisPlayer.pause();
                else if (!root.activeMprisPlayer.isPlaying && root.activeMprisPlayer.canPlay)
                  root.activeMprisPlayer.play();
                else if (root.activeMprisPlayer.canTogglePlaying)
                  root.activeMprisPlayer.togglePlaying();
              }
            }

            Button {
              id: mediaNextBtn
              implicitWidth: 36
              implicitHeight: 36
              iconSize: Style.font.iconLarge
              background: "transparent"
              foreground: Color.popups.text
              horizontalPadding: 0
              verticalPadding: 0
              hasCursor: root.focusIndex === 5
              iconText: ""
              onClicked: {
                root.wakeRequested();
                if (root.activeMprisPlayer && root.activeMprisPlayer.canGoNext)
                  root.activeMprisPlayer.next();
              }
            }
          }
        }
      }
    }

    Column {
      id: timeDateColumn
      anchors.bottom: inputField.top
      anchors.bottomMargin: 48
      anchors.horizontalCenter: parent.horizontalCenter
      spacing: 6

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: root.currentTimeString
        color: Color.lock.text
        font.family: Style.font.family
        font.pixelSize: Math.round(Style.font.heading * 3.2)
        font.weight: Font.Bold
        horizontalAlignment: Text.AlignHCenter
      }

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: root.currentDateString
        color: Color.lock.placeholder
        font.family: Style.font.family
        font.pixelSize: Math.round(Style.font.heading * 1.25)
        horizontalAlignment: Text.AlignHCenter
      }
    }

    BorderSurface {
      id: inputField
      width: root.fieldWidth
      height: root.fieldHeight
      anchors.centerIn: parent
      color: Color.lock.background
      borderSpec: root.inputBorderSpec
      radius: Style.cornerRadius
      clip: true

      TextInput {
        id: passwordInput
        anchors.fill: parent
        anchors.topMargin: inputField.borderTop
        anchors.rightMargin: inputField.borderRight + 18 + root.fingerprintReserve
        anchors.bottomMargin: inputField.borderBottom
        anchors.leftMargin: inputField.borderLeft + 18 + root.fingerprintReserve
        verticalAlignment: TextInput.AlignVCenter
        horizontalAlignment: TextInput.AlignHCenter
        activeFocusOnPress: true
        clip: true
        enabled: root.inputEnabled && !root.authenticatingPassword
        readOnly: root.authenticatingPassword
        echoMode: TextInput.Password
        passwordCharacter: "\u25CF"
        passwordMaskDelay: 0
        color: Color.lock.text
        selectionColor: Color.lock.selection
        selectedTextColor: Color.lock.text
        font.family: Style.font.family
        font.pixelSize: text.length > 0 ? Math.max(1, Math.floor(root.passwordDotFontSize * root.passwordDotScale)) : root.fieldFontSize
        font.letterSpacing: text.length > 0 ? root.passwordDotLetterSpacing * root.passwordDotScale : 0
        cursorVisible: activeFocus && root.showPasswordCursor && text.length > 0
        cursorDelegate: Rectangle {
          width: 2
          color: Color.lock.text
          visible: passwordInput.cursorVisible
        }

        onTextChanged: {
          if (!root.syncingPasswordText)
            root.passwordTextEdited(text);
          if (text.length > 0) {
            root.wakeRequested();
            root.focusIndex = 0;
          }
          if (text.length > 0 && root.failureMessage.length > 0)
            root.clearFailureRequested();
          if (text.length > 0 && root.forgotPasswordMessage.length > 0)
            root.forgotPasswordMessage = "";
        }

        onAccepted: {
          var submitted = root.passwordText;
          root.passwordTextEdited("");
          if (submitted.length > 0)
            root.submitPassword(submitted);
        }

        Keys.onPressed: function (event) {
          root.wakeRequested();
          if (event.key === Qt.Key_Tab || event.key === Qt.Key_Down) {
            root.moveFocus(1);
            event.accepted = true;
          } else if (event.key === Qt.Key_Backtab || event.key === Qt.Key_Up) {
            root.moveFocus(-1);
            event.accepted = true;
          } else if (event.key === Qt.Key_Escape) {
            if (root.mediaPopupVisible) {
              root.mediaPopupVisible = false;
            } else {
              root.passwordTextEdited("");
            }
            event.accepted = true;
          } else if (event.modifiers & Qt.ControlModifier && event.key === Qt.Key_U) {
            root.passwordTextEdited("");
            event.accepted = true;
          }
        }
      }

      Text {
        anchors.fill: passwordInput
        text: root.authenticatingPassword ? "Checking…" : (root.failureMessage.length > 0 ? root.failureMessage : root.placeholderText)
        visible: passwordInput.text.length === 0
        color: root.authenticatingPassword ? Color.lock.text : (root.failureMessage.length > 0 ? Color.lock.textError : Color.lock.placeholder)
        font.family: Style.font.family
        font.pixelSize: root.fieldFontSize
        font.italic: !root.authenticatingPassword && root.failureMessage.length > 0
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
      }

      Text {
        id: fingerprintIcon
        objectName: "fingerprintIndicator"
        anchors.right: parent.right
        anchors.rightMargin: inputField.borderRight + 18
        anchors.verticalCenter: parent.verticalCenter
        visible: root.fingerprintConfigured
        text: "󰈷"
        color: Color.lock.placeholder
        font.family: Style.font.family
        font.pixelSize: Math.round(root.fieldFontSize * 1.1)
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
      }
    }

    Button {
      id: forgotPasswordBtn
      anchors.top: inputField.bottom
      anchors.topMargin: 16
      anchors.horizontalCenter: parent.horizontalCenter
      text: "Forgot password"
      fontSize: Style.font.bodySmall
      foreground: Color.lock.placeholder
      background: "transparent"
      horizontalPadding: 12
      verticalPadding: 6
      hasCursor: root.focusIndex === 1
      onClicked: root.handleForgotPassword()
    }

    Row {
      id: powerControls
      anchors.bottom: parent.bottom
      anchors.bottomMargin: 40
      anchors.horizontalCenter: parent.horizontalCenter
      spacing: 16

      Button {
        id: sleepButton
        text: "Sleep"
        iconText: "󰤄"
        bordered: true
        horizontalPadding: 20
        verticalPadding: 10
        hasCursor: root.focusIndex === 6
        onClicked: root.suspendRequested()
      }

      Button {
        id: shutdownButton
        text: "Shutdown"
        iconText: "󰐥"
        bordered: true
        horizontalPadding: 20
        verticalPadding: 10
        hasCursor: root.focusIndex === 7
        onClicked: root.shutdownRequested()
      }

      Button {
        id: restartButton
        text: "Restart"
        iconText: "󰜉"
        bordered: true
        horizontalPadding: 20
        verticalPadding: 10
        hasCursor: root.focusIndex === 8
        onClicked: root.rebootRequested()
      }
    }
  }
}
