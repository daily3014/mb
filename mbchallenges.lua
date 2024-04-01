local uiOpen = false
local target
local hitmanEnabled = false
local tired = false

local timers = {
	bhopMaster = { left = 0, running = false },
	earthBound = { left = 0, running = false },
	hitman = { left = 0, running = false },
	tired = { left = 0, running = false },
	moving = { left = 0, running = false },
	paranoid = { left = 0, running = false },
	corona = { left = 0, running = false }
}

local settings = {
	paranoid = ui.add_checkbox("Paranoid", false),
	fragileLegs = ui.add_checkbox("Fragile Legs", false),
	alwaysMoving = ui.add_checkbox("Always Moving", false),
	teamPlayer = ui.add_checkbox("Team Player", false),
	bhopMaster = ui.add_checkbox("Bhop Master", false),
	godMode = ui.add_checkbox("God Mode", false),
	earthBound = ui.add_checkbox("Earthbound", false),
	corona = ui.add_checkbox("Corona Virus", false),
	lowProfile = ui.add_checkbox("Low Profile", false),
	aquaphobia = ui.add_checkbox("Aquaphobia", false),
	tired = ui.add_checkbox("Tired", false),
	hitman = ui.add_checkbox("Hitman", false),
}

---@param entity1 Entity
---@param entity2 Entity
local function getDistance(entity1, entity2)
	local entity1Pos = { entity1:get_abs_origin() }
	local entity2Pos = { entity2:get_abs_origin() }

	local diff = { entity1Pos[1] - entity2Pos[1], entity1Pos[2] - entity2Pos[2], entity1Pos[3] - entity2Pos[3] }
	local magnitude = math.sqrt(diff[1]^2 + diff[2]^2 + diff[3]^2)

	return magnitude
end

local function timerRunning(name)
	return timers[name].running
end

local function stopTimer(name)
	timers[name].running = false
end

local function resetTimer(name)
	stopTimer(name)
	timers[name].left = 0
end

local function setTimer(name, time)
	timers[name].left = time
	timers[name].running = true
end

local function timerExpired(name)
	return timers[name].left <= 0 and timers[name].running
end

local function onTimerExpired(name, callback)
	if timerExpired(name) then
		resetTimer(name)
		callback()
	end
end

local function clamp(num, min, max)
	if num > max then return max end
	if num < min then return min end
	return num
end

local function kill()
	console.exec("explode")
end

---@param event IGameEvent
callbacks.register("player_hurt", function(event)
	local victim_userid = event:get_int("userid")
    local victim = entity_list.get_by_user_id(victim_userid)

    if victim:get_index() == engine.get_local_index() then
		if settings.fragileLegs:get() and event:get_int("attacker") == 0 then
			kill()
		elseif settings.godMode:get() and event:get_int("attacker") ~= 0 then
			kill()
		end
	end
end)

---@param event IGameEvent
callbacks.register("player_death", function(event)
	local localPlayer = entity_list.get_local_player()

	local victim_userid = event:get_int("userid")
    local victim = entity_list.get_by_user_id(victim_userid)

	if victim:get_team_number() == localPlayer:get_team_number() then
		if settings.teamPlayer:get() and event:get_int("attacker") ~= victim_userid then
			kill()
		end
	elseif target and event:get_int("victim_entindex") == target then
		hitmanEnabled = false
		target = nil
		resetTimer("hitman")
	elseif event:get_int("inflictor_entindex") == localPlayer:get_index() then
		if settings.lowProfile:get() then
			kill()
		end
	end
end)

