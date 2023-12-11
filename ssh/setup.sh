#!/bin/bash

# keys
BASE_DIR=`realpath $(dirname $0)`
USER=`whoami`
$BASE_DIR/config.py $USER >> ~/.ssh/config
chmod 600 ~/.ssh/config

if [ ! -f ~/.ssh/cloudlab_rsa ]; then
    echo "please generate a keypair and put it in ~/.ssh/cloudlab_rsa"
fi

hosts=($(awk '/Host / {print $2}' ~/.ssh/config))
for host in ${hosts[@]}; do
    scp ~/.ssh/cloudlab_rsa $host:~/.ssh/
    ssh -q $host "chmod 600 ~/.ssh/cloudlab_rsa"
done