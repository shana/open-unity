#!/bin/bash -eu

# ------------------------------------------------------------
# Copyright (c) 2020 Andreia Gaita <shana@spoiledcat.net>
# Licensed under the MIT License.
# ------------------------------------------------------------

{ set +x; } 2>/dev/null
SOURCE=$0
DIR="$( pwd )"

# unity version, pass -n|--unity to set
UNITYVERSION=""
# default cache server, pass --cache to set
CACHESERVER="cachepi"
#default cache server version (2 is accelerator)
CACHEVERSION=2
# folder where you stuff all your Unitys, pass in --hub to set
BASEUNITYPATH="/Applications/Unity/Hub/Editor"

HUBPATH=""
OS="Mac"
BIN=""
UNITYTOOLSPATH=""

if [[ -e "/c/" ]]; then
  OS="Windows"
  BIN="/usr/bin/"
  BASEUNITYPATH="C:/Program\ Files/Unity/Hub/Editor"
  HUBPATH="$( echo ~/AppData/Roaming/UnityHub/ | xargs realpath )" || true
else
  HUBPATH="$( pushd ~/Library/Application\ Support/UnityHub/ && pwd && popd )" || true
fi

if [[ -d $HUBPATH ]]; then
  HUBPATH="$HUBPATH/secondaryInstallPath.json"
fi

RM="${BIN}rm"
CAT="${BIN}cat"
GREP="${BIN}grep"
CUT="${BIN}cut"
DATE="${BIN}date"
CP="${BIN}cp"
BIN2TXT="binary2text"
SED="sed"

if [[ x"$OS" == x"Windows" ]]; then
  BIN2TXT="${BIN2TXT}.exe"
fi

if [[ -f $HUBPATH ]]; then

  tmp="$( $CAT $HUBPATH | $SED -E 's, ,\\ ,g' | $SED -E 's,",,g' )"
  if [[ x"$tmp" != x"" ]]; then
    BASEUNITYPATH="$tmp"
    if [[ x"$OS" == x"Windows" ]]; then
      BASEUNITYPATH="$( realpath $BASEUNITYPATH )"
    fi
  fi
fi

CONFIGURATION=Dev
BATCH=0
PROJECTPATH="$DIR"
TARGET=""
QUIT=0
METHOD=""
ARGS=""
UNITYPATH=""

function usage_platforms() {
  cat << EOF

    Build Targets (optional, autodetected from current project settings):
    -w|--windows                  Set build target to Win64
    -m|--mac                      Set build target to Mac
    -a|--android                  Set build target to Android
    -i|--ios                      Set build target to iOS
    -x|--xbox                     Set build target to xbox
    -s|--ps4                      Set build target to ps4
    -n|--switch                   Set build target to Switch
EOF
}


function usage() {
  cat << EOF

Usage:

    open.sh [Options] [Build Target] [Batch mode flags] [other flags passed to Unity directly]

    Example:
    ./open.sh -p [Path to Unity Project folder]

    By default it will detect what build target and Unity version the project is currently set to and use that.

    Use -h for a list of all the options.
EOF
}

function help() {
  usage

  cat << EOF

    Options:
    -p|--path [value]             Project path relative to the current directory (optional, current directory by default)
    -v|--version [value]          Unity version (optional, autodetected by default from project settings)
    -u [value]                    Path to directory where Unity versions are installed (default: $BASEUNITYPATH)
    --unity                       Path to Unity executable
EOF

  usage_platforms

  cat << EOF

    Batch mode:
    -q|--quit                     Run Unity with -quit flag
    -b|--batch                    Runs Unity in -batchmode mode. The default method name is BuildHelp.BuildIt_[TARGET]_[CONFIGURATION]. 
                                  Use -e to set the method name, or -d/-r/-c to use the default name with a specific configuration.
                                  Implies -q

    -d|--debug                    Used with -b, sets the method to BuildHelp.BuildIt_[TARGET]_Dev
    -r|--release                  Used with -b, sets the method to BuildHelp.BuildIt_[TARGET]_Release
    -c|--configuration [value]    Used with -b, sets the method to BuildHelp.BuildIt_[TARGET]_[CONFIGURATION], where CONFIGURATION is what you set here.
    -e|--method [value]           Run Unity by invoking a method and exiting. Implies -q.

    Cache server:
    -z|--cache [value]            IP or hostname of unity accelerator
    -v1                           Use cache server v1
    -v2                           Use cache server v2 (accelerator)
EOF
}

