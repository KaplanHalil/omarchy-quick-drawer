import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Quick Drawer: one bar mark that opens a card of quick toggles,
// panel shortcuts and user-defined command tiles.
//
// This is a clone of omarchy.indicators on purpose. The clone keeps the
// source-specific first-party service access (idle, night light,
// notifications), which is what makes those toggles work without shelling
// out and polling. Screensaver, suspend and touchpad are plain Omarchy
// toggle flags, so they go through the CLI helpers.
BarWidget {
  id: root
  moduleName: "omarchy.indicators"

  readonly property var idleService: bar && bar.shell
    ? bar.shell.firstPartyServiceFor("omarchy.idle") : null
  readonly property var nightlightService: bar && bar.shell
    ? bar.shell.firstPartyServiceFor("omarchy.nightlight") : null
  readonly property var notificationService: bar && bar.shell
    ? bar.shell.firstPartyServiceFor("omarchy.notifications") : null

  property bool drawerOpen: false
  property string view: "grid"
  property bool screensaverEnabled: true
  property bool suspendEnabled: true
  property bool hasTouchpad: false
  property bool touchpadEnabled: true
  property bool hasBattery: true
  property int reminderCount: 0
  property string editingCustomId: ""
  // Runtime records for bar widgets whose icon is hidden while their panel is
  // available from the drawer. See applyPanelHosting().
  property var panelHostRecords: []
  // Installed plugin metadata (omarchy plugin list --json) and the subset we
  // can place in the drawer as extension tiles.
  property var extensionPlugins: []
  property var extensionTiles: []

  readonly property var defaultItems: ["caffeine", "nightlight", "dnd", "screensaver", "suspend"]
  // Settings are injected after the widget is created. A plain var binding on
  // settings.items did not re-evaluate when the bar handed the real entry in,
  // so keep the displayed list explicitly in sync.
  property var currentItems: []
  readonly property var catalog: [
    { id: "caffeine", label: "Caffeine", icon: "󰅶", description: "Keep the screen awake", kind: "toggle" },
    { id: "nightlight", label: "Night Light", icon: "󰔎", description: "Blue-light filter", kind: "toggle" },
    { id: "dnd", label: "DND", icon: "󰂛", description: "Silence notifications", kind: "toggle" },
    { id: "screensaver", label: "Screensaver", icon: "󱄄", description: "Enable or disable the screensaver", kind: "toggle" },
    { id: "suspend", label: "Suspend", icon: "󰒲", description: "Enable or disable suspend", kind: "toggle" },
    { id: "touchpad", label: "Touchpad", icon: "󰟸", description: "Enable or disable the touchpad", kind: "toggle" },
    { id: "audio", label: "Audio", icon: "󰕾", description: "Open the audio panel and hide its bar icon", kind: "action" },
    { id: "network", label: "Network", icon: "󰖩", description: "Open the network panel and hide its bar icon", kind: "action" },
    { id: "power", label: "Power", icon: "󰐥", description: "Open the power panel and hide its bar icon", kind: "action" },
    { id: "monitor", label: "Monitor", icon: "󰍹", description: "Open the display panel and hide its bar icon", kind: "action" },
    { id: "reminders", label: "Reminders", icon: "󰢌", description: "Open your reminders", kind: "action" }
  ]

  // Bar widgets that do not make sense as one tile, or already have a core
  // tile above. The tray and spacer are special rather than general widgets.
  readonly property var extensionBlocklist: [
    "io.github.kaplanhalil.quickdrawer",
    "io.github.ehlxr.advanced-workspaces",
    "jrmmhm.pocket",
    "omarchy.spacer",
    "omarchy.tray",
    "omarchy.workspaces",
    "omarchy.indicators",
    "omarchy.audio",
    "omarchy.network",
    "omarchy.power",
    "omarchy.monitor"
  ]

  readonly property var firstPartyIcons: ({
    "omarchy.clock": "󰥔",
    "omarchy.weather": "󰖐",
    "omarchy.agents": "󰚩",
    "omarchy.system-update": "󰚰",
    "omarchy.keyboard-layout": "󰌌",
    "omarchy.menu": "󰍜"
  })

  readonly property var thirdPartyIcons: ({
    "io.github.kaplanhalil.gazette": "\uf09e",
    "io.github.kaplanhalil.topstats": "\uf2db",
    "jankeesvw.notification-center": "󰂚",
    "ubeyidah.omaclock": "󰥔",
    "siob.power-actions": "󰐥",
    "io.github.twiking.omasettings": "\uf013",
    "omaplug": "\uf1e6"
  })

  readonly property bool caffeineOn: idleService ? idleService.stayAwake === true : false
  readonly property bool nightLightOn: nightlightService ? nightlightService.enabled === true : false
  readonly property bool dndOn: notificationService ? notificationService.doNotDisturb === true : false
  readonly property bool anyQuickToggle: caffeineOn || nightLightOn || dndOn
  readonly property bool opened: drawerOpen
  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color mutedColor: Util.alpha(foreground, 0.55)

  // Touchpad disappears from the grid when the machine has no touchpad.
  readonly property var displayItems: {
    var out = []
    for (var i = 0; i < currentItems.length; i++) {
      var item = currentItems[i]
      if (!tileAvailable(item)) continue
      out.push(item)
    }
    return out
  }

  readonly property bool hasHostedTiles: root.hasHostedTile()

  implicitWidth: mark.implicitWidth
  implicitHeight: mark.implicitHeight

  // ---------------------------------------------------------------- lifecycle

  function open() {
    drawerOpen = true
    refreshDynamic()
    refreshExtensions()
  }

  function close() {
    drawerOpen = false
  }

  function toggle() { drawerOpen ? close() : open() }

  onDrawerOpenChanged: {
    if (drawerOpen) {
      refreshDynamic()
      Qt.callLater(root.applyPanelHosting)
    } else {
      view = "grid"
      clearCustomForm()
    }
  }

  onSettingsChanged: root.reloadItems()
  onCurrentItemsChanged: Qt.callLater(root.applyPanelHosting)
  onBarChanged: Qt.callLater(root.applyPanelHosting)

  onViewChanged: {
    if (!drawerOpen) return
    if (view === "settings") refreshExtensions()
    if (view === "custom") Qt.callLater(function() { customLabel.forceActiveFocus() })
    else Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  Component.onCompleted: {
    reloadItems()
    refreshDynamic()
    if (!touchpadProbe.running) touchpadProbe.running = true
    Qt.callLater(root.applyPanelHosting)
    Qt.callLater(root.refreshExtensions)
  }

  function reloadItems() {
    // A JSON array crossing the bar's QML property boundary can arrive as a
    // QVariantList, for which Array.isArray() is false. It still has length
    // and indexed access, which is all the rest of this file needs.
    var raw = settings ? settings.items : undefined
    var next = defaultItems
    if (raw !== undefined && raw !== null && typeof raw !== "string"
        && typeof raw.length === "number")
      next = raw
    try {
      if (JSON.stringify(currentItems) === JSON.stringify(next)) return
    } catch (error) {
    }
    if (currentItems === next) return
    currentItems = next
  }

  Component.onDestruction: root.restoreAllPanelHosting()

  // ---------------------------------------------------------------- catalog

  function isTileEnabled(id) {
    for (var i = 0; i < currentItems.length; i++) {
      if (typeof currentItems[i] === "string" && currentItems[i] === id) return true
    }
    return false
  }

  function tileAvailable(id) {
    if (typeof id === "string" && id.indexOf("ext:") === 0) return extensionMeta(id) !== null
    if (id === "touchpad") return hasTouchpad
    if (id === "power") return hasBattery
    return true
  }

  function catalogEntry(id) {
    for (var i = 0; i < catalog.length; i++) {
      if (catalog[i].id === id) return catalog[i]
    }
    return null
  }

  function customItems() {
    var out = []
    for (var i = 0; i < currentItems.length; i++) {
      var item = currentItems[i]
      if (item && typeof item === "object" && item.id && item.command) out.push(item)
    }
    return out
  }

  function tileIcon(item) {
    if (typeof item === "object" && item) return item.icon ? String(item.icon) : "󰐊"
    if (typeof item === "string" && item.indexOf("ext:") === 0) {
      var meta = extensionMeta(item)
      return meta ? meta.icon : "\uf1e6"
    }
    var entry = catalogEntry(item)
    return entry ? entry.icon : "󰐊"
  }

  function tileLabel(item) {
    if (typeof item === "object" && item) return item.label ? String(item.label) : "Custom"
    if (typeof item === "string" && item.indexOf("ext:") === 0) {
      var meta = extensionMeta(item)
      return meta ? meta.label : String(item)
    }
    var entry = catalogEntry(item)
    return entry ? entry.label : String(item)
  }

  function tileKind(item) {
    if (typeof item === "object") return "command"
    if (typeof item === "string" && item.indexOf("ext:") === 0) return "action"
    var entry = catalogEntry(item)
    return entry ? entry.kind : "toggle"
  }

  function tileIsAction(item) {
    return tileKind(item) === "action" || tileKind(item) === "command"
  }

  function tileActive(item) {
    if (typeof item === "object") return false
    switch (item) {
      case "caffeine": return caffeineOn
      case "nightlight": return nightLightOn
      case "dnd": return dndOn
      case "screensaver": return screensaverEnabled
      case "suspend": return suspendEnabled
      case "touchpad": return touchpadEnabled
      default: return false
    }
  }

  function tileStatus(item) {
    if (typeof item === "object") return "Run"
    if (typeof item === "string" && item.indexOf("ext:") === 0) {
      var meta = extensionMeta(item)
      return meta && meta.mode === "panel" ? "Open" : "Run"
    }
    var entry = catalogEntry(item)
    if (entry && entry.kind === "action") {
      if (item === "reminders") return reminderCount > 0 ? (reminderCount + " due") : "Add"
      return "Open"
    }
    if (item === "caffeine") return caffeineOn ? "Awake" : "Idle"
    return tileActive(item) ? "On" : "Off"
  }

  function runTile(item) {
    if (typeof item === "object") {
      runCustom(item)
      return
    }
    if (typeof item === "string" && item.indexOf("ext:") === 0) {
      runExtension(item)
      return
    }
    switch (item) {
      case "caffeine": toggleCaffeine(); break
      case "nightlight": toggleNightLight(); break
      case "dnd": toggleDnd(); break
      case "screensaver": toggleScreensaver(); break
      case "suspend": toggleSuspend(); break
      case "touchpad": toggleTouchpad(); break
      case "audio": runAction("omarchy-shell shell toggle omarchy.audio"); break
      case "network": runAction("omarchy-shell shell toggle omarchy.network"); break
      case "power": runAction("omarchy-shell shell toggle omarchy.power"); break
      case "monitor": runAction("omarchy-shell shell toggle omarchy.monitor"); break
      case "reminders": runReminders(); break
    }
  }

  // ---------------------------------------------------------------- settings

  function persistItems(next) {
    var entry = { id: root.moduleName }
    if (root.settings && typeof root.settings === "object") {
      for (var key in root.settings) {
        if (key !== "id") entry[key] = root.settings[key]
      }
    }
    entry.items = next
    root.settings = entry
    if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function")
      root.bar.shell.updateEntryInline(root.moduleName, entry)
    root.reloadItems()
    Qt.callLater(root.applyPanelHosting)
  }

  function setTileEnabled(id, enabled) {
    var next = []
    var index = -1
    for (var i = 0; i < currentItems.length; i++) {
      next.push(currentItems[i])
      if (typeof currentItems[i] === "string" && currentItems[i] === id) index = i
    }
    if (enabled && index === -1) next.push(id)
    else if (!enabled && index !== -1) next.splice(index, 1)
    persistItems(next)
  }

  function startCustom() {
    editingCustomId = ""
    customLabel.text = ""
    customIcon.text = ""
    customCommand.text = ""
    view = "custom"
  }

  function editCustom(item) {
    if (!item) return
    editingCustomId = String(item.id)
    customLabel.text = String(item.label || "")
    customIcon.text = String(item.icon || "")
    customCommand.text = String(item.command || "")
    view = "custom"
  }

  function clearCustomForm() {
    editingCustomId = ""
    customLabel.text = ""
    customIcon.text = ""
    customCommand.text = ""
  }

  function cancelCustom() {
    clearCustomForm()
    view = "settings"
  }

  function commitCustom(label, icon, command, editId) {
    var cleanLabel = String(label || "").trim()
    var cleanCommand = String(command || "").trim()
    var cleanIcon = String(icon || "").trim() || "󰐊"
    if (cleanLabel === "" || cleanCommand === "") return ""

    var id = String(editId || "") || ("custom:" + Date.now())
    var next = []
    var found = false
    for (var i = 0; i < currentItems.length; i++) {
      var item = currentItems[i]
      if (item && typeof item === "object" && String(item.id) === id) {
        next.push({ id: id, label: cleanLabel, icon: cleanIcon, command: cleanCommand })
        found = true
      } else {
        next.push(item)
      }
    }
    if (!found) next.push({ id: id, label: cleanLabel, icon: cleanIcon, command: cleanCommand })
    persistItems(next)
    return id
  }

  function saveCustom() {
    var id = commitCustom(customLabel.text, customIcon.text, customCommand.text, editingCustomId)
    if (id === "") return
    clearCustomForm()
    view = "settings"
  }

  function deleteCustom(item) {
    if (!item) return
    var next = []
    for (var i = 0; i < currentItems.length; i++) {
      if (currentItems[i] && typeof currentItems[i] === "object"
          && String(currentItems[i].id) === String(item.id)) continue
      next.push(currentItems[i])
    }
    persistItems(next)
  }

  function findCustom(id) {
    for (var i = 0; i < currentItems.length; i++) {
      var item = currentItems[i]
      if (item && typeof item === "object" && String(item.id) === String(id)) return item
    }
    return null
  }

  function runCustom(item) {
    if (!item || !item.command) return
    runAction(String(item.command))
  }

  function runAction(command) {
    if (!command) return
    close()
    Qt.callLater(function() {
      if (root.bar) root.bar.run(command)
    })
  }

  // ------------------------------------------------------- panel hosting
  //
  // A bar-widget panel (audio, network, power, monitor) is only summonable
  // while its widget is alive in the bar. Third-party bar widgets cannot
  // rewrite the bar layout, so we keep the widget mounted, hide its slot
  // visually, and move its KeyboardPanel anchor to this widget's bar mark.
  // The real first-party panel then opens from the drawer with all of its
  // services intact.

  function panelWidgetFor(tileId) {
    switch (String(tileId || "")) {
      case "audio": return "omarchy.audio"
      case "network": return "omarchy.network"
      case "power": return "omarchy.power"
      case "monitor": return "omarchy.monitor"
      default: return ""
    }
  }

  function hasHostedTile() {
    for (var i = 0; i < currentItems.length; i++) {
      var id = currentItems[i]
      if (typeof id !== "string") continue
      if (id.indexOf("ext:") === 0) {
        if (extensionMeta(id) !== null) return true
        continue
      }
      if (panelWidgetFor(id) !== "" && tileAvailable(id)) return true
    }
    return false
  }

  function refreshPanelCapabilities() {
    var power = findPanelFor("omarchy.power")
    hasBattery = power ? power.batteryPresent === true : true
  }

  // Find a live bar-widget panel by its moduleName in this bar surface's item
  // tree. The bar root itself is not an Item ancestor of its widgets (each
  // screen is a PanelWindow), so we look for the panel object directly.
  function findPanelItem(node, moduleName, depth) {
    if (!node || depth > 40) return null
    if (String(node.moduleName || "") === moduleName
        && typeof node.open === "function" && typeof node.close === "function"
        && node.opened !== undefined)
      return node
    // `data` also contains non-Item QObjects such as panels; `children`
    // only walks visual Items.
    var kids = node.data || node.children || []
    for (var i = 0; i < kids.length; i++) {
      var found = findPanelItem(kids[i], moduleName, depth + 1)
      if (found) return found
    }
    return null
  }

  function findPanelFor(moduleName) {
    var win = root.QsWindow ? root.QsWindow.window : null
    if (!win || !win.contentItem) return null
    return findPanelItem(win.contentItem, moduleName, 0)
  }

  // ModuleSlot has activeItem === the panel it instantiated. It is the object
  // the bar uses to reserve the icon's width, so hiding it hides the icon
  // while leaving the panel and its services alive.
  function findSlotForPanel(panel) {
    var node = panel ? panel.parent : null
    while (node) {
      if (node.activeItem === panel) return node
      node = node.parent
    }
    return null
  }

  // General form of the same lookup: find the ModuleSlot and the widget it
  // instantiated for an arbitrary moduleName. This also works for third-party
  // bar widgets whose entry point is not a Panel.
  function findSlotItemIn(node, moduleName, depth) {
    if (!node || depth > 40) return null
    if (node.activeItem && String(node.activeItem.moduleName || "") === moduleName)
      return { slot: node, item: node.activeItem }
    var kids = node.data || node.children || []
    for (var i = 0; i < kids.length; i++) {
      var found = findSlotItemIn(kids[i], moduleName, depth + 1)
      if (found) return found
    }
    return null
  }

  function findSlotItem(moduleName) {
    var win = root.QsWindow ? root.QsWindow.window : null
    if (!win || !win.contentItem) return null
    return findSlotItemIn(win.contentItem, String(moduleName || ""), 0)
  }

  // The first real button a widget exposes. Panel widgets keep their bar
  // button alive inside the slot; simple widgets usually have one directly.
  function findWidgetButtonIn(node, depth) {
    if (!node || depth > 20) return null
    if (typeof node.triggerPress === "function" && node.pressable !== false) return node
    var kids = node.data || node.children || []
    for (var i = 0; i < kids.length; i++) {
      var found = findWidgetButtonIn(kids[i], depth + 1)
      if (found) return found
    }
    return null
  }

  function findWidgetButton(item) {
    return findWidgetButtonIn(item, 0)
  }

  function extensionWidgetFor(tileId) {
    var id = String(tileId || "")
    return id.indexOf("ext:") === 0 ? id.substring(4) : ""
  }

  function extensionMeta(tileId) {
    for (var i = 0; i < extensionTiles.length; i++) {
      if (extensionTiles[i].id === tileId) return extensionTiles[i]
    }
    return null
  }

  function extensionIcon(plugin, button) {
    var id = String(plugin && plugin.id || "")
    if (firstPartyIcons[id] !== undefined) return firstPartyIcons[id]
    if (thirdPartyIcons[id] !== undefined) return thirdPartyIcons[id]
    var text = button && button.text !== undefined ? String(button.text) : ""
    // A real Nerd Font glyph is usually one or two UTF-16 units. Longer text
    // (a clock, a CPU readout) is a label, not an icon.
    if (text.length > 0 && text.length <= 2) return text
    return "\uf1e6"
  }

  function updateExtensionPlugins(raw) {
    try {
      var parsed = JSON.parse(String(raw || "").trim())
      extensionPlugins = Array.isArray(parsed) ? parsed : []
    } catch (error) {
      extensionPlugins = []
    }
    buildExtensionTiles()
  }

  function buildExtensionTiles() {
    var out = []
    for (var i = 0; i < extensionPlugins.length; i++) {
      var plugin = extensionPlugins[i]
      if (!plugin || plugin.enabled !== true) continue
      if (!Array.isArray(plugin.kinds) || plugin.kinds.indexOf("bar-widget") === -1) continue
      var pluginId = String(plugin.id || "")
      if (pluginId === "" || extensionBlocklist.indexOf(pluginId) !== -1) continue

      var found = findSlotItem(pluginId)
      if (!found) continue
      var panel = findKeyboardPanel(found.item)
      var button = findWidgetButton(found.item)
      if (!panel && !button) continue

      out.push({
        id: "ext:" + pluginId,
        widgetId: pluginId,
        label: String(plugin.name || pluginId),
        icon: extensionIcon(plugin, button),
        mode: panel ? "panel" : "button",
        firstParty: plugin.firstParty === true
      })
    }
    extensionTiles = out
    Qt.callLater(root.applyPanelHosting)
  }

  function refreshExtensions() {
    if (!extensionList.running) extensionList.running = true
  }

  function runExtension(tileId) {
    var widgetId = extensionWidgetFor(tileId)
    if (widgetId === "") return
    var found = findSlotItem(widgetId)
    if (!found) return
    var panel = findKeyboardPanel(found.item)
    if (panel) {
      runAction("omarchy-shell shell toggle " + widgetId)
      return
    }
    var button = findWidgetButton(found.item)
    if (!button) return
    close()
    Qt.callLater(function() {
      button.triggerPress(Qt.LeftButton)
    })
  }

  function findKeyboardPanel(item) {
    if (!item) return null
    // KeyboardPanel has an `open` boolean property; its owner (the bar-widget
    // panel root) has open()/close() functions instead.
    if (item.anchorItem !== undefined && item.contentWidth !== undefined
        && item.open !== undefined && typeof item.close === "function")
      return item
    // KeyboardPanel is a PanelWindow (a QObject, not an Item), so it lives in
    // `data`, not `children`.
    var kids = item.data || item.children || []
    for (var i = 0; i < kids.length; i++) {
      var found = findKeyboardPanel(kids[i])
      if (found) return found
    }
    return null
  }

  function panelRecordForSlot(slot) {
    for (var i = 0; i < panelHostRecords.length; i++) {
      if (panelHostRecords[i].slot === slot) return panelHostRecords[i]
    }
    return null
  }

  function applyPanelHosting() {
    try {
      var desired = []
      for (var i = 0; i < currentItems.length; i++) {
        var tileId = currentItems[i]
        if (typeof tileId !== "string") continue

        var extId = extensionWidgetFor(tileId)
        if (extId !== "") {
          // Do not hide an extension before its metadata exists: that would
          // leave a hidden bar icon with no visible way to open it.
          if (!extensionMeta(tileId)) continue
          var found = findSlotItem(extId)
          if (!found) continue
          var extPanel = findKeyboardPanel(found.item)
          var extButton = findWidgetButton(found.item)
          if (!extPanel && !extButton) continue
          desired.push({ slot: found.slot, panel: extPanel, button: extButton })
          continue
        }

        var widgetId = panelWidgetFor(tileId)
        if (widgetId === "") continue
        if (!tileAvailable(tileId)) continue
        var panelRoot = findPanelFor(widgetId)
        if (!panelRoot) continue
        var slot = findSlotForPanel(panelRoot)
        if (!slot) continue
        var panel = findKeyboardPanel(panelRoot)
        // No KeyboardPanel means this is not a panel widget we can anchor.
        // Leave the bar icon visible and try again on the next tick.
        if (!panel) continue
        desired.push({ slot: slot, panel: panel, button: null })
      }

      for (var r = panelHostRecords.length - 1; r >= 0; r--) {
        var record = panelHostRecords[r]
        var keep = false
        for (var d = 0; d < desired.length; d++) {
          if (desired[d].slot === record.slot) { keep = true; break }
        }
        if (!keep) {
          restorePanelRecord(record)
          panelHostRecords.splice(r, 1)
        }
      }

      for (var k = 0; k < desired.length; k++) {
        var want = desired[k]
        var current = panelRecordForSlot(want.slot)
        if (!current) {
          current = {
            slot: want.slot,
            panel: want.panel,
            button: want.button || null,
            originalAnchor: want.panel ? want.panel.anchorItem : null,
            originalCenterOnBar: want.panel ? want.panel.centerOnBar : undefined
          }
          panelHostRecords.push(current)
        } else if (current.panel !== want.panel) {
          try {
            if (current.panel && current.originalAnchor) current.panel.anchorItem = current.originalAnchor
          } catch (error) {
          }
          try {
            if (current.panel && current.originalCenterOnBar !== undefined)
              current.panel.centerOnBar = current.originalCenterOnBar
          } catch (error) {
          }
          current.panel = want.panel
          current.button = want.button || null
          current.originalAnchor = want.panel ? want.panel.anchorItem : null
          current.originalCenterOnBar = want.panel ? want.panel.centerOnBar : undefined
        } else {
          current.button = want.button || null
        }
        try { want.slot.visible = false } catch (error) { }
        if (want.panel) {
          try { want.panel.centerOnBar = false } catch (error) { }
          try { want.panel.anchorItem = mark } catch (error) { }
        }
      }
    } catch (error) {
      // The bar may be tearing down; the next timer tick will retry.
    }
  }

  function restorePanelRecord(record) {
    if (!record) return
    try {
      if (record.panel && typeof record.panel.close === "function") record.panel.close()
    } catch (error) {
    }
    try { if (record.slot) record.slot.visible = true } catch (error) { }
    try {
      if (record.panel && record.originalAnchor) record.panel.anchorItem = record.originalAnchor
    } catch (error) {
    }
    try {
      if (record.panel && record.originalCenterOnBar !== undefined)
        record.panel.centerOnBar = record.originalCenterOnBar
    } catch (error) {
    }
  }

  function restoreAllPanelHosting() {
    var records = panelHostRecords
    panelHostRecords = []
    for (var i = 0; i < records.length; i++) restorePanelRecord(records[i])
  }

  function panelHostingStatus() {
    var out = {
      hasBattery: hasBattery,
      hasTouchpad: hasTouchpad,
      panels: [],
      records: []
    }
    var ids = ["audio", "network", "power", "monitor"]
    for (var i = 0; i < ids.length; i++) {
      var widgetId = panelWidgetFor(ids[i])
      var panelRoot = findPanelFor(widgetId)
      var slot = findSlotForPanel(panelRoot)
      out.panels.push({
        tile: ids[i],
        widget: widgetId,
        found: !!panelRoot,
        slotFound: !!slot,
        visible: slot ? slot.visible === true : null
      })
    }
    for (var r = 0; r < panelHostRecords.length; r++) {
      var record = panelHostRecords[r]
      var anchored = false
      try { anchored = !!record.panel && record.panel.anchorItem === mark } catch (error) { }
      out.records.push({
        visible: record.slot ? record.slot.visible === true : null,
        anchored: anchored
      })
    }
    return JSON.stringify(out)
  }

  function extensionStatus() {
    var out = { count: extensionTiles.length, tiles: [], records: [] }
    for (var i = 0; i < extensionTiles.length; i++) {
      var meta = extensionTiles[i]
      out.tiles.push({
        id: meta.id,
        widgetId: meta.widgetId,
        label: meta.label,
        mode: meta.mode,
        firstParty: meta.firstParty === true
      })
    }
    for (var r = 0; r < panelHostRecords.length; r++) {
      var record = panelHostRecords[r]
      var anchored = false
      try { anchored = !!record.panel && record.panel.anchorItem === mark } catch (error) { }
      out.records.push({
        visible: record.slot ? record.slot.visible === true : null,
        panel: !!record.panel,
        anchored: anchored
      })
    }
    return JSON.stringify(out)
  }

  function openPanel(tileId) {
    var id = String(tileId || "")
    if (id.indexOf("ext:") === 0) {
      runExtension(id)
      return
    }
    var widgetId = panelWidgetFor(id)
    if (widgetId !== "") runAction("omarchy-shell shell toggle " + widgetId)
  }

  function runReminders() {
    runAction(reminderCount > 0 ? "omarchy-reminder show" : "omarchy-reminder -i")
  }

  function openCoffee() {
    Qt.openUrlExternally("https://www.buymeacoffee.com/kaplanhalil")
  }

  function openGithub() {
    Qt.openUrlExternally("https://github.com/KaplanHalil/omarchy-quick-drawer")
  }

  // ---------------------------------------------------------------- state

  function refreshDynamic() {
    refreshFlags()
    refreshTouchpad()
    if (!reminderState.running) reminderState.running = true
  }

  function refreshFlags() {
    if (!screensaverState.running) screensaverState.running = true
    if (!suspendState.running) suspendState.running = true
  }

  function refreshTouchpad() {
    if (!touchpadProbe.running) touchpadProbe.running = true
    if (root.hasTouchpad && !touchpadState.running) touchpadState.running = true
  }

  function toggleCaffeine() {
    // setIdleEnabled takes "idle enabled", which is the inverse of stay-awake.
    // Passing the current stay-awake value is what toggles it.
    if (idleService) idleService.setIdleEnabled(caffeineOn)
  }

  function toggleNightLight() {
    if (nightlightService) nightlightService.setNightlight(!nightLightOn)
  }

  function toggleDnd() {
    if (notificationService) notificationService.setDoNotDisturb(!dndOn)
  }

  function toggleScreensaver() {
    if (!screensaverToggle.running) screensaverToggle.running = true
  }

  function toggleSuspend() {
    if (!suspendToggle.running) suspendToggle.running = true
  }

  function toggleTouchpad() {
    if (!touchpadToggle.running) touchpadToggle.running = true
  }

  IpcHandler {
    target: "omarchy.indicators"

    function refresh(): void { root.refreshDynamic() }
    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
    function openSettings(): void { root.view = "settings"; root.open() }
    function openGrid(): void { root.view = "grid"; root.open() }
    function openCustom(): void { root.startCustom(); root.open() }
    function toggleCaffeine(): void { root.toggleCaffeine() }
    function toggleNightLight(): void { root.toggleNightLight() }
    function toggleDnd(): void { root.toggleDnd() }
    function toggleScreensaver(): void { root.toggleScreensaver() }
    function toggleSuspend(): void { root.toggleSuspend() }
    function addTile(id: string): void { root.setTileEnabled(String(id), true) }
    function removeTile(id: string): void { root.setTileEnabled(String(id), false) }
    function addCustomCommand(label: string, icon: string, command: string): string {
      return root.commitCustom(String(label), String(icon), String(command), "")
    }
    function runCustomById(id: string): void {
      var item = root.findCustom(String(id))
      if (item) root.runCustom(item)
    }
    function deleteCustomById(id: string): void {
      var item = root.findCustom(String(id))
      if (item) root.deleteCustom(item)
    }
    function openPanel(id: string): void { root.openPanel(String(id)) }
    function panelHostingStatus(): string { return root.panelHostingStatus() }
    function extensionStatus(): string { return root.extensionStatus() }
    function refreshExtensions(): void { root.refreshExtensions() }
    function openCoffee(): void { root.openCoffee() }
  }

  Process {
    id: screensaverState
    command: ["omarchy-toggle-enabled", "screensaver-off"]
    onExited: function(code) { root.screensaverEnabled = code !== 0 }
  }

  Process {
    id: suspendState
    command: ["omarchy-toggle-enabled", "suspend-off"]
    onExited: function(code) { root.suspendEnabled = code !== 0 }
  }

  Process {
    id: screensaverToggle
    command: ["omarchy-toggle-screensaver"]
    onExited: function(code) { root.refreshFlags() }
  }

  Process {
    id: suspendToggle
    command: ["omarchy-toggle-suspend"]
    onExited: function(code) { root.refreshFlags() }
  }

  Process {
    id: touchpadProbe
    command: ["omarchy-hw-touchpad"]
    stdout: StdioCollector {
      onStreamFinished: {
        root.hasTouchpad = String(text || "").trim() !== ""
        if (root.hasTouchpad) root.refreshTouchpad()
      }
    }
  }

  Process {
    id: touchpadState
    command: ["bash", "-lc", "test ! -f \"$HOME/.local/state/omarchy/toggles/hypr/touchpad-disabled-name\""]
    onExited: function(code) { root.touchpadEnabled = code === 0 }
  }

  Process {
    id: touchpadToggle
    command: ["omarchy-toggle-input-device", "touchpad", "toggle"]
    onExited: function(code) { root.refreshTouchpad() }
  }

  Process {
    id: reminderState
    command: ["omarchy-reminder", "show", "--json"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var data = JSON.parse(String(text || "").trim())
          root.reminderCount = Number(data.count || 0)
        } catch (error) {
          root.reminderCount = 0
        }
      }
    }
  }

  Process {
    id: extensionList
    command: ["omarchy", "plugin", "list", "--json"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.updateExtensionPlugins(text)
    }
    onExited: function(code) {
      if (code !== 0) {
        root.extensionPlugins = []
        root.extensionTiles = []
      }
    }
  }

  // Settings are injected after construction and the var-property binding
  // proved unreliable on first load. Poll the tiny entry once a second and
  // keep the panel-host state convergent at the same time.
  Timer {
    interval: 500
    repeat: true
    running: true
    onTriggered: {
      try {
        root.reloadItems()
        root.refreshPanelCapabilities()
        if (root.hasHostedTiles || root.panelHostRecords.length > 0)
          root.applyPanelHosting()
      } catch (error) {
      }
    }
  }

  Shortcut {
    sequence: "Escape"
    enabled: root.drawerOpen && root.view === "custom"
    onActivated: root.view = "settings"
  }

  BarIconButton {
    id: mark
    anchors.fill: parent
    bar: root.bar
    slotSize: Style.bar.iconSlot
    text: "\uf1de"
    tooltipText: "Quick Settings"
    onPressed: function(button) { root.toggle() }
  }

  // A quiet accent dot tells you one of the three temporary toggles is on
  // without opening the drawer.
  Rectangle {
    visible: root.anyQuickToggle
    width: Style.space(3)
    height: width
    radius: width / 2
    color: Color.accent
    anchors.top: parent.top
    anchors.right: parent.right
    anchors.topMargin: Style.space(2)
    anchors.rightMargin: Style.space(2)
  }

  KeyboardPanel {
    id: panel

    anchorItem: mark
    owner: root
    bar: root.bar
    open: root.drawerOpen
    // Anchor under this widget's bar slot. centerOnBar would always put the
    // card in the middle of the bar, which is wrong once the drawer lives in
    // the right-hand section.
    centerOnBar: false
    padding: Style.space(18)
    focusTarget: root.view === "custom" ? customLabel : keyCatcher
    contentWidth: panel.fittedContentWidth(root.view === "grid" ? Style.space(340) : Style.space(460))
    contentHeight: panel.fittedContentHeight(contentRoot.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: root.view === "custom"
      onCloseRequested: root.close()
    }

    Item {
      id: contentRoot
      width: parent.width
      height: implicitHeight
      implicitHeight: root.view === "grid" ? gridColumn.implicitHeight
        : (root.view === "settings" ? settingsColumn.implicitHeight : customColumn.implicitHeight)

      // ---------------------------------------------------------- grid view

      Column {
        id: gridColumn
        visible: root.view === "grid"
        width: parent.width
        spacing: Style.space(12)

        PanelHeader {
          width: parent.width
          title: "Quick Settings"
          showBack: false
          onAction: root.view = "settings"
        }

        Column {
          visible: root.displayItems.length === 0
          width: parent.width
          spacing: Style.space(10)

          Text {
            width: parent.width
            text: "No tiles yet"
            horizontalAlignment: Text.AlignHCenter
            color: root.mutedColor
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.body
          }

          Button {
            width: parent.width
            text: "Add tiles"
            iconText: "\uf067"
            bordered: true
            onClicked: root.view = "settings"
          }
        }

        Flickable {
          id: gridScroll
          visible: root.displayItems.length > 0
          width: parent.width
          height: Math.min(gridContent.implicitHeight, Style.space(560))
          contentWidth: width
          contentHeight: gridContent.implicitHeight
          clip: true
          interactive: contentHeight > height

          Grid {
            id: gridContent
            width: gridScroll.width
            columns: 3
            spacing: Style.space(8)

            Repeater {
              model: root.displayItems

              delegate: Tile {
                required property var modelData
                bar: root.bar
                icon: root.tileIcon(modelData)
                label: root.tileLabel(modelData)
                active: root.tileActive(modelData)
                action: root.tileIsAction(modelData)
                statusText: root.tileStatus(modelData)
                onClicked: root.runTile(modelData)
              }
            }
          }
        }
      }

      // ------------------------------------------------------- settings view

      Column {
        id: settingsColumn
        visible: root.view === "settings"
        width: parent.width
        spacing: Style.space(12)

        PanelHeader {
          width: parent.width
          title: "Add tiles"
          showBack: true
          onBack: root.view = "grid"
        }

        Flickable {
          id: settingsScroll
          width: parent.width
          height: Math.min(settingsContent.implicitHeight, Style.space(640))
          contentWidth: width
          contentHeight: settingsContent.implicitHeight
          clip: true
          interactive: contentHeight > height

          Column {
            id: settingsContent
            width: settingsScroll.width
            spacing: Style.space(2)

            Repeater {
              model: root.catalog

              delegate: CatalogRow {
                required property var modelData
                width: settingsContent.width
                bar: root.bar
                icon: modelData.icon
                title: modelData.label
                description: modelData.description
                available: root.tileAvailable(modelData.id)
                checked: root.isTileEnabled(modelData.id)
                onToggled: root.setTileEnabled(modelData.id, !root.isTileEnabled(modelData.id))
              }
            }

            Item { width: 1; height: Style.space(8) }

            Text {
              visible: root.extensionTiles.length > 0
              width: parent.width
              text: "Extensions"
              color: root.mutedColor
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.caption
              font.bold: true
            }

            Text {
              visible: root.extensionTiles.length > 0
              width: parent.width
              text: "Installed bar widgets. Adding one hides its bar icon."
              wrapMode: Text.WordWrap
              color: root.mutedColor
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.caption
            }

            Repeater {
              model: root.extensionTiles

              delegate: CatalogRow {
                required property var modelData
                width: settingsContent.width
                bar: root.bar
                icon: modelData.icon
                title: modelData.label
                description: modelData.mode === "panel"
                  ? "Open its panel from the drawer"
                  : "Run its primary bar action"
                available: true
                checked: root.isTileEnabled(modelData.id)
                onToggled: root.setTileEnabled(modelData.id, !root.isTileEnabled(modelData.id))
              }
            }

            Item { width: 1; height: Style.space(8) }

            Text {
              visible: root.customItems().length > 0
              width: parent.width
              text: "Custom commands"
              color: root.mutedColor
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.caption
              font.bold: true
            }

            Repeater {
              model: root.customItems()

              delegate: RowLayout {
                required property var modelData
                width: settingsContent.width
                height: Style.space(42)
                spacing: Style.space(8)

                Text {
                  Layout.preferredWidth: Style.space(24)
                  Layout.alignment: Qt.AlignVCenter
                  text: modelData.icon || "󰐊"
                  horizontalAlignment: Text.AlignHCenter
                  color: root.foreground
                  font.family: root.bar ? root.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.iconLarge
                }

                ColumnLayout {
                  Layout.fillWidth: true
                  Layout.alignment: Qt.AlignVCenter
                  spacing: 0

                  Text {
                    Layout.fillWidth: true
                    text: modelData.label || "Custom"
                    elide: Text.ElideRight
                    color: root.foreground
                    font.family: root.bar ? root.bar.fontFamily : Style.font.family
                    font.pixelSize: Style.font.body
                  }

                  Text {
                    Layout.fillWidth: true
                    text: modelData.command || ""
                    elide: Text.ElideRight
                    color: root.mutedColor
                    font.family: root.bar ? root.bar.fontFamily : Style.font.family
                    font.pixelSize: Style.font.caption
                  }
                }

                Button {
                  Layout.alignment: Qt.AlignVCenter
                  iconText: "\uf044"
                  tooltipText: "Edit"
                  bordered: false
                  horizontalPadding: Style.space(6)
                  onClicked: root.editCustom(modelData)
                }

                Button {
                  Layout.alignment: Qt.AlignVCenter
                  iconText: "\uf1f8"
                  tooltipText: "Delete"
                  bordered: false
                  horizontalPadding: Style.space(6)
                  onClicked: root.deleteCustom(modelData)
                }
              }
            }

            Button {
              width: parent.width
              text: "Add custom command"
              iconText: "\uf067"
              bordered: true
              onClicked: root.startCustom()
            }
          }
        }

        Row {
          spacing: Style.space(8)

          Button {
            text: "Buy me a coffee"
            iconText: "☕"
            bordered: true
            onClicked: root.openCoffee()
          }

          Button {
            text: "GitHub"
            iconText: "\uf09b"
            bordered: true
            onClicked: root.openGithub()
          }
        }
      }

      // --------------------------------------------------------- custom form

      Column {
        id: customColumn
        visible: root.view === "custom"
        width: parent.width
        spacing: Style.space(8)

        PanelHeader {
          width: parent.width
          title: root.editingCustomId === "" ? "New command" : "Edit command"
          showBack: true
          onBack: root.cancelCustom()
        }

        Text {
          text: "Label"
          color: root.mutedColor
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.caption
        }

        TextField {
          id: customLabel
          width: parent.width
          placeholderText: "e.g. Notify me"
          foreground: root.foreground
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
        }

        Text {
          text: "Icon (Nerd Font glyph)"
          color: root.mutedColor
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.caption
        }

        TextField {
          id: customIcon
          width: parent.width
          placeholderText: "󰐊"
          foreground: root.foreground
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
        }

        Text {
          text: "Command"
          color: root.mutedColor
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.caption
        }

        TextField {
          id: customCommand
          width: parent.width
          placeholderText: "notify-send 'Hello'"
          foreground: root.foreground
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
        }

        Text {
          width: parent.width
          text: "Commands run with bash -lc as your user. Only add commands you trust."
          wrapMode: Text.WordWrap
          color: root.mutedColor
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.caption
        }

        Row {
          spacing: Style.space(8)

          Button {
            text: "Save"
            bordered: true
            focusable: true
            enabled: customLabel.text.trim() !== "" && customCommand.text.trim() !== ""
            onClicked: root.saveCustom()
          }

          Button {
            text: "Cancel"
            bordered: true
            focusable: true
            onClicked: root.cancelCustom()
          }
        }
      }
    }
  }

  // ---------------------------------------------------------------- header

  component PanelHeader: Item {
    id: header

    property string title: ""
    property bool showBack: false
    signal back()
    signal action()

    implicitHeight: Math.max(titleText.implicitHeight, actionButton.implicitHeight)

    Text {
      id: titleText
      anchors.left: header.showBack ? backButton.right : parent.left
      anchors.leftMargin: header.showBack ? Style.space(8) : 0
      anchors.right: header.showBack ? parent.right : actionButton.left
      anchors.rightMargin: header.showBack ? 0 : Style.space(8)
      anchors.verticalCenter: parent.verticalCenter
      text: header.title
      elide: Text.ElideRight
      color: root.foreground
      font.family: root.bar ? root.bar.fontFamily : Style.font.family
      font.pixelSize: Style.font.body
      font.bold: true
    }

    Button {
      id: backButton
      visible: header.showBack
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      iconText: "\uf060"
      tooltipText: "Back"
      bordered: false
      horizontalPadding: Style.space(6)
      onClicked: header.back()
    }

    Button {
      id: actionButton
      visible: !header.showBack
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      iconText: "\uf013"
      tooltipText: "Add tiles"
      bordered: false
      horizontalPadding: Style.space(6)
      onClicked: header.action()
    }
  }
}
