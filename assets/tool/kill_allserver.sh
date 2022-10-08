#!/bin/bash

#pkill skynet

ps aux | grep skynet | grep -v grep | awk '/config/{print $2}' | xargs kill > /dev/null 2>&1