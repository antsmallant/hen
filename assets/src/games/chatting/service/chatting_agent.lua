local skynet = require "skynet"
local logger = require "hen.logger"
require "luaext"

--[[
    游戏模块, 会被 plaza/agent.lua 载入
]]

local _M = {}
local _mt = {}
local REQUEST = {}

function REQUEST:join_chatting(obj)
    logger.info("join_chatting")
    return {
        err = 1
    }
end

function _mt:game_msg(name, args)
    logger.info("chatting_agent game_msg, name:%s, args:%s",
        name, tostring(args))
    self.parent_interface.hello()

    local f = REQUEST[name]
    if f then
        return f(args, self)
    end
end

function _M.new(_interface)
    local obj = {
        parent_interface = _interface,
    }
    return setmetatable(obj, {__index = _mt})
end

return _M