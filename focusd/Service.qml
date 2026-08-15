import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root

  property var shell: null
  property var manifest: null

  property string status: "stopped"
  property string phase: "work"
  property string phaseLabel: "Work"
  property string remainingText: "25:00"
  property real progress: 0
  property string tooltipText: ""

  readonly property bool stopped: status === "stopped"
  readonly property bool running: status === "running"
  readonly property bool paused: status === "paused"

  function configure(settings) {
    // Focusd keeps its own durations and presets; nothing to configure here.
  }

  function playOrStop() {
    if (running) Quickshell.execDetached(["focusd", "reset"])
    else Quickshell.execDetached(["focusd", "start"])
  }

  function togglePause() {
    if (stopped) return
    Quickshell.execDetached(["focusd", "toggle"])
  }

  function skip() {
    if (stopped) return
    Quickshell.execDetached(["focusd", "next"])
  }

  function poll() {
    stateProc.running = false
    stateProc.collected = ""
    stateProc.command = ["focusd", "state"]
    stateProc.running = true
  }

  function parseState(raw) {
    var text = String(raw || "").trim()
    if (!text) {
      status = "stopped"
      return
    }
    var state = {}
    try {
      state = JSON.parse(text)
    } catch (error) {
      console.warn("Focusd: ignoring invalid state:", error)
      status = "stopped"
      return
    }

    var classes = state.class || []
    var alt = String(state.alt || "work")

    root.paused = classes.indexOf("paused") !== -1
    root.running = !root.paused
    root.status = root.running ? "running" : "paused"

    var phaseKey = alt.replace(/-paused$/, "")
    root.phase = phaseKey
    root.phaseLabel = phaseLabelFor(phaseKey)
    root.remainingText = String(state.text || "")
    root.progress = Math.max(0, Math.min(1, (Number(state.percentage) || 0) / 100))
    root.tooltipText = String(state.tooltip || "")
  }

  function phaseLabelFor(key) {
    if (key === "short-break") return "Short Break"
    if (key === "long-break") return "Long Break"
    return "Work"
  }

  Timer {
    interval: 1000
    repeat: true
    running: true
    onTriggered: root.poll()
  }

  Process {
    id: stateProc
    property string collected: ""
    stdout: SplitParser {
      onRead: function(data) { stateProc.collected += data + "\n" }
    }
    onExited: function(exitCode) {
      if (exitCode === 0 && String(stateProc.collected).trim() !== "") {
        root.parseState(stateProc.collected)
      } else {
        root.status = "stopped"
      }
    }
  }

  Component.onCompleted: root.poll()
}
