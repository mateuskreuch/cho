local atan2 = math.atan2
local floor = math.floor
local ipairs = ipairs
local lgfx = love.graphics
local min = math.min
local pairs = pairs
local sqrt = math.sqrt
local type = type

-- constants -------------------------------------------------------------------

local PI = math.pi

local COLOR_BLACK = {0, 0, 0}
local COLOR_WHITE = {1, 1, 1}
local COLOR_CARDINALS = {0.94, 0.85, 0.7}
local COLOR_DIAGONALS = {0.7, 0.53, 0.38}
local COLOR_SUBDIAGONALS = {0.49, 0.3, 0.2}
local COLOR_OUTLINE = {0.1, 0.1, 0.1}
local COLOR_MARKER = {0.13, 0.82, 0.76}

-- utility functions -----------------------------------------------------------

local function class(table)
	table.__index = table
	return setmetatable(table, table)
end

local function is(table, class)
	return getmetatable(table) == class
end

local function contains(table, x)
	for i = 1, #table do
		if table[i] == x then
			return true
		end
	end

	return false
end

local function loop(table, times, steps)
	local newtable = {}
	local length = #table

	for _ = 1, times do
		for i = 1, length, steps do
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

	lgfx.setLineWidth(3)
	lgfx.line(x - radius, y - radius, x + radius, y + radius)
	lgfx.line(x - radius, y + radius, x + radius, y - radius)
	lgfx.setLineWidth(1)
end

function lgfx.outlined(func, color, ...)
	lgfx.colored(func, color, 'fill', ...)
	lgfx.colored(func, color == COLOR_BLACK and COLOR_WHITE
														  or COLOR_OUTLINE, 'line', ...)
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

local Pawn, Rook, King, Board, Point

do
	local function __pieceCall(class, color, position)
		return setmetatable({color = color, position = position}, class)
	end

	Pawn = class({__call = __pieceCall})
	Rook = class({__call = __pieceCall})
	King = class({__call = __pieceCall})

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

function Board.pointToIndex(point)
	if     point.y  < 0 then return nil
	elseif point.y == 0 then return 1
	elseif point.y <= 1 then return point.x/4 + point.y + 1
	elseif point.y <= 3 then return 5 + point.x/2 + 8*(point.y - 2) + 1
	elseif point.y <= 6 then return 21 + point.x + 16*(point.y - 4) + 1
	else                     return nil
	end
end

function Board.wrapPoint(x, y)
	if y < 0 then
		x, y = x + 8, -y
	elseif y == 0 then
		x = 0
	end

	return Point(x % 16, y)
end

function Board.xsteps(y)
	if     y <= 0 then return 4 -- 16
	elseif y <= 1 then return 4
	elseif y <= 3 then return 2
	elseif y <= 6 then return 1
	end
end

function Board.draw(O)
	local bw, bh = O._texture:getDimensions()

	lgfx.push()
	lgfx.translate(bw/2, bh/2)
	lgfx.draw(O._texture, -bw/2, -bh/2)

	for y = 0, 6 do
		for x = 0, 15, Board.xsteps(y) do
			local piece = O:get(Point(x, y))

			if piece then
				local px, py = y * 2*O._radiusStep, 0

				lgfx.push()
				lgfx.rotate(x * PI/8)
				piece:draw(px, py, O._pieceSize)
				lgfx.pop()
			end
		end
	end

	if O._selected then
		for _, direction in ipairs(O._selected:eyes()) do
			for _, point in pairs(direction) do
				local px, py = point.y * 2*O._radiusStep, 0

				lgfx.push()
				lgfx.rotate(point.x * PI/8)
				lgfx.colored(lgfx.cross, COLOR_MARKER, px, py, O._pieceSize/2)
				lgfx.pop()
			end
		end
	end

	lgfx.pop()
end

function Board.get(O, position)
	return O._pieces[Board.pointToIndex(position)]
end

function Board.pixelToPoint(O, pixel)
	local center = Point(O._texture:getDimensions())/2
	local y = round(pixel:distance(center) / (2*O._radiusStep))

	if y == 0 then
		return Point(0, 0)
	elseif y <= 6 then
		local arc = Board.xsteps(y) * PI/16
		local angle = wrapAngle(pixel:angle(center) + arc)

		return Point(Board.xsteps(y) * floor(angle / (2*arc)), y)
	end
end

