#!/bin/bash

CONTROLLER_LABEL=${1:-"controller"}

LOG_DIR=~/k8s/audit/log

MASTER_NAME=$(hostname)
CONTROLLERS=`grep "$CONTROLLER_LABEL" /etc/hosts | awk '{print $NF}'`
for controller in ${CONTROLLERS[@]}; do
    cp $LOG_DIR/audit-$controller.json $LOG_DIR/audit-$controller.bak.json
    sudo scp $controller:$LOG_DIR/audit.log $LOG_DIR/audit-$controller.json
    sudo chmod a+rw $LOG_DIR/audit-$controller.json
done