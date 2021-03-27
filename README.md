
# Images for CAPI

These images are only used to test Cluster API provider OpenStack.

# Devstack OS Image

## Manual Devstack build

```bash

sudo virsh net-define ./virbr-packer.xml
sudo virsh net-autostart packer
sudo virsh net-start packer

export PACKER_FLAGS="-on-error=ask -var 'headless=false' -var 'cpus=12' -var 'disk_size=15360' -var 'memory=24576'"
export PACKER_LOG=1                   
export PACKER_LOG_PATH=/tmp/packer.log
make build-qemu-ubuntu-2004

# Debugging
## Find ssh port via
ps aux | grep kvm
# e.g.
<user-id> 180143 52.4  3.1 22261992 2042452 pts/4 Sl+ 08:07   4:47 /usr/bin/qemu-system-x86_64 -display gtk -machine type=pc,accel=kvm -boot once=d -vnc 127.0.0.1:40 -name devstack -device virtio-scsi-pci,id=scsi0 -device scsi-hd,bus=scsi0.0,drive=drive0 -device virtio-net,netdev=user.0 -drive if=none,file=output/devstack/devstack,id=drive0,cache=writeback,discard=ignore,format=qcow2 -netdev user,id=user.0,hostfwd=tcp::3614-:22 -cdrom ${GITHUB_HOME}/sbueringer/cluster-api-provider-openstack-images/packer_cache/48e4ec4daa32571605576c5566f486133ecc271f.iso -m 16144M -smp cpus=4,sockets=4
# port: 3614

## Connect via ssh
ssh builder@127.0.0.1 -p 3614
```

## Publish image manually

```bash
#FIXME: change output of post-process to something in ./output
gsutil mb -l EUROPE-WEST3 gs://devstack-img/ 
gsutil cp /tmp/devstack.raw.tar.gz gs://devstack-img/devstack.raw.tar.gz
gcloud compute images create devstack --project rich-surge-165507 --source-uri gs://devstack-img/devstack.raw.tar.gz \
  --licenses "https://www.googleapis.com/compute/v1/projects/vm-options/global/licenses/enable-vmx"
# FIXME: make it public? https://cloud.google.com/compute/docs/images/managing-access-custom-images#share-images-publicly
# upload it to the staging bucket of CAPO (same for ubuntu and amphora (all) images)
```

## Test image

```bash
# create network and firewall rules according to ${CAPO_HOME}/hack/ci/devstack-on-gce-project-install.sh
gcloud compute instances create openstack \
      --project ${GCP_PROJECT} \
      --zone ${GCP_ZONE} \
      --image devstack \
      --boot-disk-size 100G \
      --boot-disk-type pd-ssd \
      --can-ip-forward \
      --tags http-server,https-server,novnc,openstack-apis \
      --min-cpu-platform "Intel Skylake" \
      --machine-type "n1-standard-8" \
      --network-interface=network="capo-e2e-mynetwork,subnet=capo-e2e-mynetwork,aliases=/24" \
      --metadata-from-file user-data=${CAPO_HOME}/hack/ci/devstack-cloud-init.yaml
```

## FIXME: integration into CAPO e2e test

# Release via

* make some changes
* execute:

```bash
RELEASE_NUMBER=1

# Ubuntu
git tag ubuntu-2004-v1.18.15-${RELEASE_NUMBER} -f; git push origin ubuntu-2004-v1.18.15-${RELEASE_NUMBER}  -f

# Devstack
git tag devstack-victoria-${RELEASE_NUMBER} -f; git push origin devstack-victoria-${RELEASE_NUMBER}  -f

# Amphora
git tag amphora-victoria-${RELEASE_NUMBER} -f; git push origin amphora-victoria-${RELEASE_NUMBER}  -f 
```

# FIXME: experiments

# How to add it to the job

* wget/gsutil (all parts of the image)
* cat /tmp/devstack.raw.tar.gz.part?? > /tmp/devstack.raw.tar.gz


```bash
# Workaround
sudo socat TCP-LISTEN:80,fork TCP:10.156.0.6:80
sudo socat TCP-LISTEN:9696,fork TCP:10.156.0.6:9696
sudo socat TCP-LISTEN:6080,fork TCP:10.156.0.6:6080
```

# debug cmds

openstack resource provider list
openstack resource provider inventory list 4aa55af2-d50a-4a53-b225-f6b22dd01044
openstack resource provider usage show 4aa55af2-d50a-4a53-b225-f6b22dd01044
openstack hypervisor stats show
openstack hypervisor list
openstack hypervisor show openstack
nova-manage cell_v2  list_hosts