local skynet = require "skynet"

--被 battle/entity.lua 载入的逻辑

local _M = {}
local _mt = {}

function _mt:on_client_msg(name, args)
    local f = _mt[name]
    assert(f, name)
    return f(self, args)
end

function _M.new(interface)
    local obj = {
        interface = interface,
    }
    return setmetatable(obj, {__index = _mt})
end

return _M