#!/bin/bash
BASE_DIR=`realpath $(dirname $0)`
cd $BASE_DIR

API_VIP=${1:-"10.10.1.100"}
API_DEST_PORT=${2:-"8443"}
API_SRC_PORT=${3:-"6443"}
PROXY_LABEL=${4:-"controller"}

HOSTS=`grep "$PROXY_LABEL" /etc/hosts | awk '{print $NF}'`

mkdir -p conf

# haproxy.cfg
APISERVER_DEST_PORT=$API_DEST_PORT envsubst < templates/haproxy.cfg > conf/haproxy.cfg
for host in ${HOSTS[@]}; do
    addr=`grep $host /etc/hosts | awk '{print $1}'`
    echo "        server $host $addr:$API_SRC_PORT check port $API_SRC_PORT inter 5s rise 2 fall 3" >> conf/haproxy.cfg
done
echo "" >> conf/haproxy.cfg

# check_apiserver.sh
APISERVER_VIP=$API_VIP APISERVER_DEST_PORT=$API_DEST_PORT \
    envsubst < templates/check_apiserver.sh > conf/check_apiserver.sh

# manifests for static pods haproxy, keepalived
mkdir -p manifests
cp templates/keepalived.yaml manifests/keepalived.yaml
APISERVER_DEST_PORT=$API_DEST_PORT envsubst < templates/haproxy.yaml > manifests/haproxy.yaml

# keepalived.conf
MASTER_NAME=$(hostname)
for host in ${HOSTS[@]}; do
    if [ $host == $MASTER_NAME ]; then
        STATE=MASTER
        PRIORITY=101
    else
        STATE=BACKUP
        PRIORITY=100
    fi
    echo "$host: $STATE"
    APISERVER_VIP=$API_VIP STATE=$STATE PRIORITY=$PRIORITY \
        envsubst < templates/keepalived.conf > conf/keepalived.conf
    ssh -q $host -- mkdir -p ~/k8s/proxy && rm -rf ~/k8s/proxy/conf ~/k8s/proxy/manifests
    scp -r conf manifests $host:~/k8s/proxy
    ssh -q $host -- sudo mkdir -p /etc/keepalived /etc/haproxy /etc/kubernetes/manifests
    ssh -q $host -- sudo cp ~/k8s/proxy/conf/keepalived.conf /etc/keepalived/
    ssh -q $host -- sudo cp ~/k8s/proxy/conf/check_apiserver.sh /etc/keepalived/
    ssh -q $host -- sudo cp ~/k8s/proxy/conf/haproxy.cfg /etc/haproxy/
    ssh -q $host -- sudo cp ~/k8s/proxy/manifests/* /etc/kubernetes/manifests/
done

exit 0