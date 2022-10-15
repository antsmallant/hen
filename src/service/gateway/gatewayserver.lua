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

local function test_redis()
    local dbutil = require "hen.dbutil"
    local r1 = skynet.call(".redisd", "lua", "exe", "set", "a", 100)
    logger.info("test_redis, r1:%s", lua_util.tostring(r1))
    assert(dbutil.redisok(r1))
    local r2 = skynet.call(".redisd", "lua", "exe", "get", "a")
    logger.info("test_redis, r2:%s", lua_util.tostring(r2))
    local r3 = skynet.call(".redisd", "lua", "exe", "mset", "a", 100, "b", 200, "c", 300)
    logger.info("test_redis, r3:%s", lua_util.tostring(r3))
    local r4 = skynet.call(".redisd", "lua", "exe", "mget", "a", "b", "c")
    logger.info("test_redis, r4:%s", lua_util.tostring(r4))
end

skynet.start(function()
    skynet.uniqueservice("common/cluster_mgr")
    skynet.uniqueservice("common/mysqld")
    skynet.uniqueservice("common/redisd")
    skynet.uniqueservice("debug_console", debug_port)

    skynet.uniqueservice("gateway/protoloader")
	local watchdog = skynet.uniqueservice("gateway/watchdog")
	local addr,port = skynet.call(watchdog, "lua", "start", {
		port = watchdog_port,
		maxclient = max_client,
		nodelay = true,
	})
	logger.info("watchdog listen on %s:%s", addr, port)

    logger.info(k_servertype .. " started")
end)