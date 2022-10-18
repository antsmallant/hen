local skynet = require "skynet"
require "skynet.manager"
local cluster = require "skynet.cluster"
local json = require "cjson.safe"
local lua_util = require "lua_util"
local skynet_util = require "hen.skynet_util"
local logger = require "hen.logger"
local etcd_util = require "hen.etcd_util"


local CMD = {}
local g_servertype = assert(skynet.getenv("servertype"), "invalid servertype")
local g_clustercfg
local k_cluster_key_prefix = "/cluster"
local k_master_key_prefix = "/master"
local k_key_sep = "/"
local k_init_retry_times = 30   --初始化的时候最多重试次数
local k_retry_inv = 2           --重试间隔(秒)
local g_cluster_etcdcli
local g_master_etcdcli

--[[
store cluster data, table format:
{
    rev = <data revision>,
    info = {<clusterid>=<clustervalue>, ...}
}
]]
local g_clusterdata

--[[
store master data, table format:
{
    rev = <data revision>,
    info = {<servertype>=<clusterid>, ...}
}
]]
local g_masterdata


--[[
    _k looks like: /cluster/battleserver_127.0.0.1_8102
    after extract, looks like: battleserver_127.0.0.1_8102
]]
local function extract_key(_key, key_prefix, key_sep)
    local start = key_prefix..key_sep
    return _key:sub(#start+1)
end

local function cluster_get_cfg()
    local cfg = {}
    cfg.ip = skynet.getenv("cluster_ip")
    if cfg.ip then
        cfg.ttl = assert(tonumber(skynet.getenv("cluster_ttl")), "invalid cluster_ttl")
        cfg.port = assert(tonumber(skynet.getenv("cluster_port")), "invalid cluster_port")
        cfg.listenip = skynet.getenv("cluster_listenip") or "0.0.0.0" --用于 listen 的 ip 可能会与 cluster_ip 一致，所以支持单独配置
    end
    return cfg
end

--return cluster_id, cluster_value
local function cluster_gen_kv(servertype, clustercfg, key_sep)
    local cluster_id = string.format("%s%s_%s_%s", key_sep, servertype, clustercfg.ip, clustercfg.port)
    local cluster_value = string.format("%s:%s", clustercfg.ip, clustercfg.port)
    return cluster_id, cluster_value
end

local function cluster_reg_self(etcdcli, servertype, clustercfg, key_sep)
    local lease

    local function do_reg()
        local grantres = etcdcli:grant(clustercfg.ttl)
        lease = grantres and grantres.ID
        if not lease then
            error(string.format("do_reg fail, get nil lease, grantres:%s", lua_util.tostring(grantres)))
        end

        local cluster_id, cluster_value = cluster_gen_kv(servertype, clustercfg, key_sep)
        local attr = {lease = lease}
        local setres = etcdcli:set(cluster_id, cluster_value, attr)
        if not (setres and setres.header and setres.header.revision) then
            error(string.format("do_reg fail, cluster_id:%s, cluster_value:%s, lease:%s, setres:%s",
                cluster_id, cluster_value, lease, lua_util.tostring(setres)))
        end
        logger.info("do_reg success, cluster_id:%s, cluster_value:%s, lease:%s",
            cluster_id, cluster_value, lease)
    end

    local function do_keepalive()
        local keepaliveres = etcdcli:keepalive(lease)

        if keepaliveres and keepaliveres.result and keepaliveres.result.TTL then
            --success
            return keepaliveres.result.TTL
        else
            --fail
            logger.error("do_keepalive fail, will try do_reg, keepaliveres:%s", lua_util.tostring(keepaliveres))
            skynet_util.error_retry(-1, k_retry_inv, do_reg) --运行期间无限次数进行重试
        end
    end

    --注册自己
    local ok = skynet_util.error_retry(k_init_retry_times, k_retry_inv, do_reg)
    if not ok then
        error("do_reg finally fail")
    end

    --定时续约
    skynet.fork(function()
        local inv = math.ceil(clustercfg.ttl/2.0)
        while true do
            skynet.sleep(inv*100)
            local ok, ttl = xpcall(do_keepalive, skynet_util.handle_err)
            if ok and ttl then
                inv = math.ceil(ttl/2.0)
            else
                inv = math.ceil(clustercfg.ttl/2.0)
            end
        end
    end)
end


local function cluster_unreg_self(etcdcli, servertype, clustercfg, key_sep)
    local cluster_id, _ = cluster_gen_kv(servertype, clustercfg, key_sep)
    local res = etcdcli:delete(cluster_id, {timeout = 2})
    logger.info("cluster_unreg_self cluster_id:%s, res:%s",
        cluster_id, lua_util.tostring(res))
end

--[[
    拉取信息
clusterdata: {
    rev = <data revision>,
    info = {<cluster_id>=<cluster_value>, ...}
}
]]
local function fetch_data(etcdcli, key_prefix, key_sep)
    logger.info("fetch_data begin, key_prefix:%s, key_sep:%s", key_prefix, key_sep)

    local ret = etcdcli:readdir(key_sep)
    if not (ret and ret.header and ret.header.revision) then
        error(string.format("fetch_data fail, ret:%s", lua_util.tostring(ret)))
    end

    local info = {}
    if ret.kvs then
        for k, v in ipairs(ret.kvs) do
            local cluster_id = extract_key(v.key, key_prefix, key_sep)
            info[cluster_id] = v.value
        end
    end

    local clusterdata = {}
    clusterdata.rev = ret.header.revision
    clusterdata.info = info

    logger.info("fetch_data suc, clusterdata: %s", lua_util.tostring(clusterdata))

    return clusterdata
end

--[[监听变化
    store: {
        rev = <data revision>,
        info = {<key>=<value>, ...}
    }
    注意: store 内部的数据会被本函数改变
    on_change: function, 数据有变化时回调
]]
local function watch_change(etcdcli, key_prefix, key_sep, store, on_change)
    assert(type(store) == "table", "invalid store")

    --此函数不可添加阻塞操作，不可打断，否则会造成数据不一致
    --return true if data changed
    local function on_data(data)
        local result = data.result
        if not (result and result.header) then
            logger.error("watch_change on_data invalid, key_prefix:%s, data:%s",
                key_prefix, lua_util.tostring(data))
            return false
        end
        local revision = result.header.revision
        assert(revision, "watch_change recv nil revision, key_prefix:"..key_prefix)

        --没有数据要处理
        if not result.events then
            return false
        end

        --处理 events
        local info = store.info
        assert(info)
        for _, event in ipairs(result.events) do
            local real_key = extract_key(event.kv.key, key_prefix, key_sep)
            if event.type == "DELETE" then
                info[real_key] = nil
            else
                info[real_key] = event.kv.value
            end
        end

        --最后再设置 revision
        store.rev = revision

        logger.info("watch_change on_data fin, key_prefix:%s, store:%s",
            key_prefix, lua_util.tostring(store))

        if #result.events > 0 then
            return true
        end
        return false
    end

    local function do_watch()
        logger.info("watch_change do_watch begin, key_prefix:%s", key_prefix)
        local rev = (store.rev or 0) + 1
        local opts = {start_revision = rev}
        local reader, stream = etcdcli:watchdir(key_sep, opts)
        if not reader then
            return
        end
        while true do
            local data = reader()
            if data then
                local has_change = on_data(data)
                if has_change and on_change ~= nil then
                    xpcall(on_change, skynet_util.handle_err)
                end
            else
                break
            end
        end
        --连接异常
        etcdcli:watchcancel(stream)
        logger.error("watch_change do_watch cancel, key_prefix:%s", key_prefix)
    end

    skynet.fork(function ()
        while true do
            xpcall(do_watch, skynet_util.handle_err)
            skynet.sleep(5*100)
        end
    end)

    return true
end

--获取符合 pat 规则的服务器名字列表
--pat : string, 正则表达式: 1、nil 或 ".*" 表示获取全部的服务器名字; 2、按照正常的 lua 正则规则进行匹配.
--      比如要获取所有 plazaserver, 则 "^plazaserver.*", 如果获取所有 server, 则 nil 或 ".*"
function CMD.cluster_get_names(source, pat)
	local names = {}
    local info = g_clusterdata.info
	if not pat or pat == ".*" then
		for name in pairs(info) do table.insert(names, name) end
		return names
	end
	for name in pairs(info) do
		if name:match(pat) == name then table.insert(names, name) end
	end
	return names
end

function CMD.shutdown(source)
    logger.info("recv shutdown from: %s", source)
    local ok = cluster_unreg_self(g_cluster_etcdcli, g_servertype, g_clustercfg, k_key_sep)
    return ok
end

function CMD.hello(source, msg)
    logger.info("recv %s from: %s", msg, source)
    return "hi"
end

function CMD.get_cluster_id(source)
    local cluster_id = cluster_gen_kv(g_servertype, g_clustercfg, "")
    return cluster_id
end

local function init_cluster()
    --create etcd client
    g_cluster_etcdcli = etcd_util.create_etcdcli(k_cluster_key_prefix)
    if not g_cluster_etcdcli then
        error("init_cluster create etcd conn fail")
    end

    g_clustercfg = cluster_get_cfg()

	--start as a cluster node
	if g_clustercfg.ip then
        assert(g_clustercfg.listenip and g_clustercfg.port, "cluster cfg invalid")
		local clusterd = skynet.uniqueservice("clusterd")
		skynet.call(clusterd, "lua", "listen", g_clustercfg.listenip, g_clustercfg.port)
		cluster_reg_self(g_cluster_etcdcli, g_servertype, g_clustercfg, k_key_sep)
	end

    --fetch
    local ok, store = skynet_util.error_retry(k_init_retry_times, k_retry_inv,
        fetch_data, g_cluster_etcdcli, k_cluster_key_prefix, k_key_sep)
    if ok and store then
        g_clusterdata = store
        cluster.reload(g_clusterdata.info)
        logger.info("init_cluster fetch_data fin, info:%s", lua_util.tostring(g_clusterdata.info))
    else
        error("init_cluster fetch_data fail")
    end

    --watch change
    local function on_change()
        cluster.reload(g_clusterdata.info)
        logger.info("watch_change on_change cluster  reloaded, info:%s",
            lua_util.tostring(store.info))
    end
    watch_change(g_cluster_etcdcli, k_cluster_key_prefix, k_key_sep, g_clusterdata, on_change)
end

local function init_master()
    --create etcd client
    g_master_etcdcli = etcd_util.create_etcdcli(k_master_key_prefix)
    if not g_master_etcdcli then
        error("init_master create etcd conn fail")
    end

    --fetch master info
    local ok, store = skynet_util.error_retry(k_init_retry_times, k_retry_inv,
        fetch_data, g_master_etcdcli, k_master_key_prefix, k_key_sep)
    if ok and store then
        g_masterdata = store
        logger.info("init_master fetch_data fin, info:%s",
            lua_util.tostring(g_masterdata.info))
    else
        error("init_master fetch_data fail")
    end

    watch_change(g_master_etcdcli, k_master_key_prefix, k_key_sep, g_masterdata, nil)
end

skynet.start(function()
	skynet.dispatch("lua", function(session, source, cmd, ...)
        return skynet_util.lua_docmd(CMD, session, cmd, source, ...)
	end)

    init_cluster()
    init_master()
    skynet.register ".cluster_mgr"
    skynet.error("cluster_mgr started")
end)