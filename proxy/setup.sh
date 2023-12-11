#!/bin/bash
BASE_DIR=`realpath $(dirname $0)`

# haproxy.cfg
if [ ! -f "$BASE_DIR/conf/haproxy.cfg"]; then
    echo "please fill in the haproxy.cfg template in $BASE_DIR/templates for haproxy"
fi

label=${1:-"controller"}
virtual_ip=${2:-"10.16.1.1"}

# check_apiserver.sh
APISERVER_VIP=$virtual_ip envsubst < $BASE_DIR/templates/check_apiserver.sh > $BASE_DIR/conf/check_apiserver.sh

# keepalived.conf
state=MASTER
priority=101

hosts=($(awk '/Host / {print $2}' ~/.ssh/config))
for host in ${hosts[@]}; do
    if ! [ $host == *"$label"* ]; then
        continue
    fi
    APISERVER_VIP=$virtual_ip STATE=$state PRIORITY=$priority \
        envsubst < $BASE_DIR/templates/keepalived.conf > $BASE_DIR/conf/keepalived.conf
    scp -r $BASE_DIR/conf $host:~/api-proxy
    ssh -q $host "sudo cp ~/api-proxy/conf/keepalived.conf /etc/keepalived/keepalived.conf"
    ssh -q $host "sudo cp ~/api-proxy/conf/check_apiserver.sh /etc/keepalived/check_apiserver.sh"
    ssh -q $host "sudo cp ~/api-proxy/conf/haproxy.cfg /etc/haproxy/haproxy.cfg"
    if [ $state == "MASTER" ]; then
        state=BACKUP
        priority=100
    fi
done