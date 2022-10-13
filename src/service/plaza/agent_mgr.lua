local skynet = require "skynet"
require "skynet.manager"
local skynet_util = require "hen.skynet_util"

local CMD = {}

skynet.start(function()
	skynet.dispatch("lua", function(session, source, cmd, ...)
        return skynet_util.lua_docmd(CMD, session, cmd, source, ...)
	end)
end)