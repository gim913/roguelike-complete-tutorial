-- imported modules
local batch = require 'batch'
local Camera = require 'Camera'
local GameMenu = require 'GameMenu'
local Infected = require 'EInfected'
local interface = require 'interface'
local Level = require 'Level'
local messages = require 'messages'
local Player = require 'Player'
local S = require 'settings'
local Tiles = require 'Tiles'

local action = require 'engine.action'
local class = require 'engine.oop'
local console = require 'engine.console'
local elements = require 'engine.elements'
local entities = require 'engine.entities'
local fontManager = require 'engine.fontManager'
local map = require 'engine.map'
local utils = require 'engine.utils'
local Entity = require 'engine.Entity'

local gamestate = require 'hump.gamestate'
local Vec = require 'hump.vector'

-- class
local Game = class('Game')

console.initialize((31 * 25) + 10 + 128, 100, 900)
messages.initialize(31 * 25, 31 * 25)

local f = math.floor
local camera = nil
local player
local Max_Dummies = 5
local dummies = {}

local minimapData = nil
local minimapImg = nil
local function updateMinimap()
	minimapImg = love.graphics.newImage(minimapData)
	minimapImg:setFilter("nearest", "nearest")
end

local function addLevel(levels, rng, depth)
	local l = Level:new(rng, depth)
	table.insert(levels, l)
	return l
end

local function processEntitiesFov()
	local time1 = love.timer.getTime()
	for _,e in pairs(entities.with(entities.Attr.Has_Fov)) do
		e:recalcVisMap()
	end
	for _,e in pairs(entities.with(entities.Attr.Has_Fov)) do
		e:recalcSeeMap()
	end
	local time2 = love.timer.getTime()
	print(string.format('fov+los took %.5f ms', (time2 - time1) * 1000))

	-- updated fog-of-war

	for k,v in pairs(player.vismap) do
		if v > 0 then
			map.known(k)
			local tileId = map.getTileId(k)
			local r,g,b = 25,25,25
			if tileId >= Tiles.Water and tileId < Tiles.Earth then
				r,g,b = 0x4c, 0x9a, 0xec
			elseif tileId >= Tiles.Earth and tileId < Tiles.Grass then
				r,g,b = 0x3c, 0x18, 0x00
			elseif tileId >= Tiles.Grass and tileId < Tiles.Bridge then
				r,g,b = 0x08, 0x7c, 0x00
			elseif tileId == Tiles.Bridge then
				r,g,b = 0x78, 0x3c, 0x00
			else
				r,g,b = 64, 64, 64
			end

			local t = elements.getTileId(k)
			if t and t >= Tiles.Trees and t <= Tiles.Tree_Maple then
				r,g,b = 0x8, 0x2c, 0x8
			end

			local x = f(k % map.width())
			local y = f(k / map.width())
			minimapData:setPixel(x, y, r / 255.0, g / 255.0, b / 255.0, 1.0)
		end
	end
	updateMinimap()
end

local function updateTiles()
	local camLu = camera:lu()
	batch.update(camera.followedEnt, camLu.x, camLu.y)
end

local Entity_Tile_Size = 64

local function prepareLetters(letters)
	local font = fontManager.get('fonts/FSEX300.ttf', 64, 'normal')
	love.graphics.setFont(font)

	local images = {}
	for i = 1, #letters do
		local c = letters:sub(i, i)
		canvas = love.graphics.newCanvas(64, 64)
		love.graphics.setCanvas(canvas)
		love.graphics.setColor(1.0, 1.0, 1.0, 1.0)
		love.graphics.printf(c, 0, 0, 64, 'center')
		love.graphics.setCanvas()

		images[c] = canvas
	end

	return images
end


local classes = {
	Player = 1,
	Infected = 2
}

local Letters

