import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Ui
import "Model.js" as Model

// Native Quattro popup for Obsidian daily note todos (day-switchable).
Panel {
  id: root
  moduleName: "bibek.obsidian-daily"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root
  readonly property var watcher: hostWidget || root
  readonly property bool hasWatcher: watcher !== null && watcher !== root

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color dim: Qt.darker(foreground, 1.45)
  readonly property color accent: Color.accent
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property real todoHoverOverflow: Style.space(6)

  property bool openOnly: hasWatcher ? watcher.openOnlyDefault === true : false
  property string sortOrder: {
    if (!hasWatcher) return "default"
    var s = String(watcher.sortOrderSetting || "default")
    if (s === "alpha") return "alphabetical"
    return (s === "newest" || s === "openFirst" || s === "alphabetical" || s === "default") ? s : "default"
  }
  property string searchText: ""
  property int selectedIndex: -1
  // Keyboard cursor: each todo is its own group alongside nav/week/tools/foot.
  property string cursorZone: "todos"
  property int cursorItem: 0
  property int editingLine: -1
  property string editingOriginal: ""
  property int pendingAppendCount: 0
  property bool todoMenuOpen: false
  property var todoMenuTodo: null
  property real todoMenuX: 0
  property real todoMenuY: 0

  readonly property string statusState: hasWatcher ? String(watcher.viewStatusState || "ok") : "ok"
  readonly property string date: hasWatcher ? String(watcher.viewDate || "") : ""
  readonly property bool exists: hasWatcher ? watcher.viewExists === true : false
  readonly property int openCount: hasWatcher ? Number(watcher.viewOpenCount || 0) : 0
  readonly property int doneCount: hasWatcher ? Number(watcher.viewDoneCount || 0) : 0
  readonly property var todos: hasWatcher ? (watcher.viewTodos || []) : []
  readonly property bool searchAvailable: root.todos.length >= 3
  readonly property string error: hasWatcher ? String(watcher.viewError || "") : ""
  readonly property string errorCode: hasWatcher ? String(watcher.viewErrorCode || "") : ""
  readonly property int carryOverCount: hasWatcher ? Number(watcher.viewCarryOverCount || 0) : 0
  readonly property bool isToday: hasWatcher ? watcher.viewIsToday === true : true
  readonly property string templateName: hasWatcher ? String(watcher.viewTemplateName || "") : ""
  readonly property var weekDays: hasWatcher ? (watcher.weekDays || []) : []

  readonly property var status: ({
    state: root.statusState,
    date: root.date,
    exists: root.exists,
    openCount: root.openCount,
    doneCount: root.doneCount,
    todos: root.todos,
    error: root.error,
    errorCode: root.errorCode,
    carryOverCount: root.carryOverCount,
    isToday: root.isToday,
    templateName: root.templateName
  })
  readonly property bool vaultSetupError: Model.isVaultSetupError(status)
  readonly property string metaText: Model.metaLine(status)
  readonly property var shownTodos: Model.visibleTodos(status, root.openOnly, root.searchText, root.sortOrder)
  readonly property string emptyText: Model.emptyMessage(status, root.openOnly, root.searchText)
  readonly property color iconColor: root.statusState === "error" ? root.urgent : root.foreground
  readonly property var selectedTodo: (selectedIndex >= 0 && selectedIndex < shownTodos.length)
    ? shownTodos[selectedIndex] : null

  onSearchAvailableChanged: {
    if (!root.searchAvailable) {
      root.searchText = ""
      if (searchField.activeFocus) inputField.forceActiveFocus()
    }
  }

  function focusCapture() {
    root.cursorZone = "foot"
    root.cursorItem = 0
    if (root.vaultSetupError)
      vaultPathField.forceActiveFocus()
    else
      inputField.forceActiveFocus()
  }

  function addTodo(underSelected) {
    if (!hasWatcher || typeof watcher.addTodo !== "function") return
    if (String(inputField.text || "").trim() === "") return
    var underLine = undefined
    if (underSelected === true && root.selectedTodo)
      underLine = root.selectedTodo.line
    if (underSelected !== true) {
      root.searchText = ""
      root.pendingAppendCount += 1
    }
    watcher.addTodo(inputField.text, underLine)
    inputField.text = ""
  }

  function toggleTodo(line, text) {
    if (!hasWatcher || typeof watcher.toggleTodo !== "function") return
    watcher.toggleTodo(line, text)
  }

  function cycleSelected() {
    if (!root.selectedTodo) return
    root.cycleTodo(root.selectedTodo, false)
  }

  function cycleSelectedBackward() {
    if (!root.selectedTodo) return
    root.cycleTodo(root.selectedTodo, true)
  }

  function cycleTodo(todo, backward) {
    if (!todo) return
    if (!hasWatcher || typeof watcher.cycleTodo !== "function") return
    watcher.cycleTodo(todo.line, todo.text, backward)
  }

  function stateColor(marker) {
    switch (marker) {
      case "-":
      case '"': return "#9AA080"
      case "/":
      case "?":
      case "*":
      case "I":
      case "k": return "#E0AC00"
      case ">":
      case "i": return "#027AFF"
      case "<": return "#53DFDD"
      case "!":
      case "c":
      case "d": return "#FB464C"
      case "l":
      case "p":
      case "u": return "#44CF6E"
      case "b": return "#F92672"
      case "f": return "#E9973F"
      default: return root.foreground
    }
  }

  function editTodo(line, expectText, newText) {
    if (!hasWatcher || typeof watcher.editTodo !== "function") return
    watcher.editTodo(line, expectText, newText)
  }

  function deleteSelected() {
    root.deleteTodo(root.selectedTodo)
  }

  function deleteTodo(todo) {
    if (!todo) return
    if (!hasWatcher || typeof watcher.deleteTodo !== "function") return
    root.closeTodoMenu()
    watcher.deleteTodo(todo.line, todo.text, true)
  }

  function deferTodo(todo) {
    if (!todo) return
    if (!hasWatcher || typeof watcher.deferTodo !== "function") return
    root.closeTodoMenu()
    watcher.deferTodo(todo.line, todo.text, true)
  }

  function closeTodoMenu() {
    root.todoMenuOpen = false
    root.todoMenuTodo = null
  }

  function openTodoMenu(item, todo) {
    if (!item || !todo) return
    root.todoMenuTodo = todo
    root.todoMenuOpen = true
    Qt.callLater(function() {
      if (!root.todoMenuOpen || !item || !todoMenuCard) return
      var p = item.mapToItem(keyCatcher, 0, item.height)
      var pad = Style.space(8)
      var w = todoMenuCard.width
      var h = todoMenuCard.height
      root.todoMenuX = Math.max(pad, Math.min(p.x, keyCatcher.width - w - pad))
      root.todoMenuY = Math.max(pad, Math.min(p.y, keyCatcher.height - h - pad))
    })
  }

  function indentSelected(delta) {
    if (!root.selectedTodo) return
    if (!hasWatcher || typeof watcher.indentTodo !== "function") return
    watcher.indentTodo(root.selectedTodo.line, root.selectedTodo.text, delta)
  }

  function undoLast() {
    if (!hasWatcher || typeof watcher.undoLast !== "function") return
    watcher.undoLast()
  }

  function shiftDay(delta) {
    if (!hasWatcher || typeof watcher.shiftView !== "function") return
    root.cancelEdit()
    watcher.shiftView(delta)
  }

  function goToday() {
    if (!hasWatcher || typeof watcher.goToday !== "function") return
    root.cancelEdit()
    watcher.goToday()
  }

  function goToDate(dateStr) {
    if (!hasWatcher || typeof watcher.goToDate !== "function") return
    root.cancelEdit()
    watcher.goToDate(dateStr)
  }

  function carryOver() {
    if (!hasWatcher || typeof watcher.carryOver !== "function") return
    watcher.carryOver()
  }

  function openInObsidian() {
    if (!hasWatcher || typeof watcher.openInObsidian !== "function") return
    watcher.openInObsidian()
  }

  function saveVaultPath(path) {
    if (!hasWatcher || typeof watcher.saveVaultPath !== "function") return
    watcher.saveVaultPath(path)
  }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barIdentity, direction)
    return false
  }

  function cancelEdit() {
    root.editingLine = -1
    root.editingOriginal = ""
  }

  function startEdit(todo) {
    if (!todo) return
    root.editingLine = todo.line
    root.editingOriginal = todo.text
  }

  function commitEdit(line, newText) {
    var trimmed = String(newText || "").trim()
    if (trimmed === "" || trimmed === root.editingOriginal) {
      root.cancelEdit()
      return
    }
    root.editTodo(line, root.editingOriginal, trimmed)
    root.cancelEdit()
  }

  function moveSelection(dy) {
    root.navMove(0, dy)
  }

  function navItems() {
    var items = ["prev"]
    if (!root.isToday) items.push("today")
    items.push("next", "open")
    return items
  }

  function toolItems() {
    var items = []
    if (root.isToday && root.carryOverCount > 0) items.push("carry")
    items.push("hide", "sort")
    return items
  }

  function zoneItems(zone) {
    if (zone === "nav") return root.navItems()
    if (zone === "week") return root.weekDays
    if (zone === "tools") return root.toolItems()
    if (zone === "todos") return root.shownTodos
    return ["add"]
  }

  function zoneList() {
    var zones = ["nav"]
    if (root.weekDays.length > 0) zones.push("week")
    zones.push("tools")
    if (root.shownTodos.length > 0) zones.push("todos")
    zones.push("foot")
    return zones
  }

  function setCursor(zone, item) {
    var zones = root.zoneList()
    if (zones.indexOf(zone) === -1)
      zone = zones.indexOf("tools") !== -1 ? "tools" : zones[0]
    var count = root.zoneItems(zone).length
    if (count === 0) return
    root.cursorZone = zone
    root.cursorItem = Math.max(0, Math.min(count - 1, item))
    if (zone === "todos") {
      root.selectedIndex = root.cursorItem
      root.scrollSelectedIntoView()
    }
  }

  function navMove(dx, dy) {
    if (root.cursorZone === "todos") {
      if (dy !== 0) {
        var cur = root.selectedIndex
        if (cur < 0) cur = dy > 0 ? -1 : root.shownTodos.length
        var row = cur + dy
        if (row < 0 || row >= root.shownTodos.length) {
          var zones = root.zoneList()
          var at = zones.indexOf("todos")
          if (at === -1) return
          var edge = at + (dy > 0 ? 1 : -1)
          if (edge < 0 || edge >= zones.length) return
          root.setCursor(zones[edge], dy > 0 ? 0 : 999999)
          return
        }
        root.setCursor("todos", row)
        return
      }
      // Left/Right inside a todo does nothing: the whole row is the target.
      return
    }
    if (dy !== 0) {
      var allZones = root.zoneList()
      var pos = allZones.indexOf(root.cursorZone)
      if (pos === -1) {
        root.setCursor(dy > 0 ? allZones[0] : allZones[allZones.length - 1], dy > 0 ? 0 : 999999)
        return
      }
      var next = pos + (dy > 0 ? 1 : -1)
      if (next < 0 || next >= allZones.length) return
      var zone = allZones[next]
      var item = root.cursorItem
      if (zone === "todos") {
        if (root.selectedIndex >= 0 && root.selectedIndex < root.shownTodos.length)
          item = root.selectedIndex
        else
          item = dy > 0 ? 0 : root.shownTodos.length - 1
      }
      root.setCursor(zone, item)
      return
    }
    if (dx === 0) return
    if (root.zoneItems(root.cursorZone).length === 0) return
    root.setCursor(root.cursorZone, root.cursorItem + dx)
  }

  function cycleSort() {
    if (root.sortOrder === "newest") root.sortOrder = "openFirst"
    else if (root.sortOrder === "openFirst") root.sortOrder = "alphabetical"
    else if (root.sortOrder === "alphabetical") root.sortOrder = "default"
    else root.sortOrder = "newest"
  }

  function activateSelected() {
    var zone = root.cursorZone
    if (zone === "todos") {
      if (!root.selectedTodo) return
      root.toggleTodo(root.selectedTodo.line, root.selectedTodo.text)
      return
    }
    if (zone === "nav") {
      var id = root.navItems()[root.cursorItem]
      if (id === "prev") root.shiftDay(-1)
      else if (id === "next") root.shiftDay(1)
      else if (id === "today") root.goToday()
      else if (id === "open") root.openInObsidian()
      return
    }
    if (zone === "week") {
      var day = root.weekDays[root.cursorItem]
      if (day && day.date) root.goToDate(day.date)
      return
    }
    if (zone === "tools") {
      var tool = root.toolItems()[root.cursorItem]
      if (tool === "carry") root.carryOver()
      else if (tool === "hide") root.openOnly = !root.openOnly
      else if (tool === "sort") root.cycleSort()
      return
    }
    if (zone === "foot") {
      root.addTodo(false)
      return
    }
  }

  function scrollItemIntoView(item) {
    if (!panelFlick || !item) return
    Qt.callLater(function() {
      if (!item) return
      var margin = Style.space(6)
      var point = item.mapToItem(panelFlick.contentItem, 0, 0)
      var top = point.y
      var bottom = top + item.height
      var viewTop = panelFlick.contentY
      var viewBottom = viewTop + panelFlick.height
      var maxY = Math.max(0, panelFlick.contentHeight - panelFlick.height)
      if (top < viewTop + margin)
        panelFlick.contentY = Math.max(0, top - margin)
      else if (bottom > viewBottom - margin)
        panelFlick.contentY = Math.min(maxY, bottom + margin - panelFlick.height)
    })
  }

  function scrollSelectedIntoView() {
    if (root.selectedIndex < 0 || root.selectedIndex >= root.shownTodos.length) return
    var kids = todoColumn.children
    for (var i = 0; i < kids.length; i++) {
      if (kids[i].todoIndex === root.selectedIndex) {
        root.scrollItemIntoView(kids[i])
        return
      }
    }
  }

  function clampSelection() {
    if (root.shownTodos.length === 0) {
      root.selectedIndex = -1
      return
    }
    if (root.selectedIndex >= root.shownTodos.length)
      root.selectedIndex = root.shownTodos.length - 1
  }

  onShownTodosChanged: {
    root.clampSelection()
    if (root.cursorZone === "todos") root.setCursor("todos", root.cursorItem)
    if (root.editingLine >= 0) {
      var stillThere = false
      for (var i = 0; i < root.shownTodos.length; i++) {
        if (root.shownTodos[i].line === root.editingLine) {
          stillThere = true
          break
        }
      }
      if (!stillThere) root.cancelEdit()
    }
  }

  onTodosChanged: {
    if (root.pendingAppendCount > 0 && root.shownTodos.length > 0) {
      root.pendingAppendCount -= 1
      Qt.callLater(function() {
        if (root.sortOrder === "newest") {
          root.selectedIndex = 0
          if (panelFlick) panelFlick.contentY = 0
        } else {
          root.selectedIndex = root.shownTodos.length - 1
          root.scrollSelectedIntoView()
        }
      })
    }
  }

  onDateChanged: {
    root.selectedIndex = -1
    root.cancelEdit()
    root.closeTodoMenu()
    if (panelFlick) panelFlick.contentY = 0
  }

  onOpenedChanged: {
    if (root.opened) {
      root.searchText = ""
      root.selectedIndex = -1
      root.cursorZone = "foot"
      root.cursorItem = 0
      root.cancelEdit()
      root.closeTodoMenu()
      if (panelFlick) panelFlick.contentY = 0
      Qt.callLater(root.focusCapture)
    } else {
      root.cancelEdit()
      root.closeTodoMenu()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(400))
    contentHeight: panel.fittedContentHeight(
      headerColumn.implicitHeight
        + (root.vaultSetupError
          ? 0
          : Style.space(8) + todoViewportContent.implicitHeight
            + Style.space(12) + addTodoFooter.implicitHeight),
      Style.space(580))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: inputField.activeFocus || searchField.activeFocus
        || vaultPathField.activeFocus || root.editingLine >= 0 || root.todoMenuOpen
      onCloseRequested: {
        if (root.todoMenuOpen) {
          root.closeTodoMenu()
          return
        }
        root.close()
      }
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onActivateRequested: root.activateSelected()
      onDeleteRequested: root.deleteSelected()
      onTextKey: function(t) {
        if (t === "/" && root.searchAvailable) {
          searchField.forceActiveFocus()
        } else if (t === "[") {
          root.shiftDay(-1)
        } else if (t === "]") {
          root.shiftDay(1)
        } else if (t === "{") {
          root.indentSelected(-1)
        } else if (t === "}") {
          root.indentSelected(1)
        } else if (t === "u" || t === "U") {
          root.undoLast()
        } else if (t === "t") {
          root.cycleSelected()
        } else if (t === "T") {
          root.cycleSelectedBackward()
        } else if (t === "e" || t === "E") {
          root.startEdit(root.selectedTodo)
        }
      }
      onMoveRequested: function(dx, dy) {
        root.navMove(dx, dy)
      }

      Column {
        id: headerColumn
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Style.space(12)

          PanelHero {
            width: parent.width
            title: "Obsidian Daily"
            meta: root.date !== "" ? root.date : "Daily note"
            foreground: root.foreground
            fontFamily: root.fontFamily

            iconComponent: Component {
              ObsidianIcon {
                iconSize: Style.font.display
                color: root.iconColor
              }
            }

            trailingControl: Component {
              Row {
                spacing: Style.space(4)

                PanelActionButton {
                  iconText: "\u25C0"
                  tooltipText: "Previous day"
                  foreground: root.foreground
                  fontFamily: root.fontFamily
                  hasCursor: root.cursorZone === "nav" && root.navItems()[root.cursorItem] === "prev"
                  onHovered: function(h) { if (h) root.setCursor("nav", root.navItems().indexOf("prev")) }
                  onClicked: {
                    root.setCursor("nav", root.navItems().indexOf("prev"))
                    root.shiftDay(-1)
                  }
                }

                PanelActionButton {
                  iconText: "\u25CF"
                  tooltipText: "Today"
                  visible: !root.isToday
                  foreground: root.foreground
                  fontFamily: root.fontFamily
                  hasCursor: root.cursorZone === "nav" && root.navItems()[root.cursorItem] === "today"
                  onHovered: function(h) { if (h) root.setCursor("nav", root.navItems().indexOf("today")) }
                  onClicked: {
                    root.setCursor("nav", root.navItems().indexOf("today"))
                    root.goToday()
                  }
                }

                PanelActionButton {
                  iconText: "\u25B6"
                  tooltipText: "Next day"
                  foreground: root.foreground
                  fontFamily: root.fontFamily
                  hasCursor: root.cursorZone === "nav" && root.navItems()[root.cursorItem] === "next"
                  onHovered: function(h) { if (h) root.setCursor("nav", root.navItems().indexOf("next")) }
                  onClicked: {
                    root.setCursor("nav", root.navItems().indexOf("next"))
                    root.shiftDay(1)
                  }
                }

                PanelActionButton {
                  iconText: "\u2197"
                  tooltipText: "Open in Obsidian"
                  y: 2
                  foreground: root.foreground
                  fontFamily: root.fontFamily
                  hasCursor: root.cursorZone === "nav" && root.navItems()[root.cursorItem] === "open"
                  onHovered: function(h) { if (h) root.setCursor("nav", root.navItems().indexOf("open")) }
                  onClicked: {
                    root.setCursor("nav", root.navItems().indexOf("open"))
                    root.openInObsidian()
                  }
                }
              }
            }
          }

          PanelSeparator {
            width: parent.width
            foreground: root.foreground
          }

          // Guided vault setup when the path is missing or invalid.
          Column {
            width: parent.width
            spacing: Style.space(10)
            visible: root.vaultSetupError

            Text {
              width: parent.width
              text: root.error !== ""
                ? root.error
                : "Set your Obsidian vault path to get started."
              textFormat: Text.PlainText
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              wrapMode: Text.WordWrap
            }

            TextField {
              id: vaultPathField
              width: parent.width
              placeholderText: "~/Documents/vault"
              foreground: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              Keys.onEscapePressed: keyCatcher.forceActiveFocus()
              Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
                  root.switchPanel(event.key === Qt.Key_Backtab ? -1 : 1)
                  event.accepted = true
                }
              }
              onAccepted: root.saveVaultPath(vaultPathField.text)
            }

            Button {
              text: "Save vault path"
              bordered: true
              foreground: root.foreground
              fontFamily: root.fontFamily
              onClicked: root.saveVaultPath(vaultPathField.text)
            }
          }

          // Main todo chrome — hidden while vault setup is required.
          Column {
            width: parent.width
            spacing: Style.space(12)
            visible: !root.vaultSetupError

            // Week strip: seven day cells with open-count dots.
            RowLayout {
              width: parent.width
              spacing: Style.space(4)
              visible: root.weekDays.length > 0

              Repeater {
                model: root.weekDays

                delegate: CursorSurface {
                  id: dayCell
                  required property var modelData
                  required property int index
                  Layout.fillWidth: true
                  Layout.preferredHeight: Style.space(48)
                  foreground: root.foreground
                  accent: root.accent
                  hasCursor: root.cursorZone === "week" && root.cursorItem === index
                  current: modelData.date === root.date
                  bordered: true

                  MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      root.setCursor("week", index)
                      root.goToDate(modelData.date)
                    }
                  }

                  Column {
                    anchors.centerIn: parent
                    spacing: Style.space(3)

                    Text {
                      anchors.horizontalCenter: parent.horizontalCenter
                      text: Model.weekdayShort(modelData.date)
                      textFormat: Text.PlainText
                      color: modelData.isToday ? root.accent : root.dim
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                      font.bold: modelData.date === root.date
                    }

                    Text {
                      anchors.horizontalCenter: parent.horizontalCenter
                      text: {
                        var parts = String(modelData.date || "").split("-")
                        return parts.length === 3 ? String(Number(parts[2])) : ""
                      }
                      textFormat: Text.PlainText
                      color: modelData.date === root.date ? root.foreground : root.dim
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.bodySmall
                      font.bold: modelData.date === root.date
                    }

                    Rectangle {
                      id: weekDayDot
                      anchors.horizontalCenter: parent.horizontalCenter
                      width: Style.space(6)
                      height: Style.space(6)
                      radius: width / 2
                      // Solid dot for days with open work; hollow dot for
                      // days that only hold done todos (e.g. archived notes).
                      readonly property bool hasOpen: modelData.openCount > 0
                      readonly property bool hasDone: modelData.exists && modelData.doneCount > 0
                      visible: hasOpen || hasDone
                      color: hasOpen ? (modelData.date === root.date ? root.accent : root.foreground) : "transparent"
                      border.width: hasOpen ? 0 : Math.max(1, Style.space(0.5))
                      border.color: modelData.date === root.date ? root.accent : root.foreground
                      opacity: modelData.exists ? 1.0 : 0.45
                    }

                    Item {
                      width: Style.space(6)
                      height: Style.space(6)
                      visible: !weekDayDot.visible
                    }
                  }
                }
              }
            }

            Column {
              width: parent.width
              spacing: Style.space(8)

              RowLayout {
                width: parent.width
                spacing: Style.space(6)
                visible: root.searchAvailable

                TextField {
                  id: searchField
                  Layout.fillWidth: true
                  placeholderText: "Search todos… ( / )"
                  foreground: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.body
                  text: root.searchText
                  onTextEdited: root.searchText = searchField.text
                  Keys.onEscapePressed: {
                    if (root.searchText !== "") {
                      root.searchText = ""
                      inputField.forceActiveFocus()
                    } else {
                      keyCatcher.forceActiveFocus()
                    }
                  }
                  Keys.onPressed: function(event) {
                    if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
                      root.switchPanel(event.key === Qt.Key_Backtab ? -1 : 1)
                      event.accepted = true
                      return
                    }
                    if (event.key === Qt.Key_Up || event.key === Qt.Key_Down) {
                      keyCatcher.forceActiveFocus()
                      event.accepted = true
                    }
                  }
                }

                PanelActionButton {
                  visible: root.searchText !== ""
                  iconText: "\u2715"
                  tooltipText: "Clear search"
                  foreground: root.foreground
                  fontFamily: root.fontFamily
                  onClicked: {
                    root.searchText = ""
                    searchField.forceActiveFocus()
                  }
                }
              }

              RowLayout {
                width: parent.width
                visible: root.isToday && root.carryOverCount > 0

                Item { Layout.fillWidth: true }

                Button {
                  text: "Carry over " + root.carryOverCount
                  bordered: true
                  foreground: root.foreground
                  fontFamily: root.fontFamily
                  fontSize: Style.font.caption
                  horizontalPadding: Style.space(10)
                  verticalPadding: Style.space(4)
                  hasCursor: root.cursorZone === "tools" && root.toolItems()[root.cursorItem] === "carry"
                  onHovered: function(h) { if (h) root.setCursor("tools", root.toolItems().indexOf("carry")) }
                  onClicked: {
                    root.setCursor("tools", root.toolItems().indexOf("carry"))
                    root.carryOver()
                  }
                }
              }
            }

            RowLayout {
              width: parent.width
              spacing: Style.space(8)
              visible: root.todos.length > 0

              PanelSectionHeader {
                text: root.metaText
                color: root.foreground
                foreground: root.foreground
                fontFamily: root.fontFamily
                fontSize: Style.font.title
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
              }

              CheckBox {
                id: hideDoneCheck
                text: "Hide done"
                checked: root.openOnly
                spacing: Style.space(5)
                leftPadding: 0
                rightPadding: 0
                topPadding: 0
                bottomPadding: 0
                Layout.alignment: Qt.AlignVCenter
                Layout.topMargin: 4
                onToggled: root.openOnly = checked

                indicator: BorderSurface {
                  implicitWidth: Style.space(14)
                  implicitHeight: Style.space(14)
                  x: 0
                  y: (hideDoneCheck.height - height) / 2
                  radius: Math.max(2, Style.cornerRadius * 0.4)
                  color: hideDoneCheck.checked
                    ? Style.selectedFillFor(root.foreground, root.accent)
                    : "transparent"
                  borderSpec: Border.controlSpec(
                    hideDoneCheck.checked ? "selected" : ((root.cursorZone === "tools" && root.toolItems()[root.cursorItem] === "hide") ? "hover" : "normal"),
                    root.foreground,
                    root.accent)

                  Text {
                    anchors.centerIn: parent
                    visible: hideDoneCheck.checked
                    text: "\u2713"
                    color: root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    font.bold: true
                  }
                }

                contentItem: Text {
                  leftPadding: hideDoneCheck.indicator.width + hideDoneCheck.spacing
                  text: hideDoneCheck.text
                  textFormat: Text.PlainText
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  font.bold: true
                  verticalAlignment: Text.AlignVCenter
                }
              }

              PanelActionButton {
                id: sortButton
                Layout.alignment: Qt.AlignVCenter
                Layout.topMargin: 4
                iconText: root.sortOrder === "newest" ? "\u2193" : (root.sortOrder === "openFirst" ? "\u21C5" : (root.sortOrder === "alphabetical" ? "A" : "\u2191"))
                tooltipText: {
                  if (root.sortOrder === "newest") return "Sort: Newest first (click to cycle)"
                  if (root.sortOrder === "openFirst") return "Sort: Unchecked first (click to cycle)"
                  if (root.sortOrder === "alphabetical") return "Sort: Alphabetical (click to cycle)"
                  return "Sort: File order (click to cycle)"
                }
                foreground: root.foreground
                fontFamily: root.fontFamily
                hasCursor: root.cursorZone === "tools" && root.toolItems()[root.cursorItem] === "sort"
                onHovered: function(h) { if (h) root.setCursor("tools", root.toolItems().indexOf("sort")) }
                onClicked: {
                  root.setCursor("tools", root.toolItems().indexOf("sort"))
                  root.cycleSort()
                }
              }
            }
          }
        }

      Flickable {
        id: panelFlick
        anchors.top: headerColumn.bottom
        anchors.topMargin: visible ? Style.space(8) : 0
        anchors.left: parent.left
        anchors.leftMargin: -root.todoHoverOverflow
        anchors.right: parent.right
        anchors.rightMargin: -root.todoHoverOverflow
        anchors.bottom: addTodoFooter.top
        anchors.bottomMargin: visible ? Style.space(12) : 0
        visible: !root.vaultSetupError
        contentWidth: width
        contentHeight: todoViewportContent.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        interactive: contentHeight > height
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Column {
          id: todoViewportContent
          width: panelFlick.width

          Text {
            x: root.todoHoverOverflow
            width: parent.width - root.todoHoverOverflow * 2
            visible: root.shownTodos.length === 0
            topPadding: Style.space(8)
            bottomPadding: Style.space(8)
            text: root.emptyText
            textFormat: Text.PlainText
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
          }

          Column {
            id: todoColumn
            x: root.todoHoverOverflow
            width: parent.width - root.todoHoverOverflow * 2
            spacing: Style.space(4)
            visible: root.shownTodos.length > 0

                Repeater {
                  model: root.shownTodos

                  delegate: CursorSurface {
                    id: todoRow
                    required property var modelData
                    required property int index
                    property int todoIndex: index
                    property bool hovered: todoMouse.containsMouse || checkboxMouse.containsMouse || (deleteButton && deleteButton.isHovered)
                    x: -root.todoHoverOverflow
                    width: todoColumn.width + root.todoHoverOverflow * 2
                    implicitHeight: todoInner.implicitHeight + Style.space(8)
                    foreground: root.foreground
                    accent: root.accent
                    hasCursor: root.selectedIndex === index || todoRow.hovered
                    current: false

                    MouseArea {
                      id: todoMouse
                      anchors.fill: parent
                      hoverEnabled: true
                      enabled: root.editingLine !== modelData.line
                      cursorShape: Qt.PointingHandCursor
                      acceptedButtons: Qt.LeftButton | Qt.RightButton
                      onClicked: function(mouse) {
                        root.setCursor("todos", index)
                        if (mouse.button === Qt.RightButton) {
                          root.openTodoMenu(todoRow, modelData)
                          return
                        }
                        if (root.todoMenuOpen) {
                          root.closeTodoMenu()
                          return
                        }
                      }
                      onDoubleClicked: {
                        root.selectedIndex = index
                        root.closeTodoMenu()
                        root.startEdit(modelData)
                      }
                    }

                    PanelToolTip {
                      visible: (todoMouse.containsMouse || checkboxMouse.containsMouse) && root.editingLine !== modelData.line && modelData.text.length > 0 && todoText.truncated
                      text: modelData.text
                      fontFamily: root.fontFamily
                    }

                    RowLayout {
                      id: todoInner
                      anchors.left: parent.left
                      anchors.right: parent.right
                      anchors.verticalCenter: parent.verticalCenter
                      anchors.leftMargin: root.todoHoverOverflow
                        + (modelData.depth || 0) * Style.space(14)
                      anchors.rightMargin: root.todoHoverOverflow + Style.space(8)
                      spacing: Style.space(10)

                      Item {
                        Layout.preferredWidth: Style.space(18)
                        Layout.preferredHeight: Style.space(18)
                        Layout.alignment: Qt.AlignTop
                        Layout.topMargin: Style.space(2)

                        BorderSurface {
                          anchors.fill: parent
                          radius: Math.max(2, Style.cornerRadius * 0.45)
                          readonly property bool boxed: modelData.marker === " " || modelData.marker === "x" || modelData.marker === "X"
                          color: !boxed ? "transparent" : (modelData.checked
                            ? Style.selectedFillFor(root.foreground, root.accent)
                            : "transparent")
                          borderSpec: !boxed ? Border.none() : Border.controlSpec(
                            modelData.checked ? "selected" : (checkboxMouse.containsMouse ? "hover" : "normal"),
                            root.foreground,
                            root.accent)

                          Text {
                            anchors.centerIn: parent
                            visible: Model.markerGlyph(modelData.marker) !== ""
                            text: Model.markerGlyph(modelData.marker)
                            textFormat: Text.PlainText
                            color: root.stateColor(modelData.marker)
                            font.family: root.fontFamily
                            font.pixelSize: Style.space(14)
                          }
                        }

                        MouseArea {
                          id: checkboxMouse
                          anchors.fill: parent
                          anchors.margins: -Style.space(4)
                          hoverEnabled: true
                          cursorShape: Qt.PointingHandCursor
                          onClicked: function(mouse) {
                            root.setCursor("todos", index)
                            if (root.todoMenuOpen) {
                              root.closeTodoMenu()
                            }
                            root.toggleTodo(modelData.line, modelData.text)
                          }
                        }
                      }

                      TextField {
                        id: editField
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        visible: root.editingLine === modelData.line
                        verticalPadding: Style.space(2)
                        text: modelData.text
                        foreground: root.foreground
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.body
                        onVisibleChanged: {
                          if (visible) {
                            text = modelData.text
                            forceActiveFocus()
                            selectAll()
                          }
                        }
                        onAccepted: root.commitEdit(modelData.line, editField.text)
                        Keys.onEscapePressed: {
                          root.cancelEdit()
                          keyCatcher.forceActiveFocus()
                        }
                        Keys.onPressed: function(event) {
                          if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
                            root.commitEdit(modelData.line, editField.text)
                            root.switchPanel(event.key === Qt.Key_Backtab ? -1 : 1)
                            event.accepted = true
                          }
                        }
                      }

                      Text {
                        id: todoText
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        visible: root.editingLine !== modelData.line
                        text: modelData.text
                        textFormat: Text.PlainText
                        color: (modelData.checked || modelData.marker === "-") ? root.dim : root.foreground
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.body
                        font.strikeout: modelData.marker === "x" || modelData.marker === "X"
                        elide: Text.ElideRight
                        wrapMode: Text.NoWrap
                      }

                      PanelActionButton {
                        id: deleteButton
                        Layout.alignment: Qt.AlignVCenter
                        property bool isHovered: false
                        visible: (todoRow.hovered || isHovered || root.selectedIndex === index) && root.editingLine !== modelData.line
                        iconText: "\u2715"
                        tooltipText: "Delete todo"
                        foreground: root.dim
                        hoverColor: root.urgent
                        fontFamily: root.fontFamily
                        fontSize: Style.font.caption
                        size: Style.space(20)
                        onHovered: function(h) { isHovered = h }
                        onClicked: {
                          root.setCursor("todos", index)
                          if (root.todoMenuOpen) root.closeTodoMenu()
                          root.deleteTodo(modelData)
                        }
                      }
                    }
                  }
                }
          }
        }
      }

      Column {
        id: addTodoFooter
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        visible: !root.vaultSetupError
        height: visible ? implicitHeight : 0
        spacing: Style.space(8)

        RowLayout {
          width: parent.width
          spacing: Style.space(6)

          TextField {
            id: inputField
            Layout.fillWidth: true
            placeholderText: "Add a todo…"
            foreground: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            onAccepted: root.addTodo(false)
            Keys.onEscapePressed: keyCatcher.forceActiveFocus()
            Keys.onPressed: function(event) {
              if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                  && (event.modifiers & Qt.ShiftModifier)) {
                root.addTodo(true)
                event.accepted = true
                return
              }
              if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
                root.switchPanel(event.key === Qt.Key_Backtab ? -1 : 1)
                event.accepted = true
                return
              }
              if (event.key === Qt.Key_Up) {
                keyCatcher.forceActiveFocus()
                root.cursorZone = "foot"
                root.cursorItem = 0
                root.navMove(0, -1)
                event.accepted = true
                return
              }
              if (event.key === Qt.Key_Down) {
                keyCatcher.forceActiveFocus()
                event.accepted = true
                return
              }
              if (event.text === "/" && inputField.text === "" && root.searchAvailable) {
                searchField.forceActiveFocus()
                event.accepted = true
              }
            }
          }

          PanelActionButton {
            iconText: "+"
            tooltipText: "Add todo"
            bordered: true
            foreground: root.foreground
            fontFamily: root.fontFamily
            hasCursor: root.cursorZone === "foot"
            onHovered: function(h) { if (h) root.setCursor("foot", 0) }
            onClicked: {
              root.setCursor("foot", 0)
              root.addTodo(false)
            }
          }
        }
      }

      Item {
        anchors.fill: parent
        visible: root.todoMenuOpen
        z: 20

        MouseArea {
          anchors.fill: parent
          acceptedButtons: Qt.AllButtons
          onPressed: root.closeTodoMenu()
        }

        BorderSurface {
          id: todoMenuCard
          x: root.todoMenuX
          y: root.todoMenuY
          width: Style.space(180)
          implicitHeight: todoMenuColumn.implicitHeight + Style.spacing.hairline * 2
          color: Color.popups.background
          borderSpec: Border.localOrSurfaceSpec("popups", "border", Color.popups.border, Color.popups.border, Style.normalBorderWidth)
          radius: Style.cornerRadius
          padding: Style.spacing.hairline

          Column {
            id: todoMenuColumn
            width: parent.width
            spacing: Style.spacing.labelGap

            Repeater {
              model: [
                { label: "Do tomorrow", action: "defer" },
                { label: "Delete", action: "delete" }
              ]

              delegate: Rectangle {
                required property var modelData
                required property int index
                property bool hovered: menuRowMouse.containsMouse
                width: todoMenuColumn.width
                height: Style.spacing.popupRowHeight
                color: hovered
                  ? (modelData.action === "delete"
                    ? Style.hoverFillFor(root.urgent, root.urgent)
                    : Style.hoverFillFor(root.foreground, root.accent))
                  : "transparent"
                radius: Math.max(2, Style.cornerRadius * 0.45)

                Text {
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  anchors.leftMargin: Style.spacing.controlPaddingX
                  anchors.rightMargin: Style.spacing.controlPaddingX
                  text: modelData.label
                  textFormat: Text.PlainText
                  color: hovered
                    ? (modelData.action === "delete"
                      ? Style.hoverStateColor(root.urgent, root.urgent)
                      : Style.hoverStateColor(root.foreground, root.accent))
                    : (modelData.action === "delete" ? root.urgent : root.foreground)
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.body
                  elide: Text.ElideRight
                }

                MouseArea {
                  id: menuRowMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  acceptedButtons: Qt.LeftButton
                  onClicked: {
                    if (modelData.action === "defer")
                      root.deferTodo(root.todoMenuTodo)
                    else
                      root.deleteTodo(root.todoMenuTodo)
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
