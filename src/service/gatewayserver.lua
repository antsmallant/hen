local skynet = require "skynet"
local sprotoloader = require "sprotoloader"
local etcdcli = require "etcd.etcd_v3api"
local lua_util = require "lua_util"
local skynet_util = require "skynet_util"
local json = require "cjson.safe"


skynet.start(function()
    skynet.error("gatewayserver started")
end)