while (( "$#" )); do
  case "$1" in
    -d|--debug)
      CONFIGURATION="Dev"
      shift
    ;;
    -r|--release)
      CONFIGURATION="Release"
      shift
    ;;
    -b|--build)
      BATCH=1
      QUIT=1
      shift
    ;;
    -c)
      shift
      CONFIGURATION=$1
      shift
    ;;
    -v|--version)
      shift
      UNITYVERSION="$1"
      shift
    ;;
    -p|--path)
      shift
      PROJECTPATH="${DIR}/${1}"
      shift
    ;;
    -x|--xbox)
      TARGET=XboxOne
      shift
    ;;
    -s|--ps4)
      TARGET=PS4
      shift
    ;;
    -w|--windows)
      TARGET=Win64
      shift
    ;;
    -n|--switch)
      TARGET=Switch
      shift
    ;;
    -a|--android)
      TARGET=Android
      shift
    ;;
    -m|--mac)
      TARGET=Mac
      shift
    ;;
    -i|--ios)
      TARGET=iOS
      shift
    ;;
    -e|--method)
      shift
      METHOD=$1
      QUIT=1
      shift
    ;;
    -z|--cache)
      shift
      CACHESERVER="$1"
      shift
      ;;
    -u)
      shift
      BASEUNITYPATH="$1"
      shift
      ;;
    --unity)
      shift
      UNITYPATH="$1"
      shift
      ;;
    -q|--quit)
      QUIT=1
      shift
    ;;
    -v1)
      CACHEVERSION=1
      shift
    ;;
    -v2)
      CACHEVERSION=2
      shift
    ;;
    --nocache)
      CACHEVERSION=0
      shift
    ;;
    -h|--help)
      help
      exit 0
    ;;
    *)
    ARGS="$ARGS$(echo $1|xargs) "
    shift
    ;;
  esac
done

PROJECTPATH="$(echo "$PROJECTPATH" | $SED -E 's,/$,,')"

if [[ ! -d "${PROJECTPATH}/Assets" ]]; then
  echo "" >&2
  echo "Error: Invalid path ${PROJECTPATH}" >&2
  usage
  exit 1
fi

if [[ x"${UNITYPATH}" == x"" ]]; then
  if [[ x"${UNITYVERSION}" == x"" ]]; then
    UNITYVERSION="$( $CAT "$PROJECTPATH/ProjectSettings/ProjectVersion.txt" | $GREP "m_EditorVersion:" | $CUT -d' ' -f 2)"
  fi

  if [[ -d "${BASEUNITYPATH}/${UNITYVERSION}" ]]; then
    echo "Using Unity v$UNITYVERSION"
    UNITYPATH="${BASEUNITYPATH}/${UNITYVERSION}"
  else
    echo "" >&2
    echo "Error: Unity not found at ${BASEUNITYPATH}/${UNITYVERSION}" >&2
    echo "Install Unity v$UNITYVERSION or use a different version with -v" >&2
    usage
    exit -1 
  fi


  if [[ x"$OS" == x"Mac" ]]; then
    UNITYTOOLSPATH="$UNITYPATH/Unity.app/Contents/Tools"
    UNITYPATH="$UNITYPATH/Unity.app/Contents/MacOS"
  else
    UNITYTOOLSPATH="$UNITYPATH/Editor/Data/Tools"
    UNITYPATH="$UNITYPATH/Editor"
  fi
else
  UNITYTOOLSPATH="$UNITYPATH/Data/Tools"
fi

if [[ ! -d "${UNITYPATH}" ]]; then
  echo "" >&2
  echo "Error: Unity not found at ${UNITYPATH}" >&2
  usage
  exit 1
