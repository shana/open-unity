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

ISMAC=1
ISWIN=
HUBPATH=""
OS="Mac"
BIN=""
UNITYTOOLSPATH=""
CONFIGURATION=Dev

BUILD=0
BATCH=0
QUIT=0
LICENSE=
LICRETURN=0
LISTVERSIONS=0
SWITCHVERSION=0
PRINT=0

PROJECTPATH=
TARGET=""
METHOD=""
ARGS=""
UNITYPATH=""

if [[ -e "/c/" ]]; then
  OS="Windows"
  ISMAC=
  ISWIN=1
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
MKDIR="mkdir -p"

if [[ x"$OS" == x"Windows" ]]; then
  BASEUNITYPATH="/c/Program Files/Unity/Hub/Editor"
  BIN2TXT="${BIN2TXT}.exe"
fi


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

    -ov|--open-version            List all available Unity versions for selection and open the project with the selected version
    -u [value]                    Path to directory where Unity versions are installed (default: $BASEUNITYPATH)
EOF
}

function help() {
  usage

  cat << EOF

    Options:
    -p|--path [value]             Project path relative to the current directory (optional, current directory by default)
    -v|--version [value]          Unity version (optional, autodetected by default from project settings)
    -lv|--list-versions           List all available Unity versions
    -ov|--open-version            List all available Unity versions for selection and open the project with the selected version
    -u [value]                    Path to directory where Unity versions are installed (default: $BASEUNITYPATH)
    --unity                       Path to Unity.exe executable
    --print                       Print the current version of Unity and the current build target that the project is set to.

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
    -k|--nocache                     Don't add any cache server parameters

    License management:
    -lic|--license                Select license to use, returning the current one first.
    -llist|--license-list         List configured licenses
    -lset|--license-set           Configure a license
    -lrem|--license-remove         Remove a configured license
    -lret|--license-return        Return the current license
EOF
}


function main() {

local ARGSONLY=0
while (( "$#" )); do
  if [[ x"$ARGSONLY" == x"1" ]]; then
    ARGS="${ARGS} $1"
    shift
    continue
  fi

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
    -k|--nocache)
      CACHEVERSION=0
    ;;
    -lv|--list-versions)
      LISTVERSIONS=1
    ;;
    -ov|--open-version)
      SWITCHVERSION=1
    ;;
    --print)
      PRINT=1
    ;;
    -lic|--license)
      LICENSE=0
      LICRETURN=1
      if [[ ${2:-0} == [1-9] ]]; then
        LICENSE=$2
        shift
      fi
    ;;
    -lset|--license-set)
      shift
      license_set $@
      exit 0
    ;;
    -llist|--license-list)
      shift
      license_list $@
      exit 0
    ;;
    -lrem|--license-remove)
      shift
      license_remove $@
      exit 0
    ;;
    -lret|--license-return)
      LICENSE=
      LICRETURN=1
      if [[ ${2:-0} == [1-9] ]]; then
        LICENSE=$2
        shift
      fi
    ;;
    -h|--help)
      help
      exit 0
    ;;
    --args)
      ARGSONLY=1
    ;;
    --trace)
     { set -x; } 2>/dev/null
    ;;
    *)
    # check if it's a platform flag, otherwise append it to the arguments
    local tmp=$(platforms "$1")
    if [[ ! -z $tmp ]]; then
      TARGET=$tmp
    elif [[ -d "$1" && x"$PROJECTPATH" == x"" ]]; then
      PROJECTPATH=$(cd $1 && pwd)
    else
      ARGS="${ARGS} $1"
    fi
    ;;
  esac
  shift
done

if [[ x"$PROJECTPATH" == x"" ]]; then
  PROJECTPATH="$DIR"
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

if [[ x"${LISTVERSIONS}" == x"1" ]]; then
  unityversions
  exit 0
fi

PROJECTPATH="$(echo "$PROJECTPATH" | $SED -E 's,/$,,')"

