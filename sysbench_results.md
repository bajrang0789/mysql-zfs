
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
```
Initializing worker threads...

Threads started!


File operations:
    reads/s:                      6248.29
    writes/s:                     4165.52
    fsyncs/s:                     13329.94

Throughput:
    read, MiB/s:                  97.63
    written, MiB/s:               65.09

General statistics:
    total time:                          300.0033s
    total number of events:              7123125

Latency (ms):
         min:                                    0.00
         avg:                                    0.04
         max:                                    8.24
         95th percentile:                        0.21
         sum:                               292329.84

Threads fairness:
    events (avg/stddev):           7123125.0000/0.00
    execution time (avg/stddev):   292.3298/0.00
```

Prepare load is split across the 8 cores, verifying : 
This balance of irq is working fine with upgraded kernel verion from `3.13.0-115-generic` to `4.4.0-139-generic`

```
root@msr-c1:~/baj_scripts# uname -r
4.4.0-139-generic
```
Test for irq balance 
```
root@msr-c1:~/baj_scripts#  cat /proc/interrupts | grep xen-dyn-event
 96:        740          0          0          0          0          0          0          0   xen-dyn-event     xenbus
 97:       5501       5081          0          0          0          0          0      51094   xen-dyn-event     blkif
 98:       1073       7416          0          0          0       1558      95081       8082   xen-dyn-event     blkif
 99:   20281233          0          0          0          0          0          0      55041   xen-dyn-event     blkif
100:         33          0          0         23          0    4188616          0          0   xen-dyn-event     vif0-q0-tx
101:      13253      17347    2131477       7309    3249375       2001      31157      10554   xen-dyn-event     vif0-q0-rx
102:      58693     107292    4337650     110674      39930     106047    4305635        140   xen-dyn-event     vif0-q1-tx
103:     656748    1150449    1125036    1065174   13108012     971109     865388     944699   xen-dyn-event     vif0-q1-rx
104:      10543     443011      22708       8635       7806     146959     361561      83056   xen-dyn-event     vif0-q2-tx
105:     130852     163184     166057     162507     161176     156450     141922     281539   xen-dyn-event     vif0-q2-rx
106:     658740    1496036    1491714    1285643     630852     500047    1120728    2534124   xen-dyn-event     vif0-q3-tx
107:      53102      74571      52064     130077      71417     134990      69415     139662   xen-dyn-event     vif0-q3-rx
108:     395465     358218     770193    1239849     632878    1261777    1151706    1010945   xen-dyn-event     vif0-q4-tx
109:     907274    1121461    1023191    1013108     912284     554559     558891    1329253   xen-dyn-event     vif0-q4-rx
110:    1068280    1312490     788823     736697     998768    1154514    2449043    1219128   xen-dyn-event     vif0-q5-tx
111:     776191     800310     757765    1257341     715221     964468     589224     490463   xen-dyn-event     vif0-q5-rx
112:      15505      16092       7834      75982      17971      37643      32921       5449   xen-dyn-event     vif0-q6-tx
113:     517503    1040301     263799     501419     556065     202675     207788     486414   xen-dyn-event     vif0-q6-rx
114:     676327     490391     234850     881162     395372     424661     860976     889300   xen-dyn-event     vif0-q7-tx
115:     302970     386996     134085     247233     326422     384055      93777     213487   xen-dyn-event     vif0-q7-rx
```

using the custom script: https://github.com/bajrang0789/mysql-zfs/blob/master/sysbench_test_zfs.sh
