#!/usr/bin/env bash
curdir=$(cd `dirname $0`; pwd)
i=2
for hostname in $(cat "${curdir}/container-configs/hosts" | awk '{print $2}'); do
  docker rm -f gpdb-${hostname}
  i=`expr $i + 1`
done
docker network rm gpdb
