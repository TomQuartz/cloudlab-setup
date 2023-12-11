#!/bin/bash

# keys
BASE_DIR=`realpath $(dirname $0)`
mkdir -p ~/.ssh && cat $BASE_DIR/cloudlab_rsa.pub >> ~/.ssh/authorized_keys
cp $BASE_DIR/cloudlab_rsa ~/.ssh/
chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys

# hosts
cat <<EOF | sudo tee -a /etc/hosts
$1
EOF

cat <<EOF | sudo tee -a ~/.ssh/config
$2
EOF