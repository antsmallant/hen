local skynet = require "skynet"
local cluster = require "skynet.cluster"
local logger = require "hen.logger"

local cluster_mgr
local _M = {}

_M.send = cluster.send
_M.call = cluster.call

local function get_names(pat)
    return skynet.call(cluster_mgr, "lua", "get_names", pat)
end
_M.get_names = get_names


local function get_rand_one(pat)
    local names = get_names(pat)
    if (not names) or (#names == 0) then
        return nil
    end
    local idx = math.random(1, #names)
    return names[idx]
end
_M.get_rand_one = get_rand_one

--cluster.send multi target
function _M.broadcast(pat, address, ...)
    local names = get_names(pat)
    for _, node in ipairs(names) do
        cluster.send(node, address, ...)
    end
end

function _M.send_rand_one(pat, address, ...)
    local node = get_rand_one(pat)
    if node then
        return cluster.send(node, address, ...)
    end
end

function _M.call_rand_one(pat, address, ...)
    local node = get_rand_one(pat)
    logger.info("call_rand_one, pat:%s, node:%s", pat, node)
    if node then
        return cluster.call(node, address, ...)
    end
end

function _M.timeout_call(timeout, node, address, ...)
end

local g_cluster_id
function _M.get_cluster_id()
    if g_cluster_id then return g_cluster_id end
    g_cluster_id = skynet.call(cluster_mgr, "lua", "get_cluster_id")
    return g_cluster_id
end

skynet.init(function()
	cluster_mgr = skynet.uniqueservice("common/cluster_mgr")
end)


return _M