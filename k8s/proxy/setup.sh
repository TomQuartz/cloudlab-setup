#!/bin/bash
BASE_DIR=`realpath $(dirname $0)`
cd $BASE_DIR

CONTROLLER_LABEL=${1:-"controller"}
API_VIP=${2:-"10.10.1.100"}
API_DEST_PORT=${3:-"6334"}
API_SRC_PORT=${4:-"6443"}
HOSTS=`grep "$CONTROLLER_LABEL" /etc/hosts | awk '{print $NF}'`

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
    ssh -q $host -- mkdir -p ~/k8s/proxy && rm -rf ~/k8s/proxy/conf
    scp -r conf $host:~/k8s/proxy
    ssh -q $host -- sudo mkdir -p /etc/kubernetes /etc/keepalived /etc/haproxy
    ssh -q $host -- sudo cp ~/k8s/proxy/conf/keepalived.conf /etc/keepalived/
    ssh -q $host -- sudo cp ~/k8s/proxy/conf/check_apiserver.sh /etc/keepalived/
    ssh -q $host -- sudo cp ~/k8s/proxy/conf/haproxy.cfg /etc/haproxy/
    ssh -q $host -- sudo systemctl restart keepalived
    ssh -q $host -- sudo systemctl restart haproxy
done
