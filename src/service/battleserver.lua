local skynet = require "skynet"
local sprotoloader = require "sprotoloader"
local etcdcli = require "etcd.etcd_v3api"
local lua_util = require "lua_util"
local skynet_util = require "hen.skynet_util"
local json = require "cjson.safe"

local k_servertype = skynet.getenv "servertype"

skynet.start(function()
    skynet.newservice("cluster_mgr")
    skynet.error(k_servertype .. " started")
end)