# open-unity.sh

This bash script opens a Unity project from the command line. I wrote this because I needed to redirect Unity's logs to a known, sane place, and not lose them every time Unity crashed or restarted. It kinda grew from there.

It can autodetect what the current build target is for a project, what Unity version is it set to, what Unity versions you have installed on your system, and it will try its best to open a project with the correct settings. It will also redirect Unity logs to a Logs folder in the project, and rotate them on every run, so no loga are ever lost.

Alternatively, you can use it to figure out what a project is set to, if you can't remember (I know I can't). It will ask for confirmation before actually running Unity, and show you the command line it will use to do it, so you can doublecheck things.

I run this on a git bash shell on Windows, and on Terminal (well, iTerm) on macOS. If you get weird errors on mac, make sure the script's line endings are set to LF (Linux), bash no like CRLF outside of Windows.

### Usage

Make sure the script is set to executable (`chmod +x open-unity.sh`) if you want to run it with `./open-unity.sh`, or run it with `sh open-unity.sh` otherwise.

`open-unity.sh [Options] [Build Target] [Batch mode flags] [other flags passed to Unity directly]`

#### Example

`./open-unity.sh -p [Path to Unity Project folder]`

#### Options

```
    -p|--path [value]             Project path relative to the current directory (optional, current directory by default)
    -v|--version [value]          Unity version (optional, autodetected by default from project settings)
    -u [value]                    Path to directory where Unity versions are installed (default: autodetected from Unity hub settings)
    --unity                       Path to Unity executable (if it really can't find your Unity installation)
```

#### Currently supported build targets

```
    -w|--windows                  Set build target to Win64
    -m|--mac                      Set build target to Mac
    -a|--android                  Set build target to Android
    -i|--ios                      Set build target to iOS
    -x|--xbox                     Set build target to xbox
    -s|--ps4                      Set build target to ps4
    -n|--switch                   Set build target to Switch
```

#### Batch mode flags

```
    -q|--quit                     Run Unity with -quit flag
    -b|--batch                    Runs Unity in -batchmode mode. The default method name is BuildHelp.BuildIt_[TARGET]_[CONFIGURATION]. 
                                  Use -e to set the method name, or -d/-r/-c to use the default name with a specific configuration.
                                  Implies -q

    -d|--debug                    Used with -b, sets the method to BuildHelp.BuildIt_[TARGET]_Dev
    -r|--release                  Used with -b, sets the method to BuildHelp.BuildIt_[TARGET]_Release
    -c|--configuration [value]    Used with -b, sets the method to BuildHelp.BuildIt_[TARGET]_[CONFIGURATION], where CONFIGURATION is what you set here.
    -e|--method [value]           Run Unity by invoking a method and exiting. Implies -q.
````

#### Cache server

```
    -z|--cache [value]            IP or hostname of unity accelerator
    -v1                           Use cache server v1
    -v2                           Use cache server v2 (accelerator)
```