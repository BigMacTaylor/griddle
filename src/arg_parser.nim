# ========================================================================================
#
#                                   Griddle
#                               Argument Parser
#
# ========================================================================================

proc printHelp() =
  echo """Griddle:
  A fullscreen app launcher for Wayland compositors.
  Copyright (C) 2026 by Mac Taylor

Usage:
  griddle [OPTIONS]

Options:
  -h, --help                       Show this help message
  -v, --version                    Show version number and exit
  -i, --init-defaults              Copy default configs to home dir
  -d, --daemon-mode                Keep running in the background
"""

proc parseArgs() =
  debug "processArgs"

  var p = initOptParser(
    commandLineParams(),
    shortNoVal = {'h', 'v', 'i', 'd'},
    longNoVal = @["help", "version", "init-defaults", "daemon-mode"],
    mode = CliMode.LaxMode
  )

  while true:
    p.next()
    case p.kind
    of cmdEnd:
      break
    of cmdArgument:
      echo "Error: Unknown argument \nUse -h for help \n"
      quit(1)
    of cmdShortOption, cmdLongOption:
      case p.key
      of "h", "help":
        printHelp()
        quit(0)
      of "v", "version":
        echo "griddle version: " & version
        quit()
      of "i", "init-defaults":
        initDefaultFile("config")
        initDefaultFile("griddle.css")
        quit(0)
      of "d", "daemon-mode":
        keepRunning = true
        return
      else:
        echo "Error: Unknown option \'", p.key, "\'"
        echo "Use -h for help \n"
        quit(1)
