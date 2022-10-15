local skynet = require "skynet.manager"
local skynet_util = require "hen.skynet_util"
local logger = require "hen.logger"
local mysql = require "skynet.db.mysql"
require "luaext"

local CMD = {}
local dbpool = {}
local dbidx = {}
local default_charset = "utf8mb4"

local function valid_db(db)
    return (dbpool[db] ~= nil)
end

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
		host = host,
		port = port,
		database = db,
		user = user,
		password = pwd,
        charset = charset,
		max_packet_size = 1024 * 1024,
		on_connect = on_connect
	})
    return conn
end

local function init_all()
    local mysql_host = assert(skynet.getenv "mysql_host")
    local mysql_port = assert(tonumber(skynet.getenv "mysql_port"))
    local mysql_user = assert(skynet.getenv "mysql_user")
    local mysql_pwd = assert(skynet.getenv "mysql_pwd")
    local mysql_dbs = assert(skynet.getenv "mysql_dbs")
    local mysql_poolsize = assert(tonumber(skynet.getenv "mysql_poolsize"))
    assert(mysql_poolsize > 0, tostring(mysql_poolsize))
    local dbs = string.split(mysql_dbs, ";")
    assert(#dbs > 0)

    for _, db in ipairs(dbs) do
        dbidx[db] = 1
        dbpool[db] = {}
        for i = 1, mysql_poolsize do
            local conn = create_conn(mysql_host, mysql_port, db, mysql_user, mysql_pwd, default_charset)
            assert(conn, db)
            table.insert(dbpool[db], conn)
        end
    end
end

function CMD.exe(db, sql)
    assert(db, "db not given")
    assert(sql, "sql not given")
    assert(valid_db(db), "not a valid db:"..db)
    local conn = get_conn(db)
    assert(conn, "get no conn for db: "..db)
    return conn:query(sql)
end

skynet.start(function()
    skynet.dispatch("lua", function(session, source, cmd, ...)
        return skynet_util.lua_docmd(CMD, session, cmd, ...)
    end)
    init_all()
    skynet.register ".mysqld"
    logger.info("mysqld started")
end)