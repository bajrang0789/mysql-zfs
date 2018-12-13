Things you should know about ZFS File System:
# some context
ZFS is a filesystem that was developed by Sun Microsystems and introduced for the first time in with OpenSolaris in 2005. ZFS is unique in many ways; let's first have a look at its code base using the sloccount tool, which provides an estimation of the development effort.

In term of code base complexity, it is approaching 10 times the complexity of EXT4; the above graphic shows the scale. To put things in perspective, the sloccount development effort for Percona-Server 5.7 which is based on MySQL community 5.7, is estimated at 680 person-years. The ZoL development is sponsored by the Lawrence Livermore National Laboratory and the project is very active.

ZFS on Linux, or ZoL (from the OpenZFS project), has been around for quite a long time now.
ZFS on Linux - the official OpenZFS implementation for Linux. https://zfsonlinux.org/
As of 2018, ZoL has been GA for more than 5 years and most of the issues that affected it in the early days have been fixed. ZFS is also GA in FreeBSD, illumos, OmniOS, and many others.
http://open-zfs.org/wiki/Main_Page

# ZFS Features
Why does ZFS need such a large code base? Well, in Linux, it functionally replaces MD (software raid), LVM (volume manager) and the filesystem. ZFS is really a transactional database designed to support filesystem operations. Let's review the ZFS main features.


# 128 Bits Filesystem
That's huge! According to Jeff Bonwick, the rest energy of such a storage device would be enough to boil the oceans. It seems inconceivable that we'd ever need a larger filesystem.

# Copy-on-Write (COW)
When ZFS needs to update a record it does not overwrite it. Instead, it writes a new record, changes the pointers, and then frees up the old one if it is no longer referenced. That design is at the core of ZFS. It allows for features like free snapshots and transactions.

# Snapshot
ZFS supports snapshots, and because of its COW architecture, taking a snapshot is merely a matter of recording a transaction number and telling ZFS to protect the referenced records from its garbage collector. This is very similar to the InnoDB MVCC. If a read view is kept open, InnoDB keeps a copy of each of the rows that changed in the undo log, and those rows are not purged until the transaction commits.

# Clone
A ZFS snapshot can be cloned and then written too. At this point, the clone is like a fork for the original data. There is no equivalent feature in MySQL/InnoDB.

Checksum
All the ZFS records have a checksum. This is exactly like the page checksums of InnoDB. If a record is found to have an invalid checksum, it is automatically replaced by a copy, provided one is available. It is normal to define a ZFS production with more than one copy of the data set. With ZFS, we can safely disable InnoDB checksums.

# Compression
ZFS records can be compressed transparently. The most common algorithms are gzip and lz4. The data is compressed per record and the recordsize is an adjustable property. The principle is similar to transparent InnoDB page compression but without the need for punching holes. In nearly all the ZFS setups I have worked with, enabling compression helped performance.

# Encryption
ZoL doesn't support transparent encryption of the records yet, but the encryption code is currently under review. If all goes well, the encryption should be available in a matter of a few months. Once there, it will offer another option for encryption at rest with MySQL. That feature compares very well with InnoDB tablespace encryption.

# Transactional
An fsync on ZFS is transactional. This comes mainly from the fact that ZFS uses COW. When a file is opened with O_SYNC or O_DSYNC, ZFS behaves like a database where the fsync calls represent commits. The writes are atomic. The fsync calls return as soon as ZFS has written the data to the ZIL (ZFS Intent Log). Later, a background process flushes the data accumulated in the ZIL to the actual data store. This flushing process is called at an interval of txg_timeout. By default, txg_timeout is set to 5s. The process is extremely similar to the way InnoDB flushes pages. A direct benefit for MySQL is the possibility of disabling the InnoDB doublewrite buffer. The InnoDB doublewrite buffer is often a source of contention in a heavy write environment, although the latest Percona Server releases have parallel doublewrite buffers that relieve most of the issue.

# ZIL/SLOG
The transactional support in ZFS bears a huge price in term of latency since the synchronous writes and fsyncs involve many random write IO operations. Since ZFS is transactional, it needs a transactional journal, the ZIL. ZIL stands for ZFS Intent Log. There is always a ZIL. The ZIL serves a purpose very similar to the InnoDB log files. The ZIL is written to sequentially, is fsynced often, and read from only for recovery after a crash. The goal is to delay random write IO operations by writing sequentially pending changes to a device. By default, the ZIL delays the actual writes by only 5s (zfs_txg_timeout) but that's still very significant. To help synchronous write performance, ZFS has the possibility of locating the ZIL on a Separate Intent Log (SLOG).

The SLOG device doesn't need to be very large, a few GB is often enough, but it must be fast for sequential writes and fast for fsyncs. A fast Flash device with good write endurance or spinners behind a raid controller with a protected write cache are great SLOG devices. Normally, the SLOG is on a redundant device like a mirror since losing the ZIL can be dramatic. With MySQL, the presence of a fast SLOG is extremely important for performance.

# ARC/L2ARC
The ARC is the ZFS file cache. It is logically split into two parts, the ARC and the L2ARC. The ARC is the in-memory file cache, while the L2ARC is an optional on-disk cache that stores items that are evicted from the ARC. The L2ARC is especially interesting with MySQL because it allows the use of a small flash storage device as a cache for a large slow storage device. Functionally, the ARC is like the InnoDB buffer pool while the L2ARC is similar to tools like flashcache/bcache/dm-cache.

# RAID
ZFS has its own way of dealing with disk. At the lowest level, ZFS can use the bare disks individually with no redundancy, a bit like JBOD devices used with LVM. Redundancy can be added with a mirror which is essentially a software RAID-1 device. These mirrors can then be striped together to form the equivalent of a RAID-10 array. Going further, there are RAIDZ-1, RAIDZ-2 and RAIDZ-3 which are respectively the equivalent of RAID-5, RAID-6, and RAID... well, an array with three parities has no standard name yet. When you build a RAID array with Linux MD, you could have the RAID-5+ write hole issue if you do not have a write journal. The write journal option is available only in recent kernels and with the latest mdadm packages. ZFS is not affected by the RAID-5 write hole.

# Self-Healing
I already touched on this feature when I talked about the checksums. If more than one copy of a record is available and one of the copies is found to be corrupted, ZFS will return only a valid copy and will repair the damaged record. You can trigger a full check with the command.

# ZVOL Block Devices
Not only can ZFS manage filesystems, it can also offer block devices. The block devices, called ZVOLs, can be snapshotted and cloned. That's a very handy feature when I want to create a cluster of similar VMs. I create a base image and then snapshot and create clones for all the VMs. The whole image is stored only once, and each clone contains only the records that have been modified since the original clone was created.

# Send/Receive
ZFS allows you to send and receive snapshots. This feature is very useful to send data between servers. If there is already a copy of the data on the remote server, you can also send only the incremental changes.

# Deduplication
ZFS can automatically hardlink together files (or records) that have identical content. Although interesting, if you have a lot of redundant data, the dedup feature is very intensive. I don't see a practical use case of dedup for databases except maybe for a backup server.

