#!/usr/bin/env bash
curdir=$(cd `dirname $0`; pwd)
cd $curdir
docker build --network=host -t gpdb:dev .
