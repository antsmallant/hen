local skynet = require "skynet"
local sprotoloader = require "sprotoloader"
local etcdcli = require "etcd.etcd_v3api"
local lua_util = require "lua_util"
local skynet_util = require "hen.skynet_util"
local json = require "cjson.safe"

local k_servertype = skynet.getenv "servertype"
local debug_port = assert(tonumber(skynet.getenv "debug_port"))

skynet.start(function()
    skynet.uniqueservice("common/cluster_mgr")
    skynet.newservice("debug_console", debug_port)
    skynet.newservice("login/logind")
    skynet.error(k_servertype .. " started")
end)