---@param cmd CUserCmd
callbacks.register("post_move", function(cmd)
	local localPlayer = entity_list.get_local_player()
	if not localPlayer or not localPlayer:is_alive() then
		return
	end

	if ui.is_open() then
		return
	end

	for _, timerInfo in pairs(timers) do
		if timerInfo.running then
			timerInfo.left = timerInfo.left - server.get_interval_per_tick()
		end
	end

	local info = {
		farTeammates = 0,
		nearbyTeammates = 0,
		onGround = localPlayer:has_flag(FL_ONGROUND)
	}

	if settings.aquaphobia:get() then
		local waterLevel = math.max(localPlayer:get_prop("m_nWaterLevel"):get_int() - 2^24, 0)
		if waterLevel > 2^8 then
			waterLevel = waterLevel - 2^8
			if waterLevel > 0 then -- levels are [1-3] 0 for not in water
				kill()
			end
		end
	end

	if settings.alwaysMoving:get() then
		local speed = math.sqrt(math.abs(cmd.sidemove)^2 + math.abs(cmd.forwardmove)^2)

		if speed < 20 then
			if timerRunning("moving") then
				onTimerExpired("moving", kill)
			else
				setTimer("moving", .5)
			end
		else
			resetTimer("moving")
		end
	end

	if not info.onGround then
		if settings.bhopMaster:get() then
			resetTimer("bhopMaster")
		end

		if settings.earthBound:get() then
			if timerRunning("earthBound") then
				onTimerExpired("earthBound", kill)
			else
				setTimer("earthBound", .4)
			end
		end
	elseif info.onGround then
		if settings.bhopMaster:get() then
			if not cmd:has_button(IN_JUMP) then
				if timerRunning("bhopMaster") then
					onTimerExpired("bhopMaster", kill)
				else
					setTimer("bhopMaster", 1)
				end
			else
				resetTimer("bhopMaster")
			end
		end

		if settings.earthBound:get() then
			resetTimer("earthBound")
		end
	end

	local players = entity_list.get_all("CTFPlayer")
	local enemies = {}

	for index = 1, #players do
		local player_index = players[index]

		local player = entity_list.get_client_entity(player_index)
		if player:get_index() == localPlayer:get_index() then goto continue end
		if player:get_team_number() ~= localPlayer:get_team_number() then
			table.insert(enemies, player:get_index())
			goto continue
		end
		if player:is_dormant() then goto continue end

		local distance =  getDistance(localPlayer, player)

		if distance < 1000 then
			info.farTeammates = info.farTeammates + 1
		end

		if distance < 230 then
			info.nearbyTeammates = info.nearbyTeammates + 1
		end

		::continue::
	end

	if hitmanEnabled then
		if not settings.hitman:get() then
			hitmanEnabled = false
			target = nil
			resetTimer("hitman")
		end

		onTimerExpired("hitman", function()
			kill()
			hitmanEnabled = false
			target = nil
			resetTimer("hitman")
		end)
	end

	if math.random(1, 1000) == 1 and settings.tired:get() and not tired then
		tired = true
		setTimer("tired", math.random(30, 120) / 10)
	end

	if tired then
		if not timerExpired("tired") then
			cmd.forwardmove = clamp(cmd.forwardmove, -20, 20)
			cmd.sidemove =clamp(cmd.sidemove, -20, 20)
		else
			tired = false
		end
	end

	if math.random(1, 1200) == 1 and not hitmanEnabled and #enemies > 0 and settings.hitman:get() then
		-- add text to screen saying whos target
		local randomEnemy = enemies[math.random(1, #enemies)]
		hitmanEnabled = true
		setTimer("hitman", 40)
		target = randomEnemy
	end

	if settings.corona:get() then
		if info.nearbyTeammates >= 2 then
			if timerRunning("corona") then
				onTimerExpired("corona", kill)
			else
				setTimer("corona", 1.5)
			end
		else
			resetTimer("corona")
		end
	end

	if settings.paranoid:get() then
		if info.farTeammates == 0 then
			if timerRunning("paranoid") then
				onTimerExpired("paranoid", kill)
			else
				setTimer("paranoid", 5)
			end
		else
			resetTimer("paranoid")
		end
	end
end)

local font = render.create_font("hitman_font", 30, 600, 0)
if not font then return end
callbacks.register("paint", function()
	if hitmanEnabled then
		local targetEntity = entity_list.get_client_entity(target)
		if targetEntity and targetEntity:is_valid() then
			local screenSize = { render.get_screen_size() }
			local text = string.format("YOU HAVE %.2f SECOND(S) LEFT TO ELIMINATE %s", timers["hitman"].left, targetEntity:get_name())
			local pos = { (screenSize[1] / 2) - (render.get_text_size(font, text) / 2), screenSize[2] / 3.5 }

			render.text(pos, color(255, 0, 0), font, text)
		end
	end
end)
