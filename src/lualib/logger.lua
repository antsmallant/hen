local skynet = require "skynet"

local LOGLVL = {
    debug = 1,
    info = 2,
    error = 3,
}

local LVL2STR = {
    [LOGLVL.debug] = "[debug]",
    [LOGLVL.info] = "[info]",
    [LOGLVL.error] = "[error]",
}

local _M = {}
local g_loglevel = LOGLVL[(skynet.getenv "loglevel") or "info"]
assert(g_loglevel, "invalid log level, should be one of these: debug info error")

local function _log(level, fmt, ...)
    assert(fmt, "fmt not given")
    if level < g_loglevel then return end
    local ok, s = pcall(string.format, fmt, ...)
    if ok then
        skynet.error(LVL2STR[level], s)
    else
        skynet.error("log fmt fail, error:", s, ",fmt:", fmt)
    end
end

function _M.debug(fmt, ...)
    _log(LOGLVL.debug, fmt, ...)
end

function _M.info(fmt, ...)
    _log(LOGLVL.info, fmt, ...)
end

function _M.error(fmt, ...)
    _log(LOGLVL.error, fmt, ...)
end

return _M