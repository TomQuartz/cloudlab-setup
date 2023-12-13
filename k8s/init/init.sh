BASE_DIR=`realpath $(dirname $0)`
cd $BASE_DIR

# sudo kubeadm init --apiserver-advertise-address=10.10.1.3 \
#                 --pod-network-cidr=10.244.0.0/16 \
#                 --control-plane-endpoint="10.10.1.100:6443" \
#   	          --ignore-preflight-errors=all \
#                 --v=4

sudo kubeadm init --config kubeadm-config.yaml --upload-certs | tee init.log
token=$(cat init.log | grep -oP '(?<=--token )[^\s]*' | head -n 1 | tee token)
token_hash=$(cat init.log | grep -oP '(?<=--discovery-token-ca-cert-hash )[^\s]*' | head -n 1 | tee token_hash)
cert_key=$(cat init.log | grep -oP '(?<=--certificate-key )[^\s]*' | head -n 1 | tee cert_key)

mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

kubectl apply -f kube-flannel.yaml

# hosts=($(awk '/Host / {print $2}' ~/.ssh/config))
# for host in ${hosts[@]}; do
#     if ! [[ $host == *"$label"* ]] || [ $host = $(hostname) ]; then
#         continue
#     fi

kubeadm join 10.10.1.100:6443 \
        --apiserver-advertise-address 10.10.1.2 \
        --token abcdef.0123456789abcdef \
        --discovery-token-ca-cert-hash sha256:9ba292b515c3cbcd4df5f2e2931d206508b0f8c8cda1532efd4b7a44780583f2 \
        --control-plane --certificate-key 341d1551ee47051ac7cd2ffae0ca6ef6fe1973e43534dfbbb36a0d261e26c13a

# kubeadm join 10.10.1.100:6443 --token abcdef.0123456789abcdef \
#         --discovery-token-ca-cert-hash sha256:9ba292b515c3cbcd4df5f2e2931d206508b0f8c8cda1532efd4b7a44780583f2

# TODO
# remove gateway
# reset + iptables