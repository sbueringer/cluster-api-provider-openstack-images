
# Images for CAPI

These images are only used to test Cluster API provider OoenStack.

# Manual Devstack build

```bash
export PACKER_FLAGS="-on-error=ask -var 'headless=false' -var 'cpus=6' -var 'disk_size=15360' -var 'memory=24576'"
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

# Release via

* make some changes
* execute

```bash
RELEASE_NUMBER=1

# Ubuntu
git tag ubuntu-2004-v1.18.15-${RELEASE_NUMBER} -f; git push origin ubuntu-2004-v1.18.15-${RELEASE_NUMBER}  -f

# Devstack
git tag devstack-victoria-${RELEASE_NUMBER} -f; git push origin devstack-victoria-${RELEASE_NUMBER}  -f

# Amphora
git tag amphora-victoria-${RELEASE_NUMBER} -f; git push origin amphora-victoria-${RELEASE_NUMBER}  -f 
```

# GCP experiments


* no quied, rhgb or splashimage
* guest env: https://cloud.google.com/compute/docs/images/install-guest-environment

```bash
export PACKER_FLAGS="-on-error=ask -var 'headless=false' -var 'cpus=12' -var 'disk_size=4096' -var 'memory=24576'"
export PACKER_LOG=1                   
export PACKER_LOG_PATH=/tmp/packer.log
make build-qemu-ubuntu-2004

sudo virt-install --name mini-caas --memory 32768 \
  --disk /var/lib/libvirt/images/mini-caas.qcow2,device=disk,bus=virtio \
  --os-type linux \
  --os-variant ubuntu20.04 \
  --virt-type kvm \
  --cpu host-passthrough \
  --vcpus 10 \
  --network network=mini-caas-mgmt,model=virtio \
  --import \
  --noautoconsole

#echo "Converting qcow2 to raw"
#qemu-img convert -f qcow2 -O raw ./output/devstack/devstack ./output/devstack/disk.raw
#pushd ./output/devstack || exit 1
#tar --format=oldgnu -Sczf devstack.raw.tar.gz disk.raw
#popd || exit 1

gsutil cp /tmp/devstack.raw.tar.gz gs://devstack-img/devstack.raw.tar.gz
gcloud compute images create devstack --project rich-surge-165507 --source-uri gs://devstack-img/devstack.raw.tar.gz

gcloud compute instances create openstack \
      --project "rich-surge-165507" \
      --zone "europe-west3-a" \
      --image devstack \
      --boot-disk-size 10G \
      --boot-disk-type pd-ssd \
      --can-ip-forward \
      --tags http-server,https-server,novnc,openstack-apis \
      --min-cpu-platform "Intel Skylake" \
      --machine-type "n1-standard-2" \
      --network-interface=network="capo-e2e-mynetwork,subnet=capo-e2e-mynetwork,aliases=/24" \
      --metadata-from-file user-data=${CAPO_HOME}/hack/ci/devstack-cloud-init-2.yaml
#gcloud compute images create devstack --project plated-hash-308018 --source-uri gs://devstack/devstack.raw.tar.gz --licenses "https://www.googleapis.com/compute/v1/projects/vm-options/global/licenses/enable-vmx"


* somehow stores in us?
wget (all files)
gsutil mb -l EUROPE-WEST3 gs://devstack-img/ 
cat /tmp/devstack.raw.tar.gz.part?? > /tmp/devstack.raw.tar.gz

```

https://github.com/xobs/debian-installer/blob/master/doc/devel/partman-auto-recipe.txt
https://github.com/deargle/kali-on-gcp/blob/master/templates/kali-2020-2.json

# FIXME

test fsck
* drop soft shutdown in packer