#!/bin/bash
label=${1:-"controller"}
hosts=($(awk '/Host / {print $2}' ~/.ssh/config))
for host in ${hosts[@]}; do
    if ! [[ $host == *"$label"* ]]; then
        continue
    fi
    ssh -q $host -- rm -rf ~/api-proxy
done