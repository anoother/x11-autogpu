#!/bin/bash

set -u

OUTPUT_FILE="/etc/X11/xorg.conf.d/09-multigpu.conf"
SNIPPETS_FILE="/etc/multigpu.snippets"
ENUMERATE_UNIQUE_CARDS=0 # Enumeration not yet implemented
REVERSE_CARD_ORDER=1 # Reverse the order in which devices appear. Hacky.
ACTION=${1-}

sections=""
function generate_section() {
    heading=$1
    shift
    case $heading in
        Files|ServerFlags|Module|Extensions)
            merge_section=1
            ;;
        *)
            merge_section=0
            ;;
    esac


    case $1 in
        EndSection)
            if ((merge_section)); then
                section=$heading
            else
                i=$(echo "$sections" | grep $heading | tail -n1 | rev | cut -d'_' -f1 | rev)
                i+=1
                section="${heading}_${i}"
            fi
            sections="$sections\n$section"
            ;;
        *)
            line=$@
            #export section_${section}="section_${section}\n${line}"
            ;;
    esac

}

function get_config_snippet() {
    to_match="$@"
    section_heading=""
    while IFS= read line; do
        if [[ "$line" =~ ^[[:space:]]+ ]]; then
            if [[ "$line" =~ ^[[:space:]]+Section ]] || [ ! -z "$section_heading" ]; then
                # This is a top-level section
                section_heading=$(echo "$line" | grep -oE '".+"' | tr -d '"')
                generate_section $section_heading $line
                if [[ "$line" =~ ^[[:space:]]+EndSection ]]; then
                    # End of top-level section
                    section_heading=""
                fi
            else
                # This is a config option for the device
                if [ ! -z "$print_config" ]; then
                    echo "$line"
                fi
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
    pci_id=$(echo $1 | sed 's/\./:/')
    shift
    device_string="$@"
    echo "Section \"Device\""
    echo "    BusID       \"PCI:${pci_id}\""
    get_config_snippet $device_string
    echo "EndSection"
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
    if (($REVERSE_CARD_ORDER)); then
        cards=$(echo "$cards" | tac)
    fi
    echo "$cards" | while read card; do
        generate_config $card >> "$OUTPUT_FILE"
    done
    for section in "$sections"; do
        echo "Section ${section}" >> "$OUTPUT_FILE"
        echo "EndSection" >> "$OUTPUT_FILE"
    done
}

main