if [[ ! -d "${PROJECTPATH}/Assets" ]]; then
  echo "" >&2
  echo "Error: Invalid path ${PROJECTPATH}" >&2
  echo "Would you like to create a new project in ${PROJECTPATH}?"
  read -n1 -r -p "Press y to create a new project in ${PROJECTPATH}, or any key to cancel..." key
  if [[ x"$key" == x'y' ]]; then
    $MKDIR "${PROJECTPATH}/Assets"
  else
    usage
    exit 1
  fi
fi

if [[ x"${SWITCHVERSION}" == x"1" ]]; then
  unityversions
  local available=$(ls "$BASEUNITYPATH"|grep -v Hub)
  available=(${available})

  echo "Select a version, or enter to cancel"
  local selection=
  read -r selection
  if [[ x"${selection:-}"x =~ ^x[1-9]{1}[0-9]*x$ ]]; then
      selection=$((selection-1))
      UNITYVERSION=${available[selection]}
  else
    echo "Set which Unity to use with -v" >&2
    usage
    exit -1
  fi
fi

# print data about the project and exit
if [[ x"${PRINT}" == x"1" ]]; then
  if [[ -f "$PROJECTPATH/ProjectSettings/ProjectVersion.txt" ]]; then
    UNITYVERSION="$( $CAT "$PROJECTPATH/ProjectSettings/ProjectVersion.txt" | $GREP "m_EditorVersion:" | $CUT -d' ' -f 2)"
  fi

  local _latestunity=$(ls "$BASEUNITYPATH"|grep -v Hub|tail -n1)
  UNITYPATH="${BASEUNITYPATH}/${_latestunity}"
  if [[ x"$OS" == x"Mac" ]]; then
    UNITYTOOLSPATH="$UNITYPATH/Unity.app/Contents/Tools"
    UNITYPATH="$UNITYPATH/Unity.app/Contents/MacOS"
  else
    UNITYTOOLSPATH="$UNITYPATH/Editor/Data/Tools"
    UNITYPATH="$UNITYPATH/Editor"
  fi

  EDITORUSERBUILDSETTINGS="$PROJECTPATH/Library/EditorUserBuildSettings.asset"
  BUILDSETTINGS="$DIR/buildsettings.txt"
  $RM -f "$BUILDSETTINGS" || true
  TARGET="Not Set"

  if [[ -e "$EDITORUSERBUILDSETTINGS" ]]; then

    "$UNITYTOOLSPATH/$BIN2TXT" "$EDITORUSERBUILDSETTINGS" "$BUILDSETTINGS" || true

    if [[ -e "$BUILDSETTINGS" ]]; then

      ACTIVETARGET="$( $CAT "$BUILDSETTINGS" | $GREP "m_ActiveBuildTarget " | CUT -d' ' -f 2)"
      $RM -f "$BUILDSETTINGS" || true

      TARGET=$(platforms "$ACTIVETARGET")

      if [[ x"$TARGET" == x"" ]]; then
        TARGET=Unknown
      fi
    fi
  fi

  cat << EOF

    Project: ${PROJECTPATH}
    Unity version: ${UNITYVERSION}
    Build Target: ${TARGET}
EOF

  exit 0
fi


