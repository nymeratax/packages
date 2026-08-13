--!strict

local thread = {}
thread.__index = thread

type state = "pending" | "completed" | "failed"

export type task_thread<R...> = typeof(setmetatable({} :: {
	state: state,
	results: { any },
	success: boolean,
	waiting_threads: { thread },
	callbacks: { (boolean, ...any) -> () },
}, thread))

local function run_task<R...>(self: task_thread<R...>, executor: (...any) -> R..., args: { [number]: any, n: number })
	local packed = table.pack(pcall(executor, table.unpack(args, 1, args.n)))
	self.success = packed[1]
	self.results = {}
	for i = 2, packed.n do
		table.insert(self.results, packed[i])
	end
	self.state = if self.success then "completed" else "failed"

	for _, waiting_thread in ipairs(self.waiting_threads) do
		task.spawn(waiting_thread)
	end
	table.clear(self.waiting_threads)

	for _, callback in ipairs(self.callbacks) do
		task.spawn(callback, self.success, table.unpack(self.results))
	end
	table.clear(self.callbacks)
end

function thread.spawn<A..., R...>(executor: (A...) -> R..., ...: A...): task_thread<R...>
	local self = setmetatable({
		state = "pending" :: state,
		results = {},
		success = false,
		waiting_threads = {},
		callbacks = {},
	}, thread)

	local args = table.pack(...)
	task.spawn(run_task, self, executor, args)
	return self
end

function thread.defer<A..., R...>(executor: (A...) -> R..., ...: A...): task_thread<R...>
	local self = setmetatable({
		state = "pending" :: state,
		results = {},
		success = false,
		waiting_threads = {},
		callbacks = {},
	}, thread)

	local args = table.pack(...)
	task.defer(run_task, self, executor, args)
	return self
end

function thread.await_result<R...>(self: task_thread<R...>): (boolean, R...)
	if self.state ~= "pending" then
		return self.success, table.unpack(self.results)
	end

	table.insert(self.waiting_threads, coroutine.running())
	coroutine.yield()

	return self.success, table.unpack(self.results)
end

function thread.and_then<R...>(self: task_thread<R...>, callback: (boolean, R...) -> ()): task_thread<R...>
	if self.state ~= "pending" then
		task.spawn(callback, self.success, table.unpack(self.results))
	else
		table.insert(self.callbacks, callback)
	end
	return self
end

return thread
