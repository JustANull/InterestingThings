local debug = require('debug')
local typecheck = assert(require('typecheck'))

local loggingFile = _G.LOG_FILE and assert(io.open(_G.LOG_FILE, 'w+')) or io.stderr

local logLevels = {
	notset =  	0,
	debug =   	1,
	info =    	2,
	warning = 	3,
	error =   	4,
	critical =	5,
	off =     	6
}

local logLevel = logLevels.notset

local log = function(level, ...)
	if logLevels[level] >= logLevel then
		loggingFile:write('[')
		loggingFile:write(string.upper(level))
		loggingFile:write('] ')

		if debug then
			local info = debug.getinfo(3, 'Sl')
			local source = info.short_src
			local line = info.currentline

			if source and line then
				if #source > 32 then
					source = '...' .. string.sub(source, #source - 29)
				end

				loggingFile:write(string.format('%s::%d ', source, line))
			end
		end

		loggingFile:write(table.concat({...}))
		loggingFile:write('\n')
		loggingFile:flush()
	end
end

local makeLogger = function(name)
	return typecheck({'number', 'string'}, '...') .. function(...)
		log(name, ...)
		return ...
	end
end

return {
	debug = makeLogger('debug'),
	info = makeLogger('info'),
	warning = makeLogger('warning'),
	error = makeLogger('error'),
	critical = makeLogger('critical'),
	setLevel = typecheck(function(arg)
		return logLevels[arg] ~= nil, 'any of ["notset", "debug", "info", "warning", "error", "critical", "off"]', tostring(arg)
	end) .. function(level)
		logBoundary = logLevels[level]
	end
}
