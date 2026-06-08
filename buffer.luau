--!strict
local BufferStream = {}
BufferStream.__index = BufferStream

local buffer_create = buffer.create
local buffer_len = buffer.len
local buffer_copy = buffer.copy
local math_clamp = math.clamp
local math_max = math.max

local bwritei8, breadi8   = buffer.writei8, buffer.readi8
local bwriteu8, breadu8   = buffer.writeu8, buffer.readu8
local bwritei16, breadi16 = buffer.writei16, buffer.readi16
local bwriteu16, breadu16 = buffer.writeu16, buffer.readu16
local bwritei32, breadi32 = buffer.writei32, buffer.readi32
local bwriteu32, breadu32 = buffer.readu32, buffer.readu32
local bwritef32, breadf32 = buffer.writef32, buffer.readf32
local bwritef64, breadf64 = buffer.writef64, buffer.readf64
local bwritestr, breadstr = buffer.writestring, buffer.readstring

type Self = {
	_buffer: buffer,
	_cursor: number,
	_size: number,
}

export type BufferStream = typeof(setmetatable({} :: Self, BufferStream))

function BufferStream.new(sizeOrBuffer: (number | buffer)?): BufferStream
	local newBuffer: buffer
	local currentSize: number

	if type(sizeOrBuffer) == "number" then
		currentSize = sizeOrBuffer
		newBuffer = buffer_create(currentSize)
	elseif typeof(sizeOrBuffer) == "buffer" then
		newBuffer = sizeOrBuffer
		currentSize = buffer_len(newBuffer)
	else
		currentSize = 64
		newBuffer = buffer_create(currentSize)
	end

	return setmetatable({
		_buffer = newBuffer,
		_cursor = 0,
		_size = currentSize,
	}, BufferStream)
end

function BufferStream:_ensureCapacity(neededBytes: number)
	local requiredSize = self._cursor + neededBytes
	if requiredSize > self._size then
		local newSize = math_max(self._size * 2, requiredSize)
		local newBuffer = buffer_create(newSize)
		buffer_copy(newBuffer, 0, self._buffer, 0, self._cursor)
		self._buffer = newBuffer
		self._size = newSize
	end
end

function BufferStream:_assertRead(neededBytes: number)
	if self._cursor + neededBytes > self._size then
		error(string.format("[BufferStream] Attempt to read out of bounds! Cursor: %d, Needed: %d, Size: %d", self._cursor, neededBytes, self._size), 2)
	end
end

function BufferStream:ResetCursor()
	self._cursor = 0
end

function BufferStream:Seek(offset: number)
	self._cursor = math_clamp(offset, 0, self._size)
end

function BufferStream:GetBuffer(): buffer
	return self._buffer
end

function BufferStream:Export(): buffer
	local result = buffer_create(self._cursor)
	buffer_copy(result, 0, self._buffer, 0, self._cursor)
	return result
end

function BufferStream:GetCursor(): number
	return self._cursor
end

function BufferStream:GetLength(): number
	return self._size
end

function BufferStream:WriteI8(value: number)
	self:_ensureCapacity(1)
	bwritei8(self._buffer, self._cursor, value)
	self._cursor += 1
end

function BufferStream:WriteU8(value: number)
	self:_ensureCapacity(1)
	bwriteu8(self._buffer, self._cursor, value)
	self._cursor += 1
end

function BufferStream:WriteBool(value: boolean)
	self:_ensureCapacity(1)
	bwriteu8(self._buffer, self._cursor, value and 1 or 0)
	self._cursor += 1
end

function BufferStream:WriteI16(value: number)
	self:_ensureCapacity(2)
	bwritei16(self._buffer, self._cursor, value)
	self._cursor += 2
end

function BufferStream:WriteU16(value: number)
	self:_ensureCapacity(2)
	bwriteu16(self._buffer, self._cursor, value)
	self._cursor += 2
end

function BufferStream:WriteI32(value: number)
	self:_ensureCapacity(4)
	bwritei32(self._buffer, self._cursor, value)
	self._cursor += 4
end

function BufferStream:WriteU32(value: number)
	self:_ensureCapacity(4)
	bwriteu32(self._buffer, self._cursor, value)
	self._cursor += 4
end

function BufferStream:WriteF32(value: number)
	self:_ensureCapacity(4)
	bwritef32(self._buffer, self._cursor, value)
	self._cursor += 4
end

function BufferStream:WriteF64(value: number)
	self:_ensureCapacity(8)
	bwritef64(self._buffer, self._cursor, value)
	self._cursor += 8
end

function BufferStream:WriteString(value: string)
	local len = #value
	self:_ensureCapacity(2 + len)
	bwriteu16(self._buffer, self._cursor, len)
	bwritestr(self._buffer, self._cursor + 2, value, len)
	self._cursor += 2 + len
end

