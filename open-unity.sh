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
QUIT=0
LICENSE=
LICRETURN=0

PROJECTPATH=
TARGET=""
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
MKDIR="mkdir -p"

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
    -licr|--license-return)
      LICENSE=
      LICRETURN=1
      if [[ ${2:-0} == [1-9] ]]; then
        LICENSE=$2
        shift
      fi
    ;;
    -lic|--license)
      LICENSE=0
      LICRETURN=1
      if [[ ${2:-0} == [1-9] ]]; then
        LICENSE=$2
        shift
      fi
    ;;
    --license-save)
      shift
      license_set $@
      exit 0
    ;;
    --license-list)
      shift
      license_list $@
      exit 0
    ;;
    --license-remove)
      shift
      license_remove $@
      exit 0
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
    elif [[ -d "$1" && ! -d "$PROJECTPATH" ]]; then
      PROJECTPATH=$(cd $1 && pwd)
    else
      ARGS="$ARGS$(echo $1|xargs) "
    fi
    ;;
  esac
  shift
done

if [[ ! -d $PROJECTPATH ]]; then
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

LOGFILE=$(printf %q "$LOGFILE")
UNITY_ARGS="${UNITY_ARGS} -logFile $LOGFILE"

UNITY_ARGS="${UNITY_ARGS} ${ARGS}"

if [[ x"$LICENSE" != x"" || x"$LICRETURN" == x"1" ]]; then

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

  declare -rA license=$(license_get $LICENSE)
  UNITY_ARGS_LICENSE="${UNITY_ARGS} -batchmode -quit -projectPath $TMPDIR -nographics -username ${license['username']} -password ${license['password']}"

  if [[ x"$LICRETURN" == x"1" ]]; then
    echo ""
    echo "Returning license first..."

    UNITY_ARGS_RETURN="${UNITY_ARGS_LICENSE} -returnlicense"
    run_unity 1 $UNITY_ARGS_RETURN
  fi

  if [[ $onlyreturn == 1 ]]; then
    return 0
  else
    echo ""
    echo ""
    echo "Activating new license... (don't worry about batchmode failure messages)"

    UNITY_ARGS_LICENSE="${UNITY_ARGS_LICENSE} -serial ${license['license']}"
    run_unity 1 $UNITY_ARGS_LICENSE
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

LIC_PLAT=(General Switch PS4 PS5 "Xbox One" "Xbox S/X")

function license_select {
  if [[ ! -f ~/.spoiledcat/licenses.yaml ]]; then
    echo "There are no configured license"
    return 0
  fi
  eval $(parse_yaml ~/.spoiledcat/licenses.yaml "UL_")
  if [[ -z ${UL_licenses_:-} ]]; then
    echo "There are no configured license"
    return 0
  fi

  declare -A licenses
  eval $(load_licenses "licenses" ${UL_licenses_})
  declare -a selections=()
  local i=0 j=0
  for key in "${licenses[@]}"; do
    i=$((i+1))
    local entry=(${key//◆/ })
    echo "$i) ${entry[0]} => ${entry[3]}"
    for j in "${!LIC_PLAT[@]}"; do
      if [[ ${entry[0]} == ${LIC_PLAT[$j]} ]];then
        selections[$i]=$((j+1))
      fi
    done

  done

  local selection=
  read -r selection
  if [[ ${selection:-} == [1-9] ]]; then
      LICENSE=${selections[$selection]}
  fi
}

function license_get {
  local key=$1
  key=$((key-1))

  if [[ ! -f ~/.spoiledcat/licenses.yaml ]]; then
    echo "There are no configured license"
    return 0
  fi
  eval $(parse_yaml ~/.spoiledcat/licenses.yaml "UL_")
  if [[ -z ${UL_licenses_:-} ]]; then
    echo "There are no configured license"
    return 0
  fi

  declare -A licenses
  eval $(load_licenses "licenses" ${UL_licenses_})

  local plat=${LIC_PLAT[$key]}

  local i=0
  for key in "${licenses[@]}"; do
    i=$((i+1))
    local entry=(${key//◆/ })
    if [[ ${entry[0]} == $plat ]]; then
      printf '(
        [username]=%q
        [password]=%q
        [license]=%q
      )' "${entry[@]:1}"
    fi
  done
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

  local i=0

  for key in "${!LIC_PLAT[@]}"; do
    i=$((i+1))
    cat << EOF
$i) ${LIC_PLAT[$key]}
EOF
  done

  local selection=
  read -r -p "Which selection? " selection

  if [[ ${selection:-} != ?(-)+([0-9]) ]]; then
    echo ""
    echo "Exiting"
    return
  fi
  selection=$((selection-1))

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
      local entry=$(format_license_entry $platform $username $password $license)
      cat > ~/.spoiledcat/licenses.yaml << EOF
licenses:
${entry}
EOF
    else
      lic_add_or_update $platform $username $password $license ${UL_licenses_}
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

  lic_list ${UL_licenses_}
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

  declare -a licenses
  licenses=
  load_licenses "licenses" ${UL_licenses_}

  cat <<EOF
Select the key to remove:
EOF

  local i=0
  for key in "${licenses[@]}"; do
    i=$((i+1))
    local entry=(${key//◆/ })
    echo "$i) ${entry[0]} => ${entry[3]}"
  done

  local selection=
  read -r selection

  if [[ ${selection:-} == [1-9] ]]; then
    selection=$((selection-1))
    local entry=${licenses[$selection]}
    entry=(${key//◆/ })
    entry=${entry[0]}
    echo "Removing $entry"
    lic_remove $entry
  fi
}

function load_licenses() {
  local thing=$1
  shift
  while (( "$#" )); do
    var="${1}platform"
    local platform="${!var}"
    var="${1}username"
    local username="${!var}"
    var="${1}password"
    local password="${!var}"
    var="${1}license"
    local license="${!var}"
    shift
    printf '%q[%q]="%q◆%q◆%q◆%q";' "$thing" "$platform" "$platform" "$username" "$password" "$license"
  done
}

function lic_list() {
  while (( "$#" )); do
    var="${1}platform"
    local platform="${!var}"
    var="${1}license"
    local license="${!var}"
    shift
    echo "$platform => $license"
  done
}


function lic_remove() {
  local newplat=$1
  shift

  local yaml=""
  while (( "$#" )); do
    var="${1}platform"
    local platform="${!var}"
    var="${1}username"
    local username="${!var}"
    var="${1}password"
    local password="${!var}"
    var="${1}license"
    local license="${!var}"
    shift

    if [[ $platform == $newplat ]]; then
      continue
    fi

    local entry=$(format_license_entry $platform $username $password $license)
    yaml="${yaml}${entry}"

    shift
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

  while (( "$#" )); do
    var="${1}platform"
    local platform="${!var}"
    var="${1}username"
    local username="${!var}"
    var="${1}password"
    local password="${!var}"
    var="${1}license"
    local license="${!var}"
    shift

    if [[ $platform == $newplat ]]; then
      found=1
      username=$newuser
      password=$newpwd
      license=$newkey
    fi
    local entry=$(format_license_entry $platform $username $password $license)
    yaml=$(cat <<EOF
${yaml}
${entry}
EOF
)
  done

  if [[ -z $found ]]; then
    local entry=$(format_license_entry $newplat $newuser $newpwd $newkey)
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
