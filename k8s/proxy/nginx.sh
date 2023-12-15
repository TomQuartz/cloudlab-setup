#!/bin/bash
BASE_DIR=`realpath $(dirname $0)`
cd $BASE_DIR

CONTROLLER_LABEL=${1:-"controller"}
API_DEST_PORT=${2:-"6443"}
API_SRC_PORT=${3:-"6443"}
HOSTS=`grep "$CONTROLLER_LABEL" /etc/hosts | awk '{print $NF}'`

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

# custom /etc/nginx/nginx.conf
CUSTOM_DIR=/etc/nginx/custom.d
INCLUDE_STATEMENT="include $CUSTOM_DIR/*.conf;"
sudo mkdir -p $CUSTOM_DIR
sudo cp conf/nginx.conf $CUSTOM_DIR/kube-api.conf
sudo cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.bak
sudo grep -qxF "$INCLUDE_STATEMENT" /etc/nginx/nginx.conf \
    || echo "$INCLUDE_STATEMENT" | sudo tee -a /etc/nginx/nginx.conf
sudo systemctl restart nginx