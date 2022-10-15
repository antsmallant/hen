local skynet_dir = "./"
local proj_dir = skynet_dir.."../../../"
package.cpath = skynet_dir.."luaclib/?.so"
package.path = ""
package.path = package.path..skynet_dir.."lualib/?.lua;"
package.path = package.path..proj_dir.."src/3rd/lualib/?.lua;"
package.path = package.path..proj_dir.."src/service/?.lua;"

if _VERSION ~= "Lua 5.4" then
	error "Use lua 5.4"
end

local socket = require "client.socket"
local gateway_proto = require "gateway.proto"
local sproto = require "sproto"
require "luaext"


local gw_pb_host = sproto.new(gateway_proto.s2c):host "package"
local gw_pb_pack = gw_pb_host:attach(sproto.new(gateway_proto.c2s))

local gateway_host = "127.0.0.1"
local gateway_port = 6101


local fd = assert(socket.connect(gateway_host, gateway_port))

local function send_package(fd, pack)
	local package = string.pack(">s2", pack)
	socket.send(fd, package)
end

local function unpack_package(text)
	local size = #text
	if size < 2 then
		return nil, text
	end
	local s = text:byte(1) * 256 + text:byte(2)
	if size < s+2 then
		return nil, text
	end

	return text:sub(3,2+s), text:sub(3+s)
end

local function recv_package(last)
	local result
	result, last = unpack_package(last)
	if result then
		return result, last
	end
	local r = socket.recv(fd)
	if not r then
		return nil, last
	end
	if r == "" then
		error "Server closed"
	end
	return unpack_package(last .. r)
end

local session = 0

local function send_request(name, args)
	session = session + 1
	local str = gw_pb_pack(name, args, session)
	send_package(fd, str)
	print("Request:", session)
end

local last = ""

local function print_request(name, args)
	if name ~= "heartbeat" then print("REQUEST", name) end
	if args then
		for k,v in pairs(args) do
			print(k,v)
		end
	end
end

local function print_response(session, args)
	print("RESPONSE", session)
	if args then
		for k,v in pairs(args) do
			print(k,v)
		end
	end
end

local function print_package(t, ...)
	if t == "REQUEST" then
		print_request(...)
	else
		assert(t == "RESPONSE")
		print_response(...)
	end
end

local function dispatch_package()
	while true do
		local v
		v, last = recv_package(last)
		if not v then
			break
		end

		print_package(gw_pb_host:dispatch(v))
	end
end


local REQ = {}

function REQ.quit()
    send_request("quit")
end

function REQ.get(what)
    send_request("get", { what = what })
end

function REQ.set(what, value)
    send_request("set", { what = what, value = value})
end

function REQ.verify(username, pwd)
    if not (username and pwd) then
        username = "ant"
        pwd = "123"
        print("verify use default username/pwd")
    end
    send_request("verify", {username = username, pwd = pwd})
end

send_request("handshake")
send_request("set", { what = "hello", value = "world" })
while true do
	dispatch_package()
	local cmdline = socket.readstdin()
	if cmdline then
        local tokens = string.split(cmdline, " ")
        print(string.format("#tokens:%s, tokens:%s", #tokens, tostring(tokens)))
        if #tokens > 0 then
            local req = tokens[1]
            local f = REQ[tokens[1]]
            if f then
                f(table.unpack(tokens, 2))
            else
                print("not support req:"..req)
            end
        else
            print("invalid cmdline:"..cmdline)
        end
	else
		socket.usleep(100)
	end
end
