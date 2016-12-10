#!/bin/bash

# Variables
OUT_FILE="io_weight_dump_direct"
SYS_THROTTLE=true

rm $OUT_FILE

# Change io schedular to CFQ
echo cfq > /sys/block/sda/queue/scheduler

C1=`docker run -it -d myubuntu /bin/bash`
C2=`docker run -it -d myubuntu /bin/bash`

# C1 remains fixed at 1000. C2 changes from 100 to 1000
echo "1000" > /sys/fs/cgroup/blkio/docker/$C1/blkio.weight
sleep 1

for (( i=1; i <= 10; i++ ))
do
  # Set weight
  echo $i"00" > /sys/fs/cgroup/blkio/docker/$C2/blkio.weight
  sleep 1

  # Start dd on system if asked for
  if [ "$SYS_THROTTLE" = true ] ; then
    sync && echo 3 > /proc/sys/vm/drop_caches
    dd of=/dev/null if=/home/pratik/Documents/tmp/zeros bs=1M count=10000 iflag=direct &
    sys_dd_pid=$!
  fi

  # Clear caches
  sync && echo 3 > /proc/sys/vm/drop_caches

  # Start dds here
  docker exec $C1 dd of=/dev/null if=/home/zeros1 iflag=direct 2> tmp1 &
  dd1_pid=$!
  docker exec $C2 dd of=/dev/null if=/home/zeros2 iflag=direct 2> tmp2 &
  dd2_pid=$!

  # Wait for dds to get done
  wait $dd1_pid
  wait $dd2_pid

  # Kill system dd
  if [ "$SYS_THROTTLE" = true ] ; then
    kill $sys_dd_pid
  fi

  # Process dd outputs
  c1_speed=`tail -n1 tmp1 | awk '{}{print $8}'`
  c2_speed=`tail -n1 tmp2 | awk '{}{print $8}'`

  # print results
  # echo -ne `echo "1000/"$i"00" | bc -l` >> $OUT_FILE
  echo -ne "1000 "$i"00" >> $OUT_FILE
  echo -ne ' ' >> $OUT_FILE
  echo $c1_speed" "$c2_speed >> $OUT_FILE
done

# Kill containers here and clean up
docker kill $C1 > /dev/null
docker kill $C2 > /dev/null
rm tmp1 tmp2
