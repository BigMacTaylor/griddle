# ========================================================================================
#
#                                   Griddle
#                                   Config
#
# ========================================================================================

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