#!/bin/bash

curdir=$(cd `dirname $0`; pwd)

function start_server() {
    cd $curdir/../../src/3rd/skynet && chmod +x ./skynet && ./skynet $curdir/../servers/config.$1
}

start_server gatewayserver
start_server plazaserver
start_server battleserver

