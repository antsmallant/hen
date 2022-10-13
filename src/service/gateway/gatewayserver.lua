local skynet = require "skynet"
local sprotoloader = require "sprotoloader"
local etcdcli = require "etcd.etcd_v3api"
local lua_util = require "lua_util"
local skynet_util = require "hen.skynet_util"
local json = require "cjson.safe"
local logger = require "hen.logger"

local k_servertype = skynet.getenv "servertype"
local debug_port = assert(tonumber(skynet.getenv "debug_port"))
local watchdog_port = assert(tonumber(skynet.getenv "watchdog_port"))
local max_client = tonumber(skynet.getenv "max_client" or 1000)

skynet.start(function()
    skynet.uniqueservice("common/cluster_mgr")
    skynet.newservice("debug_console", debug_port)

	local watchdog = skynet.newservice("gateway/watchdog")
	local addr,port = skynet.call(watchdog, "lua", "start", {
		port = watchdog_port,
		maxclient = max_client,
		nodelay = true,
	})
	logger.info("watchdog listen on %s:%s", addr, port)

    logger.info(k_servertype .. " started")
end)