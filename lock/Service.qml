import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam
import Quickshell.Wayland
import qs.Commons

Item {
  id: root

  property var shell: null
  property var settings: null
  property string omarchyPath: ""

  readonly property string home: Quickshell.env("HOME")
  readonly property string stateHome: home + "/.local/state"
  readonly property string userName: Quickshell.env("USER") || Quickshell.env("LOGNAME") || "User"
  readonly property string loginName: Quickshell.env("USER") || Quickshell.env("LOGNAME") || ""
  readonly property string currentBackgroundLink: stateHome + "/omarchy/current/background"
  readonly property string stateRoot: stateHome + "/omarchy"
  readonly property string shareRoot: "/usr/share/omarchy"
  readonly property string omarchyBin: "/usr/share/omarchy/bin/omarchy"
  readonly property string systemctlBin: "/usr/bin/systemctl"
  readonly property string sessionLockedBin: "/usr/share/omarchy/bin/omarchy-hyprland-session-locked"
  readonly property string wakeBin: "/usr/share/omarchy/bin/omarchy-system-wake"
  readonly property string brightKeyboardBin: "/usr/share/omarchy/bin/omarchy-brightness-keyboard"
  readonly property string brightDisplayBin: "/usr/share/omarchy/bin/omarchy-brightness-display"
  readonly property string fprintdListBin: "/usr/bin/fprintd-list"
  readonly property string fingerprintPamPath: "/etc/pam.d/omarchy-lock-fingerprint"
  readonly property string fixedPath: "/usr/local/sbin:/usr/local/bin:/usr/bin"
  property bool fingerprintPamFile: false
  property int maxHelperBytes: 4096
  property int helperTimeoutMs: 3000
  property int wakeTimeoutMs: 5000

  property string timeFormat: setting("timeFormat", "hh:mm AP")
  property string dateFormat: setting("dateFormat", "dddd, MMMM d")

  property bool lockRequested: false
  property bool pendingSessionLock: false
  property bool authenticatingPassword: false
  property bool fingerprintAuthenticating: false
  property bool passwordPamConfigured: false
  property bool fingerprintConfigured: false
  property bool previewVisible: false
  property string enteredPassword: ""
  property string pendingPassword: ""
  property string failureMessage: ""
  property int failedAttempts: 0
  property string backgroundPath: ""
  property int backgroundVersion: 0
  property string lastEvent: "init"
  property string lastEventAt: ""
  property bool strandedLock: false
  property bool strandedLockResolved: false

  readonly property bool locked: lockRequested || sessionLock.locked || sessionLock.secure
  readonly property bool authenticating: authenticatingPassword || fingerprintAuthenticating

  property var fileConfig: ({})
  function parseFileConfig(raw) {
    try {
      var parsed = JSON.parse(String(raw || ""));
      return parsed && typeof parsed === "object" && !Array.isArray(parsed) ? parsed : ({});
    } catch (e) {
      return ({});
    }
  }
  function setting(key, fallback) {
    var value = root.fileConfig ? root.fileConfig[key] : undefined;
    return value === undefined || value === null ? fallback : value;
  }
  FileView {
    id: configFile
    path: Quickshell.env("HOME") + "/.config/omarchy/lock.json"
    watchChanges: true
    printErrors: false
    onLoaded: root.fileConfig = root.parseFileConfig(text())
    onFileChanged: configFile.reload()
    onLoadFailed: root.fileConfig = ({})
  }

  function realScreenCount() {
    var screens = Quickshell.screens || [];
    var count = 0;
    for (var i = 0; i < screens.length; i++) {
      var screen = screens[i];
      if (screen && screen.name && screen.width > 0 && screen.height > 0)
        count += 1;
    }
    return count;
  }

  function hasRealScreen() {
    return realScreenCount() > 0;
  }

  function queueSessionLock() {
    pendingSessionLock = true;
    if (!sessionLockStabilizeTimer.running)
      logEvent("lock-pending: screen-stabilizing");
    sessionLockStabilizeTimer.restart();
    if (!pendingSessionLockTimer.running)
      pendingSessionLockTimer.start();
  }

  function requestSessionLock() {
    if (!lockRequested || sessionLock.locked || sessionLock.secure)
      return;
    if (sessionLockStabilizeTimer.running)
      return;
    if (!hasRealScreen()) {
      if (!pendingSessionLock || lastEvent !== "lock-pending: no-real-screen")
        logEvent("lock-pending: no-real-screen");
      pendingSessionLock = true;
      if (!pendingSessionLockTimer.running)
        pendingSessionLockTimer.start();
      return;
    }
    pendingSessionLock = false;
    pendingSessionLockTimer.stop();
    sessionLock.locked = true;
  }

  function checkStrandedLock() {
    if (strandedLockResolved || strandedLockCheckProc.running)
      return;
    if (locked || lockRequested) {
      strandedLockResolved = true;
      return;
    }
    strandedLockCheckProc.running = true;
    strandedWatchdog.restart();
  }

  function killProc(proc) {
    try {
      proc.signal(9);
    } catch (e) {
    }
    proc.running = false;
  }

  function acceptBackground(raw) {
    var line = String(raw || "").split("\n")[0].trim();
    if (line === "" || line.charAt(0) !== "/" || line.length > 4096)
      return "";
    if (line.indexOf(root.stateRoot + "/") !== 0 && line.indexOf(root.shareRoot + "/") !== 0)
      return "";
    return line;
  }

  function recoverStrandedLock() {
    if (!strandedLock || locked || !passwordPamConfigured)
      return;
    strandedLock = false;
    logEvent("lock-stranded: recovering");
    beginLock();
  }

  function refreshBackground() {
    if (backgroundProc.running)
      return;
    backgroundProc.collected = "";
    backgroundProc.collectedBytes = 0;
    backgroundProc.overflowed = false;
    backgroundProc.timedOut = false;
    backgroundProc.command = ["/usr/bin/env", "-i", "/usr/bin/sh", "-c", "p=$(/usr/bin/readlink -f \"$0\" 2>/dev/null); [ -n \"$p\" ] || exit 0; case \"$p\" in \"$1\"/*|\"$2\"/*) ;; *) exit 0;; esac; [ -f \"$p\" ] && [ ! -L \"$p\" ] || exit 0; [ \"$(/usr/bin/stat -c %s \"$p\")\" -le 67108864 ] || exit 0; printf '%s' \"$p\"", root.currentBackgroundLink, root.stateRoot, root.shareRoot];
    backgroundProc.running = true;
    backgroundWatchdog.restart();
  }

  function refreshFingerprintStatus() {
    if (!root.fingerprintPamFile || root.loginName === "" || fingerprintListProc.running) {
      if (!root.fingerprintPamFile || root.loginName === "")
        setFingerprintConfigured(false);
      return;
    }
    fingerprintListProc.collected = "";
    fingerprintListProc.collectedBytes = 0;
    fingerprintListProc.overflowed = false;
    fingerprintListProc.timedOut = false;
    fingerprintListProc.command = [root.fprintdListBin, root.loginName];
    fingerprintListProc.running = true;
    fingerprintWatchdog.restart();
  }

  function setFingerprintConfigured(on) {
    root.fingerprintConfigured = on === true;
    if (root.lockRequested && root.fingerprintConfigured)
      root.startFingerprint();
    else if (!root.fingerprintConfigured && fingerprintPam.active)
      fingerprintPam.abort();
  }

  function logEvent(event) {
    lastEvent = event;
    lastEventAt = new Date().toISOString();
    console.log("omarchy lock " + lastEventAt + " " + event);
  }

  function resetAuthenticationState() {
    enteredPassword = "";
    pendingPassword = "";
    failureMessage = "";
    failedAttempts = 0;
    authenticatingPassword = false;
    fingerprintAuthenticating = false;
    fingerprintRetryTimer.stop();
    if (passwordPam.active)
      passwordPam.abort();
    if (fingerprintPam.active)
      fingerprintPam.abort();
  }

  function beginLock() {
    if (!passwordPamConfigured) {
      logEvent("lock-denied: missing-pam");
      return false;
    }
    resetAuthenticationState();
    lockRequested = true;
    armBlankTimer();
    logEvent("lock-requested");
    queueSessionLock();
    Qt.callLater(function () {
        root.refreshBackground();
        root.refreshFingerprintStatus();
      });
    return true;
  }

  function finishUnlock() {
    if (!root.locked && !lockRequested)
      return;
    lockRequested = false;
    pendingSessionLock = false;
    sessionLockStabilizeTimer.stop();
    pendingSessionLockTimer.stop();
    resetAuthenticationState();
    idleBlankTimer.stop();
    sessionLock.locked = false;
    logEvent("unlocked");
    runWake();
  }

  function armBlankTimer() {
    idleBlankTimer.armedAt = Date.now();
    idleBlankTimer.restart();
  }

  function runWake() {
    if (!wakeProcess.running) {
      wakeProcess.running = true;
      wakeWatchdog.restart();
    }
    if (lockRequested)
      armBlankTimer();
  }

  function runBlank() {
    if (!blankKeyboardProc.running) {
      blankKeyboardProc.running = true;
      blankWatchdog.restart();
    }
    if (!blankDisplayProc.running) {
      blankDisplayProc.running = true;
      blankWatchdog.restart();
    }
  }

  function requestShutdown() {
    root.runPower([root.omarchyBin, "system", "shutdown"]);
  }

  function requestReboot() {
    root.runPower([root.omarchyBin, "system", "reboot"]);
  }

  function requestSuspend() {
    root.runPower([root.systemctlBin, "suspend"]);
  }

  function runPower(args) {
    if (powerProc.running)
      return;
    powerProc.command = args;
    powerProc.running = true;
    powerWatchdog.restart();
  }

  function submitPassword(value) {
    var password = String(value || "");
    if (!lockRequested || authenticatingPassword || password.length === 0)
      return;
    runWake();
    pendingPassword = password;
    failureMessage = "";
    authenticatingPassword = true;
    if (!passwordPam.start()) {
      handlePasswordFailure();
      return;
    }
    Qt.callLater(respondToPasswordPrompt);
  }

  function respondToPasswordPrompt() {
    if (!authenticatingPassword || !passwordPam.active || !passwordPam.responseRequired)
      return;
    passwordPam.respond(pendingPassword);
  }

  function handlePasswordFailure() {
    if (!lockRequested)
      return;
    authenticatingPassword = false;
    enteredPassword = "";
    pendingPassword = "";
    failedAttempts += 1;
    failureMessage = "Authentication failed (" + failedAttempts + ")";
    runWake();
  }

  function startFingerprint() {
    if (!lockRequested || !sessionLock.secure || !fingerprintConfigured)
      return;
    if (fingerprintPam.active || fingerprintAuthenticating)
      return;
    fingerprintAuthenticating = true;
    if (!fingerprintPam.start()) {
      fingerprintAuthenticating = false;
    }
  }

  function handleFingerprintFinished(result) {
    fingerprintAuthenticating = false;
    if (!lockRequested)
      return;
    if (result === PamResult.Success) {
      finishUnlock();
    } else if (fingerprintConfigured) {
      fingerprintRetryTimer.restart();
    }
  }

  WlSessionLock {
    id: sessionLock

    locked: false

    onSecureStateChanged: {
      root.logEvent("secure=" + secure);
      if (secure) {
        root.pendingSessionLock = false;
        sessionLockStabilizeTimer.stop();
        pendingSessionLockTimer.stop();
        root.startFingerprint();
      }
    }

    onLockStateChanged: {
      root.logEvent("session-locked=" + locked);
      if (locked) {
        root.pendingSessionLock = false;
        sessionLockStabilizeTimer.stop();
        pendingSessionLockTimer.stop();
      }
      if (!locked && root.lockRequested) {
        root.lockRequested = false;
        root.pendingSessionLock = false;
        sessionLockStabilizeTimer.stop();
        pendingSessionLockTimer.stop();
        root.resetAuthenticationState();
        root.runWake();
      }
    }

    WlSessionLockSurface {
      id: lockSurface
      color: Color.background

      LockView {
        id: lockView
        anchors.fill: parent
        backgroundPath: root.backgroundPath
        backgroundVersion: root.backgroundVersion
        fingerprintConfigured: root.fingerprintConfigured
        authenticatingPassword: root.authenticatingPassword
        failureMessage: root.failureMessage
        failedAttempts: root.failedAttempts
        inputEnabled: root.lockRequested
        loadBackground: root.locked
        passwordText: root.enteredPassword
        userName: root.userName
        timeFormat: root.timeFormat
        dateFormat: root.dateFormat
        onPasswordTextEdited: function (password) {
          root.enteredPassword = password;
        }
        onSubmitPassword: function (password) {
          root.submitPassword(password);
        }
        onClearFailureRequested: root.failureMessage = ""
        onWakeRequested: root.runWake()
        onSleepRequested: root.runBlank()
        onShutdownRequested: root.requestShutdown()
        onRebootRequested: root.requestReboot()
        onSuspendRequested: root.requestSuspend()
      }
    }
  }

  PanelWindow {
    id: previewWindow
    visible: root.previewVisible
    anchors {
      top: true
      bottom: true
      left: true
      right: true
    }
    color: "transparent"
    WlrLayershell.namespace: "omarchy-lock-preview"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore

    LockView {
      anchors.fill: parent
      backgroundPath: root.backgroundPath
      backgroundVersion: root.backgroundVersion
      fingerprintConfigured: root.fingerprintConfigured
      authenticatingPassword: false
      failureMessage: ""
      failedAttempts: 0
      inputEnabled: false
      loadBackground: root.previewVisible
      passwordText: ""
      userName: root.userName
      timeFormat: root.timeFormat
      dateFormat: root.dateFormat
      onWakeRequested: root.runWake()
      onSleepRequested: root.runBlank()
      onShutdownRequested: root.requestShutdown()
      onRebootRequested: root.requestReboot()
      onSuspendRequested: root.requestSuspend()
    }

    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.LeftButton | Qt.RightButton
      onClicked: root.previewVisible = false
    }
  }

  PamContext {
    id: passwordPam
    config: "omarchy-lock-password"
    user: root.userName

    onResponseRequiredChanged: root.respondToPasswordPrompt()
    onPamMessage: root.respondToPasswordPrompt()

    onCompleted: function (result) {
      root.authenticatingPassword = false;
      root.pendingPassword = "";
      if (!root.lockRequested)
        return;
      if (result === PamResult.Success)
        root.finishUnlock();
      else
        root.handlePasswordFailure();
    }

    onError: function (error) {
      root.handlePasswordFailure();
    }
  }

  PamContext {
    id: fingerprintPam
    config: "omarchy-lock-fingerprint"
    user: root.userName

    onCompleted: function (result) {
      root.handleFingerprintFinished(result);
    }

    onError: function (error) {
      root.fingerprintAuthenticating = false;
      if (root.lockRequested && root.fingerprintConfigured)
        fingerprintRetryTimer.restart();
    }
  }

  Timer {
    id: fingerprintRetryTimer
    interval: 250
    repeat: false
    onTriggered: root.startFingerprint()
  }

  Timer {
    id: backgroundWatchdog
    interval: root.helperTimeoutMs
    repeat: false
    onTriggered: {
      if (backgroundProc.running) {
        backgroundProc.timedOut = true;
        backgroundProc.collected = "";
        backgroundProc.collectedBytes = 0;
        root.killProc(backgroundProc);
      }
    }
  }

  Process {
    id: backgroundProc
    property string collected: ""
    property int collectedBytes: 0
    property bool overflowed: false
    property bool timedOut: false
    stdout: SplitParser {
      onRead: function (data) {
        if (backgroundProc.overflowed || backgroundProc.timedOut)
          return;
        var chunk = String(data + "\n");
        if (backgroundProc.collectedBytes + chunk.length > root.maxHelperBytes) {
          backgroundProc.overflowed = true;
          backgroundProc.collected = "";
          backgroundProc.collectedBytes = 0;
          root.killProc(backgroundProc);
          return;
        }
        backgroundProc.collected += chunk;
        backgroundProc.collectedBytes += chunk.length;
      }
    }
    stderr: SplitParser {
      onRead: function (data) {
        if (backgroundProc.overflowed || backgroundProc.timedOut)
          return;
        backgroundProc.collectedBytes += String(data + "\n").length;
        if (backgroundProc.collectedBytes > root.maxHelperBytes) {
          backgroundProc.overflowed = true;
          backgroundProc.collected = "";
          backgroundProc.collectedBytes = 0;
          root.killProc(backgroundProc);
        }
      }
    }
    onExited: function (exitCode) {
      backgroundWatchdog.stop();
      var failed = backgroundProc.overflowed || backgroundProc.timedOut;
      var output = String(backgroundProc.collected);
      backgroundProc.collected = "";
      backgroundProc.collectedBytes = 0;
      backgroundProc.overflowed = false;
      backgroundProc.timedOut = false;
      var next = (!failed && exitCode === 0) ? root.acceptBackground(output) : "";
      if (next !== "" && next !== root.backgroundPath) {
        root.backgroundPath = next;
        root.backgroundVersion += 1;
      } else if (next === "" && root.backgroundPath !== "") {
        root.backgroundPath = "";
        root.backgroundVersion += 1;
      }
    }
  }

  Timer {
    id: fingerprintWatchdog
    interval: root.helperTimeoutMs
    repeat: false
    onTriggered: {
      if (fingerprintListProc.running) {
        fingerprintListProc.timedOut = true;
        fingerprintListProc.collected = "";
        fingerprintListProc.collectedBytes = 0;
        root.killProc(fingerprintListProc);
        root.setFingerprintConfigured(false);
      }
    }
  }

  Process {
    id: fingerprintListProc
    clearEnvironment: true
    environment: ({
        "PATH": root.fixedPath
      })
    property string collected: ""
    property int collectedBytes: 0
    property bool overflowed: false
    property bool timedOut: false
    stdout: SplitParser {
      onRead: function (data) {
        if (fingerprintListProc.overflowed || fingerprintListProc.timedOut)
          return;
        var chunk = String(data + "\n");
        if (fingerprintListProc.collectedBytes + chunk.length > root.maxHelperBytes) {
          fingerprintListProc.overflowed = true;
          fingerprintListProc.collected = "";
          fingerprintListProc.collectedBytes = 0;
          root.killProc(fingerprintListProc);
          return;
        }
        fingerprintListProc.collected += chunk;
        fingerprintListProc.collectedBytes += chunk.length;
      }
    }
    stderr: SplitParser {
      onRead: function (data) {
        if (fingerprintListProc.overflowed || fingerprintListProc.timedOut)
          return;
        fingerprintListProc.collectedBytes += String(data + "\n").length;
        if (fingerprintListProc.collectedBytes > root.maxHelperBytes) {
          fingerprintListProc.overflowed = true;
          fingerprintListProc.collected = "";
          fingerprintListProc.collectedBytes = 0;
          root.killProc(fingerprintListProc);
        }
      }
    }
    onExited: function (exitCode) {
      fingerprintWatchdog.stop();
      var failed = fingerprintListProc.overflowed || fingerprintListProc.timedOut;
      var output = String(fingerprintListProc.collected);
      fingerprintListProc.collected = "";
      fingerprintListProc.collectedBytes = 0;
      fingerprintListProc.overflowed = false;
      fingerprintListProc.timedOut = false;
      var enrolled = !failed && exitCode === 0 && output.toLowerCase().indexOf("finger") !== -1;
      root.setFingerprintConfigured(root.fingerprintPamFile && enrolled);
    }
  }

  Timer {
    id: strandedWatchdog
    interval: root.helperTimeoutMs
    repeat: false
    onTriggered: {
      if (strandedLockCheckProc.running) {
        root.killProc(strandedLockCheckProc);
        root.strandedLockResolved = true;
      }
    }
  }

  Process {
    id: strandedLockCheckProc
    command: [root.sessionLockedBin]
    clearEnvironment: true
    environment: ({
        "PATH": root.fixedPath,
        "HYPRLAND_INSTANCE_SIGNATURE": null,
        "XDG_RUNTIME_DIR": null
      })
    stderr: SplitParser {
      onRead: function (data) {
        strandedLockCheckProc.collectedBytes += String(data + "\n").length;
        if (strandedLockCheckProc.collectedBytes > root.maxHelperBytes)
          root.killProc(strandedLockCheckProc);
      }
    }
    property int collectedBytes: 0
    onExited: function (exitCode) {
      strandedWatchdog.stop();
      strandedLockCheckProc.collectedBytes = 0;
      if (exitCode === 2)
        return;
      root.strandedLockResolved = true;
      root.strandedLock = exitCode === 0 && !root.locked && !root.lockRequested;
      root.recoverStrandedLock();
    }
  }

  Timer {
    id: wakeWatchdog
    interval: root.wakeTimeoutMs
    repeat: false
    onTriggered: {
      if (wakeProcess.running)
        root.killProc(wakeProcess);
    }
  }

  Process {
    id: wakeProcess
    command: [root.wakeBin]
    clearEnvironment: true
    environment: ({
        "PATH": root.fixedPath,
        "HYPRLAND_INSTANCE_SIGNATURE": null,
        "XDG_RUNTIME_DIR": null
      })
    stderr: SplitParser {
      onRead: function (data) {
        wakeProcess.collectedBytes += String(data + "\n").length;
        if (wakeProcess.collectedBytes > root.maxHelperBytes)
          root.killProc(wakeProcess);
      }
    }
    property int collectedBytes: 0
    onExited: {
      wakeWatchdog.stop();
      wakeProcess.collectedBytes = 0;
    }
  }

  Timer {
    id: blankWatchdog
    interval: root.wakeTimeoutMs
    repeat: false
    onTriggered: {
      if (blankKeyboardProc.running)
        root.killProc(blankKeyboardProc);
      if (blankDisplayProc.running)
        root.killProc(blankDisplayProc);
    }
  }

  Process {
    id: blankKeyboardProc
    command: [root.brightKeyboardBin, "off"]
    clearEnvironment: true
    environment: ({
        "PATH": root.fixedPath,
        "HYPRLAND_INSTANCE_SIGNATURE": null,
        "XDG_RUNTIME_DIR": null
      })
    stderr: SplitParser {
      onRead: function (data) {
        blankKeyboardProc.collectedBytes += String(data + "\n").length;
        if (blankKeyboardProc.collectedBytes > root.maxHelperBytes)
          root.killProc(blankKeyboardProc);
      }
    }
    property int collectedBytes: 0
    onExited: {
      blankKeyboardProc.collectedBytes = 0;
      if (!blankKeyboardProc.running && !blankDisplayProc.running)
        blankWatchdog.stop();
    }
  }

  Process {
    id: blankDisplayProc
    command: [root.brightDisplayBin, "off"]
    clearEnvironment: true
    environment: ({
        "PATH": root.fixedPath,
        "HYPRLAND_INSTANCE_SIGNATURE": null,
        "XDG_RUNTIME_DIR": null
      })
    stderr: SplitParser {
      onRead: function (data) {
        blankDisplayProc.collectedBytes += String(data + "\n").length;
        if (blankDisplayProc.collectedBytes > root.maxHelperBytes)
          root.killProc(blankDisplayProc);
      }
    }
    property int collectedBytes: 0
    onExited: {
      blankDisplayProc.collectedBytes = 0;
      if (!blankKeyboardProc.running && !blankDisplayProc.running)
        blankWatchdog.stop();
    }
  }

  Timer {
    id: powerWatchdog
    interval: 30000
    repeat: false
    onTriggered: {
      if (powerProc.running)
        root.killProc(powerProc);
    }
  }

  Process {
    id: powerProc
    clearEnvironment: true
    environment: ({
        "PATH": root.fixedPath
      })
    stderr: SplitParser {
      onRead: function (data) {
        powerProc.collectedBytes += String(data + "\n").length;
        if (powerProc.collectedBytes > root.maxHelperBytes)
          root.killProc(powerProc);
      }
    }
    property int collectedBytes: 0
    onExited: {
      powerWatchdog.stop();
      powerProc.collectedBytes = 0;
    }
  }

  Timer {
    id: idleBlankTimer
    interval: 5000
    repeat: false
    property double armedAt: 0
    onTriggered: {
      if (Date.now() - armedAt > interval + 2000) {
        root.armBlankTimer();
        return;
      }
      if (root.lockRequested && !root.authenticatingPassword)
        root.runBlank();
    }
  }

  Timer {
    id: sessionLockStabilizeTimer
    interval: 500
    repeat: false
    onTriggered: root.requestSessionLock()
  }

  Timer {
    id: pendingSessionLockTimer
    interval: 100
    repeat: true
    onTriggered: root.requestSessionLock()
  }

  Timer {
    id: strandedLockRetryTimer
    interval: 500
    repeat: true
    readonly property int budget: 20
    property int remaining: 20
    running: !root.strandedLockResolved && remaining > 0

    function rearm() {
      if (!root.strandedLockResolved)
        remaining = budget;
    }

    onTriggered: {
      remaining -= 1;
      root.checkStrandedLock();
    }
  }

  Connections {
    target: Quickshell
    function onScreensChanged() {
      root.requestSessionLock();
      strandedLockRetryTimer.rearm();
      root.checkStrandedLock();
    }
  }

  onAuthenticatingPasswordChanged: {
    if (!lockRequested)
      return;
    if (authenticatingPassword)
      idleBlankTimer.stop();
    else
      armBlankTimer();
  }

  FileView {
    path: "/etc/pam.d/omarchy-lock-password"
    watchChanges: true
    printErrors: false
    onLoaded: root.passwordPamConfigured = true
    onLoadFailed: root.passwordPamConfigured = false
    onFileChanged: reload()
  }

  FileView {
    path: root.fingerprintPamPath
    watchChanges: true
    printErrors: false
    onLoaded: {
      root.fingerprintPamFile = true;
      root.refreshFingerprintStatus();
    }
    onLoadFailed: {
      root.fingerprintPamFile = false;
      root.setFingerprintConfigured(false);
    }
    onFileChanged: reload()
  }

  onPasswordPamConfiguredChanged: {
    if (!passwordPamConfigured)
      return;
    strandedLock = false;
    strandedLockResolved = false;
    strandedLockRetryTimer.rearm();
    checkStrandedLock();
  }

  Component.onCompleted: {
    refreshBackground();
    refreshFingerprintStatus();
    checkStrandedLock();
  }

  IpcHandler {
    target: "lock"

    function lock(): string {
      if (!root.passwordPamConfigured)
        return "missing-pam";
      if (!root.locked && !root.beginLock())
        return "failed";
      return "ok";
    }

    function isLocked(): string {
      return root.locked ? "true" : "false";
    }

    function status(): string {
      return JSON.stringify({
          "locked": root.locked,
          "requested": root.lockRequested,
          "pending": root.pendingSessionLock,
          "sessionLocked": sessionLock.locked,
          "secure": sessionLock.secure,
          "realScreens": root.realScreenCount(),
          "passwordPam": root.passwordPamConfigured,
          "fingerprint": root.fingerprintConfigured,
          "authenticating": root.authenticating,
          "lastEvent": root.lastEvent,
          "lastEventAt": root.lastEventAt
        });
    }

    function preview(): string {
      root.refreshBackground();
      root.refreshFingerprintStatus();
      root.previewVisible = true;
      return "ok";
    }

    function hidePreview(): string {
      root.previewVisible = false;
      return "ok";
    }
  }
}
