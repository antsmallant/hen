local skynet = require "skynet"
local socket = require "skynet.socket"
local sproto = require "sproto"
local sprotoloader = require "sprotoloader"
local cluster_util = require "hen.cluster_util"
local skynet_util = require "hen.skynet_util"


local CMD = {}
local REQUEST = {}
local client_fd

local k_servertype = assert(skynet.getenv "servertype")
local host
local pack_request
local g_gatewaysvr
local g_gateway_agent
local g_uid

function REQUEST:get_game_list()
    return {
        games = {{name = "chatting"}}
    }
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
        "redirect_msg", cluster_id, k_servertype, pack)
end

function CMD.start(conf)
	g_gatewaysvr = conf.gatewaysvr
    g_gateway_agent = conf.gateway_agent
	g_uid = conf.uid

	-- slot 1,2 set at main.lua
	host = sprotoloader.load(1):host "package"
	pack_request = host:attach(sprotoloader.load(2))
end

function CMD.client_msg(msg)
    local type, protoname, result, resp = host:dispatch(msg, #msg)
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
	-- todo: do something before exit
	skynet.exit()
end

skynet.start(function()
	skynet.dispatch("lua", function(session, source, cmd, ...)
        return skynet_util.lua_docmd(CMD, session, cmd, ...)
	end)
end)
