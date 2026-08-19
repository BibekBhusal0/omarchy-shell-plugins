import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root

  property var shell: null
  property var manifest: null

  property bool installed: false
  property bool checkingInstallation: true
  property bool installing: false
  property string clipboardUrl: ""
  property string lastDetectedUrl: ""

  property var downloads: []
  readonly property int downloadCount: downloads.length
  readonly property int activeCount: {
    var n = 0
    for (var i = 0; i < downloads.length; i++) {
      if (downloads[i].status === "downloading" || downloads[i].status === "merging")
        n++
    }
    return n
  }

  property var history: []
  readonly property int historyCount: history.length

  property string downloadLocation: "~/Downloads/yt-dlp"
  property string defaultQuality: "best"
  property string cookiesBrowser: "none"
  property string extraArgs: ""

  signal downloadsUpdated()
  signal historyUpdated()

  readonly property string scriptPath: Qt.resolvedUrl("ytdl").toString().replace(/^file:\/\//, "")

  function configure(settings) {
    if (!settings) return
    if (settings.downloadLocation)
      downloadLocation = settings.downloadLocation
    if (settings.defaultQuality)
      defaultQuality = settings.defaultQuality
    if (settings.cookiesBrowser)
      cookiesBrowser = settings.cookiesBrowser
    if (settings.extraArgs != null)
      extraArgs = settings.extraArgs
  }

  function cleanUrl(url) {
    url = String(url || "").trim()
    url = url.replace(/^yt-dlp:/, "").replace(/^ytdl:/, "")
    return url
  }

  function extractVideoId(url) {
    var m = url.match(/(?:v=|youtu\.be\/|shorts\/)([\w-]{11})/)
    return m ? m[1] : null
  }

  function isYouTubeUrl(text) {
    return /(?:https?:\/\/)?(?:www\.)?(?:youtube\.com\/(?:watch\?v=|shorts\/)|youtu\.be\/)[\w-]+/.test(text)
  }

  function setItem(arr, idx, val) {
    var copy = arr.slice()
    copy[idx] = val
    return copy
  }

  function cloneDownload(d) {
    return {
      id: d.id, url: d.url, title: d.title, status: d.status,
      progress: d.progress, speed: d.speed, eta: d.eta,
      filepath: d.filepath, error: d.error
    }
  }

  function updateDownload(id, props) {
    for (var i = 0; i < downloads.length; i++) {
      if (downloads[i].id === id) {
        var d = cloneDownload(downloads[i])
        d._procIdx = downloads[i]._procIdx
        for (var k in props) d[k] = props[k]
        downloads = setItem(downloads, i, d)
        downloadsUpdated()
        return
      }
    }
  }

  function procAt(i) {
    if (i === 0) return dlProc0
    if (i === 1) return dlProc1
    return dlProc2
  }

  function findFreeProc() {
    for (var i = 0; i < 3; i++) {
      if (!procAt(i).running) return i
    }
    return -1
  }

  function startDownload(url, quality) {
    url = cleanUrl(url)
    if (!url) return

    for (var i = 0; i < downloads.length; i++) {
      if (downloads[i].url === url && (downloads[i].status === "downloading" || downloads[i].status === "merging"))
        return
    }

    var procIdx = findFreeProc()
    if (procIdx === -1) {
      return
    }

    var id = Date.now() + Math.floor(Math.random() * 1000)
    var q = quality || defaultQuality
    var outputTemplate = downloadLocation + "/%(title)s.%(ext)s"
    var cmd = [scriptPath, "download", url, q, outputTemplate, cookiesBrowser, extraArgs]

    var download = {
      id: id, url: url, title: extractVideoId(url) || url,
      status: "downloading", progress: 0, speed: "", eta: "",
      filepath: "", error: "", _procIdx: procIdx
    }

    downloads = downloads.concat([download])
    downloadsUpdated()

    var proc = procAt(procIdx)
    proc.downloadId = id
    proc.command = cmd
    proc.running = true

    titleProc.targetId = id
    titleProc.command = [scriptPath, "title", url, cookiesBrowser, extraArgs]
    titleProc.running = true
  }

  function retryDownload(item) {
    if (!item || !item.url) return
    removeHistoryItem(item.id)
    startDownload(item.url, defaultQuality)
  }

  function cancelDownload(id) {
    for (var i = 0; i < downloads.length; i++) {
      if (downloads[i].id === id) {
        var d = downloads[i]
        if (d._procIdx != null && d._procIdx >= 0) {
          procAt(d._procIdx).kill()
        }
        var updated = cloneDownload(d)
        updated.status = "cancelled"
        updated._procIdx = -1
        downloads = setItem(downloads, i, updated)
        history = [updated].concat(history)
        downloads = removeById(downloads, id)
        downloadsUpdated()
        historyUpdated()
        return
      }
    }
  }

  function clearHistory() {
    history = []
    historyUpdated()
  }

  function removeHistoryItem(id) {
    history = removeById(history, id)
    historyUpdated()
  }

  function removeById(arr, id) {
    var result = []
    for (var i = 0; i < arr.length; i++) {
      if (arr[i].id !== id) result.push(arr[i])
    }
    return result
  }

  function playFile(filepath) {
    if (!filepath) return
    Quickshell.execDetached(["xdg-open", filepath])
  }

  function openFolder(filepath) {
    if (!filepath) return
    Quickshell.execDetached(["xdg-open", filepath.replace(/\/[^\/]+$/, "")])
  }

  function onDownloadComplete(id, exitCode) {
    for (var i = 0; i < downloads.length; i++) {
      if (downloads[i].id === id) {
        var d = cloneDownload(downloads[i])
        if (exitCode === 0) {
          d.status = "done"
          d.progress = 100
        } else if (d.status !== "cancelled") {
          d.status = "error"
          if (!d.error) d.error = "yt-dlp exited with code " + exitCode
        }
        d._procIdx = -1
        downloads = removeById(downloads, id)
        downloadsUpdated()
        if (d.status === "done" || d.status === "error") {
          history = [d].concat(history)
          historyUpdated()
        }
        return
      }
    }
  }

  function parseLine(proc, line) {
    line = String(line || "").trim()
    if (!line) return
    var id = proc.downloadId

    var destMatch = line.match(/\[download\]\s+Destination:\s+(.+)/)
    if (destMatch) {
      var fname = destMatch[1].replace(/^.*\//, "").replace(/\.[^.]+$/, "")
      root.updateDownload(id, { title: fname })
      return
    }

    var alreadyMatch = line.match(/\[download\]\s+(.+?)\s+has already been downloaded/)
    if (alreadyMatch) {
      var aname = alreadyMatch[1].replace(/^.*\//, "").replace(/\.[^.]+$/, "")
      root.updateDownload(id, { title: aname, progress: 100 })
      return
    }

    var mergerRename = line.match(/\[Merger\]\s+Merging formats into "(.+)"/)
    if (mergerRename) {
      var mname = mergerRename[1].replace(/^.*\//, "").replace(/\.[^.]+$/, "")
      root.updateDownload(id, { status: "merging", progress: 100, title: mname })
      return
    }

    var pctMatch = line.match(/\[download\]\s+([\d.]+)%\s+of\s+~?\s*([\d.]+\S+)\s+at\s+([\d.]+\S+)\s+ETA\s+([\d:]+)/)
    if (pctMatch) {
      root.updateDownload(id, {
        progress: parseFloat(pctMatch[1]),
        speed: pctMatch[3],
        eta: pctMatch[4]
      })
      return
    }

    var pctMatchSimple = line.match(/\[download\]\s+([\d.]+)%/)
    if (pctMatchSimple) {
      root.updateDownload(id, { progress: parseFloat(pctMatchSimple[1]) })
      return
    }

    if (line.indexOf("ERROR") !== -1) {
      root.updateDownload(id, { error: line.replace(/^ERROR:\s*/, "") })
    }
  }

  // Title fetch process
  Process {
    id: titleProc
    property var targetId: -1
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var title = String(this.text || "").trim()
        if (title && titleProc.targetId !== -1) {
          root.updateDownload(titleProc.targetId, { title: title })
          titleProc.targetId = -1
        }
      }
    }
  }

  Process {
    id: dlProc0
    objectName: "dlProc0"
    property var downloadId: -1
    property string _errBuf: ""
    stdout: SplitParser { onRead: function(line) { root.parseLine(dlProc0, line) } }
    stderr: SplitParser { onRead: function(line) { dlProc0._errBuf += line + "\n" } }
    onExited: function(exitCode) {
      if (exitCode !== 0 && dlProc0._errBuf) {
        var errLines = String(dlProc0._errBuf).split("\n")
        for (var i = 0; i < errLines.length; i++) {
          if (errLines[i].indexOf("ERROR") !== -1) {
            root.updateDownload(downloadId, { error: errLines[i].replace(/^ERROR:\s*/, "") })
            break
          }
        }
      }
      dlProc0._errBuf = ""
      root.onDownloadComplete(downloadId, exitCode)
      downloadId = -1
    }
  }

  Process {
    id: dlProc1
    objectName: "dlProc1"
    property var downloadId: -1
    property string _errBuf: ""
    stdout: SplitParser { onRead: function(line) { root.parseLine(dlProc1, line) } }
    stderr: SplitParser { onRead: function(line) { dlProc1._errBuf += line + "\n" } }
    onExited: function(exitCode) {
      if (exitCode !== 0 && dlProc1._errBuf) {
        var errLines = String(dlProc1._errBuf).split("\n")
        for (var i = 0; i < errLines.length; i++) {
          if (errLines[i].indexOf("ERROR") !== -1) {
            root.updateDownload(downloadId, { error: errLines[i].replace(/^ERROR:\s*/, "") })
            break
          }
        }
      }
      dlProc1._errBuf = ""
      root.onDownloadComplete(downloadId, exitCode)
      downloadId = -1
    }
  }

  Process {
    id: dlProc2
    objectName: "dlProc2"
    property var downloadId: -1
    property string _errBuf: ""
    stdout: SplitParser { onRead: function(line) { root.parseLine(dlProc2, line) } }
    stderr: SplitParser { onRead: function(line) { dlProc2._errBuf += line + "\n" } }
    onExited: function(exitCode) {
      if (exitCode !== 0 && dlProc2._errBuf) {
        var errLines = String(dlProc2._errBuf).split("\n")
        for (var i = 0; i < errLines.length; i++) {
          if (errLines[i].indexOf("ERROR") !== -1) {
            root.updateDownload(downloadId, { error: errLines[i].replace(/^ERROR:\s*/, "") })
            break
          }
        }
      }
      dlProc2._errBuf = ""
      root.onDownloadComplete(downloadId, exitCode)
      downloadId = -1
    }
  }

  // Clipboard polling
  property string _clipboardBuf: ""

  Timer {
    id: clipboardTimer
    interval: 2000
    repeat: true
    running: root.installed && !root.installing
    onTriggered: {
      if (!clipboardProc.running) {
        root._clipboardBuf = ""
        clipboardProc.running = true
      }
    }
  }

  Process {
    id: clipboardProc
    command: ["wl-paste", "--no-newline"]
    stdout: SplitParser {
      onRead: function(data) { root._clipboardBuf += data }
    }
    onExited: function(exitCode) {
      if (exitCode !== 0) return
      var content = String(root._clipboardBuf || "").trim()
      root._clipboardBuf = ""
      if (root.isYouTubeUrl(content)) {
        var cleaned = content.match(/(https?:\/\/[^\s]+)/)
        if (cleaned && cleaned[1] !== root.lastDetectedUrl) {
          root.clipboardUrl = cleaned[1]
          root.lastDetectedUrl = cleaned[1]
        }
      } else {
        root.clipboardUrl = ""
        root.lastDetectedUrl = ""
      }
    }
  }

  // Installation check
  function checkInstallation() {
    if (whichProc.running) return
    root.checkingInstallation = true
    whichProc.command = [scriptPath, "check"]
    whichProc.running = true
  }

  function installInTerminal() {
    root.installing = true
    var cmd = "omarchy pkg add yt-dlp"
    Quickshell.execDetached(["omarchy", "launch", "floating", "terminal", "with", "presentation", cmd])
    installPoll.restart()
    installTimeout.restart()
  }

  Process {
    id: whichProc
    onExited: function(exitCode) {
      root.checkingInstallation = false
      root.installed = (exitCode === 0)
      if (root.installed) {
        root.installing = false
        installPoll.stop()
        installTimeout.stop()
      }
    }
  }

  Timer {
    id: installPoll
    interval: 2000
    repeat: true
    running: root.installing && !root.installed
    onTriggered: root.checkInstallation()
  }

  Timer {
    id: installTimeout
    interval: 300000
    onTriggered: {
      if (!root.installing) return
      root.installing = false
      installPoll.stop()
    }
  }

  IpcHandler {
    target: "ytdl"
    function start(url: string) { root.startDownload(url) }
    function status() { return JSON.stringify({downloads: root.downloadCount, active: root.activeCount}) }
    function ping() { return "pong" }
  }

  Component.onCompleted: root.checkInstallation()
}
