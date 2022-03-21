#!/bin/bash -eu

# ------------------------------------------------------------
# Copyright (c) 2020, 2021, 2022 Andreia Gaita <shana@spoiledcat.net>
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
# folder where you stuff all your Unitys, pass in -u to set
BASEUNITYPATH="/Applications/Unity/Hub/Editor"

HUBPATH=""
OS="Mac"
BIN=""
UNITYTOOLSPATH=""
CONFIGURATION=Dev
BUILD=0
BATCH=0
PROJECTPATH=
TARGET=""
QUIT=0
METHOD=""
ARGS=""
UNITYPATH=""

if [[ -e "/c/" ]]; then
  OS="Windows"
fi

if [[ x"$OS" == x"Windows" ]]; then
  BIN="/usr/bin/"
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
  BASEUNITYPATH="/c/Program Files/Unity/Hub/Editor"
  BIN2TXT="${BIN2TXT}.exe"
fi

declare -A PLATFORMS
PLATFORMS=(\
    [2]=Mac [-m]=Mac [--mac]=Mac \
    [5]=Win32 [--win32]=Win32 \
    [9]=iOS [-i]=iOS [--mac]=iOS \
    [13]=Android [-a]=Android [--android]=Android \
    [19]=Win64 [-w]=Win64 [--windows]=Win64 \
    [20]=WebGL [-g]=WebGL [--webgl]=WebGL \
    [24]=Linux64 [-l]=Linux64 [--linux]=Linux64 \
    [31]=PS4 [-s]=PS4 [--ps4]=PS4 \
    [33]=XboxOne [-x]=XboxOne [--xbox]=XboxOne \
    [37]=tvOS [--tvos]=tvOS \
    [38]=Switch [-n]=Switch [--switch]=Switch \
    [40]=Stadia [--stadia]=Stadia \
    [42]=GameCoreScarlett [-xs]=GameCoreScarlett [--scarlett]=GameCoreScarlett [--xboxs]=GameCoreScarlett \
    [43]=GameCoreXboxOne [-xx]=GameCoreXboxOne [--xbox1gdk]=GameCoreXboxOne \
    [44]=PS5 [-5]=PS5 [--ps5]=PS5 \
)
declare -r PLATFORMS

function usage_platforms() {
  cat << EOF

    Build Targets (optional, autodetected from current project settings):
    -w|--windows                  Set build target to Win64
    -m|--mac                      Set build target to Mac
    -l|--linux                    Set build target to Linux
    -a|--android                  Set build target to Android
    -i|--ios                      Set build target to iOS
    -x|--xbox                     Set build target to Xbox One
    -s|--ps4                      Set build target to ps4
    -5|--ps5                      Set build target to ps5
    -n|--switch                   Set build target to Switch
    -g|--webgl                    Set build target to WebGL
    -xx|--xbox1gdk                Set build target to GameCore Xbox One
    -xs|--xboxs                   Set build target to GameCore Xbox Series S/X
    --tvos                        Set build target to tvOS
    --stadia                      Set build target to Stadia
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
    Use --trace to enable bash trace mode (see everything as it is executed)
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
    --v1                          Use cache server v1
    --v2                          Use cache server v2 (accelerator)
    --nocache                     Don't add any cache server parameters
EOF
}


function main() {

while (( "$#" )); do
  case "$1" in
    -d|--debug)
      CONFIGURATION="Dev"
    ;;
    -r|--release)
      CONFIGURATION="Release"
    ;;
    -b|--batch)
      BATCH=1
      QUIT=1
    ;;
    -b|--build)
      BUILD=1
      BATCH=1
      QUIT=1
    ;;
    -c)
      shift
      CONFIGURATION=$1
    ;;
    -v|--version)
      shift
      UNITYVERSION="$1"
    ;;
    -p|--path)
      shift
      PROJECTPATH="${DIR}/${1}"
    ;;
    -e|--method)
      shift
      METHOD=$1
      QUIT=1
    ;;
    -z|--cache)
      shift
      CACHESERVER="$1"
    ;;
    -u)
      shift
      BASEUNITYPATH="$1"
    ;;
    --unity)
      shift
      UNITYPATH="$1"
    ;;
    -q|--quit)
      QUIT=1
    ;;
    --noquit)
      QUIT=0
    ;;
    --v1)
      CACHEVERSION=1
    ;;
    --v2)
      CACHEVERSION=2
    ;;
    --nocache)
      CACHEVERSION=0
    ;;
    -h|--help)
      help
      exit 0
    ;;
    --trace)
     { set -x; } 2>/dev/null
    ;;
    *)
    # check if it's a platform flag, otherwise append it to the arguments
    if [[ ! -z ${PLATFORMS[$1]:-} ]]; then
      TARGET=${PLATFORMS[$1]}
    elif [[ -d $1 && ! -d $PROJECTPATH ]]; then
      PROJECTPATH=$(cd $1 && pwd)
    else
      ARGS="$ARGS$(echo $1|xargs) "
    fi
    ;;
  esac
  shift