if [[ x"${UNITYPATH}" == x"" ]]; then
  if [[ x"${UNITYVERSION}" == x"" ]]; then
    if [[ -f "$PROJECTPATH/ProjectSettings/ProjectVersion.txt" ]]; then
      UNITYVERSION="$( $CAT "$PROJECTPATH/ProjectSettings/ProjectVersion.txt" | $GREP "m_EditorVersion:" | $CUT -d' ' -f 2)"
    else
      echo "" >&2
      echo "Error: No Unity version detected in project." >&2
      unityversions
      local available=$(ls "$BASEUNITYPATH"|grep -v Hub)
      available=(${available})

      echo "Select a version, or enter to cancel"
      local selection=
      read -r selection
      if [[ x"${selection:-}"x =~ ^x[1-9]{1}[0-9]*x$ ]]; then
        selection=$((selection-1))
        UNITYVERSION=${available[selection]}
      else
        echo "Set which Unity to use -v" >&2
        usage
        exit -1
      fi
    fi
  else
    if [[ ! -d "${BASEUNITYPATH}/${UNITYVERSION}" && -d "${BASEUNITYPATH}/${UNITYVERSION}f1" ]]; then
      UNITYVERSION="${UNITYVERSION}f1"
    fi
    if [[ ! -d "${BASEUNITYPATH}/${UNITYVERSION}" && -d "${BASEUNITYPATH}/${UNITYVERSION}f2" ]]; then
      UNITYVERSION="${UNITYVERSION}f2"
    fi
    if [[ ! -d "${BASEUNITYPATH}/${UNITYVERSION}" && -d "${BASEUNITYPATH}/${UNITYVERSION}f3" ]]; then
      UNITYVERSION="${UNITYVERSION}f3"
    fi
    if [[ ! -d "${BASEUNITYPATH}/${UNITYVERSION}" && -d "${BASEUNITYPATH}/${UNITYVERSION}f4" ]]; then
      UNITYVERSION="${UNITYVERSION}f4"
    fi
  fi

  if [[ -d "${BASEUNITYPATH}/${UNITYVERSION}" ]]; then
    echo "Using Unity v$UNITYVERSION"
    UNITYPATH="${BASEUNITYPATH}/${UNITYVERSION}"
  else
    echo "" >&2
    echo "Error: Unity not found at ${BASEUNITYPATH}/${UNITYVERSION}" >&2
    echo "Install Unity v$UNITYVERSION or use a different version with -ov or -v" >&2
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

      TARGET=$(platforms "$ACTIVETARGET")

      if [[ x"$TARGET" == x"" ]]; then
        echo "Error: Invalid target $ACTIVETARGET" >&2
        usage
        usage_platforms
        exit 1
      fi
    fi
  fi
fi

if [[ x"$TARGET" == x"" ]]; then
  echo "" >&2
  local currentplat=-w
  [[ ! -z $ISMAC ]] && currentplat=-m
  TARGET=$(platforms "$currentplat")
  echo "Project has no active target, defaulting to ${TARGET}" >&2
  echo "Pass one of the platform flags to set a specific platform." >&2
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

LOGFILE=$(printf %q "$LOGFILE")
UNITY_ARGS="${UNITY_ARGS} -logFile $LOGFILE"

if [[ x"$LICENSE" != x"" || x"$LICRETURN" == x"1" ]]; then

  if [[ ! -f ~/.spoiledcat/licenses.yaml ]]; then
    echo "There are no configured license"
    return 0
  fi
  eval $(parse_yaml ~/.spoiledcat/licenses.yaml "UL_")
  if [[ -z ${UL_licenses_:-} ]]; then
    echo "There are no configured license"
    return 0
  fi

  local onlyreturn=0

  if [[ x"$LICENSE" == x"" ]]; then
    onlyreturn=1
  fi

  if [[ $LICENSE != [1-9] ]]; then

    local action=""
    if [[ $onlyreturn == 1 ]]; then
      action="return? If they all share the same credentials, pick any."
    else
      action="switch to?"
    fi

    echo ""
    echo "Which license to you want to ${action}"
    license_select
  fi

  license=($(license_get $LICENSE))

  UNITY_ARGS_LICENSE="${UNITY_ARGS} -batchmode -quit -projectPath $TMPDIR -nographics -username ${license[0]} -password ${license[1]}"

  if [[ x"$LICRETURN" == x"1" ]]; then
    echo ""
    echo "Returning license first..."
    echo ""

    run_unity 1 ${UNITY_ARGS_LICENSE} -returnlicense
  fi

  if [[ $onlyreturn == 1 ]]; then
    return 0
  else
    echo ""
    run_unity 1 ${UNITY_ARGS_LICENSE} -serial ${license[2]}
  fi
fi

PROJECTPATH=$(printf %q "$PROJECTPATH")
UNITY_ARGS="${UNITY_ARGS} -buildTarget $TARGET -projectPath $PROJECTPATH ${ARGS}"

echo "Opening project ${PROJECTPATH} with $UNITYVERSION : $TARGET"
run_unity 0 $UNITY_ARGS

}

