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

ZFS support is all in build from 16.04 onwards: 
http://manpages.ubuntu.com/manpages/xenial/en/man8/mount.zfs.8.html

##########################################################################################

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

ZFS does not support AIO on Ubuntu 14.04 so need to config MySQL not to use it for the InnoDB engine.
Adding the following line to /etc/mysql/my.cnf:
More details: 
https://dev.mysql.com/doc/refman/5.7/en/innodb-linux-native-aio.html

Further more, we can comment out the O_DIRECT FLUSH Method for InnoDB and disable the innodb_doublewrite buffers as ZFS is transactionally compliant and self-heals in case of any data-corruption at Block Levels. 
The checksums are configured at ZPOOL block level.


my.cnf :
```
innodb_use_native_aio           = 0
#innodb-flush-method            = O_DIRECT

innodb_doublewrite              = 0
innodb_checksum_algorithm       = none
```
# Creation of Backup ZPOOL:
Backup MySQL POOL is required in case we large DATA SIZE and make sure we are not choking up the same EBS Volume DISK IOPS on which the MASTER MySQL POOL is running. 

To test and keep our backup snapshot we used the free nvme storage (only for the testing purpose, comes with i3.2x.large instance)

Create backup POOL:
```zpool create -f backup /dev/nvme0n1```

we get the status of the POOL with
```
ZPOOL STATUS
```
Output:
```
  pool: backup
 state: ONLINE
  scan: none requested
config:

	NAME        STATE     READ WRITE CKSUM
	backup      ONLINE       0     0     0
	  nvme0n1   ONLINE       0     0     0

errors: No known data errors

  pool: zp0
 state: ONLINE
  scan: none requested
config:

	NAME        STATE     READ WRITE CKSUM
	zp0         ONLINE       0     0     0
	  xvdc      ONLINE       0     0     0

errors: No known data errors
```

# HOW TO PERFORM INCREMENTAL SNAPSHOTS with ZFS : - 

1.) Create a separate Backup Pool:

```zpool create -f backup /dev/nvme0n1```

```
zfs mount
zp0                             /zp0
zp0/mslave01                    /zp0/mslave01
zp0/mysql                       /zp0/mysql
zp0/mysql/data                  /data2/data
zp0/mysql/logs                  /data2/logs
zp0/mysql/tmp                   /data2/tmp
backup                          /backup
```

2.) Rotate previous snapshots (and also keep one copy of snapshot in hand)
Assuming these snapshots exist
```
sudo zfs destroy -r zp0/mysql@mysql002
sudo zfs rename -r zp0/mysql@mysql001 mysql002
```

3.) Take a snapshot


```sudo zfs snapshot -r zp0/mysql@mysql001```
TAKE SNAPSHOTS without data-incosistency:
```
mysql -h127.0.0.1 -uroot --port=3310 -e 'flush tables with read lock;show master status;\! zfs snapshot -r zp0/mysql@mysql001'
```

4.) Look at the difference of this snapshot 
```sudo zfs diff zp0/mysql@mysql001 zp0/mysql@mysql002```

5.) 
Option 1) Send to a local disk containing the /backup POOL.
5A.1 Send that snapshot (completely) to the backup pool (first-time run)
```
sudo zfs send zp0/mysql@mysql001 | sudo zfs receive backup/mysql
```
5A.2 Send that snapshot to the backup pool, incrementally to the previous time (from the second time on)
```
sudo zfs send -i mysql002 zp0/mysql@mysql001 | sudo zfs receive backup/mysql
```
Result is that now backup/mysql is again a duplicate of zp0/mysql, up until the moment the last snapshot was taken

5 
Option 2) Send to a remote disk containing the backup/mysql POOL
In this way, we can have the snapshot replicated to another system on a safe(r) location

5B.1 Send that snapshot (completely) to the backup pool
```
sudo zfs send zp0/mysql@mysql001 | ssh ubuntu@10.0.32.111 sudo zfs receive backup/mysql
```
5B.2  Send that snapshot to the backup pool, incrementally to the previous time
```
sudo zfs send -i mysql002 zp0/mysql@mysql001 | ssh ubuntu@10.0.32.111 sudo zfs receive backup/mysql
```

you can find a detailed mysql snapshot script for this here: 
https://github.com/bajrang0789/mysql-zfs/blob/master/incremental_zfs_snap.sh



# ZFS Clone :

In order to access the ZFS Snapshot of the ZVOL, you can do so through a clone or through ZFS as a file system.

Here's how: 

1.) Get the list of snapshot 
``` zfs list -t snapshot ```
Output:
```
NAME                      USED  AVAIL  REFER  MOUNTPOINT
backup/mysql@mysql002       1K      -    19K  -
backup/mysql@mysql001       1K      -    19K  -
zp0/mysql@mysql002           0      -    19K  -
zp0/mysql@mysql001           0      -    19K  -
zp0/mysql/data@mysql002      0      -  1.55M  -
zp0/mysql/data@mysql001      0      -  1.55M  -
zp0/mysql/logs@mysql002      0      -   309K  -
zp0/mysql/logs@mysql001      0      -   309K  -
zp0/mysql/tmp@mysql002       0      -    19K  -
zp0/mysql/tmp@mysql001       0      -    19K  -
```
You probably wonder why the USED column reports 0B. That's simply because there were no changes to the filesystem since the snapshot was created.
It is a measure of the amount of data that hasn't been free because the snapshot requires the data. Said otherwise, it how far the snapshot has diverged from its parent.


