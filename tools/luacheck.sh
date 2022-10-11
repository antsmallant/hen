#!/bin/bash

flag="--no-unused --no-unused-args --no-unused-secondaries 
    --no-redefined --no-color 
    --globals class interface table string implements SERVICE_NAME 
    --ignore 542 512 --no-max-code-line-length"

files=`find ../src/lualib/ -name '*.lua'`
luacheck $files $flag > luacheck_result.log

files=`find ../src/service/ -name '*.lua'`
luacheck $files $flag >> luacheck_result.log

grep -v "Checking.*OK" luacheck_result.log

rm luacheck_result.log