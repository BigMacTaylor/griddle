# ========================================================================================
#
#                                   Griddle
#                          version 1.0.3 by Mac_Taylor
#
# ========================================================================================

import nim2gtk/[gtk, glib, gobject, gio]
import nim2gtk/[gdk, gtklayershell, gdkpixbuf]
import std/[os, strutils, parsecfg]

const defaultConfig =
  """
[Grid]
overlay=false
[Icons]
useGenericName=false
num_icons=7
icon_size=64
icon_spacing=40
"""

const defaultCss =
  """
/*          Griddle by Mac Taylor
    Try out these other background colors:
    background-color: rgba(47, 47, 47, 1.0);
    background-color: rgba(36, 47, 79, 0.95);
*/

window {
    background-color: rgba(7, 12, 30, 0.85);
    color: rgba(255, 255, 255, 1.0);
}

/* search entry */
entry {
    background-color: rgba(0, 0, 0, 0.2);
    margin: 10px;
    box-shadow: none;
}

entry:focus {
    background: none;
}

button {
    min-width: 150px;
    min-height: 120px;
    border-radius: 10px;
    border: none;
    padding: 10px;
}

button, image {
    background: none;
    border: none
}

button, label {
    color: rgba(255, 255, 255, 1.0);
}

button:focus {
    background-color: rgba(255, 255, 255, 0.15);
}
"""

type Grid = object
  overlay = false
  useGenericName = false
  num_icons = 7
  icon_size = 64
  icon_spacing = 40

type DesktopEntry = object
  name: string
  genericName: string
  icon: string
  exec: string
  noDisplay: bool
  terminal: bool

type AppButton = tuple[btn: Button, entry: DesktopEntry]

var g = default(Grid)
var appButtons: seq[AppButton] = @[]
var window: ApplicationWindow
var scrollBox: ScrolledWindow
var searchEntry: SearchEntry
var focusProtect: bool

proc toBool(s: string): bool =
  case s.toLowerAscii()
  of "true", "t", "yes", "y", "1":
    return true
  else:
    return false

# ----------------------------------------------------------------------------------------
#                                    Config
# ----------------------------------------------------------------------------------------

proc getConfigDir(): string =
  let home = getEnv("XDG_CONFIG_HOME")
  if not home.isEmptyOrWhitespace():
    result = home / "griddle"
  else:
    result = os.getHomeDir() / ".config" / "griddle"

proc initFile(fileName: string, defaultData: string): string =
  let path = getConfigDir()
  if not fileExists(path / fileName):
    if not dirExists(path):
      createDir(path)
    writeFile(path / fileName, defaultData)

  return path / fileName

proc parseConfig(configFile: string) =
  let config =
    try:
      loadConfig(configFile)
    except:
      echo "Error: Failed to parse configuration file"
      return

  if config.getSectionValue("Grid", "overlay").len > 0:
    g.overlay = config.getSectionValue("Grid", "overlay").toBool()

  if config.getSectionValue("Icons", "useGenericName").len > 0:
    g.useGenericName = config.getSectionValue("Icons", "useGenericName").toBool()

  if config.getSectionValue("Icons", "num_icons").len > 0:
    g.num_icons = config.getSectionValue("Icons", "num_icons").parseInt()

  if config.getSectionValue("Icons", "icon_size").len > 0:
    g.icon_size = config.getSectionValue("Icons", "icon_size").parseInt()

  if config.getSectionValue("Icons", "icon_spacing").len > 0:
    g.icon_spacing = config.getSectionValue("Icons", "icon_spacing").parseInt()

# ----------------------------------------------------------------------------------------
#                                    Get Desktop Files
# ----------------------------------------------------------------------------------------

proc getAppDirs(): seq[string] =
  result = @[]

  # Get environment dirs
  let
    home = getEnv("HOME")
    xdgDataHome = getEnv("XDG_DATA_HOME")
    xdgDataDirs = getEnv("XDG_DATA_DIRS", "/usr/local/share/:/usr/share/")
      # XDG_DATA_DIRS or default "/usr/local/share/:/usr/share/"

  if xdgDataHome.len > 0:
    for dir in xdgDataHome.split(":"):
      result.add(joinPath(dir, "applications"))
  else:
    if home.len > 0:
      result.add(joinPath(home, ".local/share/applications"))

  for dir in xdgDataDirs.split(":"):
    result.add(joinPath(dir, "applications"))

  # Add flatpak dirs if not already present
  let suffix = "flatpak/exports/share/applications"
  let flatpakDataDirs = @[joinPath(home, suffix), joinPath("/var/lib", suffix)]
  for fpDir in flatpakDataDirs:
    if not contains(result, fpDir):
      result.add(fpDir)

