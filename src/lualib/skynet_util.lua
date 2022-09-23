local skynet = require "skynet"

local _M = {}

function _M.handle_err(e)
	e = debug.traceback(coroutine.running(), tostring(e), 2)
	skynet.error(e)
	return e
end

return _M