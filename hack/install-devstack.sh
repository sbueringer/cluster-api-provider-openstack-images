#!/bin/bash

set -o errexit -o nounset -o pipefail
set -x

# GCP setup

## Cleanup grub command line
sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT=.*$/GRUB_CMDLINE_LINUX_DEFAULT=\"\"/' /etc/default/grub
sed -i 's/GRUB_CMDLINE_LINUX=.*$/GRUB_CMDLINE_LINUX=\"console=tty0 console=ttyS0,38400n8d\"/' /etc/default/grub
sudo update-grub

## Cleanup fstab
sed -i -e $'s|/dev/fd0|#/def/fd0|' /etc/fstab
cat /etc/fstab


# Install basic packages

## Setup apt repos
cat <<EOF > /tmp/sources.list
deb http://us.archive.ubuntu.com/ubuntu focal main restricted universe
deb http://us.archive.ubuntu.com/ubuntu focal-updates main restricted universe
deb http://us.archive.ubuntu.com/ubuntu focal-backports main restricted universe
deb http://security.ubuntu.com/ubuntu focal-security main restricted universe
EOF
sudo mv /tmp/sources.list /etc/apt/sources.list

## Install kvm and some other tools
sudo apt-get update && sudo apt-get install qemu-kvm jq net-tools git curl gnupg2 software-properties-common vim -y

# Add universe to be able to install gce-compute-image-packages
sudo apt-add-repository universe
sudo apt-get update
sudo apt-get install -y gce-compute-image-packages

## Install cloud-init
sudo apt-get install cloud-init cloud-guest-utils cloud-initramfs-copymods cloud-initramfs-dyn-netconf cloud-initramfs-growroot -y
sudo systemctl enable cloud-final
sudo systemctl enable cloud-config
sudo systemctl enable cloud-init
sudo systemctl enable cloud-init-local
### disable cloud-init growroot, otherwise the server won't boot:
### * xref: https://cloudinit.readthedocs.io/en/latest/topics/modules.html#growpart
touch /etc/growroot-disabled


# Install Devstack

cat <<EOF > /tmp/devstack.conf
net.ipv4.ip_forward=1
net.ipv4.conf.default.rp_filter=0
net.ipv4.conf.all.rp_filter=0
EOF
sudo sysctl -p /tmp/devstack.conf

# from https://raw.githubusercontent.com/openstack/octavia/master/devstack/contrib/new-octavia-devstack.sh
git clone -b stable/victoria https://github.com/openstack/devstack.git /tmp/devstack

cat <<EOF > /tmp/devstack/local.conf

[[local|localrc]]
GIT_BASE=https://github.com

# Enable after installation
#OFFLINE=True

# Neutron
enable_plugin neutron https://github.com/openstack/neutron stable/victoria

# Octavia
enable_plugin octavia https://github.com/openstack/octavia stable/victoria
enable_plugin octavia-dashboard https://github.com/openstack/octavia-dashboard stable/victoria
#LIBS_FROM_GIT+=python-octaviaclient

# Cinder
enable_plugin cinderlib https://github.com/openstack/cinderlib stable/victoria

KEYSTONE_TOKEN_FORMAT=fernet

SERVICE_TIMEOUT=240

DATABASE_PASSWORD=secretdatabase
RABBIT_PASSWORD=secretrabbit
ADMIN_PASSWORD=secretadmin
SERVICE_PASSWORD=secretservice
SERVICE_TOKEN=111222333444

# IP from packer (we need to create the server later with this IP)
HOST_IP=10.0.2.15
FLOATING_RANGE="172.24.4.0/24"
OCTAVIA_MGMT_PORT_IP=192.168.0.96
OCTAVIA_MGMT_SUBNET_START=192.168.0.2
OCTAVIA_MGMT_SUBNET_END=192.168.0.200

# Enable Logging
LOGFILE=/opt/stack/logs/stack.sh.log
VERBOSE=True
LOG_COLOR=True

# Pre-requisite
ENABLED_SERVICES=key,rabbit,mysql
# Nova
ENABLED_SERVICES+=,n-api,n-obj,n-cpu,n-cond,n-sch,n-novnc,n-api-meta
# Placement service needed for Nova
ENABLED_SERVICES+=,placement-api,placement-client
# Glance
ENABLED_SERVICES+=,g-api,g-reg

# Octavia-Neutron
ENABLED_SERVICES+=,neutron-api,neutron-agent,neutron-dhcp,neutron-l3
ENABLED_SERVICES+=,neutron-metadata-agent,neutron-qos
# Octavia
ENABLED_SERVICES+=,octavia,o-api,o-cw,o-hm,o-hk,o-da

# Horizon (enable for manual tests)
# ENABLED_SERVICES+=,horizon

# Cinder
ENABLED_SERVICES+=,c-sch,c-api,c-vol

# Additional services
ENABLED_SERVICES+=,horizon

LIBVIRT_TYPE=kvm

# Don't download default images, just our test images
DOWNLOAD_DEFAULT_IMAGES=False
# Upload amphora so it doesn't have to be built
IMAGE_URLS="https://storage.googleapis.com/artifacts.k8s-staging-capi-openstack.appspot.com/test/amphora/2021-03-27/amphora-x64-haproxy.qcow2"

# See: https://docs.openstack.org/nova/victoria/configuration/sample-config.html
# Helpful commands (on the devstack VM):
# * source /opt/stack/devstack/openrc admin admin
# * openstack resource provider list
# * openstack resource provider inventory list 4aa55af2-d50a-4a53-b225-f6b22dd01044
# * openstack resource provider usage show 4aa55af2-d50a-4a53-b225-f6b22dd01044
# * openstack hypervisor stats show
# * openstack hypervisor list
# * openstack hypervisor show openstack
# * nova-manage cell_v2  list_hosts
# A CPU allocation ratio von 32 gives us 32 vCPUs in devstack
# This should be enough to run multiple e2e tests at the same time
[[post-config|\$NOVA_CONF]]
[DEFAULT]
cpu_allocation_ratio = 32.0
EOF

# Create the stack user
HOST_IP=10.0.2.15 /tmp/devstack/tools/create-stack-user.sh

# Move everything into place (/opt/stack is the $HOME folder of the stack user)
mv /tmp/devstack /opt/stack/
chown -R stack:stack /opt/stack/devstack/

# Stack that stack!
su - stack -c /opt/stack/devstack/stack.sh

echo "Installation done at $(date)"

# set OFFLINE for the next boot
sed -i 's|#OFFLINE=True|OFFLINE=True|g' /opt/stack/devstack/local.conf

# Allow more restarts, this is necessary because we're skipping most of the installation on boot later,
# so there are a lot of apache2 systemd service restarts triggered in a short amount of time
mkdir -p /lib/systemd/system/apache2.service.d
cat << EOF > /lib/systemd/system/apache2.service.d/restart.conf
[Service]
StartLimitBurst=20
EOF
systemctl daemon-reload

# FIXME: test one image without that manual shutdown

#echo "disable all devstack services"
#
#echo "disable devstack services"
#sudo systemctl list-unit-files --type=service | grep enabled | grep devstack | awk '{print $1}' | xargs -I {} sudo systemctl disable {}
#echo "disable misc services"
#sudo systemctl disable rabbitmq-server.service haproxy.service apache2.service memcached.service openvswitch-switch.service uwsgi.service

# Add environment variables for auth/endpoints
echo 'source /opt/stack/devstack/openrc admin admin' >> /opt/stack/.bashrc

su - stack -c /opt/stack/devstack/unstack.sh