function Game:ctor(rng)
	self.rng = rng
	self.seed = 0
	self.fatFont = fontManager.get(32)

	self.levels = {}
	for depth = 1, S.game.DEPTH do
		addLevel(self.levels, self.rng, depth)
	end

	self.depthLevel = 1
	self.updateLevel = false
	self.doActions = false
	self.ui = {}
	-- self.ui.showGrabMenu
	-- self.ui.examine

	batch.prepare()
	local level = self.levels[self.depthLevel]
	map.initialize(level.w, level.h)

	minimapData = love.image.newImageData(level.w, level.h)
	minimapData:mapPixel(function(x, y, r, g, b, a)
		return 0.1, 0.1, 0.1, 1.0
	end)
	updateMinimap()

	Letters = prepareLetters('@iBCSTM[')
	local f = math.floor
	player = Player:new(Vec(f(map.width() / 2), map.height() - 59))
	player.img = Letters['@']
	player.class = classes.Player

	entities.add(player)
	entities.addAttr(player, entities.Attr.Has_Fov)
	entities.addAttr(player, entities.Attr.Has_Move)
	entities.addAttr(player, entities.Attr.Has_Attack)

	-- TODO: get rid of dummies later
	for i = 1, Max_Dummies do
		local rx = self.rng:random(-15, 15)
		local ry = self.rng:random(0, 30)
		local dummy = Infected:new(Vec(f(map.width() / 2 + rx), map.height() - 45 - ry))
		dummy.img = Letters['i']
		dummy.class = classes.Infected

		entities.add(dummy)
		entities.addAttr(dummy, entities.Attr.Has_Fov)
		entities.addAttr(dummy, entities.Attr.Has_Move)
		entities.addAttr(dummy, entities.Attr.Has_Attack)
		entities.addAttr(dummy, entities.Attr.Has_Ai)
		dummy:occupy()

		table.insert(dummies, dummy)
	end

	local elemPos = Vec(f(map.width() / 2 - 5), map.height() - 27)
	local idx = elemPos.y * map.width() + elemPos.x
	local go = elements.create(idx)
	go:setTileId(3 * 16)

	camera = Camera:new()
	camera:follow(player)
	camera:update()

	cameraIdx = 0
	--updateTiles()
end

-- semi constants
local Tile_Size = 30
local Tile_Border = 1
local Tile_Size_Adj = Tile_Size + Tile_Border


-- function love.textinput(t)
--     imgui.TextInput(t)
--     if not imgui.GetWantCaptureKeyboard() then
--         -- Pass event to the game
--     end
-- end

function Game:mousemoved(x, y)
    imgui.MouseMoved(x, y)
	if imgui.GetWantCaptureMouse() then
		return
    end
end

function Game:mousereleased(x, y, button)
    imgui.MouseReleased(button)
	if imgui.GetWantCaptureMouse() then
		return
    end
end

function Game:mousepressed(x, y, button)
	imgui.MousePressed(button)
	if imgui.GetWantCaptureMouse() then
		return
	end

	if player.astar_path then
		player.follow_path = 1
	end
end

function Game:wheelmoved(x, y)
	imgui.WheelMoved(y)
	if imgui.GetWantCaptureMouse() then
		return
	end

	if love.keyboard.isDown('lctrl') then
		if love.keyboard.isDown('lshift') then
			console.nextFont()
		else
			console.changeFontSize(y)
		end
	else
		S.game.VIS_RADIUS = math.max(12, math.min(63, S.game.VIS_RADIUS + y))

		Tile_Size = batch.recalc(S.game.VIS_RADIUS)
		Tile_Size_Adj = Tile_Size + Tile_Border
		camera:follow(player)
		camera:update()
		updateTiles()
	end
end

local function playerMoveAction(moveVec)
	local nextAct,nPos = player:wantGo(moveVec)
	if nextAct ~= action.Action.Blocked then
		--print('action ', nextAct)
		if nextAct == action.Action.Attack then
			action.queue(player.actions, Player.Bash_Speed, action.Action.Attack, nPos)
		else
			action.queue(player.actions, Player.Base_Speed, action.Action.Move, nPos)
		end
		return true, nextAct
	end

	return false
end

local Move_Vectors = {
	Vec( 0, -1), -- up
	Vec( 0,  1), -- down
	Vec(-1,  0), -- left
	Vec( 1,  0), -- right
	Vec( 0,  0) -- rest
}

local function checkKeyPress(pressedKey, keyNames)
	for _, keyName in pairs(keyNames) do
		if keyName == pressedKey then
			return true
		end
	end

	return false
end

local function movementKeyToVector(pressedKey)
	for index = 1, #Move_Vectors do
		if checkKeyPress(pressedKey, S.keyboard[index]) then
			return Move_Vectors[index]
		end
	end

	return nil
end

function Game:keyreleased(key)
    imgui.KeyReleased(key)
    if imgui.GetWantCaptureKeyboard() then
        return
    end
end

