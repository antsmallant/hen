local skynet = require "skynet"
require "skynet.manager"
local skynet_util = require "hen.skynet_util"
local errors = require "common.errors"
local cluster_util = require "hen.cluster_util"
local logger = require "hen.logger"

local CMD = {}
--[[
所有用户
{
    [uid] = {
        agent = ,
        ...
    }
    ...
}
]]
local g_users = {}

--检查用户是否已经登录过其中某个 plazaserver
local function has_logined(uid)
    if g_users[uid] then
        return true, cluster_util.get_cluster_id(), g_users[uid].agent
    end
    return false
end

function CMD.login(gatewaysvr, gateway_agent, uid)
    local has, cluster_id, agent = has_logined(uid)
    if has then
        return {
            err = errors.already_login,
            plazasvr = cluster_util.get_cluster_id(),
            agent = agent,
        }
    end
    local agent = skynet.newservice("plaza/agent")
    local conf =  {
        gatewaysvr = gatewaysvr,
        gateway_agent = gateway_agent,
        uid = uid
    }
    skynet.call(agent, "lua", "start", conf)
    g_users[uid] = {
        gatewaysvr = gatewaysvr,
        gateway_agent = gateway_agent,
        agent = agent
    }
    return {err = errors.ok, agent = agent}
end

function CMD.logout(gatewaysvr, uid)
    local user = g_users[uid]
    if user then
        if user.gatewaysvr == gatewaysvr then
            logger.info("user logout:%s", uid)
            skynet.send(user.agent, "lua", "disconnect")
            g_users[uid] = nil
        else
            logger.info("logout gateway not match, mine:%s, theirs:%s",
                user.gatewaysvr, gatewaysvr)
        end
    else
        logger.info("user logout not found user: %s", uid)
    end
end

skynet.start(function()
	skynet.dispatch("lua", function(session, source, cmd, ...)
        return skynet_util.lua_docmd(CMD, session, cmd, ...)
	end)
    skynet.register ".agent_mgr"
    logger.info("agent_mgr started")
end)