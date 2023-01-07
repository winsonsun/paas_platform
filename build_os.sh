#!/bin/bash

# Update APT source

if [ "${SK_REGION}" = "CHN" ]; then 

    cat > /etc/apt/sources.list <<EOL
deb http://10.130.208.51:8081/nexus/repository/ubuntu-apt/ focal main restricted universe multiverse
deb-src http://10.130.208.51:8081/nexus/repository/ubuntu-apt/ focal main restricted universe multiverse
deb http://10.130.208.51:8081/nexus/repository/ubuntu-apt/ focal-security main restricted universe multiverse
deb-src http://10.130.208.51:8081/nexus/repository/ubuntu-apt/ focal-security main restricted universe multiverse
deb http://10.130.208.51:8081/nexus/repository/ubuntu-apt/ focal-updates main restricted universe multiverse
deb-src http://10.130.208.51:8081/nexus/repository/ubuntu-apt/ focal-updates main restricted universe multiverse
deb http://10.130.208.51:8081/nexus/repository/ubuntu-apt/ focal-proposed main restricted universe multiverse
deb-src http://10.130.208.51:8081/nexus/repository/ubuntu-apt/ focal-proposed main restricted universe multiverse
deb http://10.130.208.51:8081/nexus/repository/ubuntu-apt/ focal-backports main restricted universe multiverse
deb-src http://10.130.208.51:8081/nexus/repository/ubuntu-apt/ focal-backports main restricted universe multiverse
EOL

fi 

### Install docker-ce engine
apt-get remove docker docker-engine docker.io containerd runc
apt-get install
apt-get install -y  ca-certificates    curl     gnupg     lsb-release

mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
#usermod -aG docker $USER
#usermod -aG docker "${SK_USER}"
#systemctl start docker

apt install -y resolveconf

if [ $( readlink /etc/resolv.conf ) = "/run/systemd/resolve/resolv.conf" ]; then 
    ln -s /run/systemd/resolve/resolv.conf /etc/resolv.conf
fi 

#/etc/systemd/resolved.conf
systemctl restart systemd-resolved.service

cat > /etc/netplan/00-installer-config.yaml <<EOL
network:
  ethernets:
    enp4s3:
      dhcp4: true
  version: 2
EOL

netplan apply

systemctl status firewalled

#Disable swap partition, due to k8s needs
swapoff /swap.img
rm -f /swap.img
cp /etc/fstab /etc/fstab.bak
sed -i '/\/swapfile/d' /etc/fstab

hostnamectl set-hostname "paas-public-img"

if grep -q "KUBECONFIG" /etc/profile; then 
    echo "export KUBECONFIG=/etc/kubernetes/admin.conf" >> /etc/profile
fi

cat > /etc/systemd/system/kubelet.service <<EOL 
[Unit]
Description=Kubernetes Kubelet Server
Documentation=https://github.com/GoogleCloudPlatform/kubernetes
After=containerd.service
Wants=containerd.service

[Service]
EnvironmentFile=-/etc/kubernetes/kubelet.env
ExecStart=/usr/local/bin/kubelet \
                $KUBE_LOGTOSTDERR \
                $KUBE_LOG_LEVEL \
                $KUBELET_API_SERVER \
                $KUBELET_ADDRESS \
                $KUBELET_PORT \
                $KUBELET_HOSTNAME \
                $KUBELET_ARGS \
                $DOCKER_SOCKET \
                $KUBELET_NETWORK_PLUGIN \
                $KUBELET_VOLUME_PLUGIN \
                $KUBELET_CLOUDPROVIDER
Restart=always
RestartSec=10s

[Install]
WantedBy=multi-user.target
EOL

systemctl enable kubelet.service
systemctl start kubelet.service
systemctl status kubelet.service

#############################
# Images & source binaries
#root@rebuild-test-worker-01:~# cd /tmp/releases/images
#root@rebuild-test-worker-01:/tmp/releases/images# ls
#docker.io_library_nginx_1.21.4.tar              k8s.gcr.io_pause_3.3.tar
#k8s.gcr.io_dns_k8s-dns-node-cache_1.21.1.tar    quay.io_calico_cni_v3.22.3.tar
#k8s.gcr.io_ingress-nginx_controller_v1.2.1.tar  quay.io_calico_kube-controllers_v3.22.3.tar
#k8s.gcr.io_kube-apiserver_v1.22.8.tar           quay.io_calico_node_v3.22.3.tar
#k8s.gcr.io_kube-controller-manager_v1.22.8.tar  quay.io_calico_pod2daemon-flexvol_v3.22.3.tar
#k8s.gcr.io_kube-proxy_v1.22.8.tar               quay.io_calico_typha_v3.22.3.tar
#k8s.gcr.io_kube-scheduler_v1.22.8.tar
#root@rebuild-test-worker-01:/tmp/releases/images# cd ..
#root@rebuild-test-worker-01:/tmp/releases# ls
#calicoctl                            containerd-rootless.sh             kubeadm-v1.22.8-amd64              runc
#cni-plugins-linux-amd64-v1.1.1.tgz   crictl                             kubelet-v1.22.8-amd64
#containerd-1.6.4-linux-amd64.tar.gz  crictl-v1.22.0-linux-amd64.tar.gz  nerdctl
#containerd-rootless-setuptool.sh     images                             nerdctl-0.19.0-linux-amd64.tar.gz
#root@rebuild-test-worker-01:/tmp/releases# cd ..
#root@rebuild-test-worker-01:/tmp# ls
#k8s.gcr.io_coredns_coredns_v1.8.0.tar  systemd-private-a43ffb26f6cf4c83a7a705907ca96a7b-chrony.service-v7NIyg
#releases                               systemd-private-a43ffb26f6cf4c83a7a705907ca96a7b-systemd-logind.service-ea5ari
#############################

