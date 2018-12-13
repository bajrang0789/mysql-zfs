#!/bin/bash
mkdir -pv /backup/sysbench
cd /backup/sysbench
outputdir=/backup/sysbench
mkdir -p $outputdir
for threads in 8 16;
do
 for mode in async sync ;
 do
 for test in rndrw rndwr rndrd;
# for test in rndrd;
 do
 echo 3 > /proc/sys/vm/drop_caches
 echo "`date` Starting ${mode} ${test} test with ${threads} threads..."
 sysbench fileio --file-total-size=1T --file-test-mode=${test} \
 --threads=${threads} --time=3600 --max-requests=0 \
  --file-fsync-freq=0 --report-interval=1 \
 --rand-type=pareto --file-extra-flags=direct \
 --file-block-size=16384 --file-io-mode=${mode} --percentile=99 \
 run | tee ${outputdir}/${test}.${mode}.${threads}.log
 echo "done."
 done
 done
done
