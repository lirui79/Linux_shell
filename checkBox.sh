#!/bin/sh

lib_path="/usr/local/lib/:/usr/local/smartApp/lib/"
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:${lib_path}
#udevfiles=$(ls /dev/sd[abc][0-9])
/usr/local/smartApp/bin/smartBoxTest 1 /usr/local/smartApp/ &
pid=$!
echo ${pid} > "/run/smartBoxTest.pid"
