local skynet = require "skynet.manager"
local cluster = require "skynet.cluster"
local json = require "cjson.safe"
local etcd_v3api = require "etcd.etcd_v3api"
local lua_util = require "lua_util"
local skynet_util = require "skynet_util"
local logger = require "logger"

local command = {}
local g_servertype = assert(skynet.getenv("servertype"), "invalid servertype")
local g_clustercfg
local g_etcdcli
local k_key_prefix = "/cluster"
local k_key_sep = "/"

--[[
store cluster data, table format:
{
    rev = <data revision>, 
    info = {<clusterid>=<clustervalue>, ...}
}    
]]
local g_clusterdata     

local function get_cluster_cfg()
    local cfg = {}
    cfg.ip = skynet.getenv("cluster_ip")
    if cfg.ip then
        cfg.ttl = assert(tonumber(skynet.getenv("cluster_ttl")), "invalid cluster_ttl")
        cfg.port = assert(tonumber(skynet.getenv("cluster_port")), "invalid cluster_port")
        cfg.listenip = skynet.getenv("cluster_listenip") or "0.0.0.0" --用于 listen 的 ip 可能会与 cluster_ip 一致，所以支持单独配置
    end
    return cfg
end

local function get_etcd_cfg()
    local hosts = json.decode(skynet.getenv "etcd_hosts")
    local user = skynet.getenv "etcd_user"
    local password = skynet.getenv "etcd_password"
    assert(hosts, [[invalid etcd_hosts, check config please, config should looks like etcd_hosts = "[\"127.0.0.1:2379\"]"]])

    return {
        hosts = hosts,
        user = user,
        password = password,
        serializer = "raw",
    }    
end

local function create_etcdcli(key_prefix)
    local cfg = get_etcd_cfg()
    cfg.key_prefix = key_prefix
    local etcdcli = etcd_v3api.new(cfg)
    return etcdcli
end

--return cluster_id, cluster_value
local function gen_cluster_kv(servertype, clustercfg, key_sep)
    local cluster_id = string.format("%s%s_%s_%s", key_sep, servertype, clustercfg.ip, clustercfg.port)
    local cluster_value = string.format("%s:%s", clustercfg.ip, clustercfg.port)       
    return cluster_id, cluster_value
end

