local ffi = assert(require('ffi'))
local pthread = assert(require('pthread'))
local serial = assert(require('serial'))

ffi.cdef([[
	struct Node_t {
		struct Node_t*	next;
		void*         	data;
	};
	struct MessageBox_t {
		struct Node_t*  	head;
		struct Node_t*  	tail;
		pthread_mutex_t*	mutex;
	};

	//We need these to allocate/deallocate...
	void*	malloc(	size_t size);
	void 	free(  	void*);
]])

local capture = function(data)
	local dataType = type(data)

	if dataType == 'nil' then
		return nil
	elseif dataType == 'boolean' then
		--on x86 and x64, pointers are 4-byte aligned
		--so we can use the extra space
		return ffi.cast('void*', data and 2 or 1)
	elseif dataType == 'number' then
		--doubles are expected to be 8 byte-aligned in worst case
		local ptr = ffi.cast('char*', ffi.C.malloc(16))
		ptr[0] = 0
		ffi.cast('double*', ptr)[1] = data
		return ptr
	elseif dataType == 'string' then
		local ptr = ffi.cast('char*', ffi.C.malloc(#data + 2))
		ptr[0] = 1
		ffi.copy(ptr + 1, data)
		return ptr
	elseif
			dataType == 'function' or
			dataType == 'table' or
			dataType == 'userdata' then
		data = serial.serialize(data)
		local ptr = ffi.cast('char*', ffi.C.malloc(#data + 2))
		ptr[0] = 2
		ffi.copy(ptr + 1, data)
		return ptr
	else
		error('unable to capture data of type ' .. dataType)
	end
end

local release = function(data)
	data = ffi.cast('char*', data)

	if data == nil then
		return nil, false
	elseif data - 2 == nil then
		return true, false
	elseif data - 1 == nil then
		return false, false
	else
		if data[0] == 0 then
			local doublePtr = ffi.cast('double*', data + 8)
			return tonumber(doublePtr[0]), true
		elseif data[0] == 1 then
			return ffi.string(data + 1), true
		else --data[0] == 2
			return serial.deserialize(ffi.string(data + 1)), true
		end
	end
end

local rawGetMessage = function(mboxptr)
	--Assume the mutex is locked.
	local result, gotAnything = nil, false

	if mboxptr[0].head ~= nil then
		gotAnything = true
		local node = mboxptr[0].head
		mboxptr[0].head = node[0].next
		result, shouldFree = release(node[0].data)

		if shouldFree then
			ffi.C.free(node[0].data)
		end

		ffi.C.free(node)
	end

	return result, gotAnything
end

local mt = {
	--Be very careful to not consume messages you're sending to yourself
	--Unless you're into that kind of thing
	__index = {
		getMessage = function(mbox)
			if mbox.bufferSize > 0 then
				mbox.bufferSize = mbox.bufferSize - 1
				return table.remove(mbox.buffer, 1), true
			else
				ffi.C.pthread_mutex_lock(mbox.ptr[0].mutex)
				local result, gotAnything = rawGetMessage(mbox.ptr)

				--Try to read additional messages to avoid more locks.
				for i = mbox.bufferSize + 1, 20 do
					local bufferedResult, bufferedGot = rawGetMessage(mbox.ptr)

					if bufferedGot then
						mbox.bufferSize = i
						mbox.buffer[i] = bufferedResult
					else
						break
					end
				end

				ffi.C.pthread_mutex_unlock(mbox.ptr[0].mutex)
				return result, gotAnything
			end
		end,
		sendMessage = function(mbox, data)
			local node = ffi.cast('struct Node_t*', ffi.C.malloc(ffi.sizeof('struct Node_t[1]')))
			node[0].next = nil
			node[0].data = capture(data)

			ffi.C.pthread_mutex_lock(mbox.ptr[0].mutex)

			if mbox.ptr[0].head == nil then
				mbox.ptr[0].head = node
				mbox.ptr[0].tail = node
			else
				mbox.ptr[0].tail.next = node
				mbox.ptr[0].tail = node
			end

			ffi.C.pthread_mutex_unlock(mbox.ptr[0].mutex)
		end
	}
}

return setmetatable({
	new = function(self)
		local mutex = ffi.C.malloc(ffi.sizeof('pthread_mutex_t[1]'))
		ffi.C.pthread_mutex_init(mutex, nil)
		local box = ffi.cast('struct MessageBox_t*', ffi.C.malloc(ffi.sizeof('struct MessageBox_t')))
		box.head = nil
		box.tail = nil
		box.mutex = mutex

		return setmetatable({
			ptr = box,
			buffer = {},
			bufferSize = 0
		}, mt)
	end,
	fromPtr = function(self, ptr)
		return setmetatable({
			ptr = ffi.cast('struct MessageBox_t*', ptr),
			buffer = {},
			bufferSize = 0
		}, mt)
	end
}, {
	__call = function(self)
		return self:new()
	end
})
