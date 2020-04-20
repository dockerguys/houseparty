Install docker
--------------
Installs docker. Optionally move `/var/lib/docker` to a dedicated disk. The disk is assumed to be raw and will be XFS formatted, and mounted permanently to `/storage/ssd/docker`.

```bash
curl -o ./install-docker.sh https://github.com/dockerguys/houseparty/raw/branch/master/ubuntu/install-docker.sh
chmod +x install-docker.sh
sudo ./install-docker.sh -d /dev/sdb
sudo reboot
```

Install NFS server
-----------
You need to have a dedicated raw disk. Sample script below assumes `/dev/sdb`.

Script will format disk to XFS and mount permanently to path specified by `-m`.

NFS volume is exported as `nfsvol` under the mounted path.

```bash
curl -o ./install-nfs-server.sh https://github.com/dockerguys/houseparty/raw/branch/master/ubuntu/install-nfs-server.sh
./install-nfs-server.sh -d /dev/sdb -m /storage/hdd
sudo ./install-nfs-server.sh -d /dev/sdb -m /storage/hdd
```
