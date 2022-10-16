local skynet = require "skynet"
local etcd_util = require "hen.etcd_util"
local typeof = require "etcd.typeof"
local logger = require "hen.logger"

local _M = {}
local _mt = {}
local k_key_prefix = "/master"

function _mt:run()
    if self.is_running then return end
    self.is_running = true

    local function try_2_be_master()
    end

    skynet.fork(function()
        while true do
            skynet.sleep(500)
            try_2_be_master()
        end
    end)
end

function _mt:is_master()
    return self.is_master
end


function _M.new(master_key, handler)
    assert(master_key)
    assert(typeof.table(handler))

    local obj = {
        master_key = master_key,
        handler = handler,
        is_master = false,
        is_running = false,
    }
    return setmetatable(obj, {__index = _mt})
end

return _M