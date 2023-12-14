BASE_DIR=`realpath $(dirname $0)`
cd $BASE_DIR

CONTROLLER_LABEL=${1:-"controller"}
WORKER_LABEL=${2:-"worker"}
API_VIP=${3:-"10.10.1.100"}

# haproxy + keepalived for api server
./proxy/setup.sh $CONTROLLER_LABEL $API_VIP

# api server auditting 
./audit/setup.sh $CONTROLLER_LABEL

MASTER_NAME=$(hostname)
MASTER_ADDR=$(grep $MASTER_NAME /etc/hosts | awk '{print $1}')

if ! [[ $MASTER_NAME == *"$CONTROLLER_LABEL"* ]]; then
    echo "must be running on a controller node"
    exit 1
fi

# kubeadm config
# --apiserver-advertise-address=$MASTER_ADDR
# --control-plane-endpoint=$API_VIP:6443
# --pod-network-cidr=10.244.0.0/16 (for flannel)
# --ignore-preflight-errors=all
mkdir -p conf && rm -f conf/*
MASTER_NAME=$MASTER_NAME MASTER_ADDR=$MASTER_ADDR HOME=$HOME APISERVER_VIP=$API_VIP \
        envsubst < templates/kubeadm-config.yaml > conf/kubeadm-config.yaml

sudo kubeadm init --config conf/kubeadm-config.yaml --upload-certs | tee init.log

TOKEN=$(cat init.log | grep -oP '(?<=--token )[^\s]*' | head -n 1 | tee conf/token)
TOKEN_HASH=$(cat init.log | grep -oP '(?<=--discovery-token-ca-cert-hash )[^\s]*' | head -n 1 | tee conf/token_hash)
CERT_KEY=$(cat init.log | grep -oP '(?<=--certificate-key )[^\s]*' | head -n 1 | tee conf/cert_key)

mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

kubectl apply -f templates/kube-flannel.yaml

CONTROLLERS=`grep "$CONTROLLER_LABEL" /etc/hosts | awk '{print $NF}'`
for controller in ${CONTROLLERS[@]}; do
    if [ $controller = $(hostname) ]; then
        continue
    fi
    addr=`grep $controller /etc/hosts | awk '{print $1}'`
    ssh -q $controller -- sudo kubeadm join ${API_VIP}:6443 \
        --control-plane \
        --apiserver-advertise-address $addr \
        --token $TOKEN \
        --discovery-token-ca-cert-hash $TOKEN_HASH \
        --certificate-key $CERT_KEY
done

WORKERS=`grep "$WORKER_LABEL" /etc/hosts | awk '{print $NF}'`
for worker in ${WORKERS[@]}; do
    ssh -q $worker -- sudo kubeadm join ${API_VIP}:6443 \
        --token $TOKEN \
        --discovery-token-ca-cert-hash $TOKEN_HASH
done