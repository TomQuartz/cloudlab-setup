BASE_DIR=`realpath $(dirname $0)`
cd $BASE_DIR

CONTROLLER_LABEL=${1:-"controller"}
HOSTS=`grep "$CONTROLLER_LABEL" /etc/hosts | awk '{print $NF}'`

for host in ${HOSTS[@]}; do
    ssh -q $host -- mkdir -p ~/k8s/audit/
    scp audit-policy.yaml $host:~/k8s/audit
    ssh -q $host -- sudo mkdir -p /etc/kubernetes
    ssh -q $host -- sudo cp ~/k8s/audit/audit-policy.yaml /etc/kubernetes
    ssh -q $host -- mkdir -p ~/k8s/audit/log && chmod a+rw ~/k8s/audit/log && rm -f ~/k8s/audit/log/*
    # ssh -q $host -- sudo mkdir -p /var/log/kubernetes/audit && sudo chmod a+rw /var/log/kubernetes/audit
done
