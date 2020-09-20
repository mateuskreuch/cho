local atan2 = math.atan2
local floor = math.floor
local ipairs = ipairs
local lgfx = love.graphics
local min = math.min
local pairs = pairs
local setmetatable = setmetatable
local sqrt = math.sqrt
local type = type

-- constants -------------------------------------------------------------------

local PI = math.pi

local COLOR_BLACK = {0, 0, 0}
local COLOR_WHITE = {1, 1, 1}
local COLOR_CARDINALS = {0.94, 0.85, 0.7}
local COLOR_DIAGONALS = {0.7, 0.53, 0.38}
local COLOR_SUBDIAGONALS = {0.75, 0.71, 0.65}
local COLOR_OUTLINE = {0.1, 0.1, 0.1}
local COLOR_MARKER = {0, 0.41, 0.87}

-- utility functions -----------------------------------------------------------

local function class(table)
	table.__index = table; return setmetatable(table, table)
end

local function contains(table, x)
	for i = 1, #table do
		if table[i] == x then
			return true
		end
	end

	return false
end

local function is(table, class)
	return getmetatable(table) == class
end

local function loop(table, times, steps)
	local newtable = {}

	for _ = 1, times do
		for i = 1, #table, steps do
			newtable[#newtable + 1] = table[i]
		end
	end

	return newtable
end

local function round(x)
	return floor(x + 0.5)
end

local function wrapAngle(angle)
	return angle - 2*PI * floor(angle / (2*PI))
end

-- love extensions -------------------------------------------------------------

function lgfx.colored(func, color, ...)
	lgfx.setColor(color)
	func(...)
	lgfx.setColor(COLOR_WHITE)
end

function lgfx.cross(x, y, radius)
	radius = radius * sqrt(2)/2

	lgfx.setLineWidth(radius * 3/4)
	lgfx.line(x - radius, y - radius, x + radius, y + radius)
	lgfx.line(x - radius, y + radius, x + radius, y - radius)
	lgfx.setLineWidth(1)
end

function lgfx.outlined(func, color, ...)
	lgfx.colored(func, color, 'fill', ...)
	lgfx.colored(func, color == COLOR_BLACK and COLOR_WHITE
														  or COLOR_OUTLINE, 'line', ...)
end

function lgfx.rotated(radians, func, ...)
	lgfx.push()
	lgfx.rotate(radians)
	func(...)
	lgfx.pop()
end

function lgfx.stripedDisk(x, y, radius, colors)
	local strips = #colors

	lgfx.colored(lgfx.ellipse, colors[1], 'fill', x, y, radius)

	for i = 0, strips - 1 do
		local angle0 = -PI / strips + i*PI / (strips/2)
		local angle1 = -PI / strips + (i + 1)*PI / (strips/2)

		lgfx.outlined(lgfx.arc, colors[i + 1], x, y, radius, angle0, angle1)
	end
end

-- implementation --------------------------------------------------------------

local Pawn, Rook, Queen, Board, Point

do
	local function __pieceCall(class, color, position)
		return setmetatable({position = position, _color = color}, class)
	end

	local function isAllyOf(a, b)
		return a._color == b._color
	end

	Pawn  = class({__call = __pieceCall, isAllyOf = isAllyOf})
	Rook  = class({__call = __pieceCall, isAllyOf = isAllyOf})
	Queen = class({__call = __pieceCall, isAllyOf = isAllyOf})

	Point = class({})
	Board = {}
end

--------------------------------------------------------------------------------

function Point.__call(_, x, y)
	return setmetatable({x = x, y = y}, Point)
end

function Point.__div(a, b)
	if type(b) == 'number' then return Point(a.x / b, a.y / b)
	else                        return Point(a.x / b.x, a.y / b.y)
	end
end

function Point.__eq(a, b)
	return a.x == b.x and a.y == b.y
end

function Point.angle(a, b)
	return atan2(a.y - b.y, a.x - b.x)
end

function Point.distance(a, b)
	return sqrt((a.x - b.x)^2 + (a.y - b.y)^2)
end

--------------------------------------------------------------------------------

function Board.isIntersection(p)
	return (p.y == 2 and p.x % 4 ~= 0) or (p.y == 4 and p.x % 2 ~= 0)
end

function Board.pointToIndex(p)
	if     p.y  < 0 then return nil
	elseif p.y == 0 then return 1
	elseif p.y <= 1 then return p.x/4 + p.y + 1
	elseif p.y <= 3 then return 5 + p.x/2 + 8*(p.y - 2) + 1
	elseif p.y <= 6 then return 21 + p.x + 16*(p.y - 4) + 1
	end
end

function Board.point(x, y)
	if y < 0 then
		x, y = x + 8, -y
	elseif y == 0 then
		x = 0
	end

	return Point(x % 16, y)
end

function Board.xsteps(y)
	if     y <= 0 then return 16
	elseif y <= 1 then return 4
	elseif y <= 3 then return 2
	elseif y <= 6 then return 1
	end
end

function Board:draw()
	local bw, bh = self._texture:getDimensions()

	lgfx.push()
	lgfx.translate(bw/2, bh/2)
	lgfx.draw(self._texture, -bw/2, -bh/2)

	for y = 0, 6 do
		for x = 0, 15, Board.xsteps(y) do
			local piece = self:get(Point(x, y))

			if piece then
				lgfx.rotated(x * PI/8, piece.draw, piece,
								 y * 2*self._radiusStep, 0, self._pieceSize)
			end
		end
	end

	if self._selected then
		for _, point in pairs(self:listValidMoves()) do
			lgfx.rotated(point.x * PI/8, lgfx.colored, lgfx.cross, COLOR_MARKER,
							 point.y * 2*self._radiusStep, 0, self._pieceSize/2)
		end
	end

	lgfx.pop()
end

function Board:get(position)
	return self._pieces[Board.pointToIndex(position)]
end

function Board:listValidMoves()
	local moves = {}

	for _, direction in ipairs(self._selected:eyes()) do
		for _, point in ipairs(direction) do
			local target = self:get(point)

			if point.y > 6 or point.x % Board.xsteps(point.y) ~= 0 then
				break
			elseif target then
				if not self._selected:isAllyOf(target) then
					moves[#moves + 1] = point
				end

				break
			else
				moves[#moves + 1] = point
			end
		end
	end

	return moves
end

function Board:move(piece, point)
	if is(self:get(point), Queen) or is(self:get(Point(0, 0)), Queen) then
		Board:reset()
	else
		self:remove(piece)
		piece.position = point
		self:place(piece)

		if piece.position.y == 0 then
			piece:promote()
		end
	end
end

function Board:pixelToPoint(pixel)
	local center = Point(self._texture:getDimensions())/2
	local y = round(pixel:distance(center) / (2*self._radiusStep))

	if y <= 6 then
		local arc = Board.xsteps(y) * PI/16
		local angle = wrapAngle(pixel:angle(center) + arc)

		return Board.point(Board.xsteps(y) * floor(angle / (2*arc)), y)
	end
end

function Board:remove(piece)
	self._pieces[Board.pointToIndex(piece.position)] = nil
end

function Board:renderBoardTexture()
	local w, h = lgfx.getDimensions()

	self._texture    = lgfx.newCanvas(w, h, {msaa = 16})
	self._radius     = min(w, h)/2
	self._radiusStep = self._radius/13
	self._pieceSize  = 0.65 * self._radiusStep

	lgfx.setCanvas(self._texture)

	local cx, cy = w/2, h/2
	local strips = {COLOR_CARDINALS, COLOR_SUBDIAGONALS,
						 COLOR_DIAGONALS, COLOR_SUBDIAGONALS}

	for _, y in ipairs({6, 3, 1}) do
		lgfx.stripedDisk(cx, cy, (2*y + 1) * self._radiusStep,
							  loop(strips, 4, Board.xsteps(y)))
	end

	lgfx.colored(lgfx.ellipse, COLOR_CARDINALS, 'fill', cx, cy, self._radiusStep)

	for i = 1, 13, 2 do
		lgfx.colored(lgfx.ellipse, COLOR_OUTLINE, 'line',
						 cx, cy, i * self._radiusStep)
	end

	lgfx.setCanvas()
end

function Board:reset()
	self._pieces   = {}
	self._selected = nil

	for x, color in pairs({[4] = COLOR_BLACK, [12] = COLOR_WHITE}) do
		self:place(Pawn(color, Point(x, 3)))
		self:place(Rook(color, Point(x, 4)))
		self:place(Rook(color, Point(x, 5)))
		self:place(Queen(color, Point(x, 6)))

		for dx = -1, 1, 2 do
			for y = 4, 6 do
				self:place(Pawn(color, Point(x + dx, y)))
			end
		end
	end
end

function Board:select(point)
	local target = self:get(point)

	if self._selected then
		if target and self._selected:isAllyOf(target) then
			self._selected = target ~= self._selected and target or nil
		elseif contains(self:listValidMoves(), point) then
			self:move(self._selected, point)
			self._selected = nil
		else
			self._selected = nil
		end
	else
		self._selected = target
	end
end

function Board:place(piece)
	self._pieces[Board.pointToIndex(piece.position)] = piece
end

--------------------------------------------------------------------------------

function Pawn:draw(px, py, size)
	lgfx.outlined(lgfx.ellipse, self._color, px, py, size)
end

function Pawn:eyes()
	local x, y = self.position.x, self.position.y
	local m = Board.xsteps(self.position.y)
	local eyes = {{Board.point(x, y + 1)}}

	if Board.isIntersection(self.position) then
		eyes[#eyes + 1] = {Board.point(x + m, y - 1)}
		eyes[#eyes + 1] = {Board.point(x - m, y - 1)}
	else
		eyes[#eyes + 1] = {Board.point(x, y - 1)}
	end

	if y == 0 then
		x, y, m = 0, 1, 4
	end

	eyes[#eyes + 1] = {Board.point(x - m, y)}
	eyes[#eyes + 1] = {Board.point(x + m, y)}

	return eyes
end

function Pawn:promote()
	setmetatable(self, Rook)
end

--------------------------------------------------------------------------------

function Rook:draw(px, py, size)
	size = size * PI/4

	lgfx.outlined(lgfx.rectangle, self._color, px - size, py - size,
															 2*size, 2*size)
end

function Rook:eyes()
	local x, y = self.position.x, self.position.y
	local m = Board.xsteps(self.position.y)
	local eyes = {}

	for j = -1, 1, 2 do
		local one = {}; eyes[#eyes + 1] = one
		local two = {}; eyes[#eyes + 1] = two

		if self.position.y == 0 then
			for i = y + j, 6*j, j do
				one[#one + 1] = Board.point(x + 4, i)
			end
		else
			for i = x + j*m, x + 15*j, j*m do
				one[#one + 1] = Board.point(i, y)
			end
		end

		for i = y + j, 6*j, j do
			two[#two + 1] = Board.point(x, i)
		end
	end

	return eyes
end

function Rook:promote()
	setmetatable(self, Pawn)
end

--------------------------------------------------------------------------------

function Queen:draw(px, py, size)
	size = size * PI/sqrt(3)

	local l = sqrt(size^2 * 4/3)

	lgfx.outlined(lgfx.polygon, self._color, {px - size/2, py,
													      px + size/2, py - l/2,
													      px + size/2, py + l/2})
end

function Queen:eyes()
	local x, y = self.position.x, self.position.y
	local m = Board.xsteps(self.position.y)

	return {{Board.point(x - m, y), Board.point(x - 2*m, y)},
			  {Board.point(x + m, y), Board.point(x + 2*m, y)},
			  {Board.point(x, y - 1), Board.point(x, y - 2)}}
end

function Queen:promote()
end

--------------------------------------------------------------------------------

function love.load()
	Board:renderBoardTexture()
	Board:reset()
end

function love.resize()
	Board:renderBoardTexture()
end

function love.draw()
	Board:draw()
end

function love.mousepressed(px, py)
	local p = Board:pixelToPoint(Point(px, py))

	if p then
		Board:select(p)
	end
end