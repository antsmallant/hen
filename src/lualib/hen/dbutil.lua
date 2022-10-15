local skynet = require "skynet.manager"

local _M = {}

function _M.redisok(r)
    return r == "OK"
end

return _M