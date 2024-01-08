#!/bin/bash
BASE_DIR=`realpath $(dirname $0)`
cd $BASE_DIR

API_VIP=${1:-"gateway1"} # must be the hostname of a node in the cluster
API_DEST_PORT=${2:-"8443"}
API_SRC_PORT=${3:-"6443"}
PROXY_LABEL=${4:-"controller"}

grep -qF "$API_VIP" /etc/hosts
if ! [ $? -eq 0 ]; then
    echo "must specify a valid hostname in the cluster as API_VIP"
    exit 1
fi

HOSTS=`grep "$PROXY_LABEL" /etc/hosts | awk '{print $NF}'`

mkdir -p conf

# backends
rm -f conf/backends.conf
for host in ${HOSTS[@]}; do
    addr=`grep $host /etc/hosts | awk '{print $1}'`
    echo "        server $host:$API_SRC_PORT;" >> conf/backends.conf
done

# nginx
APISERVER_DEST_PORT=$API_DEST_PORT envsubst < templates/nginx.conf > conf/nginx.conf
sed -i "/upstream/r conf/backends.conf" conf/nginx.conf

# customize /etc/nginx/nginx.conf
CUSTOM_DIR=/etc/nginx/custom.d
INCLUDE_STATEMENT="include $CUSTOM_DIR/*.conf;"

ssh -q $API_VIP -- mkdir -p ~/k8s/proxy/conf && rm -rf ~/k8s/proxy/conf/*
scp conf/nginx.conf $API_VIP:~/k8s/proxy/conf/
ssh -q $API_VIP -- sudo mkdir -p $CUSTOM_DIR
ssh -q $API_VIP -- sudo cp ~/k8s/proxy/conf/nginx.conf $CUSTOM_DIR/kube-api.conf
ssh -q $API_VIP -- sudo cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.bak
ssh -q $API_VIP -- "sudo grep -qxF \"${INCLUDE_STATEMENT}\" /etc/nginx/nginx.conf \\
                    || echo \"${INCLUDE_STATEMENT}\" | sudo tee -a /etc/nginx/nginx.conf"
ssh -q $API_VIP -- sudo systemctl restart nginx

exit 0