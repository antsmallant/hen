local skynet = require "skynet"
require "skynet.manager"
local mysql = require "skynet.db.mysql"
local logger = require "hen.logger"
local skynet_util = require "hen.skynet_util"
require "luaext"
local dbname = require "common.dbname"

local CMD = {}
local k_gamedb = assert(dbname.gamedb)

local function get_uid(username)
    local sql = string.format("select * from users where username = %s", mysql.quote_sql_str(username))
    local dbres = skynet.call(".mysqld", "lua", "exe", k_gamedb, sql)
    if dbres and dbres[1] and dbres[1].uid then
        return dbres[1].uid
    end
end

local function gen_uid()
    local sql = string.format("insert into uid_gen () values ()")
    local dbres = skynet.call(".mysqld", "lua", "exe", k_gamedb, sql)
    if dbres and dbres.insert_id then
        return dbres.insert_id
    end
end

local function create_user(username, uid)
    local sql = string.format("insert into users (username, uid) values (%s, %s)", mysql.quote_sql_str(username), mysql.quote_sql_str(uid))
    local dbres = skynet.call(".mysqld", "lua", "exe", k_gamedb, sql)
    logger.info("create_user dbres:%s", tostring(dbres))
    return true
end

--简单的用户认证(只用于简单示例)
function CMD.verify(username, pwd)
    assert(username)
    assert(pwd)
    local uid = get_uid(username)
    if uid then
        return true, uid
    end
    uid = gen_uid()
    local ok = create_user(username, uid)
    if ok then
        return true, uid
    end
    return false, "create user fail"
end

skynet.start(function()
    skynet.dispatch("lua", function(session, source, cmd, ...)
        return skynet_util.lua_docmd(CMD, session, cmd, ...)
    end)
    skynet.register ".logind"
    logger.info("logind started")
end)