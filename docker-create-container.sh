#!/usr/bin/env bash
curdir=$(cd `dirname $0`; pwd)
cd $curdir
docker network create --subnet=172.18.255.0/24 gpdb
i=2
for hostname in $(cat ./container-configs/hosts | awk '{print $2}'); do
  docker run -itd --net gpdb --ip 172.18.255.$i --name gpdb-${hostname} --hostname ${hostname} gpdb:dev /bin/bash
  docker cp ./container-configs/hosts gpdb-${hostname}:/home/gpadmin/.hosts
  if [ $i == 2 ]; then
    coordinator=$hostname
	docker exec -it gpdb-${hostname} /bin/bash -c "echo 'export COORDINATOR_DATA_DIRECTORY=/data/coordinator/gpseg-1' >> ~/.bashrc"
  else
    docker exec -it gpdb-${hostname} mkdir -p /data/1/primary
    docker exec -it gpdb-${hostname} mkdir -p /data/2/primary
  fi
  i=`expr $i + 1`
done
docker cp ./gpconfigs gpdb-${coordinator}:/home/gpadmin/
docker exec -it gpdb-${coordinator} /bin/bash -c 'cd ~ && source /usr/local/gpdb/greenplum_path.sh && sudo -u root /root/.startup.sh && ./auto_hosts_configure.sh && gpssh-exkeys -f gpconfigs/hostfile_exkeys && gpinitsystem -c gpconfigs/gpinitsystem_config -h gpconfigs/hostfile_gpinitsystem -a'
