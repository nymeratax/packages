--!strict

local maid = {}
maid.class_name = "maid"
maid.__index = maid

export type maid_task =
	(() -> ())
	| Instance
	| thread
	| RBXScriptConnection
	| { destroy: (any) -> () }
	| { Destroy: (any) -> () }
	| { cancel: (any) -> () }
	| { Cancel: (any) -> () }
	| { disconnect: (any) -> () }
	| { Disconnect: (any) -> () }
	| { [any]: any }
	| nil

export type Maid = {
	_tasks: { [any]: maid_task },
	add: <T>(self: Maid, task: T) -> T,
	give_task: (self: Maid, task: maid_task) -> number,
	give_promise: <T>(self: Maid, promise: T) -> T,
	do_cleaning: (self: Maid) -> (),
	destroy: (self: Maid) -> (),
	[any]: any,
}

local function clean_task(job: maid_task)
	if job == nil then
		return
	end

	local job_type = typeof(job)

	if job_type == "RBXScriptConnection" then
		(job :: RBXScriptConnection):Disconnect()
	elseif job_type == "function" then
		(job :: () -> ())()
	elseif job_type == "Instance" then
		(job :: Instance):Destroy()
	elseif job_type == "thread" then
		local thread_job = job :: thread
		if coroutine.running() ~= thread_job then
			if not pcall(task.cancel, thread_job) then
				task.defer(task.cancel, thread_job)
			end
		else
			task.defer(task.cancel, thread_job)
		end
	elseif job_type == "table" then
		local tbl = job :: any
		if type(tbl.destroy) == "function" then
			tbl:destroy()
		elseif type(tbl.Destroy) == "function" then
			tbl:Destroy()
		elseif type(tbl.cancel) == "function" then
			tbl:cancel()
		elseif type(tbl.Cancel) == "function" then
			tbl:Cancel()
		elseif type(tbl.disconnect) == "function" then
			tbl:disconnect()
		elseif type(tbl.Disconnect) == "function" then
			tbl:Disconnect()
		end
	end
end

function maid.new(): Maid
	return setmetatable({
		_tasks = {},
	}, maid) :: any
end

function maid.is_maid(value: any): boolean
	return type(value) == "table" and value.class_name == "maid"
end

function maid.__index(self: any, index: any)
	if maid[index] ~= nil then
		return maid[index]
	end
	return self._tasks[index]
end

function maid.__newindex(self: any, index: any, new_task: maid_task)
	if maid[index] ~= nil then
		error(string.format("cannot use '%s' as a maid key", tostring(index)), 2)
	end

	local tasks = self._tasks
	local old_task = tasks[index]

	if old_task == new_task then
		return
	end

	tasks[index] = new_task

	if old_task then
		clean_task(old_task)
	end
end

function maid.add<T>(self: Maid, task: T): T
	if not task then
		error("task cannot be false or nil", 2)
	end

	self[#self._tasks + 1] = task
	return task
end

function maid.give_task(self: Maid, task: maid_task): number
	if not task then
		error("task cannot be false or nil", 2)
	end

	local task_id = #self._tasks + 1
	self[task_id] = task
	return task_id
end

function maid.give_promise<T>(self: Maid, promise: T): T
	local prom = promise :: any
	
	local is_pending = if type(prom.isPending) == "function"
		then prom:isPending()
		elseif type(prom.IsPending) == "function" then prom:IsPending()
		elseif type(prom.getStatus) == "function" then prom:getStatus() == "Started"
		else true

	if not is_pending then
		return promise
	end

	local id = self:give_task(prom)

	local finally_fn = prom.finally or prom.Finally
	if type(finally_fn) == "function" then
		finally_fn(prom, function()
			self[id] = nil
		end)
	end

	return promise
end

function maid.do_cleaning(self: Maid)
	local tasks = self._tasks

	for index, job in pairs(tasks) do
		if typeof(job) == "RBXScriptConnection" then
			tasks[index] = nil
			(job :: RBXScriptConnection):Disconnect()
		end
	end

	while true do
		local index, job = next(tasks)
		if index == nil then
			break
		end
		tasks[index] = nil
		clean_task(job)
	end
end

maid.destroy = maid.do_cleaning

return maid
