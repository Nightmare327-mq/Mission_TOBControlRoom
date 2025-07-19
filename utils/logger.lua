--- @type Mq
local mq = require('mq')

local actions = {}

-- TODO: Determine name automatically
local app_name = 'Mission_TOBControlRoom'
local logLeader = '\ar[\ag'..app_name..'\ar]\aw '

--- @type number
local logLevel = 4

actions.LogLevels = {
	none = 0,
	error = 2,
	warning = 3,
	info = 4,
	debug = 5,
	trace = 6
}

function actions.get_log_level() return logLevel end

function actions.set_log_level(level) logLevel = level end

function actions.error(format, ...)
	if (logLevel < actions.LogLevels.error) then
		return
	end
    local output = string.format(format, ...)
	mq.cmdf('/mqlog [%s] %s', mq.TLO.Me.Name(), output)
	printf('%s \ar %s', logLeader, output)
end

function actions.warning(format, ...)
	if (logLevel < actions.LogLevels.warning) then
		return
	end
    local output = string.format(format, ...)
	mq.cmdf('/mqlog [%s] %s', mq.TLO.Me.Name(), output)
	printf('%s \aw %s', logLeader, output)
end

function actions.info(format, ...)
	if (logLevel < actions.LogLevels.info) then
		return
	end
    local output = string.format(format, ...)
	mq.cmdf('/mqlog [%s] %s', mq.TLO.Me.Name(), output)
	printf('%s \ao %s', logLeader, output)
end

function actions.debug(format, ...)
	if (logLevel < actions.LogLevels.debug) then
		return
	end
    local output = string.format(format, ...)
	mq.cmdf('/mqlog [%s] %s', mq.TLO.Me.Name(), output)
	printf('%s \ag %s', logLeader, output)
end

function actions.trace(format, ...)
	if (logLevel < actions.LogLevels.trace) then
		return
	end
    local output = string.format(format, ...)
	mq.cmdf('/mqlog [%s] %s', mq.TLO.Me.Name(), output)
	printf('%s \ay %s', logLeader, output)
end

function actions.output_test_logs()
	actions.error("Test Error")
	actions.warning("Test Warning")
	actions.info("Test Normal")
	actions.debug("Test Debug")
	actions.trace("Test Trace")
end

return actions