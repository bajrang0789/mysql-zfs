# mysql-zfs
mysql-zfs file system

Official Github Link for ZFS project on Linux:
https://github.com/zfsonlinux/zfs

# Setting up ZFS file system on Ubuntu 14.04:
1.) Add ppa zfs-native/stable repository (latest-stable)
```
sudo add-apt-repository ppa:zfs-native/stable
sudo apt-get update
```
https://launchpad.net/~zfs-native/+archive/ubuntu/stable

2.) Install required Packages
```
sudo apt-get install python-pycurl python-mysqldb python-software-properties ubuntu-zfs zfsutils
```
3.) Laod ZFS Modules to RUNTIM
```
/sbin/modprobe zfs
```
# Setting up ZFS file system on Ubuntu 16.04+:
Ubuntu 16.04 onwards has native support for ZFS, which means that VMs may start to use ZFS for non-root filesystems. Here’s a cookbook for expanding those filesystems. In OpenStack, the ZFS filesystem must be exported before this can be done, but at AWS it can be done without downtime.

In AWS we may require the EBS Vol Expansion, we can do so without any service interuption : 
Expanding ZFS in an AWS EC2 instance requires no service interruption.

1.) Add an EBS volume to the target VM. It will show up as, e.g., /dev/xvdc (if the root volume is /dev/xvda).
2.) Install ZFS libraries and utilities.

```
# or use aptitude, but it's not always available
apt-get install zfs
```
3.) Create a zpool and zfs filesystem.
```
# these utilities get installed with the zfs packages.
zpool create -o autoexpand=on zp0 /dev/xvdc
zfs create -o mountpoint=/data zp0/data
```
Worth noting at this point is that the ZFS on Linux stuff deals with whole-disk virtual volume by initially creating two partitions: partition number 1 contains the filesystem, partition number 9 is a buffering partition.

Time passes. Work goes on until the filesystem needs expansion.

(a.) Expand the EBS volume, using the AWS web GUI or the command-line tools. This can take a while.
(b.) Expand the ZFS partition, first removing the buffering partition.
```
# after this command, type ‘Fix’ at prompt to take advantage
# of new space.
parted -l
# remove the buffering partition
parted /dev/xvdc rm 9
# expand partition holding zpool
parted /dev/xvdc resizepart 1 100%
```
(c.)Expand the zpool (and, by extension, the filesystem it contains).
```
zpool online -e zp0 /dev/xvdc
```
At that point, the buffering partition is gone. After the next expansion, the resizing can be done without removing any partitions.

##############################################################################################################################

# Creation of ZPOOL:

1.) create Master - ZPOOL (zp0) with expansion capablities: (as detailed above^) 
```zpool create -f -o autoexpand=on data2 /dev/xvdc```
So now, we have the device /dev/xvdc with partition 1 and 9, to expand. 
```
ubuntu@msr-c1:~$ lsblk
NAME    MAJ:MIN RM   SIZE RO TYPE MOUNTPOINT
xvda    202:0    0    10G  0 disk
└─xvda1 202:1    0    10G  0 part /
xvdc    202:32   0   4.4T  0 disk
├─xvdc1 202:33   0   4.4T  0 part
└─xvdc9 202:41   0     8M  0 part
```

2.) Creation of Pool for MySQL usuage :
  
  i.) create root level mysql ZVOL for flexiblity of snapshots and easy management of pools.
  ```zfs create zp0/mysql```
  ii.) Set ZFS Properties for root level mysql ZVOL. (this property is inherited by default to all underlying ZVOL) 
  ```
  zfs set compression=gzip zp0/mysql
  zfs set recordsize=128k zp0/mysql
  zfs set atime=off zp0/mysq
  ```
  iii.) create mysql ZVOL for the below ->> data ZVOL , logs ZVOL, tmp ZVOL
  ```
  zfs create zp0/mysql/data
  zfs create zp0/mysql/logs
  zfs create zp0/mysql/tmp
  ```
  iv.) Set ZFS Properties for mysql/data ZVOL
  ```
  zfs set recordsize=16k zp0/mysql/data
  zfs set primarycache=metadata zp0/mysql/data
  ```
  v.) Verify the Properties :
  ```
  zfs get compression,recordsize,atime
  ```
  Output: 
  ```
  NAME                     PROPERTY     VALUE     SOURCE
  zp0                      compression  off       default
  zp0                      recordsize   128K      default
  zp0                      atime        on        default
  zp0/mysql                compression  gzip      local
  zp0/mysql                recordsize   128K      local
  zp0/mysql                atime        off       local
  zp0/mysql/data           compression  gzip      inherited from zp0/mysql
  zp0/mysql/data           recordsize   16K       local
  zp0/mysql/data           atime        off       inherited from zp0/mysql
  zp0/mysql/logs           compression  gzip      inherited from zp0/mysql
  zp0/mysql/logs           recordsize   128K      inherited from zp0/mysql
  zp0/mysql/logs           atime        off       inherited from zp0/mysql
  zp0/mysql/tmp            compression  gzip      inherited from zp0/mysql
  zp0/mysql/tmp            recordsize   128K      inherited from zp0/mysql
  zp0/mysql/tmp            atime        off       inherited from zp0/mysql
  ```
  zfs list:
  ```
  zfs list
  NAME             USED  AVAIL  REFER  MOUNTPOINT
  zp0              128K  4.24T    19K  /zp0
  zp0/mysql         57K  4.24T    19K  /zp0/mysql
  zp0/mysql/data    19K  4.24T    19K  /zp0/mysql/data
  zp0/mysql/logs     19K  4.24T   19K  /zp0/mysql/logs
  zp0/mysql/tmp     19K  4.24T    19K  /zp0/mysql/tmp
  ```
  
  vi.) Setting up MySQL ZVOL Mountpoints: 
  ```
  zfs set mountpoint=/data2/data  zp0/mysql/data
  zfs set mountpoint=/data2/logs  zp0/mysql/logs
  zfs set mountpoint=/data2/tmp   zp0/mysql/tmp
  ```
  zfs list:
  ```
  zfs list
  NAME             USED  AVAIL  REFER  MOUNTPOINT
  zp0             7.14M  4.24T    19K  /zp0
  zp0/mysql       1.89M  4.24T    19K  /zp0/mysql
  zp0/mysql/data  1.55M  4.24T  1.55M  /data2/data
  zp0/mysql/logs   309K  4.24T   309K  /data2/logs
  zp0/mysql/tmp     19K  4.24T    19K  /data2/tmp
  ```
  
  vii.) Preparing the DIR: (as per the config in my.cnf)
  
  ```
  mkdir -pv /data2/logs/binlog
  mkdir -pv /data2/logs/relaylog
  touch /data2/logs/mysql-error.log
  ```
  
  viii.) Assigning correct Permissions for MySQL 
  
  ```
  chown -R mysql.mysql /data2
  chmod -R  750 /data2
  chmod -R  755 /data2/tmp
  ```

3.) MySQL Config Changes: 










