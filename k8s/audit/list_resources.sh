#!/bin/bash
APIS=$(kubectl get --raw /apis | jq -r '[.groups | .[].name] | join(" ")')

# do core resources first, which are at a separate api location
api="core"
kubectl get --raw /api/v1 | jq -r --arg api "$api" '.resources | .[] | "\($api) \(.name): \(.verbs | join(" "))"'

# now do non-core resources
for api in $APIS; do
    version=$(kubectl get --raw /apis/$api | jq -r '.preferredVersion.version')
    kubectl get --raw /apis/$api/$version | jq -r --arg api "$api" '.resources | .[]? | "\($api) \(.name): \(.verbs | join(" "))"'
done