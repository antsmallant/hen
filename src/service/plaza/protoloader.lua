local skynet = require "skynet"
local sprotoparser = require "sprotoparser"
local sprotoloader = require "sprotoloader"
local proto = require "plaza.proto"

skynet.start(function()
    --todo: rewrite sprotoloader, support at least 2000 global proto, now at max is 16,
    --      which is define as MAX_GLOBALSPROTO in lsproto.c
	sprotoloader.save(proto.c2s_plaza, 1)
	sprotoloader.save(proto.s2c_plaza, 2)

    --games
    --todo: dynamic load
	sprotoloader.save(proto.c2s_chatting, 3)
	sprotoloader.save(proto.s2c_chatting, 4)

	-- don't call skynet.exit() , because sproto.core may unload and the global slot become invalid
end)
