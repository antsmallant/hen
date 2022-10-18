local skynet = require "skynet"
local socket = require "skynet.socket"
local sproto = require "sproto"
local sprotoloader = require "sprotoloader"
local cluster_util = require "hen.cluster_util"
local skynet_util = require "hen.skynet_util"
local logger = require "hen.logger"
local mysql = require "skynet.db.mysql"
local dbname = require "common.dbname"
local errors = require "common.errors"
require "luaext"


local CMD = {}
local REQUEST = {}
local g_interface = {}  --暴露给游戏mod的接口
local client_fd
local k_gamedb = assert(dbname.gamedb)
local k_servertype = assert(skynet.getenv "servertype")
local g_plaza_host
local g_plaza_pack
local g_gatewaysvr
local g_gateway_agent
local g_uid
local g_userinfo
local g_gamemod = {}
local g_gameproto = {}



local function load_game(game)
    assert(game)
    if g_gamemod[game] and g_gameproto[game] then
        return
    end
    assert(g_gamemod[game] == nil, game)
    assert(g_gameproto[game] == nil, game)

    local modpath = string.format("games.%s.service.%s_agent", game, game)
    local mod = require(modpath)
    assert(mod, modpath)
    g_gamemod[game] = mod.new(g_interface)

    --todo: dynamic load
    if game == "chatting" then
        local tmp = {}
        -- slot 3,4 set at plaza/protoloader.lua
        tmp.host = sprotoloader.load(3):host "package"
        tmp.pack = tmp.host:attach(sprotoloader.load(4))
        g_gameproto[game] = tmp
    else
        assert(false, "not support " .. game)
    end
end

function g_interface.hello()
    logger.info("g_interface.hello")
end

function REQUEST:get_game_list()
    return {
        games = {
            {name = "chatting"}
        }
    }
end

local function _game_msg(game, name, args, response)
    local mod = g_gamemod[game]
    assert(mod, game)
	local f = assert(mod.game_msg, game)
	local r = f(mod, name, args)
	if response then
		return response(r)
	end
end

--游戏模块要处理的消息
function REQUEST:game_msg()
    local game = self.game
    local msg = self.msg

    --加载游戏模块
    if not g_gamemod[game] then
        load_game(game)
    end
    assert(g_gamemod[game], game)
    assert(g_gameproto[game], game)

    --分发消息给具体的游戏模块去处理
    local type, protoname, result, resp = g_gameproto[game].host:dispatch(msg, #msg)
    if type ~= "REQUEST" then
        error("game_msg not support type:"..type)
    end
    local ok, result = pcall(_game_msg, game, protoname, result, resp)
    if ok then
        return {err = errors.ok, msg = result}
    else
        skynet.error(result)
        return {err = errors.game_msg_err}
    end
end

local function request(name, args, response)
	local f = assert(REQUEST[name])
	local r = f(args)
	if response then
		return response(r)
	end
end

local function send_package(pack)
    local cluster_id = cluster_util.get_cluster_id()
    cluster_util.send(g_gatewaysvr, g_gateway_agent,
        "server_msg", cluster_id, k_servertype, pack)
end

local function load_user_info(uid)
    local sql = string.format("select username from users where uid = %s",
        mysql.quote_sql_str(uid))
    local dbres = skynet.call(".mysqld", "lua", "exe", k_gamedb, sql)
    if dbres and dbres[1] and dbres[1].username then
        return {username = dbres[1].username}
    end
    return nil
end

function CMD.start(conf)
	g_gatewaysvr = conf.gatewaysvr
    g_gateway_agent = conf.gateway_agent
	g_uid = conf.uid

	-- slot 1,2 set at plaza/protoloader.lua
	g_plaza_host = sprotoloader.load(1):host "package"
	g_plaza_pack = g_plaza_host:attach(sprotoloader.load(2))

    g_userinfo = load_user_info(g_uid)
    assert(g_userinfo, g_uid)
end

function CMD.client_msg(msg)
    local type, protoname, result, resp = g_plaza_host:dispatch(msg, #msg)
    if type ~= "REQUEST" then
        error("not support type:"..type)
    end
    local ok, result = pcall(request, protoname, result, resp)
    if ok then
        if result then
            send_package(result)
        end
    else
        skynet.error(result)
    end
end

function CMD.disconnect()
    logger.info("user disconnect:"..g_uid)
	skynet.exit()
end

skynet.start(function()
	skynet.dispatch("lua", function(session, source, cmd, ...)
        return skynet_util.lua_docmd(CMD, session, cmd, ...)
	end)
end)
