#!/usr/bin/env bash
curdir=$(cd `dirname $0`; pwd)
cd $curdir
docker network create --subnet=172.18.255.0/24 gpdb
i=2
for hostname in $(cat ./container-configs/hosts | awk '{print $2}'); do
  docker start gpdb-${hostname}
  if [ $i == 2 ]; then
    coordinator=$hostname
  fi
  i=`expr $i + 1`
done
docker exec -it gpdb-${coordinator} gpstart -a
