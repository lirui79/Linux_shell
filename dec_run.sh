#!/bin/bash

FILE=$1
BNUM=$2
PNUM=$3
TNUM=$4

for ((INDEX=0; INDEX < PNUM; ++INDEX))
do

nohup ./multi_thread_dec -i ${FILE} -b ${BNUM} -t ${TNUM} -R 0 -l 1 > dec_${BNUM}_${INDEX}_${TNUM}.log &

sleep 1
 
done
