#!/bin/bash

export OS=xUbuntu_22.04
export VERSION=1.28 # of k8s and cri-o

BASE_DIR=`realpath $(dirname $0)`

# firewall
ufw disable

sudo apt-get update
sudo apt-get install -y selinux-utils
setenforce 0  

# iptables and forwarding 
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

# sysctl params required by setup, params persist across reboots
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

# Apply sysctl params without reboot
sudo sysctl --system

# verify
lsmod | grep br_netfilter
lsmod | grep overlay
sysctl net.bridge.bridge-nf-call-iptables net.bridge.bridge-nf-call-ip6tables net.ipv4.ip_forward

# disable swap
swapoff -a
sed -ri 's/.*swap.*/#&/' /etc/fstab

# install cri-o v1.28
$BASE_DIR/install_crio.sh

# install k8s v1.28
$BASE_DIR/install_k8s.sh

sudo systemctl enable kubelet
sudo systemctl start kubelet

sudo apt-get install -y python3-pip
python3 -m pip install --upgrade pip