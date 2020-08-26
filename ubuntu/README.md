Install docker
--------------
Installs docker. Optionally move `/var/lib/docker` to a dedicated disk. The disk is assumed to be raw and will be XFS formatted, and mounted permanently to `/storage/ssd/docker`.

```bash
curl -o ./install-docker.sh https://raw.githubusercontent.com/dockerguys/houseparty/master/ubuntu/install-docker.sh
sudo sh install-docker.sh -d /dev/sdb
sudo reboot
```

Install NFS server
-----------
You need to have a dedicated raw disk. Sample script below assumes `/dev/sdb`.

Script will format disk to XFS and mount permanently to path specified by `-m`.

NFS volume is exported as `nfsvol` under the mounted path.

```bash
curl -o ./install-nfs-server.sh https://raw.githubusercontent.com/dockerguys/houseparty/master/ubuntu/install-nfs-server.sh
sudo sh install-nfs-server.sh -d /dev/sdb -m /storage/hdd
```

Lazy Prep Script
----------------
A simple script to set things up. Assuming second storage is at /dev/vdb.

```bash
wget https://raw.githubusercontent.com/dockerguys/houseparty/master/ubuntu/install-docker.sh
wget https://raw.githubusercontent.com/dockerguys/houseparty/master/ubuntu/prep_disk.sh

mkdir -p /storage
sh ./prep_disk.sh /dev/vdb /storage

mkdir -p /storage/docker
sh ./install-docker.sh -d /storage/docker
```
