local skynet = require "skynet"
require "skynet.manager"
local lua_util = require "lua_util"
local skynet_util = require "hen.skynet_util"
local logger = require "hen.logger"
local master_util = require "hen.master_util"
local cluster_util = require "hen.cluster_util"

local CMD = {}
local g_master
local master_handler = {}
local k_servertype = assert(skynet.getenv "servertype")

function master_handler.become()
    logger.info("become master")
end

function master_handler.retire()
    logger.info("retire master")
end

skynet.start(function()
	skynet.dispatch("lua", function(session, source, cmd, ...)
        return skynet_util.lua_docmd(CMD, session, cmd, ...)
	end)
    local cluster_id = cluster_util.get_cluster_id()
    g_master = master_util.new(k_servertype, cluster_id, master_handler)
    g_master:run()
    skynet.register ".battle_master"
    logger.info(SERVICE_NAME .. " started")
end)