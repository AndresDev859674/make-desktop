#!/bin/bash

CACHE_FILE="$HOME/.cache/make-desktop-last.txt"
TARGET_DIR="$HOME/.local/share/applications"

# Arrays to store regional entries dynamically
declare -a REGIONAL_NAMES
REGIONAL_COUNT=0

declare -a REGIONAL_GENERICS
REGIONAL_GEN_COUNT=0

declare -a REGIONAL_COMMENTS
REGIONAL_COMM_COUNT=0

# Arrays to keep track of defined actions
declare -a ACTION_IDS
ACTION_COUNT=0

show_help() {
    cat << EOF
Usage: $(basename "$0") [EXECUTABLE] [OPTIONS]
       $(basename "$0") -d <desktop_file_name>
       $(basename "$0") -dl

A CLI script you can use doesn't waste your time simply creating a .desktop file for application desktop entries (sorry arch users).

Arguments:
  EXECUTABLE               Path to the executable binary or script.

Options:
  -i,  --icon <path>       Specify an absolute or relative path to an icon image.
  -n,  --name <string>     Override the default application name displayed in the menu.
  -gn, --generic-name <st> Set a generic description of the app (e.g., 'Web Browser').
  -rn, --regional-name <l> <str> Add a localized name for a specific language code.
  -rgn,--regional-generic-name <l> <str> Add a localized generic name for a language code.
  -c,  --comment <str>     Add a description/comment to the launcher (hidden if omitted).
  -rc, --regional-comment <l> <str> Add a localized comment/description for a language code.
  -ib, --icon-binary       Attempt to use the binary's name itself as the icon theme name.
  -ca, --categories <str>   Set the XDG categories (defaults to 'Utility;Development;').
                           Use "none" to completely omit the Categories field.
  -mt, --mime-type <str>   Add supported MimeTypes (e.g., 'text/html;image/png;').
  -nd, --no-display        Hide the launcher from application menus (NoDisplay=true).
  -t,  --terminal          Run the application inside a terminal window (Terminal=true).
  -v,  --version <str>     Set the application version (defaults to '1.0').
  -h,  --help              Display this help menu and exit.

Desktop Actions Options (Quick Menu / Right-Click):
  -a,  --action <id>       Register a new action ID (e.g., 'new-window').
  -an, --action-name <id> <str> Set the main display name for a specific action.
  -ran,--regional-action-name <id> <l> <str> Add a localized action name for a language code.
  -ae, --action-exec <id> <cmd> Set the command to execute for a specific action.

Management Options:
  -d,  --delete <name>     Delete a specific desktop file by its name (e.g., 'palemoon-bin').
  -dl, --delete-latest     Delete the last .desktop file created by this script.

Standard XDG Categories (for -ca / --categories):
  AudioVideo, Development, Education, Game, Graphics, Network, Office,
  Science, Settings, System, Utility

Examples:
  $(basename "$0") ./palemoon/palemoon -n "Pale Moon" -gn "Web Browser" -rgn de "Web-Browser" -ca Network
  $(basename "$0") ./my-script.sh -n "My Script" -t -c "Interactive terminal script"
  $(basename "$0") ./browser-name -n "My Browser" -v "1.0.0" -a "new-tab" -an "new-tab" "New Tab" -ran "new-tab" es "Nueva pestaña" -ae "new-tab" "./browser-name --new-tab"
  $(basename "$0") -d palemoon
EOF
    exit 0
}

# Handle absolute deletion features before checking for EXECUTABLE
if [[ "$1" == "-dl" || "$1" == "--delete-latest" ]]; then
    if [ -f "$CACHE_FILE" ]; then
        LAST_CREATED=$(cat "$CACHE_FILE")
        if [ -f "$LAST_CREATED" ]; then
            rm "$LAST_CREATED"
            echo "Removed latest desktop file: $LAST_CREATED"
            rm "$CACHE_FILE"
        else
            echo "Error: The last recorded file ($LAST_CREATED) no longer exists."
        fi
    else
        echo "No history found. Nothing to delete."
    fi
    exit 0
fi

if [[ "$1" == "-d" || "$1" == "--delete" ]]; then
    if [ -z "$2" ]; then
        echo "Error: Please specify the name of the desktop shortcut to delete."
        exit 1
    fi
    DEL_NAME=$(basename "$2" .desktop)
    DEL_TARGET="$TARGET_DIR/$DEL_NAME.desktop"

    if [ -f "$DEL_TARGET" ]; then
        rm "$DEL_TARGET"
        echo "Successfully deleted: $DEL_TARGET"
    else
        echo "Error: Shortcut '$DEL_NAME.desktop' not found in $TARGET_DIR"
    fi
    exit 0