function Game:keypressed(key)
	imgui.KeyPressed(key)
    if imgui.GetWantCaptureKeyboard() then
        return
	end

	local nextAct=action.Action.Blocked, nPos

	-- general / UI
	if 'escape' == key then
		if self.ui.examine then
			self.ui.examine = false
		else
			gamestate.push(GameMenu:new())
		end
	elseif '`' == key or '~' == key then
		console.toggle()
	end

	-- debug
	-- TODO: XXX: TODO: devel: quit
	if love.keyboard.isDown('lctrl') then
		if key == "1" then
			-- toggle flag
			current = batch.debug('disableVismap') or false
			batch.debug({ disableVismap = not current })
			updateTiles()
		elseif key == "2" then
			S.game.debug.show_astar_paths = not S.game.debug.show_astar_paths
		end
	end

	-- movement / game / actions
	local moveVec = nil
	if #(player.actions) == 0 then
		-- ignore keyboard controls if following the path
		if not player.follow_path then
			moveVec = movementKeyToVector(key)
			if ',' == key or 'g' == key then
				self.ui.showGrabMenu = true
			elseif 'x' == key then
				self.ui.examine = true
			end
		end

		-- TODO: XXX: TODO: devel: remove this before releasing ^^
		if key == "tab" then
			if cameraIdx == Max_Dummies then
				camera:follow(player)
				cameraIdx = 0
			else
				cameraIdx = cameraIdx + 1
				camera:follow(dummies[cameraIdx])
			end
			camera:update()
			updateTiles()
		end
	end

	if self.ui.examine then
		-- use moveVec to move selection
	else
		if moveVec and playerMoveAction(moveVec) then
			self.doActions = true
		end
	end
end

function Game:startLevel()
	local level = self.levels[self.depthLevel]
	love.window.setTitle("Pandemos - (game in progress)")
	if not level.visited then
		level:initializeGenerator()
		self.updateLevel = true
	end
end

local updateTilesAfterMove = false
-- returns true when there was any move
-- will require some recalculations later
local function processMoves()
	local ret = false
	for _,e in pairs(entities.with(entities.Attr.Has_Move)) do
		if e.actionState == action.Action.Move then
			e:move()
			e.actionState = action.Action.Idle

			-- fire up ai to queue next action item
			e:analyze(player)

			if camera:isFollowing(e) then
				updateTilesAfterMove = true
			end

			ret = true
		end
	end
	return ret
end

local function processAttacks()
	local ret = false
	for _,e in pairs(entities.with(entities.Attr.Has_Attack)) do
		if e.actionState == action.Action.Attack then
			print('processing attack')
			e:attack()
			e.actionState = action.Action.Idle

			-- fire up ai to queue next action item
			e:analyze(player)

			if camera:isFollowing(e) then
				updateTilesAfterMove = true
			end

			ret = true
		end
	end
	return ret
end

local function processAi()
	local ret = false
	for _,e in pairs(entities.with(entities.Attr.Has_Ai)) do
		if e.actionState == action.Action.Idle then
			if e:analyze(player) then
				ret = true
			end
		end
	end

	return ret
end

local function pathPlayerMovement()
	local ret = false

	if player.astar_path and player.follow_path and player.follow_path > 0 then
		local moveVec = player.astar_path[player.follow_path] - player.pos
		local nextAction

		ret, nextAction = playerMoveAction(moveVec)
		if ret and action.Action.Move == nextAction then
			player.follow_path = player.follow_path + 1
			if player.follow_path > #player.astar_path then
				player.follow_path = nil
				player.astar_path = nil
			end
		end
	end

	return ret
end

local mouseCell = nil

function Game:doUpdateLevel(dt)
	local level = self.levels[self.depthLevel]
	self.updateLevel = level:update(dt)

	-- update after updating the map
	if not self.updateLevel then
		-- recalc player fov, after map is generated
		processEntitiesFov()

		-- update batch
		print('updating batch')
		updateTiles()
	end
end

local initializeAi = true
function Game:updateGameLogic(dt)
	-- at this point map should be ready, fire up AI once,
	-- afterwards it should be fired after finishing actions
	if initializeAi then
		processAi()
		initializeAi = false
	end

	-- 'execute' planned path
	if #(player.actions) == 0 then
		self.doActions = pathPlayerMovement()
	end

	-- not yet sure if it should be here
	messages.update(dt, camera:lu(), Tile_Size_Adj)

	if self.doActions then
		self.doActions = entities.processActions(player)
		local movementDone = processMoves()
		processAttacks()

		elements.process()

		-- if movementDone then
		-- 	elements.refresh()
		-- end

		if updateTilesAfterMove then
			camera:update()

			-- not needed here anymore
			--processAi()

			-- TODO: probably wrong location
			processEntitiesFov()

			updateTiles()
			updateTilesAfterMove = false
		end
	end
