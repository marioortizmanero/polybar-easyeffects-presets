#!/usr/bin/env bash
# Script to control PulseEffects via Polybar with the saved presets.

####################################################################
# Polybar PulseEffects Presets                                     #
# https://github.com/marioortizmanero/polybar-pulseeffects-presets #
####################################################################

PRESET_FILE="$HOME/.config/pulseeffects_preset"
# shellcheck disable=SC2016
FORMAT='$PRESET'
NO_PRESET_NAME=None
MODE=Output

function getCurPreset() {
    unset curPreset
    if [ -f "$PRESET_FILE" ]; then
        curPreset=$(cat "$PRESET_FILE")
    fi
}

function setCurPreset() {
    echo "$1" > "$PRESET_FILE"
}

function show() {
    local PRESET

    getCurPreset
    if [ -n "$curPreset" ]; then
        PRESET="$curPreset"
    else
        # shellcheck disable=2034
        PRESET="$NO_PRESET_NAME"
    fi

    eval echo "$FORMAT"
}

# Switches to the next preset available.
function next() {
    local presets newPreset numPresets

    # Obtaining the presets available
    IFS="," read -r -a presets <<< $(pulseeffects --presets 2>&1 | grep "$MODE Presets:" | sed 's/^.\+: //')
    numPresets=${#presets[@]}

    # If the resulting list is empty, nothing is done
    if [ $numPresets -eq 0 ]; then return; fi

    # Iterate the available presets and set the next one
    getCurPreset
    for i in "${!presets[@]}"; do
        if [ "$curPreset" = "${presets[$i]}" ]; then
            local newIndex=$(((i + 1) % numPresets))
            newPreset=${presets[$newIndex]}

            break
        fi
    done

    # Otherwise just use the first preset
    if [ -z "$newPreset" ]; then
        newPreset=${presets[0]}
    fi

    # The new preset is loaded and saved for the next run.
    pulseeffects --load-preset "$newPreset" &>/dev/null &
    setCurPreset "$newPreset"

    show
}

function reset() {
    pulseeffects --reset &
    rm -f "$PRESET_FILE"

    show
}

function usage() {
    echo "\
Usage: $0 [OPTIONS...] ACTION

Options: [defaults]
  --format <string>            use a format string to control the output
                               Available variables: \$PRESET [$FORMAT]
  --config <string>            the script's save file's location [$PRESET_FILE]
  --no-preset-name <string>    what name to use when no preset is set
                               [$NO_PRESET_NAME]
  --output                     whether to use output or input presets in this
  --input                      script [$MODE]

Actions:
  help   display this message and exit
  show   print the PulseEffects status once
  next   switch to the next PulseEffects status available
  reset  restore this script and PulseEffects to their initial states"
}

if ! pgrep -x pulseeffects &>/dev/null; then
    echo ""
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
        --config)
            PRESET_FILE="$val"
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
    next)
        next
        ;;
    reset)
        reset
        ;;
    *)
        usage
        ;;
esac
