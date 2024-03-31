---@alias AAConfig table<number, table<number|string|boolean|table<any, any>>>
---@alias DatabaseData table

local currentConfig = ""
local database_utils = require("database_utils")
local oldDropdownSelected

local settings = {
	title = ui.add_label("AA+ by dailybot & zundae"),
	-- presets = ui.add_dropdown("Presets", {"Daily's Legit AA", "Daily's Rage AA"}),
	configs = ui.add_dropdown("Configs", {""}),
	configUpdate = ui.add_button("Update Config"),
	configName = ui.add_textbox("Config Name", "My Config"),
	configSave = ui.add_button("Save Config"),
	configDelete = ui.add_button("Delete Config"),
	exportTextBox = ui.add_textbox("Export", "Shareable config will be shown here"),
	exportButton = ui.add_button("Export loaded config"),
	importTextBox = ui.add_textbox("Import Textbox", "Paste config here"),
	importButton = ui.add_button("Import"),
	resetTextboxes = ui.add_button("Clear Textboxes")
}

local antiaimConfiguration = {
	{0, { 'Active On Threat' }},
	{0, { 'Activate On' }},
	{0, { 'Resolver' }},
	{0, { 'Avoid Overlap' }},
	{0, { 'Style' }},
	{0, { 'At Targets' }},
	{0, { 'Pitch' }},
	{0, { 'Real' }},
	{0, { 'Real', 'Yaw Offset' }},
	{0, { 'Real', 'Spin Speed' }},
	{0, { 'Real', 'Auto Direction' }},
	{1,  { 'Real', 'Settings' }},
	{0, { 'Real', 'Jitter' }},
	{0, { 'Real', 'Jitter Type' }},
	{0, { 'Real', 'Jitter Amount' }},
	{0, { 'Real', 'Spin' }},
	{0, { 'Real', 'Rotation Amount' }},
	{0, { 'Real', 'Rotation Speed' }},
	{0, { 'Fake' }},
	{0, { 'Fake', 'Yaw Offset' }},
	{0, { 'Fake', 'Spin Speed' }},
	{0, { 'Fake', 'Jitter' }},
	{0, { 'Fake', 'Jitter Type' }},
	{0, { 'Fake', 'Jitter Amount' }},
	{0, { 'Fake', 'Spin' }},
	{0, { 'Fake', 'Rotation Amount' }},
	{0, { 'Fake', 'Rotation Speed' }},
	{0, { 'Anti Backstab' }},
	{0, { 'Force Turn' }},
	{0, { 'Factor' }},
	{0, { 'Speed' }},
	{0, { 'Shift' }},
	{0, { 'Await' }},
	{0, { 'Shift Factor' }},
	{0, { 'Manual Direction' }},
	{1,  { 'Ignore' }},
	--{2, { 'Left hotkey' }},
	--{2, { 'Right hotkey' }},
	{0, { 'Retry' }},
	{0, { 'Retry Value' }},
}

local dropdownOptions = {
	[12] = {"Ignore Modifiers", "Ignore Distortion", "Prefer Edge"},
	[36] = {"Distortion", "Jitter", "Spin"},
}

---Retrives a setting
---@param index number
---@return ui_menuitem uiElement
local function getUIElement(index)
	local setting = antiaimConfiguration[index]
	return ui.get('Misc', 'Rage', 'Pay2Win Angles', unpack(setting[2]))
end

---@param data JSONObject
---@return JSONObject data
local function fix_indices(data)
	local fixed = {}

	for index, value in pairs(data) do
		value = type(value) == "table" and fix_indices(value) or value
		local isNumber = tonumber(index) ~= nil

		if isNumber then
			fixed[tonumber(index) + 1] = value
			goto continue
		end

		fixed[index] = value

		::continue::
	end

	return fixed
end

