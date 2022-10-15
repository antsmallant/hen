local skynet = require "skynet.manager"
local skynet_util = require "hen.skynet_util"
local logger = require "hen.logger"
local mysql = require "skynet.db.mysql"
require "luaext"

local CMD = {}
local dbpool = {}
local dbidx = 1


--todo: 返回真正空闲的连接，而不是这样轮流的
local function get_conn(db)
    assert(db)
    local pool = dbpool[db]
    assert(pool, db)

    local idx = dbidx[db]
    assert(idx)
    assert(idx <= #pool)
    local conn = pool[idx]
    assert(conn)

    local nextidx = idx + 1
    if nextidx > #pool then nextidx = 1 end
    dbidx[db] = nextidx

    logger.info("get_conn, idx:%s", idx)

    return conn
end

local function create_conn(host, port, db, user, pwd, charset)
	local function on_connect(conn)
		conn:query("set charset "..charset)
	end
	local conn=mysql.connect({
		host=host,
		port=port,
		database=db,
		user=user,
		password=pwd,
        charset=charset,
		max_packet_size = 1024 * 1024,
		on_connect = on_connect
	})
    return conn
end

local function init_all()
    local redis_host = assert(skynet.getenv "redis_host")
    local redis_port = assert(tonumber(skynet.getenv "redis_port"))
    local redis_auth = assert(skynet.getenv "redis_auth")
    local redis_db = assert(tonumber(skynet.getenv "redis_db"))
    local redis_poolsize = assert(tonumber(skynet.getenv("redis_poolsize")))
    assert(redis_poolsize > 0, tostring(redis_poolsize))
end

function CMD.exe(script)
    assert(script, "script not given")
    local conn = get_conn()
    return conn:query(script)
end

skynet.start(function()
    skynet.dispatch("lua", function(session, source, cmd, ...)
        return skynet_util.lua_docmd(CMD, session, cmd, ...)
    end)

    init_all()

    skynet.register ".redisd"
    logger.info("redisd started")
end)