local skynet = require "skynet"
require "skynet.manager"
local lua_util = require "lua_util"
local skynet_util = require "hen.skynet_util"
local logger = require "hen.logger"

local CMD = {}

local entities = {}

function CMD.create_entity()

end

skynet.start(function()
	skynet.dispatch("lua", function(session, source, cmd, ...)
        return skynet_util.lua_docmd(CMD, session, cmd, ...)
	end)
    skynet.register ".entity_mgr"
    logger.info(SERVICE_NAME .. " started")
end)