#!/bin/bash

curdir=$(cd `dirname $0`; pwd)

function start_server() {
    cd $curdir/../../src/3rd/skynet && chmod +x ./skynet && ./skynet $curdir/../etc/config.$1
}

./rm_logs.sh

start_server gatewayserver
start_server loginserver
start_server plazaserver
start_server battleserver