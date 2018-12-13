
Preparing files on the ZFS backup pool to benchmark the perf:
sysbench fileio --file-total-size=1T --file-test-mode=rndrd --threads=16 --file-block-size=16384 prepare

```
root@msr-c1:~/baj_scripts# zpool iostat 30
               capacity     operations    bandwidth
pool        alloc   free   read  write   read  write
----------  -----  -----  -----  -----  -----  -----
backup       126G  1.60T      0     11  14.8K  1.36M
zp0         79.9M  4.37T      0      0  3.77K  10.6K
----------  -----  -----  -----  -----  -----  -----
backup       143G  1.58T      0  6.17K    529   759M
zp0         79.9M  4.37T      0      0      0      0
----------  -----  -----  -----  -----  -----  -----
backup       158G  1.56T      0  6.21K    870   763M
zp0         79.9M  4.37T      0      0      0      0
----------  -----  -----  -----  -----  -----  -----
backup       177G  1.55T      0  6.18K    494   762M
zp0         79.9M  4.37T      0      0      0      0
----------  -----  -----  -----  -----  -----  -----
backup       190G  1.53T      0  6.21K  1.48K   763M
zp0         79.9M  4.37T      0      0      0      0
----------  -----  -----  -----  -----  -----  -----
backup       203G  1.52T      0  6.20K    477   760M
zp0         79.9M  4.37T      0      0      0      0
----------  -----  -----  -----  -----  -----  -----
```

Running Test : 
Extra file open flags: directio
128 files, 8GiB each
1TiB total file size
Block size 16KiB

using the custom script: https://github.com/bajrang0789/mysql-zfs/blob/master/sysbench_test_zfs.sh