proc parseDesktopFile(desktopFile: string): DesktopEntry =
  var entry: DesktopEntry
  var keyFile = newKeyFile()

  # Read the .desktop file (using GKeyFile for parsing)
  if not keyFile.loadFromFile(desktopFile, KeyFileFlags.none):
    echo "Error loading desktop file: ", desktopFile
    return

  try:
    entry.name = keyFile.getString("Desktop Entry", "Name")
  except:
    discard

  try:
    entry.genericName = keyFile.getString("Desktop Entry", "GenericName")
  except:
    discard

  try:
    entry.icon = keyFile.getString("Desktop Entry", "Icon")
  except:
    discard

  try:
    entry.exec = keyFile.getString("Desktop Entry", "Exec")
  except:
    discard

  try:
    entry.noDisplay = toBool(keyFile.getString("Desktop Entry", "NoDisplay"))
  except:
    discard

  try:
    entry.terminal = toBool(keyFile.getString("Desktop Entry", "Terminal"))
  except:
    discard

  return entry

# ----------------------------------------------------------------------------------------
#                                    Button Callbacks
# ----------------------------------------------------------------------------------------

proc exec(entry: DesktopEntry) =
  var cmd = entry.exec

  # Trim '%' and everything afterwards
  if '%' in cmd:
    cmd = cmd.split('%')[0]

  if not entry.terminal:
    discard execShellCmd(cmd & " &")
    return

  # If terminal
  let terminal = getEnv("TERMINAL")
  if terminal != "":
    cmd = terminal & "-e " & cmd
  elif fileExists("/etc/alternatives/x-terminal-emulator"):
    cmd = "/etc/alternatives/x-terminal-emulator -e " & cmd
  else:
    cmd = "foot " & cmd

  discard execShellCmd(cmd & " &")

proc onBtnClick(btn: Button, entry: DesktopEntry) =
  echo "btn click"
  exec(entry)
  window.hide()

proc onBtnHover(btn: Button, event: EventCrossing): bool =
  if not focusProtect:
    btn.grabFocus()
  return true

proc onBtnLeave(btn: Button, event: EventCrossing): bool =
  if not focusProtect:
    window.setFocus(nil)
  return true

proc onBtnFocus(btn: Button, event: EventFocus): bool =
  btn.grabFocus()
  return true

# ----------------------------------------------------------------------------------------
#                                    FlowBox and Buttons
# ----------------------------------------------------------------------------------------

proc createPixbuf(icon: string, size: int): Pixbuf =
  let iconTheme = getDefaultIconTheme()

  try:
    let pixbuf = iconTheme.loadIcon(icon, size, {IconLookupFlag.forceSize})
    return pixbuf
  except:
    discard

  if '/' in icon:
    let pixbuf = newPixbufFromFileAtSize(icon, size, size)
    return pixbuf
  elif icon.endsWith(".svg") or icon.endsWith(".png") or icon.endsWith(".xpm"):
    let newIcon = icon.split('.')[0]
    let pixbuf = iconTheme.loadIcon(cstring(newIcon), size, {IconLookupFlag.forceSize})
    return pixbuf

  return nil

proc createAppBtn(entry: DesktopEntry): Button =
  # Create image for button
  var img: Image
  if entry.icon != "":
    let pixbuf = createPixbuf(entry.icon, g.icon_size)
    if pixbuf != nil:
      img = newImageFromPixbuf(pixbuf)
      when defined(debug):
        echo "setting img"
    else:
      img = newImageFromIconName("image-missing", IconSize.dialog.ord)
      when defined(debug):
        echo "pixbuf is nil"
  else:
    img = newImageFromIconName("image-missing", IconSize.dialog.ord)
    when defined(debug):
      echo "entry Blank"

  # Create name for button
  var name: string
  if not g.useGenericName:
    name = entry.name
  elif entry.genericName.len > 0:
    name = entry.genericName
  else:
    name = entry.name

  if name.len > 18:
    name = name[0 .. 16] & "…"

  let button = newButton(cstring(name))
  button.image = img
  button.alwaysShowImage = true
  button.imagePosition = PositionType.top

  button.connect("clicked", onBtnClick, entry)
  button.connect("enter-notify-event", onBtnHover)
  button.connect("leave-notify-event", onBtnLeave)
  button.connect("focus-in-event", onBtnFocus)

  return button

proc buildFlowBox(desktopEntries: seq[DesktopEntry]): FlowBox =
  result = newFlowBox()
  result.homogeneous = true
  result.selectionMode = SelectionMode.none
  result.rowSpacing = g.icon_spacing
  result.columnSpacing = g.icon_spacing
  result.maxChildrenPerLine = g.num_icons
  result.minChildrenPerLine = g.num_icons

  appButtons = @[]

  # Add buttons to the FlowBox
  for entry in desktopEntries:
    if not entry.noDisplay:
      let button = createAppBtn(entry)
      result.add(button)
      button.getParent.canFocus = false
      appButtons.add((button, entry))

# ----------------------------------------------------------------------------------------
#                                    Callbacks
# ----------------------------------------------------------------------------------------

proc onClick(box: EventBox, event: EventButton): bool =
  window.hide()
  return true

proc onMotion(box: EventBox, event: EventButton): bool =
  focusProtect = false
  return true