local function reg_self(etcdcli, servertype, clustercfg, key_sep)
    local lease

    local function do_reg()
        local grantres = etcdcli:grant(clustercfg.ttl)
        lease = grantres.ID
        skynet.error("do_reg grantres:", lua_util.tostring(grantres))        
        local cluster_id, cluster_value = gen_cluster_kv(servertype, clustercfg, key_sep) 
        local attr = {lease = lease}
        local setres = etcdcli:set(cluster_id, cluster_value, attr)       
        logger.info("do_reg cluster_id:%s, cluster_value:%s, setres:%s", 
            cluster_id, cluster_value, lua_util.tostring(setres))                                   
    end

    --注册自己
    do_reg()

    --续约
    local function do_keepalive()
        local keepaliveres = etcdcli:keepalive(lease)
        --skynet.error("reg_self keepaliveres:", lua_util.tostring(keepaliveres))

        if keepaliveres and keepaliveres.result and keepaliveres.result.TTL then
            --success
            skynet.error("reg_self keepalive suc, TTL:", keepaliveres.result.TTL)
            return keepaliveres.result.TTL
        else
            --fail
            skynet.error("reg_self keepalive fail, do_reg again")
            do_reg()           
        end
    end

    skynet.fork(function()
        local inv = math.ceil(clustercfg.ttl/2.0)
        inv = clustercfg.ttl+2
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


local function unreg_self(etcdcli, servertype, clustercfg, key_sep)
    local cluster_id, _ = gen_cluster_kv(servertype, clustercfg, key_sep) 
    local res = etcdcli:delete(cluster_id, {timeout = 2})       
    logger.info("unreg_self cluster_id:%s, res:%s", 
        cluster_id, lua_util.tostring(res))       
end

--[[
    _k looks like: /cluster/battleserver_127.0.0.1_8102
    after extract, looks like: battleserver_127.0.0.1_8102
]]

local function extract_cluster_id(_key, key_prefix, key_sep)
    local start = key_prefix..key_sep
    return _key:sub(#start+1)
end

--[[
    拉取所有节点信息
clusterdata: {
    rev = <data revision>,
    info = {<cluster_id>=<cluster_value>, ...}
}
]]
local function fetch_cluster(etcdcli, key_prefix, key_sep)
    local ret = etcdcli:readdir(key_sep)
    skynet.error("fetch_cluster ret:", lua_util.tostring(ret))

    local info = {}
    if ret.kvs then
        for k, v in ipairs(ret.kvs) do
            local cluster_id = extract_cluster_id(v.key, k_key_prefix, k_key_sep)
            info[cluster_id] = v.value
        end
    end

    local clusterdata = {}
    clusterdata.rev = ret and ret.header and ret.header.revision
    clusterdata.info = info

    skynet.error("fetch_cluster, clusterdata:", lua_util.tostring(clusterdata))

    return clusterdata
end

--[[监听节点变化
    clusterdata: {
        rev = <data revision>, 
        info = {<clusterid>=<clustervalue>, ...}
    }
    注意: clusterdata 内部的数据会被本函数改变
]]
local function watch_cluster(etcdcli, clusterdata, key_prefix, key_sep)
    assert(type(clusterdata) == "table", "invalid clusterdata")

    --此函数不可添加阻塞操作，不可打断，否则会造成数据不一致
    local function on_data(data)
        local result = data.result
        if not (result and result.header) then
            logger.error("watch_cluster on_data invalid data: %s", lua_util.tostring(data))
            return 
        end
        local revision = result.header.revision
        assert(revision, "nil revision")

        --没有数据要处理
        if not result.events then
            return
        end

        logger.info("on_data before, clusterdata: %s", lua_util.tostring(clusterdata))

        --处理 events
        local info = clusterdata.info
        assert(info)
        for _, event in ipairs(result.events) do
            if event.type == "DELETE" then
                local cluster_id = extract_cluster_id(event.kv.key, key_prefix, key_sep)
                info[cluster_id] = nil
            else
                local cluster_id = extract_cluster_id(event.kv.key, key_prefix, key_sep)
                info[cluster_id] = event.kv.value
            end
        end

        --最后再设置 revision
        clusterdata.rev = revision

        logger.info("on_data after, clusterdata: %s", lua_util.tostring(clusterdata))
    end

    local function do_watch()
        skynet.error("do_watch begin")
        local rev = (clusterdata.rev or 0) + 1
        local opts = {start_revision = rev}
        local reader, stream = etcdcli:watchdir(key_sep, opts)
        if not reader then
            return
        end
        while true do
            local data = reader()
            if data then
                logger.info("do_watch recv: %s", lua_util.tostring(data))
                on_data(data)            
            else
                break
            end
        end
        --连接异常
        etcdcli:watchcancel(stream)
        logger.error("do_watch cancel")
    end

    skynet.fork(function ()
        while true do
            xpcall(do_watch, skynet_util.handle_err)
            skynet.sleep(5*100)
        end
    end)
end

function command.hello(source, msg)
    skynet.error("recv msg:", msg)
end

function command.oneof(source, pat)

end

function command.shutdown(source)
    logger.info("recv shutdown from: %s", source)
    local ok = unreg_self(g_etcdcli, g_servertype, g_clustercfg, k_key_sep)
    return ok
end

skynet.start(function()
	skynet.dispatch("lua", function(session, source, cmd, ...)
		return assert(command[string.lower(cmd)])(source, ...)
	end)

    g_clustercfg = get_cluster_cfg()

    --create etcd client
    g_etcdcli = create_etcdcli(k_key_prefix)
    if not g_etcdcli then
        error("create etcd conn fail")
    end

	--start as a cluster node
	if g_clustercfg.ip then
        assert(g_clustercfg.listenip and g_clustercfg.port, "cluster cfg invalid")
		local clusterd = skynet.uniqueservice("clusterd")
		skynet.call(clusterd, "lua", "listen", g_clustercfg.listenip, g_clustercfg.port)
		reg_self(g_etcdcli, g_servertype, g_clustercfg, k_key_sep)
	end

    --fetch and watch cluster info
    skynet.fork(function ()
        g_clusterdata = fetch_cluster(g_etcdcli, k_key_prefix, k_key_sep)
        watch_cluster(g_etcdcli, g_clusterdata, k_key_prefix, k_key_sep)
    end)

    skynet.register ".cluster_mgr"

    skynet.timeout(30*100, function()
        skynet.send(skynet.self(), "lua", "shutdown")
    end)

    skynet.error("cluster_mgr started")
end)