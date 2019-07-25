-- imported modules
local Action = require 'GameAction'

local bindings = {
	["up"] = Action.Up
	, ["kp8"] = Action.Up
	, ["down"] = Action.Down
	, ["kp2"] = Action.Down
	, ["left"] = Action.Left
	, ["kp4"] = Action.Left
	, ["right"] = Action.Right
	, ["kp6"] = Action.Right
	, ["."] = Action.Rest
	, ["kp5"] = Action.Rest

	, [","] = Action.Grab
	, ["g"] = Action.Grab
	, ["d"] = Action.Drop
	, ["x"] = Action.Examine
	, ["l"] = Action.Examine

	, ["1"] = Action.Equip1
	, ["2"] = Action.Equip2
	, ["3"] = Action.Equip3
	, ["4"] = Action.Inventory1
	, ["5"] = Action.Inventory2
	, ["6"] = Action.Inventory3
	, ["7"] = Action.Inventory4
	, ["8"] = Action.Inventory5
	, ["9"] = Action.Inventory6

	, ["escape"] = Action.Escape
	, ["`"] = Action.Toggle_Console
	, ["tab"] = Action.Experimental_Camera_Switch
	, ["lctrl+1"] = Action.Debug_Toggle_Vismap
	, ["lctrl+2"] = Action.Debug_Toggle_Astar
}

return bindings
