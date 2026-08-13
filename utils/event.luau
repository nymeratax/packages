--!strict

local connection = {}
connection.__index = connection

type connection_impl<T... = ...any> = {
	connected: boolean,
	_callback: ((T...) -> ())?,
	_next: connection<T...>?,
	_prev: connection<T...>?,
	_event: { event<T...> }?,
}

export type connection<T... = ...any> = typeof(setmetatable({} :: connection_impl<T...>, connection))

local event = {}
event.__index = event

type event_impl<T... = ...any> = {
	_head: connection<T...>?,
}

export type event<T... = ...any> = typeof(setmetatable({} :: event_impl<T...>, event))

function event.new<T...>(): event<T...>
	local self = setmetatable({
		_head = nil,
	}, event)
	return (self :: any) :: event<T...>
end

function event.connect<T...>(self: event<T...>, callback: (T...) -> ()): connection<T...>
	assert(type(callback) == "function", "callback must be a function")

	local event_ref = setmetatable({ self }, { __mode = "v" })

	local conn: connection<T...> = setmetatable({
		connected = true,
		_callback = callback,
		_next = self._head,
		_prev = nil,
		_event = event_ref,
	}, connection) :: any

	if self._head then
		self._head._prev = conn
	end
	self._head = conn

	return conn
end

function connection.disconnect<T...>(self: connection<T...>)
	if not self.connected then
		return
	end
	self.connected = false
	self._callback = nil

	local evt = self._event and self._event[1]

	if self._prev then
		self._prev._next = self._next
	elseif evt then
		evt._head = self._next
	end

	if self._next then
		self._next._prev = self._prev
	end

	self._prev = nil
	self._next = nil
	self._event = nil
end

function event.once<T...>(self: event<T...>, callback: (T...) -> ()): connection<T...>
	assert(type(callback) == "function", "callback must be a function")
	local conn: connection<T...>
	conn = self:connect(function(...: T...)
		conn:disconnect()
		callback(...)
	end)
	return conn
end

function event.fire<T...>(self: event<T...>, ...: T...)
	local item = self._head
	while item do
		local next_item = item._next
		if item.connected and item._callback then
			task.spawn(item._callback, ...)
		end
		item = next_item
	end
end

function event.wait<T...>(self: event<T...>): T...
	local thread = coroutine.running()
	local conn: connection<T...>
	conn = self:connect(function(...: T...)
		conn:disconnect()
		task.defer(thread, ...)
	end)
	return coroutine.yield()
end

function event.disconnect_all<T...>(self: event<T...>)
	local item = self._head
	while item do
		local next_item = item._next
		item:disconnect()
		item = next_item
	end
	self._head = nil
end

return event
