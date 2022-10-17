local skynet = require "skynet"
local etcd_util = require "hen.etcd_util"
local typeof = require "etcd.typeof"
local logger = require "hen.logger"
local cluster_util = require "hen.cluster_util"
local skynet_util = require "hen.skynet_util"
require "luaext"
require "skynet.queue"

local _M = {}
local _mt = {}
local k_key_prefix = "/master"
local k_key_sep = "/"
local k_master_ttl = assert(tonumber(skynet.getenv "master_ttl"))
assert(k_master_ttl > 0, tostring(k_master_ttl))
local cycle_queue = skynet.queue()

function _mt:run()
    if self.is_running then return end
    self.is_running = true

    local etcdcli = etcd_util.create_etcdcli(k_key_prefix)
    if not etcdcli then
        error("create etcdcli fail")
    end

    local function gen_key()
        return k_key_sep..self.master_key
    end

    local function _try_2_be_master()
        local grantres = etcdcli:grant(k_master_ttl)
        local lease = grantres and grantres.ID
        if not lease then
            error(string.format("try_2_be_master fail, get nil lease, grantres:%s",
                tostring(grantres)))
        end

        local etcd_key = gen_key()
        local etcd_val = self.master_val

        --尝试键不存在的情况
        local nxres = etcdcli:setnx(etcd_key, etcd_val, lease, {})
        logger.info("try_2_be_master setnx, lease:%s, nxres: %s", lease, tostring(nxres))
        if nxres and nxres.succeeded == true then
            logger.info("try_2_be_master setnx success")
            self.is_master = true
            self.lease = lease
            self.handler.become()
            return
        end

        --尝试键与自己相等的情况
        local eqres = etcdcli:seteq(etcd_key, etcd_val, lease, {})
        logger.info("try_2_be_master seteq, lease:%s, eqres: %s", lease, tostring(eqres))
        if eqres and eqres.succeeded == true then
            logger.info("try_2_be_master seteq success")
            self.is_master = true
            self.lease = lease
            self.handler.become()
            return
        end

        --最终失败, 回收 lease
        skynet.fork(function() etcdcli:revoke(lease) end) --fork 避免无谓阻塞
    end

    local function _master_keepalive()
        assert(self.is_master)
        assert(self.lease)

        local etcd_key = gen_key()
        local etcd_val = self.master_val
        local lease = self.lease

        local keepres = etcdcli:keepalive(lease)
        if keepres and keepres.result and keepres.result.TTL then
            --需要确切的验证自己的key还是存在的并且再次设置lease以确保没有意外的情况发生
            local eqres = etcdcli:seteq(etcd_key, etcd_val, lease, {})
            if eqres and eqres.succeeded == true then
                logger.info("master_keepalive suc, lease:%s, TTL:%s",
                    lease, keepres.result.TTL)
                return true
            else
                logger.info("master_keepalive fail seteq, lease:%s", lease)
                skynet.fork(function() etcdcli:revoke(lease) end)  --回收, fork 避免无谓阻塞
            end
        else
            logger.info("master_keepalive fail keepalive, lease:%s", lease)
        end

        --失败了
        self.is_master = false
        self.lease = nil
        self.handler.retire()
        return false
    end

    local try_2_be_master = function() return cycle_queue(_try_2_be_master) end
    local master_keepalive = function() return cycle_queue(_master_keepalive) end

    local function cycle()
        if self.is_master and master_keepalive() then
            return
        end
        try_2_be_master()
    end

    skynet.fork(function()
        while true do
            local begin_t = skynet.now()
            xpcall(cycle, skynet_util.handle_err)
            local cost_inv = skynet.now()-begin_t

            --如果 cycle 调用消耗的时间超过了计划要 sleep 的间隔就不 sleep 了
            local plan_sleep_inv = math.ceil(k_master_ttl/3.0)*100 --计划要 sleep 的间隔
            local real_sleep_inv = plan_sleep_inv-cost_inv
            if real_sleep_inv > 0 then
                skynet.sleep(real_sleep_inv)
            end
        end
    end)
end

function _mt:is_master()
    return self.is_master
end

function _M.new(master_key, master_val, handler)
    assert(master_key)
    assert(typeof.table(handler))

    local obj = {
        master_key = master_key,
        master_val = master_val,
        handler = handler,
        is_master = false,
        is_running = false,
    }
    return setmetatable(obj, {__index = _mt})
end

return _M