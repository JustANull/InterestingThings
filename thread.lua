local ffi = assert(require('ffi'))
local MessageBox = assert(require('messagebox'))
local pthread = assert(require('pthread'))

if ffi.os == 'OSX' then
	ffi.load('bin/luajit.dylib')
else
	error('unsupported')
end

ffi.cdef([[
	//Lua types...
	typedef struct lua_State	lua_State;
	typedef double          	lua_Number;

	//Lua functions...
	int        	lua_pcall(      	lua_State* L, int nargs, int nresults, int errfunc);
	void       	lua_settop(     	lua_State* L, int idx);
	const char*	lua_tolstring(  	lua_State* L, int idx, size_t *len);
	lua_Number 	lua_tonumber(   	lua_State* L, int idx);
	lua_State* 	luaL_newstate(  	);
	int        	luaL_loadstring(	lua_State* L, const char* s);
	void       	luaL_openlibs(  	lua_State* L);

	//We need these to allocate/deallocate...
	void*	malloc(	size_t size);
	void 	free(  	void*);
]])

local mt = {}

local isThread = function(arg)
	return getmetatable(arg) == mt, 'thread handle', type(arg)
end

mt.__index = {
	join = function(thread)
		if thread.status == 'running' then
			local errp = ffi.new('char*[1]')
			assert(ffi.C.pthread_join(thread.id[0], ffi.cast('void**', errp)) == 0, 'Unable to join.')

			if errp[0] ~= nil then
				thread.status = 'error'
				error(ffi.string(errp[0]), 2)
				ffi.C.free(errp[0])
			else
				thread.status = 'done'
			end
		end
	end,
	getMessage = function(thread)
		return thread.inbox:getMessage()
	end,
	sendMessage = function(thread, data)
		thread.outbox:sendMessage(data)
	end
}

local bootstrapper = ffi.cast('const char*', [[
	local ffi = assert(require('ffi'))
	local MessageBox = assert(require('messagebox'))
	local serial = assert(require('serial'))
	local thread = assert(require(']] .. (...) .. [['))

	local inbox = nil
	local outbox = nil

	_G.getMessage = function()
		return inbox:getMessage()
	end
	_G.sendMessage = function(data)
		outbox:sendMessage(data)
	end

	local callback = ffi.cast('void*(*)(void*)', function(data)
		data = ffi.cast('void**', data)
		inbox = MessageBox:fromPtr(data[0])
		outbox = MessageBox:fromPtr(data[1])
		local code = ffi.string(data[2])
		ffi.C.free(data[2])

		local success, err = xpcall(loadstring(ffi.string(code), '@THREAD'), function(err)
			local debug = require('debug')

			if debug then
				return debug.traceback(err, 2)
			else
				return err
			end
		end)

		--Consume the rest of the messages so we don't leak memory so badly
		while getMessage() ~= nil do
		end

		if not success then
			local errp = ffi.C.malloc(#err + 1)
			ffi.copy(errp, err)
			return errp
		end

		return nil
	end)

	return tonumber(ffi.cast('ptrdiff_t', callback))
]])

return setmetatable({
	new = function(self, code)
		--First, make a new Lua state...
		local state = ffi.C.luaL_newstate()
		ffi.C.luaL_openlibs(state)
		--Add the bootstrapper
		ffi.C.luaL_loadstring(state, bootstrapper)
		--Execute it
		if ffi.C.lua_pcall(state, 0, -1, 0) ~= 0 then
			error('Error running bootstrapper: ' .. ffi.string(ffi.C.lua_tolstring(state, -1, nil)))
		end

		--Get the return value... as a number, because of workarounds.
		--Pretend it's a function pointer
		local fp = ffi.cast('void*(*)(void*)', ffi.C.lua_tonumber(state, -1))
		ffi.C.lua_settop(state, -2)
		--Set up the info they're getting
		local ptrs = ffi.cast('void**', ffi.C.malloc(ffi.sizeof('void*[3]')))
		local outbox = MessageBox()
		ptrs[0] = outbox.ptr
		local inbox = MessageBox()
		ptrs[1] = inbox.ptr
		ptrs[2] = ffi.C.malloc(#code + 1)
		ffi.copy(ptrs[2], code)
		--Send that off to threading...
		local id = ffi.new('pthread_t[1]')
		local err = ffi.C.pthread_create(id, nil, fp, ptrs)

		return setmetatable({
			id = id,
			outbox = outbox,
			inbox = inbox,
			status = 'running'
		}, mt)
	end,
	newFromFile = function(self, filename)
		return self:newFromFP(assert(io.open(filename, 'r')))
	end,
	newFromFP = function(self, fp)
		return self:new(fp:read('*all'))
	end,
	isThread = function(_, arg)
		return isThread(arg)
	end
}, {
	__call = function(self, code)
		return self:new(code)
	end
})