proc onKeyPress(win: ApplicationWindow, event: gdk.EventKey): bool =
  focusProtect = true
  let key = event.getKeyval

  case key
  of KEY_Escape:
    window.hide()
    focusProtect = false
    return true # Event handled
  of KEY_Return, KEY_KP_Enter:
    echo "Enter pressed!"
    let s = searchEntry.getText()
    if s.len > 0:
      echo s
    return false
  of KEY_Tab:
    echo "tab pressed!"
    return false
  of KEY_Up:
    echo "up pressed!"
    return false
  of KEY_Down:
    echo "down pressed!"
    return false
  of KEY_Left:
    echo "left pressed!"
    return false
  of KEY_Right:
    echo "right pressed!"
    return false
  else:
    if not searchEntry.hasFocus():
      searchEntry.grabFocusWithoutSelecting()
    return false # Event not handled

proc onSearchChange(entry: SearchEntry) =
  let searchStr = entry.text.toLower

  if searchStr.len > 0:
    var isFirst = true
    for (btn, entry) in appButtons:
      let visible =
        searchStr in entry.name.toLower or searchStr in entry.genericName.toLower or
        searchStr in entry.exec.toLower
      btn.getParent.setVisible(visible)
      if isFirst and visible:
        btn.grabFocus()
        isFirst = false
  else:
    for (btn, entry) in appButtons:
      btn.getParent.setVisible(true)

# ----------------------------------------------------------------------------------------
#                                    Main Window
# ----------------------------------------------------------------------------------------

proc createWin(app: Application): ApplicationWindow =
  # Create a normal GTK window
  window = newApplicationWindow(app)

  # Before the window is first realized, set it up to be a layer surface.
  initForWindow(window)

  if g.overlay:
    setLayer(window, Layer.overlay)
    setExclusiveZone(window, -1)
  else:
    setLayer(window, Layer.top)

  # Anchors pin the window to specific edges of the screen
  window.setAnchor(Edge.top, true)
  window.setAnchor(Edge.left, true)
  window.setAnchor(Edge.right, true)
  window.setAnchor(Edge.bottom, true)

  # Get keyboard input
  window.setKeyboardMode(KeyboardMode.exclusive)
  window.connect("key-press-event", onKeyPress)

  var desktopFiles: seq[string] = @[]

  # Search app directories for desktop files
  for dir in getAppDirs():
    for file in walkFiles(joinPath(dir, "*.desktop")):
      desktopFiles.add(file)

  var desktopEntries: seq[DesktopEntry] = @[]

  # Parse desktop files
  for file in desktopFiles:
    let entry = parseDesktopFile(file)
    desktopEntries.add(entry)

  # Have to create event box to handle clicks, because
  # Gtk Window wont release focus after first click. Gtk bug?
  let clickBox = newEventBox()
  clickBox.connect("button-press-event", onClick)
  clickBox.connect("motion-notify-event", onMotion)

  let mainBox = newBox(Orientation.vertical, 0)

  let searchBox = newBox(Orientation.horizontal, 0)

  searchEntry = newSearchEntry()
  searchEntry.maxWidthChars = 30
  searchEntry.setPlaceholderText("Type to search")
  searchEntry.connect("search-changed", onSearchChange)

  scrollBox = newScrolledWindow(nil, nil)
  scrollBox.setPolicy(PolicyType.external, PolicyType.external)

  let appBox = newBox(Orientation.horizontal, 0)
  appBox.valign = Align.start

  # Create FlowBox
  let appFlowBox = buildFlowBox(desktopEntries)

  # Load CSS from file
  let cssFile = initFile("griddle.css", defaultCss)
  let cssProvider = getDefaultCssProvider()
  try:
    discard cssProvider.loadFromPath(cstring(cssFile))
  except:
    discard cssProvider.loadFromData(defaultCss)
  addProviderForScreen(
    getDefaultScreen(), cssProvider, STYLE_PROVIDER_PRIORITY_APPLICATION
  )

  # Pack the window
  searchBox.packStart(searchEntry, true, false, 0)
  appBox.packStart(appFlowBox, true, false, 0)
  scrollBox.add(appBox)

  mainBox.packStart(searchBox, false, false, 10)
  mainBox.packStart(scrollBox, true, true, 10)

  clickBox.add(mainBox)
  window.add(clickBox)

  return window

# ----------------------------------------------------------------------------------------
#                                    Main
# ----------------------------------------------------------------------------------------

proc appActivate(app: Application) =
  let windows = app.getWindows()

  if windows.len > 0:
    # Toggle visibility of the existing window
    let win = windows[0]
    if win.isVisible:
      win.hide()
    else:
      win.present() # Bring to front and show
      searchEntry.setText("")
      win.setFocus(nil)
      getVadjustment(scrollBox).setValue(0)
  else:
    # Create new window
    let config = initFile("config", defaultConfig)
    parseConfig(config)

    let win = createWin(app)
    win.showAll()
    win.setFocus(nil)

proc main() =
  let app = newApplication("org.gtk.griddle")
  app.connect("activate", appActivate)
  discard app.run()

main()
