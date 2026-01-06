local mq = require('mq')
-- local logger = require('utils.logger')
local config_path = ''

local function file_exists(name)
	local f = io.open(name, "r")
	if f ~= nil then io.close(f) return true else return false end
end

Load_settings = function()
    local config_dir = mq.configDir:gsub('\\', '/') .. '/'
    local config_file = string.format('mission_tobcontrolroom_%s.ini', mq.TLO.Me.CleanName())
    config_path = config_dir .. config_file
    if (file_exists(config_path) == false) then
        LIP.save(config_path, settings)
	else
        Settings = LIP.load(config_path)

        -- Version updates
        local is_dirty = false
        if (Settings.general.GroupMessage == nil) then
            Settings.general.GroupMessage = 'dannet'
            is_dirty = true
        end
		if (Settings.general.BurnTiltPhase == nil) then
            Settings.general.BurnTiltPhase = true
            is_dirty = true
        end
        if (Settings.general.PreManaCheck == nil) then
            Settings.general.PreManaCheck = false
            is_dirty = true
        end
		if (Settings.general.OpenChest == nil) then
            Settings.general.OpenChest = false
            is_dirty = true
        end
        if (Settings.general.Automation == nil) then
            Settings.general.Automation = 'CWTN'
            is_dirty = true
        end

        if (is_dirty) then LIP.save(config_path, settings) end
   end
 end