#!/usr/bin/env bash
curdir=$(cd `dirname $0`; pwd)
cd $curdir
coordinator=$(cat "${curdir}/container-configs/hosts" | sed -n 1,1p | awk '{print $2}')
docker exec -it gpdb-${coordinator} $@
