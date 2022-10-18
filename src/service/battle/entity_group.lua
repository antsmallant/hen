local skynet = require "skynet"
require "skynet.manager"
local lua_util = require "lua_util"
local skynet_util = require "hen.skynet_util"
local logger = require "hen.logger"

--[[
战斗集合
* 一种 game 下面会有多个 entity_group
* 每个 entity_group 下面会有多个 entity
* entity 分布在多个 battleserver，由 entity_mgr 负责创建及管理


]]
local CMD = {}

skynet.start(function()
	skynet.dispatch("lua", function(session, source, cmd, ...)
        return skynet_util.lua_docmd(CMD, session, cmd, ...)
	end)
end)