end

function Game:handleGrabUpdate(dt)
	local locationId = player.pos.y * map.width() + player.pos.x
	local items, itemCount = elements.getItems(locationId)
	if items then
		if itemCount == 1 then
			for itemId, item in pairs(items) do
				table.insert(player.inventory, item)
				elements.del(locationId, itemId)

				updateTiles()
			end
		else
			console.log('Game:handleGrabUpdate() more items inside the cell')
		end
	end

	self.ui.showGrabMenu = false
end

function Game:doUpdate(dt)
	if self.ui.showGrabMenu then
		-- if single item on the ground and there is a space in inventory, just grab it
		-- if more items show menu
		self:handleGrabUpdate(dt)
	else
		self:updateGameLogic(dt)
	end

	local mouseX, mouseY = love.mouse.getPosition()

	local vis = 2 * S.game.VIS_RADIUS + 1
	if mouseX >= 0 and mouseX < (Tile_Size_Adj * vis) and mouseY >= 0 and mouseY < (Tile_Size_Adj * vis) then
		local newMouseCell = Vec(math.floor(mouseX / Tile_Size_Adj), math.floor(mouseY / Tile_Size_Adj))
		if not mouseCell or newMouseCell ~= mouseCell then
			mouseCell = newMouseCell
			if not player.follow_path or player.follow_path == 0 then
				local camLu = camera:lu()
				local destination = camLu + mouseCell
				player.astar_path = player:findPath(destination)
			end
		end
	else
		mouseCell = nil
	end

	console.update(dt)
end

function Game:update(dt)
	-- keep running level update, until level generation is done
	if self.updateLevel then
		self:doUpdateLevel(dt)
	else
		self:doUpdate(dt)
	end
end

local function drawItems(ent, camLu)
	local scaleFactor = Tile_Size / Entity_Tile_Size
	local ya = camLu.y
	local xa = camLu.x

	local tc = 2 * S.game.VIS_RADIUS + 1
	for y=0, tc - 1 do
		if ya + y > map.height() then
			break
		end

		local locationId = (ya + y) * map.width() + xa
		for x=0, tc - 1 do
			local items, itemCount = elements.getItems(locationId)
			if itemCount > 0 then
				local vismap = ent.vismap
				if debug.disableVismap or (vismap[locationId] and vismap[locationId] > 0) then
					love.graphics.setColor(1.0, 1.0, 1.0)

					local itemImg = Letters[items[1].desc.symbol]
					love.graphics.draw(itemImg, x * Tile_Size_Adj, y * Tile_Size_Adj, 0, scaleFactor, scaleFactor)
				end
			end
			locationId = locationId + 1
		end
	end
end

local function drawEntityPath(ent, camLu)
	if ent ~= player and S.game.debug and not S.game.debug.show_astar_paths then
		return
	end

	if not ent.astar_path then
		return
	end

	for i, node in pairs(ent.astar_path) do
		local relPos = node - camLu
		if camera.followedEnt == ent then
			love.graphics.setColor(0.1, 0.1, 0.1, 0.5)
			love.graphics.rectangle('fill', relPos.x * Tile_Size_Adj, relPos.y * Tile_Size_Adj, Tile_Size + 1, Tile_Size + 1)
			love.graphics.setColor(0.9, 0.9, 0.9, 1.0)
			love.graphics.print(tostring(i), relPos.x * Tile_Size_Adj + 10, relPos.y * Tile_Size_Adj + 10)
		else
			love.graphics.setColor(0.9, 0.7, 0.7, 0.5)
			love.graphics.rectangle('fill', relPos.x * Tile_Size_Adj, relPos.y * Tile_Size_Adj, Tile_Size + 1, Tile_Size + 1)
			love.graphics.setColor(0.3, 0.1, 0.1, 1.0)
			love.graphics.print(tostring(i), relPos.x * Tile_Size_Adj, relPos.y * Tile_Size_Adj)
		end
	end
end

