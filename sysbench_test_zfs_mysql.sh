#!/bin/bash
outputdir=/backup/sysbench/mysql
mkdir -p $outputdir
for threads in 8 16 32 64
do
 mysqld_multi stop 2
 PSCOUNT=`ps aux | grep 'data2/mysqld.sock' | grep -v grep | wc -l`
 while [[ $PSCOUNT -ne 0 ]];
 do
 echo "sleeping 60 seconds for mysql to stop..."
 sleep 60
 PSCOUNT=`ps aux | grep 'data2/mysqld.sock' | grep -v grep | wc -l`
 done
 echo "mysql is not running. starting it."
 mysqld_multi start 2
 RETVAL=1
 while [[ $RETVAL -ne 0 ]] ;
 do
 echo "sleeping 10 seconds for mysql to start..."
 sleep 10
 mysqladmin ping > /dev/null
 RETVAL=$?
 done
 echo "mysql is running. starting test at $(date)"
 mysqladmin ext -i1 -c10 > ${outputdir}/mysqladmin.${threads}.log &
 sysbench.new --test=db/oltp.lua \
 --mysql-socket=/data2/mysqld.sock \
 --mysql-user=root --mysql-db=sbtest --oltp-table-size=1000000 \
 --max-requests=0 --max-time=10 --rand-init=on \
 --rand-type=pareto --oltp-tables-count=1024 \
 --threads=${threads} --report-interval=1 \
 --oltp-reconnect=on --oltp-read-only=off \
 --oltp-sum-ranges=0 --oltp-non-index-updates=0 \
 --oltp-dist-type=pareto --oltp-test-mode=notrx \
 --oltp-skip-trx=on --mysql-ignore-errors=all \
 --oltp-non-trx-mode=insert,select,update_key \
 --percentile=99 run | tee ${outputdir}/oltp.${threads}.log
 echo "done at $(date)"
done