---Create an anti-aim config using the anti-aim settings in the cheat ui
local function fromSettings()
	local antiaimSettings = {}

	for _, setting in ipairs(antiaimConfiguration) do
		local settingType, path = setting[1], setting[2]
		local uiElement = ui.get('Misc', 'Rage', 'Pay2Win Angles', unpack(path))

		if settingType == 0 then
			table.insert(antiaimSettings, #antiaimSettings + 1, uiElement:get())
		elseif settingType == 1 then
			table.insert(antiaimSettings, #antiaimSettings + 1, uiElement:get_all())
		elseif settingType == 2 then
			table.insert(antiaimSettings, #antiaimSettings + 1, {uiElement:get()})
		end
	end

	return antiaimSettings
end

---Applies config
---@param antiaimSettings AAConfig
local function applySettings(antiaimSettings)
	for index, data in pairs(antiaimSettings) do
		local settingType = antiaimConfiguration[index][1]
		local uiElement = getUIElement(index)

		if settingType == 0 then
			local data = type(data) == "string" and tonumber(data) or data

			uiElement:set(data)
		elseif settingType == 1 then
			for dropdownIndex, active in pairs(data) do
				local option = dropdownOptions[index][dropdownIndex]
				uiElement:set(option, active)
			end
		elseif settingType == 2 then
			uiElement:set_cond(data[2]) -- no work
		end
	end
end

---Export an anti-aim config to a string of text that can be imported
---@param configName string
local function exportConfig(configName, antiaimSettings)
	antiaimSettings[0] = configName
	return (json.stringify(antiaimSettings):gsub("\n", ""):gsub("%s+", ""))
end

---Import an anti-aim config from a string of text
---@param configString string
---@return AAConfig|nil config, string|nil name
local function importConfig(configString)
	local antiaimSettings = json.parse(configString)
	if not antiaimSettings then return nil end

	antiaimSettings = fix_indices(antiaimSettings) --[[@as AAConfig]]

	local name = table.remove(antiaimSettings, 1)
	if not name then return nil, nil end

	return antiaimSettings, name
end

local prefix = "v1-aap-config-"

if not database_utils.exists(prefix .. "list") then
	local function addPreset(presetName, presetSettings)
		presetSettings = json.parse(presetSettings)
		if not presetSettings then return nil end

		presetSettings = fix_indices(presetSettings) --[[@as AAConfig]]

		if not database_utils.save(prefix .. presetName, presetSettings, false) then
			return
		end
	
		database_utils.update(prefix .. "list", function(data)
			table.insert(data, presetName)
			return data
		end)
	end

	addPreset("Daily's Rage AA", '[false,1.0,true,true,0.0,false,5.0,1.0,0.0,0.0,false,[false,false,true],true,3.0,56.0,false,30.0,20.0,5.0,0.0,25.0,false,3.0,-18.0,false,0.0,1.0,true,true,27.805,35.826,true,2.0,24.597,true,[false,false,true],false,0.0]')
	addPreset("Daily's Legit AA", '[false,1.0,true,false,0.0,false,0.0,4.0,0.0,0.0,false,[false,false,true],false,3.0,56.0,false,30.0,20.0,2.0,0.0,25.0,false,3.0,-18.0,false,0.0,1.0,true,true,27.805,35.826,true,2.0,24.597,true,[true,true,true],false,0.0]')

	database_utils.save(prefix .. "list", {"", "Daily's Rage AA", "Daily's Legit AA"})
end

local function refreshConfigs()
	local got, savedConfigs = database_utils.load(prefix .. "list", false)
	if not got or not savedConfigs then return end

	local emptyIndex, foundAnotherConfig, needsRemoval = nil, nil, {}

	for i, v in pairs(savedConfigs) do
		if foundAnotherConfig and emptyIndex then break end

		if v == "" then
			emptyIndex = i
		else
			local got, dbConfig = database_utils.load(prefix .. v, false)

			if not got or not dbConfig then
				needsRemoval[v] = true
				goto continue
			end

			foundAnotherConfig = true
		end
		
	    ::continue::
	end

	if #needsRemoval > 0 then
		database_utils.update(prefix .. "list", function(data)
			local new = {}

			for _, value in pairs(data) do
				if needsRemoval[value] then
					goto continue
				end

				table.insert(new, value)

				::continue::
			end

			return new
		end)
	end

	if type(emptyIndex) == "number" and foundAnotherConfig then
		table.remove(savedConfigs, emptyIndex)
	end

	settings.configs:update_items(savedConfigs)
end

local function changeConfig(index)
	local got, savedConfigs = database_utils.load(prefix .. "list", false)
	if not got or not savedConfigs then return end

	local configName = savedConfigs[index + 1] --[[@as string]]
	if not configName or not (database_utils.load(prefix .. configName)) then return end

	currentConfig = configName

	local _, configSettings = database_utils.load(prefix .. configName) --[[@as AAConfig]]
	applySettings(configSettings)
end

refreshConfigs()

settings.configSave:add_callback(function()
	local configName = settings.configName:get()
	if configName == "" or database_utils.exists(prefix .. configName) then
		return
	end

	if not database_utils.save(prefix .. configName, fromSettings(), false) then
		return
	end

	if not database_utils.update(prefix .. "list", function(data)
		table.insert(data, configName)
		return data
	end) then return end

	refreshConfigs()
	settings.configName:set("")
end)

settings.configDelete:add_callback(function()
	local configName = settings.configName:get()
	if configName == "" or not database_utils.exists(prefix .. configName) then
		return
	end

	if not database_utils.delete(prefix .. configName) then
		return
	end

	refreshConfigs()
	settings.configName:set("")
end)

settings.configUpdate:add_callback(function()
	if currentConfig == "" or not database_utils.exists(prefix .. currentConfig) then
		return
	end

	database_utils.update(prefix.. currentConfig, function(_)
		return fromSettings()
	end)
end)

settings.exportButton:add_callback(function()
	if currentConfig == "" then return end

	if not currentConfig or not (database_utils.load(prefix .. currentConfig)) then return end
	local _, configSettings = database_utils.load(prefix .. currentConfig) --[[@as AAConfig]]

	local configString = exportConfig(currentConfig, configSettings)
	if not configString then return end

	settings.exportTextBox:set(configString)
end)

settings.importButton:add_callback(function()
	local importText = settings.importTextBox:get()
	if importText == "" then return end

	local config, name = importConfig(importText)
	if not config or not name then return end
	
	if not database_utils.save(prefix .. name, config, false) then
		return
	end

	if not database_utils.update(prefix .. "list", function(data)
		table.insert(data, name)
		return data
	end) then return end

	refreshConfigs()

	settings.importTextBox:set("")
end)

settings.resetTextboxes:add_callback(function()
	settings.exportTextBox:set("")
	settings.importTextBox:set("")
end)

callbacks.register("paint", function()
	local dropdownSelected = settings.configs:get()
	if oldDropdownSelected == nil then
		oldDropdownSelected = dropdownSelected
	end

	if dropdownSelected ~= oldDropdownSelected then
		oldDropdownSelected = dropdownSelected
		changeConfig(dropdownSelected + 1)
	end
end)