function Board.renderBoardTexture(O)
	local w, h = lgfx.getDimensions()

	O._texture = lgfx.newCanvas(w, h, {msaa = 16})
	O._radius = min(w, h)/2
	O._radiusStep = O._radius/13
	O._pieceSize = 0.65 * O._radiusStep

	lgfx.setCanvas(O._texture)

	local cx, cy = w/2, h/2
	local strips = {COLOR_CARDINALS, COLOR_SUBDIAGONALS,
						 COLOR_DIAGONALS, COLOR_SUBDIAGONALS}

	for _, y in ipairs({6, 3, 1}) do
		lgfx.stripedDisk(cx, cy, (2*y + 1) * O._radiusStep,
							  loop(strips, 4, Board.xsteps(y)))
	end

	lgfx.colored(lgfx.ellipse, COLOR_CARDINALS, 'fill', cx, cy, O._radiusStep)

	for i = 1, 13, 2 do
		lgfx.colored(lgfx.ellipse, COLOR_OUTLINE, 'line', cx, cy, i*O._radiusStep)
	end

	lgfx.setCanvas()
end

function Board.reset(O)
	O._pieces = {}
	O._selected = nil

	for dx, color in pairs({[0] = COLOR_BLACK, [8] = COLOR_WHITE}) do
		O:set(Rook(color, Point(4 + dx, 6)))
		O:set(King(color, Point(4 + dx, 5)))
		O:set(Rook(color, Point(4 + dx, 4)))
		O:set(Pawn(color, Point(4 + dx, 3)))

		for x = 0, 2, 2 do
			for y = 4, 6 do
				O:set(Pawn(color, Point(3 + x + dx, y)))
			end
		end
	end
end

function Board.select(O, point)
	O._selected = O:get(point)
end

function Board.set(O, piece)
	O._pieces[Board.pointToIndex(piece.position)] = piece
end

--------------------------------------------------------------------------------

function Pawn.draw(O, px, py, size)
	lgfx.outlined(lgfx.ellipse, O.color, px, py, size)
end

function Pawn.eyes(O)
	local m = Board.xsteps(O.position.y)
	local eyes = {}

	if O.position.y == 0 then
		eyes[#eyes + 1] = {Board.wrapPoint(-4, 1)}
		eyes[#eyes + 1] = {Board.wrapPoint(4, 1)}
	else
		eyes[#eyes + 1] = {Board.wrapPoint(O.position.x - m, O.position.y)}
		eyes[#eyes + 1] = {Board.wrapPoint(O.position.x + m, O.position.y)}
	end

	if O.position.y < 6 then
		eyes[#eyes + 1] = {Board.wrapPoint(O.position.x, O.position.y + 1)}
	end

	if (O.position.y == 2 and O.position.x % 4 ~= 0)
	or (O.position.y == 4 and O.position.x % 2 ~= 0) then
		eyes[#eyes + 1] = {Board.wrapPoint(O.position.x - m, O.position.y - 1)}
		eyes[#eyes + 1] = {Board.wrapPoint(O.position.x + m, O.position.y - 1)}
	else
		eyes[#eyes + 1] = {Board.wrapPoint(O.position.x, O.position.y - 1)}
	end

	return eyes
end

--------------------------------------------------------------------------------

function Rook.draw(O, px, py, size)
	size = size * PI/4

	lgfx.outlined(lgfx.rectangle, O.color, px - size, py - size, 2*size, 2*size)
end

function Rook.eyes(O)
	local m = Board.xsteps(O.position.y)
	local eyes = {}

	for j = -1, 1, 2 do
		local horizontal = {}; eyes[#eyes + 1] = horizontal
		local vertical   = {}; eyes[#eyes + 1] = vertical

		if O.position.y == 0 then
			for i = O.position.y + j, 6*j, j do
				horizontal[#horizontal + 1] = Board.wrapPoint(O.position.x + 4, i)
			end
		else
			for i = O.position.x + j*m, O.position.x + 8*j, j*m do
				horizontal[#horizontal + 1] = Board.wrapPoint(i, O.position.y)
			end
		end

		for i = O.position.y + j, 6*j, j do
			vertical[#vertical + 1] = Board.wrapPoint(O.position.x, i)
		end
	end

	return eyes
end

--------------------------------------------------------------------------------

function King.draw(O, px, py, size)
	size = size * PI/sqrt(3)

	local l = sqrt(size^2 * 4/3)

	lgfx.outlined(lgfx.polygon, O.color, {px - size/2, py,
													  px + size/2, py - l/2,
													  px + size/2, py + l/2})
end

function King.eyes(O)
	local m = Board.xsteps(O.position.y)
	local eyes = {{Board.wrapPoint(O.position.x - m, O.position.y)},
					  {Board.wrapPoint(O.position.x + m, O.position.y)}}

	if O.position.y < 6 then
		eyes[#eyes + 1] = {Board.wrapPoint(O.position.x, O.position.y + 1)}
	end

	if not ((O.position.y == 2 and O.position.x % 4 ~= 0)
	or (O.position.y == 4 and O.position.x % 2 ~= 0)) then
		eyes[#eyes + 1] = {Board.wrapPoint(O.position.x, O.position.y - 1)}
	end

	return eyes
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

function love.touchpressed(_, px, py)
	love.mousepressed(px, py)
end