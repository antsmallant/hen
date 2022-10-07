#!/bin/bash

curdir=$(cd `dirname $0`; pwd)

cd $curdir/../../src/3rd/skynet && chmod +x ./skynet && ./skynet $curdir/../conf/config.gatewayserver