function BufferStream:ReadI8(): number
	self:_assertRead(1)
	local v = breadi8(self._buffer, self._cursor)
	self._cursor += 1
	return v
end

function BufferStream:ReadU8(): number
	self:_assertRead(1)
	local v = breadu8(self._buffer, self._cursor)
	self._cursor += 1
	return v
end

function BufferStream:ReadBool(): boolean
	self:_assertRead(1)
	local v = breadu8(self._buffer, self._cursor)
	self._cursor += 1
	return v == 1
end

function BufferStream:ReadI16(): number
	self:_assertRead(2)
	local v = breadi16(self._buffer, self._cursor)
	self._cursor += 2
	return v
end

function BufferStream:ReadU16(): number
	self:_assertRead(2)
	local v = breadu16(self._buffer, self._cursor)
	self._cursor += 2
	return v
end

function BufferStream:ReadI32(): number
	self:_assertRead(4)
	local v = breadi32(self._buffer, self._cursor)
	self._cursor += 4
	return v
end

function BufferStream:ReadU32(): number
	self:_assertRead(4)
	local v = breadu32(self._buffer, self._cursor)
	self._cursor += 4
	return v
end

function BufferStream:ReadF32(): number
	self:_assertRead(4)
	local v = breadf32(self._buffer, self._cursor)
	self._cursor += 4
	return v
end

function BufferStream:ReadF64(): number
	self:_assertRead(8)
	local v = breadf64(self._buffer, self._cursor)
	self._cursor += 8
	return v
end

function BufferStream:ReadString(): string
	self:_assertRead(2)
	local len = breadu16(self._buffer, self._cursor)
	self:_assertRead(len + 2)
	local v = breadstr(self._buffer, self._cursor + 2, len)
	self._cursor += 2 + len
	return v
end

function BufferStream:WriteVector2(value: Vector2)
	self:_ensureCapacity(8)
	local b, c = self._buffer, self._cursor
	bwritef32(b, c, value.X)
	bwritef32(b, c + 4, value.Y)
	self._cursor += 8
end

function BufferStream:ReadVector2(): Vector2
	self:_assertRead(8)
	local b, c = self._buffer, self._cursor
	local x = breadf32(b, c)
	local y = breadf32(b, c + 4)
	self._cursor += 8
	return Vector2.new(x, y)
end

function BufferStream:WriteVector3(value: Vector3)
	self:_ensureCapacity(12)
	local b, c = self._buffer, self._cursor
	bwritef32(b, c, value.X)
	bwritef32(b, c + 4, value.Y)
	bwritef32(b, c + 8, value.Z)
	self._cursor += 12
end

function BufferStream:ReadVector3(): Vector3
	self:_assertRead(12)
	local b, c = self._buffer, self._cursor
	local x = breadf32(b, c)
	local y = breadf32(b, c + 4)
	local z = breadf32(b, c + 8)
	self._cursor += 12
	return Vector3.new(x, y, z)
end

function BufferStream:WriteColor3(value: Color3)
	self:_ensureCapacity(3)
	local b, c = self._buffer, self._cursor
	bwriteu8(b, c, math_clamp(value.R * 255, 0, 255))
	bwriteu8(b, c + 1, math_clamp(value.G * 255, 0, 255))
	bwriteu8(b, c + 2, math_clamp(value.B * 255, 0, 255))
	self._cursor += 3
end

function BufferStream:ReadColor3(): Color3
	self:_assertRead(3)
	local b, c = self._buffer, self._cursor
	local r = breadu8(b, c) / 255
	local g = breadu8(b, c + 1) / 255
	local b_val = breadu8(b, c + 2) / 255
	self._cursor += 3
	return Color3.new(r, g, b_val)
end

function BufferStream:WriteCFrame(value: CFrame)
	self:_ensureCapacity(24)
	local b, c = self._buffer, self._cursor
	local x, y, z, qx, qy, qz = value:GetComponents()
	
	bwritef32(b, c, x)
	bwritef32(b, c + 4, y)
	bwritef32(b, c + 8, z)
	bwritef32(b, c + 12, qx)
	bwritef32(b, c + 16, qy)
	bwritef32(b, c + 20, qz)
	self._cursor += 24
end

function BufferStream:ReadCFrame(): CFrame
	self:_assertRead(24)
	local b, c = self._buffer, self._cursor
	local x = breadf32(b, c)
	local y = breadf32(b, c + 4)
	local z = breadf32(b, c + 8)
	local qx = breadf32(b, c + 12)
	local qy = breadf32(b, c + 16)
	local qz = breadf32(b, c + 20)
	self._cursor += 24
	
	local trace = 1 - (qx*qx + qy*qy + qz*qz)
	local qw = trace > 0 and math.sqrt(trace) or 0
	
	return CFrame.new(x, y, z, qx, qy, qz, qw)
end

return BufferStream
