#!/usr/bin/env bash
# Script to control EasyEffects via Polybar with the saved presets.

####################################################################
# Polybar EasyEffects Presets                                      #
# https://github.com/marioortizmanero/polybar-easyeffects-presets  #
####################################################################

SAVE_FILE="$HOME/.config/easyeffects_preset"
# shellcheck disable=SC2016
FORMAT='$PRESET'
NO_PRESET_NAME=None
MODE=Output

function getCurPreset() {
    unset PRESET POSITION TOTAL
    if [ -f "$SAVE_FILE" ]; then
        # shellcheck disable=2034
        PRESET=$(sed -n '1p' < "$SAVE_FILE")
        # shellcheck disable=2034
        POSITION=$(sed -n '2p' < "$SAVE_FILE")
        # shellcheck disable=2034
        TOTAL=$(sed -n '3p' < "$SAVE_FILE")
    fi
}

# The name, position and total number of presets are saved into the save file
# to print them later on.
function setCurPreset() {
    local name position total
    name=$1
    position=$(($2 + 1))
    total=$3

    easyeffects --load-preset "$name" &>/dev/null &
    echo -e "$name\n$position\n$total" > "$SAVE_FILE"
}

function show() {
    getCurPreset
    if [ -z "$PRESET" ]; then
        PRESET="$NO_PRESET_NAME"
    fi

    eval echo "$FORMAT"
}

# Switches to the next ($1 = "next") or previous ($1 = "prev") preset available.
function updatePreset() {
    local mode=$1

    # Obtaining the presets available
    IFS="," read -r -a presets <<< "$(easyeffects --presets 2>&1 | grep "$MODE Presets:" | sed 's/^.\+: //')"
    local numPresets=${#presets[@]}

    # If the resulting list is empty, nothing is done
    if [ "$numPresets" -eq 0 ]; then return; fi

    # Iterate the available presets and set the next one
    getCurPreset
    local newIndex newPreset
    for i in "${!presets[@]}"; do
        if [ "$PRESET" = "${presets[$i]}" ]; then
            if [ "$mode" = "next" ]; then
                newIndex=$(((i + 1) % numPresets))
            else
                newIndex=$(((i - 1) % numPresets))
            fi
            newPreset=${presets[$newIndex]}

            break
        fi
    done

    # Otherwise just use the first preset
    if [ -z "$newPreset" ]; then
        newPreset=${presets[0]}
    fi

    # The new preset is loaded and saved for the next run.
    setCurPreset "$newPreset" "$newIndex" "$numPresets"
}

function reset() {
    easyeffects --reset &
    rm -f "$SAVE_FILE"

    show
}

function usage() {
    echo "\
Usage: $0 [OPTIONS...] ACTION

Options:
  --format <string>
        Use a format string to control the output.
        Available variables:
        * \$PRESET
        * \$POSITION
        * \$TOTAL
        Default: $FORMAT
  --save-file <string>
        The script's save file's location for persistent data.
        Default: $SAVE_FILE
  --no-preset-name <string>
        What name to use when no preset is set.
        Default: $NO_PRESET_NAME
  --output,
  --input
        Whether to use output or input presets in this script
        Defaut: $MODE

Actions:
  help   display this message and exit
  show   print the EasyEffects status once
  next   switch to the next EasyEffects status available
  prev   switch to the previous EasyEffects status available
  reset  restore this script and EasyEffects to their initial states

Author:
    Mario Ortiz Manero
More info on GitHub:
    https://github.com/marioortizmanero/polybar-easyeffects-presets"
}

if ! pgrep -x easyeffects &>/dev/null; then
    echo "EasyEffects not running"
    exit 1
fi

while [[ "$1" = --* ]]; do
    unset arg
    unset val
    if [[ "$1" = *=* ]]; then
        arg="${1//=*/}"
        val="${1//*=/}"
        shift
    else
        arg="$1"
        # Support space-separated values, but also value-less flags
        if [[ "$2" != --* ]]; then
            val="$2"
            shift
        fi
        shift
    fi

    case "$arg" in
        --format)
            FORMAT="$val"
            ;;
        --save-file)
            SAVE_FILE="$val"
            ;;
        --no-preset-name)
            NO_PRESET_NAME="$val"
            ;;
        --output)
            MODE=Output
            ;;
        --input)
            MODE=Input
            ;;
        *)
            echo "Unrecognised option: $arg" >&2
            exit 1
            ;;
    esac
done

case "$1" in
    show)
        show
        ;;
    prev)
        updatePreset prev
        ;;
    next)
        updatePreset next
        ;;
    reset)
        reset
        ;;
    *)
        usage
        ;;
esac