#RSync from nfs [TBD]
#/root/kmcloud
chmod a+x /root/kmcloud/addon-images/load-image.sh

## 

./kubectl-v1.22.8-amd64 -v

apt-get install -y ipvsadm

ipvsadm -v

#vim /etc/systemd/system/kubelet.service

/usr/local/bin/containerd -v

# bridge, TBD
#tar -zxvf  cri-containerd-cni-1.6.4-linux-amd64.tar.gz -C /

apt-get install -y libseccomp2 socat
apt-get update

iptables -nL

#mkdir -p /proc/sys/net/bridge
#modprobe br_netfilter

#cat /etc/modules-load.d/br_netfilter.conf
#echo br_netfilter >> /etc/modules-load.d/br_netfilter.conf

#sysctl -w net.bridge.bridge-nf-call-iptables=1
#sysctl -w net.bridge.bridge-nf-call-arptables=1
#sysctl -w net.bridge.bridge-nf-call-ip6tables=1

echo ip_vs >> /etc/modules-load.d/kube_proxy-ipvs.conf
echo ip_vs_rr >> /etc/modules-load.d/kube_proxy-ipvs.conf
echo ip_vs_wrr >> /etc/modules-load.d/kube_proxy-ipvs.conf
echo ip_vs_sh >>  /etc/modules-load.d/kube_proxy-ipvs.conf
echo nf_conntrack_ipv4 >> /etc/modules-load.d/kube_proxy-ipvs.conf
sysctl -w net.ipv4.ip_forward=1

## [?] vim /etc/sysctl.conf

sysctl -p

apt-get install -y conntrack

cat > /etc/systemd/system/cloud-init.service <<EOL
# /lib/systemd/system/cloud-init.service
[Unit]
Description=Initial cloud-init job (metadata service crawler)
DefaultDependencies=no
Wants=cloud-init-local.service
Wants=sshd-keygen.service
Wants=sshd.service
After=cloud-init-local.service
After=systemd-networkd-wait-online.service
After=networking.service
Before=network-online.target
Before=sshd-keygen.service
Before=sshd.service
Before=sysinit.target
Before=shutdown.target
Conflicts=shutdown.target
Before=systemd-user-sessions.service

[Service]
Type=oneshot
ExecStart=/usr/bin/cloud-init init
RemainAfterExit=yes
TimeoutSec=0

# Output needs to appear in instance console output
StandardOutput=journal+console

[Install]
WantedBy=cloud-init.target
EOL

systemctl status cloud-init.service

kubectl -v
kubelet -v
containerd -v

## [?] vim /etc/hosts

systemctl enable containerd.service
systemctl start containerd.service
systemctl status containerd.service

kubeadm init

#cat ../../addon-images/load-image.sh

#nerdctl -n k8s.io load -i *
nerdctl -v
#nerdctl -n k8s.io load -i k8s.gcr.io_kube-proxy_v1.22.8.tar
#nerdctl -n k8s.io load -i k8s.gcr.io_kube-apiserver_v1.22.8.tar
#nerdctl -n k8s.io load -i k8s.gcr.io_dns_k8s-dns-node-cache_1.21.1.tar
#nerdctl -n k8s.io load -i k8s.gcr.io_pause_3.5.tar.gz
#nerdctl -n k8s.io load -i k8s.gcr.io_kube-controller-manager_v1.22.8.tar
#nerdctl -n k8s.io load -i k8s.gcr.io_kube-scheduler_v1.22.8.tar
#nerdctl -n k8s.io load -i k8s.gcr.io_etcd_3.5.0-0.tar.gz
#nerdctl -n k8s.io load -i k8s.gcr.io_coredns_coredns_v1.8.4.tar.gz

#nerdctl -n k8s.io images
#nerdctl -n k8s.io load rmi a319ac2280eb
#nerdctl -n k8s.io  rmi a319ac2280eb

apt-get install -y nfs-utils

rm /etc/cloud/cloud.cfg.d/99-installer.cfg
vi /etc/cloud/cloud.cfg

#kubeadm init -v 7