local function drawEntities(camLu)
	local scaleFactor = Tile_Size / Entity_Tile_Size
	for _,ent in pairs(entities.all()) do
		local relPos = ent.pos - camLu
		if ent == player then
			love.graphics.setColor(0.9, 0.9, 0.9, 1.0)
		else
			love.graphics.setColor(0.7, 0.1, 0.1, 1.0)
		end

		-- drawEntity
		if camera.followedEnt == ent or camera.followedEnt.seemap[ent] then
			love.graphics.draw(ent.img, relPos.x * Tile_Size_Adj, relPos.y * Tile_Size_Adj, 0, scaleFactor, scaleFactor)

			-- show entity name on hover -- TODO: remove
			if mouseCell and relPos == mouseCell then
				love.graphics.setColor(0.9, 0.9, 0.9, 0.8)
				love.graphics.rectangle('fill', (mouseCell.x + 1) * Tile_Size_Adj, mouseCell.y * Tile_Size_Adj, 2 * Tile_Size + 1, 16)
				love.graphics.setColor(0.0, 0.0, 0.0, 1.0)
				love.graphics.print(ent.name, (mouseCell.x + 1) * Tile_Size_Adj, mouseCell.y * Tile_Size_Adj)
			end

			-- if ent.astar_visited then
			-- 	for k, v in pairs(ent.astar_visited) do
			-- 		local sx = v.x - camLuX
			-- 		local sy = v.y - camLuY

			-- 		love.graphics.setColor(0.9, 0.9, 0.9, 0.3)
			-- 		love.graphics.rectangle('fill', sx * ts, sy * ts, Tile_Size + 1, Tile_Size + 1)
			-- 	end
			-- end

			drawEntityPath(ent, camLu)
		end
	end
end

local function drawMinimap()
	local scale = (31 * 25) / minimapImg:getHeight()
	love.graphics.setColor(1.0, 1.0, 1.0, 1.0)
	love.graphics.draw(minimapImg, (31 * 25) + 10, 0, 0, 1, scale)
end

local function drawInterface()
	local startX = (31 * 25) + 10 + minimapImg:getWidth() + 10
	local camLu = camera:lu()

	interface.begin('Entities', startX, 10)

	local h = interface.drawPlayerInfo(player, 260)

	interface.drawVisible(player.seemap, 260, 260, function(ent)
		local relPos = ent.pos - camLu
		if mouseCell and relPos == mouseCell then
			return true
		end
		return false
	end)
	interface.finish()

	interface.begin('Equipment', startX, 260 + 20 + h + 50)

	imgui.BeginGroup()
	imgui.BeginChild_2(1, 260, 80, true, "ImGuiWindowFlags_None");
	imgui.Text('1: <filler>')
	imgui.Text('2: <filler>')
	imgui.Text('3: <filler>')
	imgui.EndChild()
	imgui.EndGroup()

	interface.finish()

	interface.begin('Inventory', startX, 260 + h + 50 + 80 + 60)

	imgui.BeginGroup()
	imgui.BeginChild_2(1, 260, 150, true, "ImGuiWindowFlags_None");
	if #player.inventory > 0 then
		for _, item in pairs(player.inventory) do
			imgui.Text(item.desc.name)
			imgui.SameLine(150)
			imgui.Text(item.desc.type)
		end
	else
		imgui.Text('<filler>')
		imgui.Text('<filler>')
		imgui.Text('<filler>')
		imgui.Text('<filler>')
		imgui.Text('<filler>')
	end
	imgui.EndChild()
	imgui.EndGroup()

	interface.finish()

	imgui.Render();
end

function Game:show()
	-- TODO: debug info
	local camLu = camera:lu()
	love.graphics.print("radius: "..S.game.VIS_RADIUS, S.resolution.x - 200 - 10, 30)
	love.graphics.print("player: " .. player.pos.x .. "," .. player.pos.y, S.resolution.x - 200 - 10, 50)
	love.graphics.print("camera: " .. cameraIdx, S.resolution.x - 200 - 10, 70)
	if mouseCell then
		local mapCoords = camLu + mouseCell
		love.graphics.print("mouse: " .. tostring(mapCoords), S.resolution.x - 200 - 10, 90)
	end

	if self.ui.examine then
		love.graphics.print("self.ui.examine", S.resolution.x - 200 - 10, 110)
	end

	-- draw map
	batch.draw()
	drawItems(camera.followedEnt, camLu)

	-- ^^
	drawEntities(camLu)

	if mouseCell then
		love.graphics.setColor(0.5, 0.9, 0.5, 0.9)
		love.graphics.rectangle('line', mouseCell.x * Tile_Size_Adj, mouseCell.y * Tile_Size_Adj, Tile_Size + 1, Tile_Size + 1)
	end

	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.draw(messages.popups.getCanvas())
	drawInterface()
	drawMinimap()
	console.draw(0, 900 - console.height())
end

function Game:draw()
	if self.updateLevel then
		local level = self.levels[self.depthLevel]
		level:show()
	else
		self:show()
	end
end

return Game