function run_unity {
  local wait=$1
  shift
  local args=$@

  echo "\"$UNITYPATH/Unity\" $args"
  read -n1 -r -p "Press space to continue..." key

  if [[ x"$key" != x'' ]]; then
    return
  fi

  SUBFILENAME=$( $DATE +%Y%m%d-%H%M%S )

  if [[ -e "$LOGFILE" ]]; then
      $CP "$LOGFILE" "$LOGFOLDER/Editor_$SUBFILENAME.log"
  fi

  { set +e; } 2>/dev/null
  if [[ $wait == 1 ]]; then
    $"$UNITYPATH/Unity" $args
  else
    "$UNITYPATH/Unity" $args &
  fi
  { set -e; } 2>/dev/null

  echo ""
  return 0
}

# ======= HELPERS ========== #

function unityversions() {
  local available=$(ls "$BASEUNITYPATH"|grep -v Hub)
  local availablecount=(${available#})
  availablecount=${#availablecount[@]}
  available=(${available})
  availablecount=$((availablecount-1))
  for i in `seq 0 $availablecount`; do
  echo "$((i+1))) ${available[$i]}"
  done
}

function platforms() {
  case $1 in
    2|-m|--mac) echo 'Mac';;
    5|--win32) echo 'Win32';;
    9|-i|--mac) echo 'iOS';;
    13|-a|--android) echo 'Android';;
    19|-w|--windows) echo 'Win64';;
    20|-g|--webgl) echo 'WebGL';;
    24|-l|--linux) echo 'Linux64';;
    31|-s|--ps4) echo 'PS4';;
    33|-x|--xbox) echo 'XboxOne';;
    37|--tvos) echo 'tvOS';;
    38|-n|--switch) echo 'Switch';;
    40|--stadia) echo 'Stadia';;
    42|-xs|--scarlett|--xboxs) echo 'GameCoreScarlett';;
    43|-xx|--xbox1gdk) echo 'GameCoreXboxOne';;
    44|-5|--ps5) echo 'PS5';;
    *) echo '';;
  esac
}

LIC_PLAT=("" General Switch PS4 PS5 "Xbox One" "Xbox S/X")

