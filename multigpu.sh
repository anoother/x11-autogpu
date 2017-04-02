#!/bin/bash

set -u

OUTPUT_FILE="/etc/X11/xorg.conf.d/09-multigpu.conf"
SNIPPETS_FILE="/etc/multigpu.snippets"
ENUMERATE_UNIQUE_CARDS=0 # Enumeration not yet implemented
ACTION=$1

function get_config_snippet() {
    to_match="$@"
    while IFS= read line; do
        if [[ "$line" =~ ^[[:space:]]+ ]]; then
            # This is a config option
            if [ ! -z "$print_config" ]; then
                echo "$line"
            fi
        else
            # This is a new device section
            if [[ "$to_match" =~ $line ]]; then
                print_config=something
            else
                print_config=""
            fi
        fi
    done < "$SNIPPETS_FILE"
}

function generate_config() {
    pci_id=$1
    shift
    device_string="$@"
    echo "Section \"Device\""
    echo "    BusID       PCI:${pci_id}\""
    get_config_snippet $device_string
    echo 'EndSection'
    echo # newline
}

function main() {
    case $ACTION in
        noop)
            OUTPUT_FILE=/dev/stdout
            ;;
        uninstall)
            rm -v "$OUTPUT_FILE"
            ;;
        install|reinstall)
            :
            ;;
        *)
            echo "Please provide an option."
            ;;
    esac
    : > "$OUTPUT_FILE"
    cards="$(lspci | grep -E '^[0-9:.]+ VGA compatible controller')"
    echo "$cards" | while read card; do
        generate_config $card >> "$OUTPUT_FILE"
    done
}

main

