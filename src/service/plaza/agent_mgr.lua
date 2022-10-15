local skynet = require "skynet"
require "skynet.manager"
local skynet_util = require "hen.skynet_util"

local CMD = {}

--检查用户是否已经登录过其中某个 plazaserver
local function chk_if_logined(uid)
end

function CMD.login(uid)

end

skynet.start(function()
	skynet.dispatch("lua", function(session, source, cmd, ...)
        return skynet_util.lua_docmd(CMD, session, cmd, source, ...)
	end)
end)