#!/bin/bash
curdir=$(pwd)
cd ../../src/3rd/skynet && chmod +x ./3rd/lua/lua && ./3rd/lua/lua $curdir/../../src/test/gw_client.lua