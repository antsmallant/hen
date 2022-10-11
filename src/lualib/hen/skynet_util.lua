local skynet = require "skynet"
local typeof = require "etcd.typeof"

local _M = {}

local function handle_err(e)
	e = debug.traceback(coroutine.running(), tostring(e), 2)
	skynet.error(e)
	return e
end

_M.handle_err = handle_err


--[[
如果执行没有 error 报错就返回, 报错就最多执行 max_times 次，每次间隔 sleep_inv 秒
arg:
    max_times: int, 最多执行次数, -1 表示无限
    sleep_inv: number, 重试休息间隔, 单位是秒, 可以是浮点数, 比如 0.1 秒, 精度只能去到 0.01 秒
    func: 要执行的函数
return:
    result: bool, true for success, false for fail
    ...: 如果 result 为 true, 则后面返回调用 func() 的结果
]]
function _M.error_retry(max_times, sleep_inv, func, ...)
    assert(typeof.int(max_times), "max_times not an integer")
    assert(typeof.number(sleep_inv), "sleep_inv not an integer")
    assert(typeof.Function(func), "func not an function")

    sleep_inv = math.ceil(sleep_inv*100) -- skynet.sleep是以0.01秒为单位的
    local cnt = 0
    while max_times == -1 or cnt < max_times do
        cnt = cnt + 1
        local res = table.pack(xpcall(func, handle_err, ...))
        if res[1] == true then
            return true, table.unpack(res, 2)
        end
        skynet.sleep(sleep_inv)
    end
    return false
end

return _M