2.) Use the data from snapshot: 

As said we have two approach to access the data from ZFS Snapshot 

a.) through ZFS filesystem:
By default the Snapshot data is invisible, we can however change the ZFS properties for the ZVOL:
lets try out for ZVOL : `zp0/mysql/logs` which is mouted at `/data2/logs`
	```
	root@msr-c1:/data2/logs# ls -alrth
	total 291K
	drwxr-x--- 2 mysql mysql    2 Dec 11 19:57 relaylog
	drwxr-x--- 4 mysql mysql    6 Dec 11 20:27 .
	-rw-r----- 1 mysql mysql  820 Dec 11 21:17 mysql-slow.log
	drwxr-x--- 2 mysql mysql    7 Dec 11 21:17 binlog
	drwxr-x--- 5 mysql mysql 4.0K Dec 11 21:17 ..
	-rwxr-x--- 1 mysql mysql 4.7M Dec 11 21:17 mysql-error.log
	```
To access the snapshot through ZFS, you have to set the snapdir parameter to "visible, " and then you can see the files.
	``` 
	zfs set snapdir=visible zp0/mysql/logs
	```
You can see that we had two snap shots `zp0/mysql/logs@mysql001` and `zp0/mysql/logs@mysql002` for ZVOL: 	`zp0/mysql/logs`	
	```
	root@msr-c1:/data2/logs# ls  .zfs/
	shares  snapshot
	root@msr-c1:/data2/logs# ls  .zfs/snapshot/
	mysql001  mysql002
	root@msr-c1:/data2/logs# ls  .zfs/snapshot/mysql001/
	binlog  mysql-error.log  mysql-slow.log  relaylog
	root@msr-c1:/data2/logs#
	```

b.) use ZFS clone to access the data:
The files in the snapshot directory are read-only. If you want to be able to write to the files, you first need to clone the snapshots.

	```
	root@msr-c1:/# zfs list -t snapshot
	NAME                      USED  AVAIL  REFER  MOUNTPOINT
	zp0/mysql@mysql001           0      -    19K  -
	zp0/mysql/data@mysql001      0      -  1.55M  -
	zp0/mysql/logs@mysql001      0      -   309K  -
	```
As we already have a mysql snaphot, we need to create a root level ZVOL (`zp0/mslave01`) similar to the mysql one we did earlier (`zp0/mysql`) 
Here, I am using the same Zpool (zp0)

	```
	zfs create zp0/mslave01
	```

	```zfs list```
	Output:
	```
	NAME             USED  AVAIL  REFER  MOUNTPOINT
	zp0             7.10M  4.24T    19K  /zp0
	zp0/mslave01      19K  4.24T    19K  /zp0/mslave01
	zp0/mysql       1.87M  4.24T    19K  /zp0/mysql
	zp0/mysql/data  1.55M  4.24T  1.55M  /data2/data
	zp0/mysql/logs   309K  4.24T   309K  /data2/logs
	```
	
3. Cloning to a new ZVOL: (`/zp0/mslave01`)

Cloning mysql ZVOL using snapshot @001:
	```
	zfs clone zp0/mysql/data@mysql001 zp0/mslave01/data
	zfs clone zp0/mysql/logs@mysql001 zp0/mslave01/logs
	zfs clone zp0/mysql/tmp@mysql001  zp0/mslave01/tmp
	```
	
ZFS Clone is a quick process, which makes a fork of the original data, only tracking the file meta-data and block level.
It creates a layer on the File System and actually uses the underlying snapshot data, which only writes the new data to the clone space on File System. 
ZFS records that haven't changed since the snapshot was taken are shared. That's huge space savings. 

So, Ideally the actual data size consumed on the EBS volume doesn't grow even if you create multiple Clones from the same snapshot, unless new data is written to the created Clones.

# System Overview :-
	1.) The system which I used for the MySQL on ZFS POC, is a AWS EC2 instance on i3.2x.large class.
	2.) The set up is simple, we are running multiple MySQL instances listening on different Ports. 
	3.) Port - 3306, is used as a slave MySQL instance which is actually set up as a Multi-source Replication Slave, replicating from different master DB servers. 
	4.) Port - 3310, is used as the ZFS MySQL Master instance.
	5.) Port - 3312, is used as the ZFS MySQL Cloned instance.
	6.) Port - 3306, uses a single EBS VOLUME which is in EXT4 File system.
	7.) Port - 3310 and 3312, uses a single EBS VOLUME which of ZFS Filesystem.
	8.) Detail Config can be found here: https://github.com/bajrang0789/mysql-zfs/blob/master/my.cnf


```
root@msr-c1:/data2/logs# service mysql status
 * Percona Server 5.7.24-26 is running
root@msr-c1:/data2/logs# mysqld_multi report
Reporting MySQL (Percona Server) servers
MySQL (Percona Server) from group: mysqld2 is running
MySQL (Percona Server) from group: mysqld3 is not running
```

``` zfs list ```

Output

so yes the clone is up and running now. let's do a `mysqld_multi start 3` to start listening on the new Port : `3312`








