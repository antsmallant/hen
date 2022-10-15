local skynet = require "skynet.manager"
local skynet_util = require "hen.skynet_util"
local logger = require "hen.logger"
local redis = require "skynet.db.redis"
require "luaext"

local CMD = {}
local dbpool = {}
local dbidx = 1

--todo: 返回真正空闲的连接，而不是这样轮流的
local function get_conn()
    local conn = dbpool[dbidx]
    assert(conn)
    logger.info("redisd get_conn, dbidx:%s", dbidx)

    dbidx = dbidx + 1
    if dbidx > #dbpool then dbidx = 1 end

    return conn
end

local function create_conn(host, port, db, auth)
    local conn = redis.connect {
        host = host,
        port = port,
        db   = db,
        auth = auth
    }
    return conn
end

local function init_all()
    local redis_host = assert(skynet.getenv "redis_host")
    local redis_port = assert(tonumber(skynet.getenv "redis_port"))
    local redis_db = assert(tonumber(skynet.getenv "redis_db"))
    local redis_auth = assert(skynet.getenv "redis_auth")
    local redis_poolsize = assert(tonumber(skynet.getenv("redis_poolsize")))
    assert(redis_poolsize > 0, tostring(redis_poolsize))

    for i = 1, redis_poolsize do
        local conn = create_conn(redis_host, redis_port, redis_db, redis_auth)
        assert(conn, i)
        table.insert(dbpool, conn)
    end
end

function CMD.exe(cmd, ...)
    assert(cmd, "cmd not given")
    local conn = get_conn()
    assert(conn, cmd)
    local f = conn[cmd]
    assert(f, "cmd not found:" .. cmd)
    return f(conn, ...)
end

skynet.start(function()
    skynet.dispatch("lua", function(session, source, cmd, ...)
        return skynet_util.lua_docmd(CMD, session, cmd, ...)
    end)

    init_all()

    skynet.register ".redisd"
    logger.info("redisd started")
end)