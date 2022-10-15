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

local function test_mysql()
    local function dotest()
        local sql = "insert into uid_gen()values()"
        local dbres = skynet.call(".mysqld", "lua", "exe", "hen", sql)
        logger.info("test_mysql, insert_id: %s", dbres.insert_id)
    end
    for i = 1, 2 do
        dotest()
    end
end

skynet.start(function()
    skynet.uniqueservice("common/cluster_mgr")
    skynet.newservice("debug_console", debug_port)
    skynet.uniqueservice("gateway/protoloader")
    skynet.uniqueservice("common/mysqld")

	local watchdog = skynet.newservice("gateway/watchdog")
	local addr,port = skynet.call(watchdog, "lua", "start", {
		port = watchdog_port,
		maxclient = max_client,
		nodelay = true,
	})
	logger.info("watchdog listen on %s:%s", addr, port)

    skynet.fork(test_mysql)

    logger.info(k_servertype .. " started")
end)