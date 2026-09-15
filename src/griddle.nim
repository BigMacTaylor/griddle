# ========================================================================================
#
#                                   Griddle
#                                by Mac Taylor
#
# ========================================================================================

const version = "1.0.5"

import nim2gtk/[gtk, glib, gobject, gio]
import nim2gtk/[gdk, gtklayershell, gdkpixbuf]
import std/[os, strutils, sequtils, parsecfg]
import std/[posix, terminal, parseopt, inotify]

type Grid = object
  overlay = false
  useGenericNames = false
  numIcons = 7
  iconSize = 64
  iconSpacing = 40

type DesktopEntry = object
  name: string
  nameLower: string
  genericName: string
  genericNameLower: string
  exec: string
  execLower: string
  icon: string
  noDisplay: bool
  terminal: bool

type AppButton = tuple[btn: Button, entry: DesktopEntry]

var g = default(Grid)
var appDirs: seq[string] = @[]
var appButtons: seq[AppButton] = @[]
var window: ApplicationWindow
var scrollBox: ScrolledWindow
var flowBox: FlowBox
var searchEntry: SearchEntry
var focusProtect: bool
var keepRunning: bool
var inotifyFd: cint

template debug(args: varargs[untyped]) =
  when not defined(release) and not defined(danger):
    system.debugEcho(args)

template errorMsg(args: varargs[untyped]) =
  styledWriteLine(stderr, fgRed, styleBright, "Error: ", resetStyle, args)

template warnMsg(args: varargs[untyped]) =
  styledWriteLine(stderr, fgYellow, styleBright, "Warning: ", resetStyle, args)

template infoMsg(args: varargs[untyped]) =
  styledWriteLine(stdout, fgCyan, styleBright, "Info: ", resetStyle, args)

include /[config, arg_parser, buttons]

# ----------------------------------------------------------------------------------------
#                                    Callbacks
# ----------------------------------------------------------------------------------------

proc onClick(box: EventBox, event: EventButton): bool =
  if keepRunning:
    window.setKeyboardMode(KeyboardMode.none)
    window.hide()
    return true
  else: quit()

proc onMotion(box: EventBox, event: EventButton): bool =
  focusProtect = false
  return true

proc onKeyPress(win: ApplicationWindow, event: gdk.EventKey): bool =
  focusProtect = true
  let key = event.getKeyval

  case key
  of KEY_Escape:
    if keepRunning:
      window.setKeyboardMode(KeyboardMode.none)
      window.hide()
      focusProtect = false
      return true # Event handled
    else: quit()
  of KEY_Return, KEY_KP_Enter:
    debug "Enter pressed!"
    let s = searchEntry.getText()
    if s.len > 0:
      debug s
    return false
  of KEY_Tab:
    debug "tab pressed!"
    return false
  of KEY_Up:
    debug "up pressed!"
    return false
  of KEY_Down:
    debug "down pressed!"
    return false
  of KEY_Left:
    debug "left pressed!"
    return false
  of KEY_Right:
    debug "right pressed!"
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
        searchStr in entry.nameLower or
        searchStr in entry.genericNameLower or
        searchStr in entry.execLower
      btn.getParent.setVisible(visible)
      if isFirst and visible:
        btn.grabFocus()
        isFirst = false
  else:
    for (btn, entry) in appButtons:
      btn.getParent.setVisible(true)

proc onInotifyEvent(source: IOChannel, condition: glib.IOCondition, data: pointer): bool =
  debug "Read inotify events"

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
      elif (ev.mask and IN_MOVED_FROM) != 0:
        echo "[MOVED_FROM] ", name
      elif (ev.mask and IN_MOVED_TO) != 0:
        echo "[MOVED_TO] ", name

    # Rebuild FlowBox
    flowBox.clearFlowBox()
    flowBox.populateFlowBox()
    flowBox.showAll()

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
  flowBox = newFlowBox()
  flowBox.homogeneous = true
  flowBox.selectionMode = SelectionMode.none
  flowBox.rowSpacing = g.icon_spacing
  flowBox.columnSpacing = g.icon_spacing
  flowBox.maxChildrenPerLine = g.num_icons
  flowBox.minChildrenPerLine = g.num_icons
  flowBox.populateFlowBox()

  # Try to load CSS file
  let cssPath = getFilePath("griddle.css")
  let cssProvider = getDefaultCssProvider()
  try:
    discard cssProvider.loadFromPath(cstring(cssPath))
    addProviderForScreen(
      getDefaultScreen(), cssProvider, STYLE_PROVIDER_PRIORITY_USER
    )
  except:
    errorMsg("Failed to load CSS from \'" & cssPath & "\': " & getCurrentExceptionMsg())

  # Pack the window
  searchBox.packStart(searchEntry, true, false, 0)
  appBox.packStart(flowBox, true, false, 0)
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
    if keepRunning:
      # Toggle visibility of the existing window
      let win = windows[0]
      if win.isVisible:
        win.setKeyboardMode(KeyboardMode.none)
        win.hide()
      else:
        win.setKeyboardMode(KeyboardMode.exclusive)
        win.present()
        searchEntry.setText("")
        win.setFocus(nil)
        getVadjustment(scrollBox).setValue(0)
    else:
      app.quit()

  else:
    # Create a new window
    let configPath = getFilePath("config")
    if configPath != "":
      parseConfig(configPath)

    let win = createWin(app)
    win.showAll()
    win.setFocus(nil)

    if keepRunning:
      # Immediately hide the window
      win.hide()

      # Setup Inotify
      inotifyFd = inotifyInit()
      if inotifyFd == -1:
        errorMsg("Failed to initialize inotify")
        app.quit()

      # Add watches for app directories
      for dir in appDirs:
        let wd = inotifyAddWatch(inotifyFd, cstring(dir), IN_CREATE or IN_DELETE or IN_MODIFY or IN_MOVED_FROM or IN_MOVED_TO)
        if wd == -1:
          errorMsg("Failed to add watch")
          app.quit()

        echo "Watching directory: ", dir

      # Create GIOChannel from file descriptor
      let channel = unixNew(inotifyFd)
      # Set to non-blocking to prevent UI stalls
      #discard setFlags(channel, nonblock.IOFlags)

      # Register inotify FD with GLib main loop
      discard ioAddWatch(channel, PRIORITY_DEFAULT, {glib.IOCFlag.`in`}, cast[IOFunc](onInotifyEvent), cast[pointer](app), nil)

proc main() =
  case paramCount()
  of 0:
    discard
  of 1:
    parseArgs()
  else:
    errorMsg("Too many paramters entered")
    quit(1)

  let app = newApplication("org.gtk.griddle")
  app.connect("activate", appActivate)
  discard app.run()

main()
