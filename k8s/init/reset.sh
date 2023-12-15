#!/bin/bash
CONTROLLER_LABEL=${1:-"controller"}
WORKER_LABEL=${2:-"worker"}

HOSTS=`grep -E "$CONTROLLER_LABEL|$WORKER_LABEL" /etc/hosts | awk '{print $NF}'`
for host in ${HOSTS[@]}; do
    ssh -q $host -- sudo kubeadm reset -f
    ssh -q $host -- sudo rm /etc/cni/net.d/*flannel*
    ssh -q $host -- rm -f ~/.kube/config
    ssh -q $host -- sudo iptables -F && sudo iptables -t nat -F && sudo iptables -t mangle -F && sudo iptables -X
done