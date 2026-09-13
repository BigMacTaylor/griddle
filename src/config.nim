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

  echo "Error: Failed to find file \'" & fileName & "\'"

  return ""

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
    echo "Error: Failed to load desktop file: ", desktopFile
    entry.noDisplay = true
    return entry

  try:
    entry.name = keyFile.getString("Desktop Entry", "Name")
  except:
    echo "Error: No name in desktop file: ", desktopFile
    entry.noDisplay = true
    return entry

  try:
    entry.genericName = keyFile.getString("Desktop Entry", "GenericName")
  except: discard

  try:
    entry.icon = keyFile.getString("Desktop Entry", "Icon")
  except: discard

  try:
    entry.exec = keyFile.getString("Desktop Entry", "Exec")
  except: discard

  try:
    entry.noDisplay = toBool(keyFile.getString("Desktop Entry", "NoDisplay"))
  except: discard

  try:
    entry.terminal = toBool(keyFile.getString("Desktop Entry", "Terminal"))
  except: discard

  return entry
