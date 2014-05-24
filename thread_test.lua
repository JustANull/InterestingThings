local ffi = assert(require('ffi'))
local Thread = assert(require('thread'))

ffi.cdef([=[
	int poll(void* unused, unsigned long unused2, int timeout);
]=])

local thread = Thread([[
	local ffi = assert(require('ffi'))
	ffi.cdef([=[
		int poll(void* unused, unsigned long unused2, int timeout);
	]=])

	print('Thread: getting message early... this should return nil')
	for i = 1, 1000000 do
		local hopefullyNil = getMessage()
		assert(hopefullyNil == nil, 'oh god why')
	end
	print('Thread: sleeping for 1000 ms')
	ffi.C.poll(nil, 0, 1000)
	print('Thread: getting messages...')
	local now = os.clock()
	for i = 1, 1000000 do
		getMessage()
	end
	local later = os.clock()
	print('Thread: Recving 1000000 messages took', later - now, 'seconds.')
	print('Thread:', (later - now) / 1000000, 'seconds per message.')
	print('Thread:', 1000000 / (later - now), 'messages per second.')
	print('Thread: sending ACK')
	sendMessage('ACK')
	print('Thread: done')
]])

print('Main: sleeping for 500 ms')
ffi.C.poll(nil, 0, 500)
print('Main: sending 1000000 messages...')
local now = os.clock()
for i = 1, 1000000 do
	thread:sendMessage({})
end
local later = os.clock()
print('Main: Sending 1000000 messages took', later - now, 'seconds.')
print('Main:', (later - now) / 1000000, 'seconds per message.')
print('Main:', 1000000 / (later - now), 'messages per second.')
print('Main: sent')
print('Main: done')
thread:join()
print('Main: ACK?', thread:getMessage())
print('Main: see thread done')
