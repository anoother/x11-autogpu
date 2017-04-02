#!/bin/bash

cards="$(lspci | grep -E '^[0-9:.]+ VGA compatible controller')"

function generate_config() {
    id=$1
    echo $id
    shift
    echo $@
}

echo "$cards" | while read card; do
    generate_config $card
done
