# ========================================================================================
#
#                                   Griddle
#                          version 1.0.5 by Mac_Taylor
#
# ========================================================================================

import nim2gtk/[gtk, glib, gobject, gio]
import nim2gtk/[gdk, gtklayershell, gdkpixbuf]
import std/[os, strutils, parsecfg]
import std/[posix, inotify]

const defaultCss = staticRead("griddle.css")

const defaultConfig =
  """
[Grid]
overlay=false
[Icons]
useGenericName=false
num_icons=7
icon_size=64
icon_spacing=42
"""

type Grid = object
  overlay = false
  useGenericName = false
  num_icons = 7
  icon_size = 64
  icon_spacing = 42

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
var inotifyFd: cint

include /[config, buttons]

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

proc onInotifyEvent(source: IOChannel, condition: glib.IOCondition, data: pointer): bool =
  # Read inotify events
  var buffer: array[4096, char]
  let length = read(inotifyFd, addr buffer[0], buffer.len)

  if length > 0:
    for ev in inotify_events(addr buffer, length):
      let name = if ev.len > 0:
        $cast[cstring](addr ev.name)
      else: "unknown"
      
      if (ev.mask and IN_CREATE) != 0:
        echo "[CREATED] ", name
      elif (ev.mask and IN_DELETE) != 0:
        echo "[DELETED] ", name
      elif (ev.mask and IN_MODIFY) != 0:
        echo "[MODIFIED] ", name

    discard inotifyFd.close()
    quit()

  # Return true to keep source active
  return SOURCE_CONTINUE

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

  # Try to load CSS file
  let cssPath = getFilePath("griddle.css")
  let cssProvider = getDefaultCssProvider()
  try:
    discard cssProvider.loadFromPath(cstring(cssPath))
    addProviderForScreen(
      getDefaultScreen(), cssProvider, STYLE_PROVIDER_PRIORITY_USER
    )
  except:
    echo "Error: Failed to load CSS: " & getCurrentExceptionMsg()

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
    let configPath = getFilePath("config")
    if configPath != "":
      parseConfig(configPath)

    let win = createWin(app)

    win.showAll()
    win.setFocus(nil)

    # Setup Inotify
    inotifyFd = inotifyInit()
    if inotifyFd == -1:
      quit("Failed to initialize inotify")

    # Add watches for app directories
    for dir in getAppDirs():
      if dirExists(dir):
        let wd = inotifyAddWatch(inotifyFd, cstring(dir), IN_CREATE or IN_DELETE or IN_MODIFY or IN_MOVED_FROM or IN_MOVED_TO)
        if wd == -1:
          quit("Failed to add watch")

        echo "Watching directory: ", dir

    # Create GIOChannel from file descriptor
    let channel = unixNew(inotifyFd)
    # Set to non-blocking to prevent UI stalls
    #discard setFlags(channel, nonblock.IOFlags)

    # Register inotify FD with GLib main loop
    discard ioAddWatch(channel, PRIORITY_DEFAULT, {glib.IOCFlag.`in`}, cast[IOFunc](onInotifyEvent), nil, nil)

proc main() =
  let app = newApplication("org.gtk.griddle")
  app.connect("activate", appActivate)
  discard app.run()

main()
