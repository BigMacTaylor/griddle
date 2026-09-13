# ========================================================================================
#
#                                   Griddle
#                                   Buttons
#
# ========================================================================================

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
    try:
      let pixbuf = newPixbufFromFileAtSize(icon, size, size)
      return pixbuf
    except:
      discard
  elif icon.endsWith(".svg") or icon.endsWith(".png") or icon.endsWith(".xpm"):
    let newIcon = icon.split('.')[0]
    try:
      let pixbuf =
        iconTheme.loadIcon(cstring(newIcon), size, {IconLookupFlag.forceSize})
      return pixbuf
    except:
      discard

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