fi

# Show help if no arguments or help flag passed
if [[ -z "$1" || "$1" == "-h" || "$1" == "--help" ]]; then
    show_help
fi

# Core logic: Process the mandatory executable path
EXEC_PATH=$(realpath "$1")
if [ ! -f "$EXEC_PATH" ]; then
    echo "Warning: Executable target '$1' does not exist right now, writing path anyway."
fi

APP_NAME=$(basename "$EXEC_PATH")
GENERIC_NAME=""
ICON_PATH=""
USE_BINARY_ICON=false
APP_COMMENT=""
APP_CATEGORIES="Utility;Development;"
APP_VERSION="1.0"
APP_MIME=""
NO_DISPLAY=false
USE_TERMINAL=false

shift # Move past executable
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -i|--icon)
            if [ -n "$2" ]; then ICON_PATH=$(realpath "$2"); shift; else echo "Error: Missing arg for $1"; exit 1; fi ;;
        -n|--name)
            if [ -n "$2" ]; then APP_NAME="$2"; shift; else echo "Error: Missing arg for $1"; exit 1; fi ;;
        -gn|--generic-name)
            if [ -n "$2" ]; then GENERIC_NAME="$2"; shift; else echo "Error: Missing arg for $1"; exit 1; fi ;;
        -rn|--regional-name)
            if [ -n "$2" ] && [ -n "$3" ]; then
                REGIONAL_NAMES[$REGIONAL_COUNT]="Name[$2]=$3"
                ((REGIONAL_COUNT++)); shift 2
            else echo "Error: $1 requires language and string."; exit 1; fi ;;
        -rgn|--regional-generic-name)
            if [ -n "$2" ] && [ -n "$3" ]; then
                REGIONAL_GENERICS[$REGIONAL_GEN_COUNT]="GenericName[$2]=$3"
                ((REGIONAL_GEN_COUNT++)); shift 2
            else echo "Error: $1 requires language and string."; exit 1; fi ;;
        -c|--comment)
            if [ -n "$2" ]; then APP_COMMENT="$2"; shift; else echo "Error: Missing arg for $1"; exit 1; fi ;;
        -rc|--regional-comment)
            if [ -n "$2" ] && [ -n "$3" ]; then
                REGIONAL_COMMENTS[$REGIONAL_COMM_COUNT]="Comment[$2]=$3"
                ((REGIONAL_COMM_COUNT++)); shift 2
            else echo "Error: $1 requires language and string."; exit 1; fi ;;
        -ca|--categories)
            if [ -n "$2" ]; then
                if [ "$2" == "none" ]; then APP_CATEGORIES="none"
                elif [[ "$2" == *";" ]]; then APP_CATEGORIES="$2"
                else APP_CATEGORIES="$2;"; fi
                shift
            else echo "Error: Missing arg for $1"; exit 1; fi ;;
        -mt|--mime-type)
            if [ -n "$2" ]; then
                if [[ "$2" == *";" ]]; then APP_MIME="$2"
                else APP_MIME="$2;"; fi
                shift
            else echo "Error: Missing arg for $1"; exit 1; fi ;;
        -nd|--no-display)
            NO_DISPLAY=true ;;
        -t|--terminal)
            USE_TERMINAL=true ;;
        -v|--version)
            if [ -n "$2" ]; then APP_VERSION="$2"; shift; else echo "Error: Missing arg for $1"; exit 1; fi ;;
        -ib|--icon-binary)
            USE_BINARY_ICON=true ;;

        # Desktop Actions
        -a|--action)
            if [ -n "$2" ]; then
                ACTION_IDS[$ACTION_COUNT]="$2"
                ((ACTION_COUNT++))
                shift
            else echo "Error: Missing action ID for $1"; exit 1; fi ;;
        -an|--action-name)
            if [ -n "$2" ] && [ -n "$3" ]; then
                clean_id=$(echo "$2" | tr '[:space:]-' '__')
                eval "ACTION_NAME_${clean_id}=\"\$3\""
                shift 2
            else echo "Error: $1 requires action ID and name string."; exit 1; fi ;;
        -ran|--regional-action-name)
            if [ -n "$2" ] && [ -n "$3" ] && [ -n "$4" ]; then
                clean_id=$(echo "$2" | tr '[:space:]-' '__')
                eval "ACTION_REG_${clean_id}+=\"Name[\$3]=\$4\n\""
                shift 3
            else echo "Error: $1 requires action ID, language code, and name string."; exit 1; fi ;;
        -ae|--action-exec)
            if [ -n "$2" ] && [ -n "$3" ]; then
                clean_id=$(echo "$2" | tr '[:space:]-' '__')
                if [[ "$3" == ./* ]]; then
                     cmd_base=$(echo "$3" | awk '{print $1}')
                     args_base=$(echo "$3" | cut -d' ' -f2-)
                     abs_cmd=$(realpath "$cmd_base")
                     if [ "$cmd_base" != "$args_base" ]; then
                         eval "ACTION_EXEC_${clean_id}=\"\\\"${abs_cmd}\\\" ${args_base}\""
                     else
                         eval "ACTION_EXEC_${clean_id}=\"\\\"${abs_cmd}\\\"\""
                     fi
                else
                     eval "ACTION_EXEC_${clean_id}=\"\$3\""
                fi
                shift 2
            else echo "Error: $1 requires action ID and execution string."; exit 1; fi ;;
        *)
            echo "Unknown option: $1"
            echo "Try '$(basename "$0") --help' for more information."
            exit 1 ;;
    esac
    shift
done

if [ "$USE_BINARY_ICON" = true ]; then ICON_PATH=$(basename "$EXEC_PATH"); fi

mkdir -p "$TARGET_DIR"
TARGET_FILE="$TARGET_DIR/$(basename "$EXEC_PATH").desktop"

# Generate Core Header
cat <<EOF > "$TARGET_FILE"
[Desktop Entry]
Type=Application
Version=$APP_VERSION
Name=$APP_NAME
EOF

if [ -n "$GENERIC_NAME" ]; then echo "GenericName=$GENERIC_NAME" >> "$TARGET_FILE"; fi
if [ ${#REGIONAL_NAMES[@]} -gt 0 ]; then
    for item in "${REGIONAL_NAMES[@]}"; do echo "$item" >> "$TARGET_FILE"; done
fi
if [ ${#REGIONAL_GENERICS[@]} -gt 0 ]; then
    for item in "${REGIONAL_GENERICS[@]}"; do echo "$item" >> "$TARGET_FILE"; done
fi

# Write central executable properties
cat <<EOF >> "$TARGET_FILE"
Exec="$EXEC_PATH"
Icon=$ICON_PATH
EOF

# Toggle dynamic Terminal property
if [ "$USE_TERMINAL" = true ]; then
    echo "Terminal=true" >> "$TARGET_FILE"
else
    echo "Terminal=false" >> "$TARGET_FILE"
fi

echo "StartupNotify=true" >> "$TARGET_FILE"

if [ "$NO_DISPLAY" = true ]; then echo "NoDisplay=true" >> "$TARGET_FILE"; fi
if [ "$APP_CATEGORIES" != "none" ]; then echo "Categories=$APP_CATEGORIES" >> "$TARGET_FILE"; fi
if [ -n "$APP_COMMENT" ]; then echo "Comment=$APP_COMMENT" >> "$TARGET_FILE"; fi
if [ ${#REGIONAL_COMMENTS[@]} -gt 0 ]; then
    for item in "${REGIONAL_COMMENTS[@]}"; do echo "$item" >> "$TARGET_FILE"; done
fi
if [ -n "$APP_MIME" ]; then echo "MimeType=$APP_MIME" >> "$TARGET_FILE"; fi

# Append the central Actions tracking line if any exist
if [ ${#ACTION_IDS[@]} -gt 0 ]; then
    ACTIONS_LINE="Actions="
    for id in "${ACTION_IDS[@]}"; do
        ACTIONS_LINE+="${id};"
    done
    echo "$ACTIONS_LINE" >> "$TARGET_FILE"
fi

# Generate individual blocks for each action at the absolute bottom
if [ ${#ACTION_IDS[@]} -gt 0 ]; then
    for id in "${ACTION_IDS[@]}"; do
        clean_id=$(echo "$id" | tr '[:space:]-' '__')

        eval "act_name=\$ACTION_NAME_${clean_id}"
        eval "act_exec=\$ACTION_EXEC_${clean_id}"
        eval "act_regs=\$ACTION_REG_${clean_id}"

        echo "" >> "$TARGET_FILE"
        echo "[Desktop Action $id]" >> "$TARGET_FILE"
        echo "Name=${act_name:-$id}" >> "$TARGET_FILE"

        if [ -n "$act_regs" ]; then
            echo -e -n "$act_regs" >> "$TARGET_FILE"
        fi

        echo "Exec=$act_exec" >> "$TARGET_FILE"
    done
fi

chmod +x "$TARGET_FILE"
mkdir -p "$(dirname "$CACHE_FILE")"
echo "$TARGET_FILE" > "$CACHE_FILE"

echo "Success! Shortcut created at: $TARGET_FILE"
# hiya, thanks for reading the code
