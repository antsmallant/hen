local skynet = require "skynet"
local sprotoloader = require "sprotoloader"
local etcdcli = require "etcd.etcd_v3api"
local lua_util = require "lua_util"
local skynet_util = require "skynet_util"
local json = require "cjson.safe"

local servertype = skynet.getenv "servertype"

skynet.start(function()
    skynet.error(servertype .. " started")
end)