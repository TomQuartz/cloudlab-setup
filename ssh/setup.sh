#!/bin/bash

# keys
BASE_DIR=`realpath $(dirname $0)`
mkdir -p ~/.ssh && cat $BASE_DIR/cloudlab_rsa.pub >> ~/.ssh/authorized_keys
cp $BASE_DIR/cloudlab_rsa ~/.ssh/
chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys

# hosts
cat >> /etc/hosts <<EOF
$1
EOF

cat >> ~/.ssh/config <<EOF
$2
EOF