done

if [[ ! -d $PROJECTPATH ]]; then
  $PROJECTPATH="$DIR"
fi

if [[ x"$OS" == x"Windows" ]]; then
  HUBPATH="$( echo ~/AppData/Roaming/UnityHub/ | xargs realpath )" || true
else
  HUBPATH="$( cd ~/Library/Application\ Support/UnityHub/ && pwd )" || true
fi

if [[ -d $HUBPATH ]]; then
  HUBPATH="$HUBPATH/secondaryInstallPath.json"
fi

if [[ -f $HUBPATH ]]; then
  tmp="$( $CAT "$HUBPATH" | $SED -E 's, ,\\ ,g' | $SED -E 's,",,g' )"
  if [[ x"$tmp" != x"" ]]; then
    BASEUNITYPATH="$tmp"
    if [[ x"$OS" == x"Windows" ]]; then
      BASEUNITYPATH="$( realpath $BASEUNITYPATH )"
    fi
  fi
fi

PROJECTPATH="$(echo "$PROJECTPATH" | $SED -E 's,/$,,')"

if [[ ! -d "${PROJECTPATH}/Assets" ]]; then
  echo "" >&2
  echo "Error: Invalid path ${PROJECTPATH}" >&2
  usage
  exit 1
fi

if [[ x"${UNITYPATH}" == x"" ]]; then
  if [[ x"${UNITYVERSION}" == x"" ]]; then
    if [[ -f "$PROJECTPATH/ProjectSettings/ProjectVersion.txt" ]]; then
      UNITYVERSION="$( $CAT "$PROJECTPATH/ProjectSettings/ProjectVersion.txt" | $GREP "m_EditorVersion:" | $CUT -d' ' -f 2)"
    else
      echo "" >&2
      echo "Error: No Unity version detected in project." >&2
      echo "Set which Unity to use with -v" >&2
      usage
      exit -1 
    fi
  else
    if [[ ! -d "${BASEUNITYPATH}/${UNITYVERSION}" && -d "${BASEUNITYPATH}/${UNITYVERSION}f1" ]]; then
      UNITYVERSION="${UNITYVERSION}f1"
    fi
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
LOGFOLDER="$PROJECTPATH/Logs"
LOGFILE="$LOGFOLDER/Editor.log"

if [[ x"$TARGET" == x"" ]]; then

  EDITORUSERBUILDSETTINGS="$PROJECTPATH/Library/EditorUserBuildSettings.asset"
  BUILDSETTINGS="$DIR/buildsettings.txt"
  $RM -f "$BUILDSETTINGS" || true

  if [[ -e "$EDITORUSERBUILDSETTINGS" ]]; then

    "$UNITYTOOLSPATH/$BIN2TXT" "$EDITORUSERBUILDSETTINGS" "$BUILDSETTINGS" || true

    if [[ -e "$BUILDSETTINGS" ]]; then

      ACTIVETARGET="$( $CAT "$BUILDSETTINGS" | $GREP "m_ActiveBuildTarget " | CUT -d' ' -f 2)"
      $RM -f "$BUILDSETTINGS" || true

      TARGET=${PLATFORMS[$ACTIVETARGET]}

      if [[ x"$TARGET" == x"" ]]; then
        echo "Error: Invalid target $ACTIVETARGET"
        exit 1
      fi

    else
      echo "" >&2
      echo "Error: Project has no active target, pass one of the platform flags to set one" >&2
      usage
      usage_platforms
      exit 1
    fi

  fi
fi

if [[ x"$TARGET" == x"" ]]; then
  echo "" >&2
  echo "Error: Project has no active target, pass one of the platform flags to set one" >&2
  usage
  usage_platforms
  exit 1
fi

if [[ x"$BUILD" == x"1" && x"$METHOD" == x"" ]]; then
  METHOD="BuildHelp.BuildIt_${TARGET}_${CONFIGURATION}"
fi

UNITY_ARGS="-disable-assembly-updater"

if [[ x"$CACHEVERSION" == x"1" ]]; then
  UNITY_ARGS="${UNITY_ARGS} -CacheServerIPAddress $CACHESERVER"
elif  [[ x"$CACHEVERSION" == x"2" ]]; then
  UNITY_ARGS="${UNITY_ARGS} -cacheServerEndpoint $CACHESERVER -adb2 -EnableCacheServer"
fi

if [[ x"$BATCH" == x"1" ]]; then
  UNITY_ARGS="${UNITY_ARGS} -batchmode"
fi


if [[ x"$QUIT" == x"1" ]]; then
  UNITY_ARGS="${UNITY_ARGS} -quit"
fi

if [[ x"$METHOD" != x"" ]]; then
  UNITY_ARGS="${UNITY_ARGS} -executeMethod ${METHOD}"
fi

UNITY_ARGS="${UNITY_ARGS} ${ARGS}"


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

}

main "$@"