function license_select {
  licensecount=(${UL_licenses_#})
  licensecount=${#licensecount[@]}

  for i in `seq 1 $licensecount`; do
    local plat="UL_licenses_${i}_platform"
    local license="UL_licenses_${i}_license"
    echo "$i) ${!plat} => ${!license}"
  done

  local selection=
  read -r selection
  if [[ ${selection:-} == [1-9] ]]; then
      LICENSE=$selection
  fi
}

function license_get {
  local platform="UL_licenses_${1}_platform"
  local license="UL_licenses_${1}_license"
  local username="UL_licenses_${1}_username"
  local password="UL_licenses_${1}_password"
  printf '%q %q %q' "${!username}" "${!password}" "${!license}"
}


function license_set {

  cat << EOF
This will store a license key so you can switch licenses with the --license option, for the given platform.
Note: Unity requires passing the username, password and license key on the command line as plain text arguments in order to switch licenses.
The values set here are stored in plaintext in ~/.spoiledcat/licenses.yaml
EOF

  local continue
  echo ""
  read -n1 -r -p 'Continue? (Enter or Space to continue, or any other key to quit):' continue

  if [[ ! -z "$continue" ]]; then
    echo ""
    echo "Exiting"
    return
  fi


  local platform
  local user
  local pwd
  local license

  cat << EOF

Platform for this key:
EOF

  local count=${#LIC_PLAT[@]}
  count=$((count-1))
  for i in `seq 1 $count`; do
    cat << EOF
$i) ${LIC_PLAT[$i]}
EOF
  done

  local selection=
  read -r -p "Which selection? " selection

  if [[ ${selection:-} != [1-9] ]]; then
    echo ""
    echo "Exiting"
    return
  fi

  if [[ -z ${LIC_PLAT[$selection]:-} ]] ; then
    echo ""
    echo "Exiting"
    return
  fi

  local platform=${LIC_PLAT[$selection]}
  { set -u; } 2>/dev/null

  echo ""
  echo "Platform selected: $platform"

  echo ""
  read -r -p "Unity username: " username
  read -r -s -p "Unity password: " password
  echo ""
  read -r -p "Unity license key: " license
  echo ""

  $MKDIR ~/.spoiledcat
  if [[ -f ~/.spoiledcat/licenses.yaml ]]; then
    eval $(parse_yaml ~/.spoiledcat/licenses.yaml "UL_")

    if [[ -z ${UL_licenses_:-} ]]; then
      local entry=$(format_license_entry "$platform" "$username" "$password" "$license")
      cat > ~/.spoiledcat/licenses.yaml << EOF
licenses:
${entry}
EOF
    else
      lic_add_or_update "$platform" "$username" "$password" "$license"
    fi
  fi
}

function license_list() {
  if [[ ! -f ~/.spoiledcat/licenses.yaml ]]; then
    echo "There are no configured license"
    return 0
  fi

  eval $(parse_yaml ~/.spoiledcat/licenses.yaml "UL_")

  if [[ -z ${UL_licenses_:-} ]]; then
    echo "There are no configured license"
    return 0
  fi

  licensecount=(${UL_licenses_#})
  licensecount=${#licensecount[@]}
  for i in `seq 1 $licensecount`; do
    local platform="UL_licenses_${i}_platform"
    local license="UL_licenses_${i}_license"
    echo "${!platform} => ${!license}"
  done
}

function license_remove() {
  if [[ ! -f ~/.spoiledcat/licenses.yaml ]]; then
    echo "There are no configured license"
    return 0
  fi
  eval $(parse_yaml ~/.spoiledcat/licenses.yaml "UL_")
  if [[ -z ${UL_licenses_:-} ]]; then
    echo "There are no configured license"
    return 0
  fi

  cat <<EOF
Select the key to remove:
EOF

  licensecount=(${UL_licenses_#})
  licensecount=${#licensecount[@]}
  for i in `seq 1 $licensecount`; do
    local platform="UL_licenses_${i}_platform"
    local license="UL_licenses_${i}_license"
    echo "$i) ${!platform} => ${!license}"
  done

  local selection=
  read -r selection

  if [[ ${selection:-} == [1-9] ]]; then
    lic_remove $selection
  fi
}

function lic_remove() {
  local index=$1
  shift

  local yaml=""

  local licensecount=(${UL_licenses_#})
  licensecount=${#licensecount[@]}
  for i in `seq 1 $licensecount`; do
    local platform="UL_licenses_${i}_platform"
    platform=${!platform}
    if [[ $i == $index ]]; then
      echo "Removing $platform"
      continue
    fi
    local username="UL_licenses_${i}_username"
    username=${!username}
    local password="UL_licenses_${i}_password"
    password=${!password}
    local license="UL_licenses_${i}_license"
    license=${!license}

    local entry=$(format_license_entry "$platform" "$username" "$password" "$license")
    yaml=$(cat <<EOF
${yaml}
${entry}
EOF
)
  done

  cat > ~/.spoiledcat/licenses.yaml << EOF
licenses:
${yaml}
EOF

}

function lic_add_or_update() {
  local newplat=$1
  shift
  local newuser=$1
  shift
  local newpwd=$1
  shift
  local newkey=$1
  shift

  local yaml=""
  local found=

  local licensecount=(${UL_licenses_#})
  licensecount=${#licensecount[@]}
  for i in `seq 1 $licensecount`; do
    local platform="UL_licenses_${i}_platform"
    platform=${!platform}
    local username="UL_licenses_${i}_username"
    username=${!username}
    local password="UL_licenses_${i}_password"
    password=${!password}
    local license="UL_licenses_${i}_license"
    license=${!license}

    if [[ x"$platform" == x"$newplat" ]]; then
      found=1
      username=$newuser
      password=$newpwd
      license=$newkey
    fi
    local entry=$(format_license_entry "$platform" "$username" "$password" "$license")
    yaml=$(cat <<EOF
${yaml}
${entry}
EOF
)
  done

  if [[ -z $found ]]; then
    local entry=$(format_license_entry "$newplat" "$newuser" "$newpwd" "$newkey")
    yaml=$(cat <<EOF
${yaml}
${entry}
EOF
)
  fi

  cat > ~/.spoiledcat/licenses.yaml << EOF
licenses:
${yaml}
EOF

}

function format_license_entry() {
  local platform=$1
  shift
  local username=$1
  shift
  local password=$1
  shift
  local license=$1
  shift
  cat <<EOF
  - platform: ${platform}
    username: ${username}
    password: ${password}
    license: ${license}
EOF
}


# source: https://github.com/mrbaseman/parse_yaml.git

function parse_yaml {
   local prefix=${2:-}
   local separator=${3:-_}

   local indexfix
   # Detect awk flavor
   if awk --version 2>&1 | grep -q "GNU Awk" ; then
      # GNU Awk detected
      indexfix=-1
   elif awk -Wv 2>&1 | grep -q "mawk" ; then
      # mawk detected
      indexfix=0
   fi

   local s='[[:space:]]*' sm='[ \t]*' w='[a-zA-Z0-9_]*' fs=$(echo @|tr @ '\034') i='  '
   cat $1 | \
   awk -F$fs "{multi=0;
       if(match(\$0,/$sm\|$sm$/)){multi=1; sub(/$sm\|$sm$/,\"\");}
       if(match(\$0,/$sm>$sm$/)){multi=2; sub(/$sm>$sm$/,\"\");}
       while(multi>0){
           str=\$0; gsub(/^$sm/,\"\", str);
           indent=index(\$0,str);
           indentstr=substr(\$0, 0, indent+$indexfix) \"$i\";
           obuf=\$0;
           getline;
           while(index(\$0,indentstr)){
               obuf=obuf substr(\$0, length(indentstr)+1);
               if (multi==1){obuf=obuf \"\\\\n\";}
               if (multi==2){
                   if(match(\$0,/^$sm$/))
                       obuf=obuf \"\\\\n\";
                       else obuf=obuf \" \";
               }
               getline;
           }
           sub(/$sm$/,\"\",obuf);
           print obuf;
           multi=0;
           if(match(\$0,/$sm\|$sm$/)){multi=1; sub(/$sm\|$sm$/,\"\");}
           if(match(\$0,/$sm>$sm$/)){multi=2; sub(/$sm>$sm$/,\"\");}
       }
   print}" | \
   sed  -e "s|^\($s\)?|\1-|" \
       -ne "s|^$s#.*||;s|$s#[^\"']*$||;s|^\([^\"'#]*\)#.*|\1|;t1;t;:1;s|^$s\$||;t2;p;:2;d" | \
   sed -ne "s|,$s\]$s\$|]|" \
        -e ":1;s|^\($s\)\($w\)$s:$s\(&$w\)\?$s\[$s\(.*\)$s,$s\(.*\)$s\]|\1\2: \3[\4]\n\1$i- \5|;t1" \
        -e "s|^\($s\)\($w\)$s:$s\(&$w\)\?$s\[$s\(.*\)$s\]|\1\2: \3\n\1$i- \4|;" \
        -e ":2;s|^\($s\)-$s\[$s\(.*\)$s,$s\(.*\)$s\]|\1- [\2]\n\1$i- \3|;t2" \
        -e "s|^\($s\)-$s\[$s\(.*\)$s\]|\1-\n\1$i- \2|;p" | \
   sed -ne "s|,$s}$s\$|}|" \
        -e ":1;s|^\($s\)-$s{$s\(.*\)$s,$s\($w\)$s:$s\(.*\)$s}|\1- {\2}\n\1$i\3: \4|;t1" \
        -e "s|^\($s\)-$s{$s\(.*\)$s}|\1-\n\1$i\2|;" \
        -e ":2;s|^\($s\)\($w\)$s:$s\(&$w\)\?$s{$s\(.*\)$s,$s\($w\)$s:$s\(.*\)$s}|\1\2: \3 {\4}\n\1$i\5: \6|;t2" \
        -e "s|^\($s\)\($w\)$s:$s\(&$w\)\?$s{$s\(.*\)$s}|\1\2: \3\n\1$i\4|;p" | \
   sed  -e "s|^\($s\)\($w\)$s:$s\(&$w\)\(.*\)|\1\2:\4\n\3|" \
        -e "s|^\($s\)-$s\(&$w\)\(.*\)|\1- \3\n\2|" | \
   sed -ne "s|^\($s\):|\1|" \
        -e "s|^\($s\)\(---\)\($s\)||" \
        -e "s|^\($s\)\(\.\.\.\)\($s\)||" \
        -e "s|^\($s\)-$s[\"']\(.*\)[\"']$s\$|\1$fs$fs\2|p;t" \
        -e "s|^\($s\)\($w\)$s:$s[\"']\(.*\)[\"']$s\$|\1$fs\2$fs\3|p;t" \
        -e "s|^\($s\)-$s\(.*\)$s\$|\1$fs$fs\2|" \
        -e "s|^\($s\)-\?\($w-\?$w\?\)$s:$s[\"']\?\(.*\)$s\$|\1$fs\2$fs\3|" \
        -e "s|^\($s\)[\"']\?\([^&][^$fs]\+\)[\"']$s\$|\1$fs$fs$fs\2|" \
        -e "s|^\($s\)[\"']\?\([^&][^$fs]\+\)$s\$|\1$fs$fs$fs\2|" \
        -e "s|$s\$||p" | \
   awk -F$fs "{
      gsub(/\t/,\"        \",\$1);
      if(NF>3){if(value!=\"\"){value = value \" \";}value = value  \$4;}
      else {
        if(match(\$1,/^&/)){anchor[substr(\$1,2)]=full_vn;getline};
        indent = length(\$1)/length(\"$i\");
        vname[indent] = \$2;
        value= \$3;
        for (i in vname) {if (i > indent) {delete vname[i]; idx[i]=0}}
        if(length(\$2)== 0){  vname[indent]= ++idx[indent] };
        vn=\"\"; for (i=0; i<indent; i++) { vn=(vn)(vname[i])(\"$separator\")}
        vn=\"$prefix\" vn;
        full_vn=vn vname[indent];
        if(vn==\"$prefix\")vn=\"$prefix$separator\";
        if(vn==\"_\")vn=\"__\";
      }
      assignment[full_vn]=value;
      if(!match(assignment[vn], full_vn))assignment[vn]=assignment[vn] \" \" full_vn;
      if(match(value,/^\*/)){
         ref=anchor[substr(value,2)];
         if(length(ref)==0){
            data[full_vn]=value;
           #printf(\"%s=\\\"%s\\\"\n\", full_vn, value);
         } else {
           for(val in assignment){
              if((length(ref)>0)&&index(val, ref)==1){
                 tmpval=assignment[val];
                 sub(ref,full_vn,val);
                 if(match(val,\"$separator\$\")){
                    gsub(ref,full_vn,tmpval);
                 } else if (length(tmpval) > 0) {
                    #printf(\"%s=\\\"%s\\\"\n\", val, tmpval);
                    data[val]=tmpval;
                 }
                 assignment[val]=tmpval;
              }
           }
         }
      } else if (length(value) > 0) {
         if (match(value,/:/)){
            sep=\":\";
            vn=substr(value,0,index(value,sep)-1);
            value=substr(value,index(value,sep)+1);
            gsub(/^[ \t\r\n]+/, \"\",value);
            base_vn=full_vn;
            full_vn=full_vn \"$separator\" vn;
            base_vn=base_vn \"$separator\";
            #printf(\"%s=\\\"%s\\\"\n\", full_vn, value);
            data[full_vn]=value;
            #if(!match(assignment[base_vn], full_vn))assignment[base_vn]=assignment[base_vn] \" \" full_vn;
         } else {
            #printf(\"%s=\\\"%s\\\"\n\", full_vn, value);
            data[full_vn]=value;
         }
      }
   }END{
      for(val in data){
         printf(\"%s=\\\"%s\\\"\n\", val, data[val]);
         value=val
         a=gsub(/_[a-zA-Z0-9]+$/,\"\",val);
         key=val \"$separator\"
         if (!match(keys[key], value))keys[key]=keys[key] \" \" value;
         while(a>0) {
            value=val
            a=gsub(/_[a-zA-Z0-9]+$/,\"\",val);
            ix=index(val,\"$separator\");
            if (ix>=0) {
               key=val \"$separator\"
               if (!match(keys[key], value))keys[key]=keys[key] \" \" value \"$separator\";
            }
         }
      }
      for(key in keys) {
         printf(\"%s=\\\"%s\\\"\n\", key, keys[key]);
      }
   }"
}


main "$@"
