# ========================================================================================
#
#                                   Griddle
#                                   Config
#
# ========================================================================================

func toBool(s: string): bool =
  case s.toLowerAscii()
  of "true", "t", "yes", "y", "1":
    return true
  else:
    return false

func getConfigDir(): string =
  # Get XDG_CONFIG_HOME or default "~/.config"
  let dir = getEnv("XDG_CONFIG_HOME", os.getHomeDir() / ".config")
  return dir / "griddle"

proc getFilePath(fileName: string): string =
  let configDir = getConfigDir()

  let lookupPaths = [
    configDir / fileName,
    "/etc/griddle" / fileName,
    "/usr/local/etc/griddle" / fileName
  ]

  for path in lookupPaths:
    if fileExists(path):
      return path

  errorMsg("Error: Failed to find file \'" & fileName & "\'")

  return ""

proc initFile(fileName: string, defaultData: string): string =
  let path = getConfigDir()
  if not fileExists(path / fileName):
    if not dirExists(path):
      createDir(path)
    writeFile(path / fileName, defaultData)

  return path / fileName

proc initDefaultFile(fileName: string) =
  var defaultFile = ""
  let lookupPaths = [
    "/etc/griddle" / fileName,
    "/usr/local/etc/griddle" / fileName
  ]

  for path in lookupPaths:
    if fileExists(path):
      defaultFile = path
      continue

  if defaultFile == "":
    errorMsg("Could not locate default \'" & fileName & "\'")
    return

  let targetDir = getConfigDir()

  if fileExists(targetDir / fileName):
    errorMsg("Default file already exists")
    return

  # Create directory if missing
  createDir(targetDir)
  copyFileToDir(defaultFile, targetDir)

proc getInt(config: Config; sec, key: string; default: int): int =
  let val = config.getSectionValue(sec, key)
  if val.len == 0: return default

  try:
    return val.parseInt()
  except ValueError:
    errorMsg("Invalid integer for \'" & key & "\'")
    return default

proc getBool(config: Config; sec, key: string; default: bool): bool =
  let val = config.getSectionValue(sec, key)
  if val.len == 0: return default

  try:
    return val.parseBool()
  except ValueError:
    errorMsg("Invalid boolean for \'" & key & "\'")
    return default

proc parseConfig(configFile: string) =
  let config =
    try:
      loadConfig(configFile)
    except CatchableError:
      errorMsg("Failed to load configuration file")
      return

  g.overlay = config.getBool("Grid", "overlay", g.overlay)

  let sec = "Icons"
  g.useGenericNames = config.getBool(sec, "generic_names", g.useGenericNames)
  g.numIcons = config.getInt(sec, "num_icons", g.numIcons)
  g.iconSize = config.getInt(sec, "icon_size", g.iconSize)
  g.iconSpacing = config.getInt(sec, "icon_spacing", g.iconSpacing)

# ----------------------------------------------------------------------------------------
#                                    Get Desktop Files
# ----------------------------------------------------------------------------------------

proc getAppDirs(): seq[string] =
  var appDirs: seq[string] = @[]

  # Get environment dirs
  let
    home = getEnv("HOME")
    xdgDataHome = getEnv("XDG_DATA_HOME", if home.len > 0: home / ".local/share" else: "")
    xdgDataDirs = getEnv("XDG_DATA_DIRS", "/usr/local/share/:/usr/share/")

  # Process XDG Data Home
  if xdgDataHome.len > 0:
    let userAppDir = xdgDataHome / "applications"
    if dirExists(userAppDir):
      appDirs.add(userAppDir)

      # Scan recursively for subfolders inside ~/.local/share/applications/
      for path in walkDirRec(userAppDir, yieldFilter = {pcDir}):
        if dirExists(path):
          appDirs.add(path)

  # Process XDG Data Dirs
  for dir in xdgDataDirs.split(':'):
    if dir.len > 0:
      appDirs.add(dir / "applications")

  # Process Flatpak Paths
  let flatpakSuffix = "flatpak/exports/share/applications"
  if home.len > 0:
    appDirs.add(home / ".local/share" / flatpakSuffix)
  appDirs.add("/var/lib" / flatpakSuffix)

  result = appDirs.deduplicate().filterIt(dirExists(it))

proc parseDesktopFile(desktopFile: string): DesktopEntry =
  var entry: DesktopEntry
  var keyFile = newKeyFile()

  # Read the .desktop file (using GKeyFile for parsing)
  try: discard keyFile.loadFromFile(desktopFile, KeyFileFlags.none)
  except:
    errorMsg("Failed to load desktop file: ", desktopFile)
    entry.noDisplay = true
    return entry

  try:
    entry.name = keyFile.getString("Desktop Entry", "Name")
    entry.nameLower = entry.name.toLower
  except:
    errorMsg("No name in desktop file: ", desktopFile)
    entry.noDisplay = true
    return entry

  try:
    entry.genericName = keyFile.getString("Desktop Entry", "GenericName")
    entry.genericNameLower = entry.genericName.toLower
  except: discard

  try:
    entry.exec = keyFile.getString("Desktop Entry", "Exec")
    entry.execLower = entry.exec.toLower
  except: discard

  try:
    entry.icon = keyFile.getString("Desktop Entry", "Icon")
  except:
    warnMsg("No icon in desktop file: ", desktopFile)
    discard

  try:
    entry.noDisplay = toBool(keyFile.getString("Desktop Entry", "NoDisplay"))
  except: discard

  try:
    entry.terminal = toBool(keyFile.getString("Desktop Entry", "Terminal"))
  except: discard

  return entry