fi

if [[ ! -f "$UNITYTOOLSPATH/$BIN2TXT" ]]; then
  echo "Error: Unity not found at ${UNITYPATH}" >&2
  exit 1
fi

if [[ x"$TARGET" == x"" ]]; then

  EDITORUSERBUILDSETTINGS="$PROJECTPATH/Library/EditorUserBuildSettings.asset"
  BUILDSETTINGS="$DIR/buildsettings.txt"
  $RM -f "$BUILDSETTINGS" || true

  if [[ -e "$EDITORUSERBUILDSETTINGS" ]]; then

    "$UNITYTOOLSPATH/$BIN2TXT" "$EDITORUSERBUILDSETTINGS" "$BUILDSETTINGS" || true

    if [[ -e "$BUILDSETTINGS" ]]; then

      ACTIVETARGET="$( $CAT "$BUILDSETTINGS" | $GREP "m_ActiveBuildTarget " | CUT -d' ' -f 2)"
      $RM -f "$BUILDSETTINGS" || true

      case "$ACTIVETARGET" in
        2)
        TARGET=Mac
        ;;
        5)
        TARGET=Win
        ;;
        9)
        TARGET=iOS
        ;;
        13)
        TARGET=Android
        ;;
        19)
        TARGET=Win64
        ;;
        31)
        TARGET=PS4
        ;;
        33)
        TARGET=XboxOne
        ;;
        38)
        TARGET=Switch
        ;;
        *)
        echo "Error: Invalid target $ACTIVETARGET"
        exit 1
      esac

    else
      echo "" >&2
      echo "Error: Project has no active target, pass -w|-s|x to set one" >&2
      usage
      exit 1
    fi

  fi
fi

if [[ x"$TARGET" == x"" ]]; then
  echo "" >&2
  echo "Error: Project has no active target, pass a build target flag to set one" >&2
  usage
  usage_platforms
  exit 1
fi

if [[ x"$BATCH" == x"1" && x"$METHOD" == x"" ]]; then
  METHOD="BuildHelp.BuildIt_${TARGET}_${CONFIGURATION}"
fi

UNITY_ARGS="-disable-assembly-updater"

if [[ x"$CACHEVERSION" == x"1" ]]; then
  UNITY_ARGS="${UNITY_ARGS} -CacheServerIPAddress $CACHESERVER"
elif  [[ x"$CACHEVERSION" == x"2" ]]; then
  UNITY_ARGS="${UNITY_ARGS} -cacheServerEndpoint $CACHESERVER -adb2 -EnableCacheServer"
fi

if [[ x"$QUIT" == x"1" ]]; then
  UNITY_ARGS="${UNITY_ARGS} -quit"
fi

if [[ x"$BATCH" == x"1" ]]; then
  UNITY_ARGS="${UNITY_ARGS} -batchmode"
fi

if [[ x"$METHOD" != x"" ]]; then
  UNITY_ARGS="${UNITY_ARGS} -executeMethod ${METHOD}"
fi

UNITY_ARGS="${UNITY_ARGS} ${ARGS}"

LOGFOLDER="$PROJECTPATH/Logs"
LOGFILE="$LOGFOLDER/Editor.log"

echo "Opening project ${PROJECTPATH} with $UNITYVERSION : $TARGET"
echo "\"$UNITYPATH/Unity\" -buildTarget $TARGET -projectPath \"$PROJECTPATH\" -logFile \"$LOGFILE\" $UNITY_ARGS &"

read -n1 -r -p "Press space to continue..." key

if [[ x"$key" == x'' ]]; then

  SUBFILENAME=$( $DATE +%Y%m%d-%H%M%S )

  if [[ -e "$LOGFILE" ]]; then
      $CP "$LOGFILE" "$LOGFOLDER/Editor_$SUBFILENAME.log"
  fi

  "$UNITYPATH/Unity" -buildTarget $TARGET -projectPath "$PROJECTPATH" -logFile "$LOGFILE" $UNITY_ARGS &

fi

