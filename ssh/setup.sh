#!/bin/bash

# keys
BASE_DIR=`realpath $(dirname $0)`
USER=`whoami`

HOSTS=`grep -v "localhost" /etc/hosts | awk '{print $NF}'`

for host in ${HOSTS[@]}; do
    addr=`grep $host /etc/hosts | awk '{print $1}'`
    echo "
Host $host
    Hostname $addr
    User $USER
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null" >> ~/.ssh/config
done

if [ ! -f ~/.ssh/id_rsa ]; then
    echo "please upload your key to ~/.ssh/id_rsa"
fi

chmod 600 ~/.ssh/config && chmod 700 ~/.ssh

for host in ${HOSTS[@]}; do
    scp ~/.ssh/id_rsa $host:~/.ssh/
    ssh -q $host -- chmod 600 ~/.ssh/id_rsa
    ssh -q $host -- sudo hostnamectl set-hostname $host
done