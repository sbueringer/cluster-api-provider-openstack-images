
# Images for CAPI

These images are only used to test Cluster API provider OoenStack.

# Manual Devstack build

```bash
export PACKER_FLAGS="-debug -on-error=ask -var 'headless=false' -var 'cpus=4' -var 'disk_size=15360' -var 'memory=24576'"
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