local skynet = require "skynet"
require "skynet.manager"
local lua_util = require "lua_util"
local skynet_util = require "hen.skynet_util"
local logger = require "hen.logger"

local CMD = {}
local g_game
local g_conf

function CMD.client_msg()

end

function CMD.start(conf)
    g_conf = conf
    local game_type = conf.game_type
    local entity_path = string.format("games.%s.%s_entity", game_type, game_type)
    g_game = require(entity_path)
    assert(g_game, entity_path .. " not found")
end


skynet.start(function()
	skynet.dispatch("lua", function(session, source, cmd, ...)
        return skynet_util.lua_docmd(CMD, session, cmd, ...)
	end)
end)