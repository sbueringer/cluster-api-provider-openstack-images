
# Images for CAPI

These images are only used to test Cluster API provider OoenStack.

# Manual Devstack build

```bash
export PACKER_FLAGS="-debug -on-error=ask -var 'headless=false' -var 'cpus=4' -var 'disk_size=10240' -var 'memory=16144'"
make build-qemu-ubuntu-2004
```