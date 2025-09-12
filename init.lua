-- Mission_TOBControlRoom
-- Version 1.1
-- TODO: Overpull section to position named closer to where we actually want him
-- TODO: implement tilt phase switch - still having issues with this implementation not working correctly, so this may not get done
-- DONE: Close task window after getting the mission
-- DONE: if named <= 5% and no gilded guardians are up, concentrate on killing the named
-- TODO: Change the spark movement section to only move me if the spark is on the left half of the room, where it can actally be a problem
-- TODO: 
---------------------------
local mq = require('mq')
local lip = require('lib.LIP')
local logger = require('utils.logger')

local DEBUG = false
logger.set_log_level(4) -- 4 = Info level, use 5 for debug, and 6 for trace
local command = 0
local Ready = false
local my_class = mq.TLO.Me.Class.ShortName()
local my_name = mq.TLO.Me.CleanName()
local zone_name = mq.TLO.Zone.ShortName()
local request_zone = 'aureatecovert'
local request_npc = 'Lokta'
local request_phrase = 'warlord'
local zonein_phrase = 'ready'
local quest_zone = 'gildedspire_missionone'
local task_name = 'Control Room'
local delay_before_zoning = 27000  -- 27s
local config_path = ''

local CampY = 450
local CampX = 110
local CampZ = 1156

local task = mq.TLO.Task(task_name)
local settings = {
    general = {
        GroupMessage = "dannet", -- or "bc"
		BurnTiltPhase = true,
        PreManaCheck = false,       -- true to pause until the check for everyone's mana, endurance, hp is full before proceeding, false if it stalls at that point
        OpenChest = false,
        Automation = "CWTN",        -- or "RGMercs" - not yet implemented
    }
}

-- #region Functions
local function file_exists(name)
	local f = io.open(name, "r")
	if f ~= nil then io.close(f) return true else return false end
end

local function load_settings()
    local config_dir = mq.configDir:gsub('\\', '/') .. '/'
    local config_file = string.format('mission_tobcontrolroom_%s.ini', mq.TLO.Me.CleanName())
    config_path = config_dir .. config_file
    if (file_exists(config_path) == false) then
        lip.save(config_path, settings)
	else
        settings = lip.load(config_path)

        -- Version updates
        local is_dirty = false
        if (settings.general.GroupMessage == nil) then
            settings.general.GroupMessage = 'dannet'
            is_dirty = true
        end
		if (settings.general.BurnTiltPhase == nil) then
            settings.general.BurnTiltPhase = true
            is_dirty = true
        end
        if (settings.general.PreManaCheck == nil) then
            settings.general.PreManaCheck = false
            is_dirty = true
        end
		if (settings.general.OpenChest == nil) then
            settings.general.OpenChest = false
            is_dirty = true
        end
        if (settings.general.Automation == nil) then
            settings.general.Automation = 'CWTN'
            is_dirty = true
        end

        if (is_dirty) then lip.save(config_path, settings) end
   end
 end

local function MoveToSpawn(spawn, distance)
    if (distance == nil) then distance = 5 end

    if (spawn == nil or spawn.ID() == nil) then return end
    if (spawn.Distance() < distance) then return true end

    mq.cmdf('/squelch /nav id %d npc |dist=%s log=off', spawn.ID(), distance)
    mq.delay(10)
    while mq.TLO.Nav.Active() do mq.delay(10) end
    mq.delay(500)
    return true
end

local function MoveTo(spawn_name, distance)
    local spawn = mq.TLO.Spawn('npc '..spawn_name)
    return MoveToSpawn(spawn, distance)
end

local function MoveToId(spawn_id, distance)
    local spawn = mq.TLO.Spawn('npc id '..spawn_id)
    return MoveToSpawn(spawn, distance)
end

local function MoveToAndTarget(spawn)
    if MoveTo(spawn, 15) == false then return false end
    mq.cmdf('/squelch /mqtarget %s', spawn)
    mq.delay(250)
    return true
end

local function MoveToAndAct(spawn,cmd)
    if MoveToAndTarget(spawn) == false then return false end
    mq.cmd(cmd)
    return true
end

local function MoveToAndSay(spawn,say) return MoveToAndAct(spawn, string.format('/say %s', say)) end

local function query(peer, query, timeout)
    mq.cmdf('/dquery %s -q "%s"', peer, query)
    mq.delay(timeout)
    local value = mq.TLO.DanNet(peer).Q(query)()
    return value
end

local function tell(delay,gm,aa) 
    local z = mq.cmdf('/timed %s /dex %s /multiline ; /stopcast; /timed 1 /alt act %s', delay, mq.TLO.Group.Member(gm).Name(), aa)
    return z
end

local function classShortName(x)
    local y = mq.TLO.Group.Member(x).Class.ShortName()
    return y
end

local function all_double_invis()
    
    local dbl_invis_status = false
    local grpsize = mq.TLO.Group.Members()

    for gm = 0,grpsize do
        local name = mq.TLO.Group.Member(gm).Name()
        local result1 = query(name, 'Me.Invis[1]', 100) 
        local result2 = query(name, 'Me.Invis[2]', 100)
        local both_result = false
        
        if result1 == 'TRUE' and result2 == 'TRUE' then
            both_result = true
            -- logger.debug("\ay%s \at%s \ag%s", name, "DBL Invis: ", both_result)
        else
            -- logger.debug('gm'..gm)
            break
        end

        if gm == grpsize then
            dbl_invis_status = true
        end
    end
    return dbl_invis_status
end

local function the_invis_thing()
    --if i am bard or group has bard, do the bard invis thing
    if mq.TLO.Spawn('Group Bard').ID()>0 then
        local bard = mq.TLO.Spawn('Group Bard').Name()
        if bard == mq.TLO.Me.Name() then
                -- I am a bard, cast 'Selos Sonata' then 'Shaun's Sonorous Clouding'
                mq.cmd('/mutliline ; /stopsong; /timed 1 /alt act 3704; /timed 3 /alt act 231') 
            else
                -- Telling the bard to cast 'Selos Sonata' then 'Shaun's Sonorous Clouding'
                mq.cmdf('/dex %s /multiline ; /stopsong; /timed 1 /alt act 3704; /timed 3 /alt act 231', bard)
        end
        logger.info('\ag-->\atINVer: \ay%s\at IVUer: \ay%s\ag<--', bard, bard)
    else
    --without a bard, find who can invis and who can IVU
        local inver = 0
        local ivuer = 0
        local grpsize = mq.TLO.Group.Members()
        
            --check classes that can INVIS only
        for i=0,grpsize do
            if string.find("RNG DRU SHM", classShortName(i)) ~= nil then
                inver = i
                break
            end
        end

        --check classes that can IVU only
        for i=0,grpsize do
            if string.find("CLR NEC PAL SHD", classShortName(i)) ~= nil then
                ivuer = i
                break
            end
        end
        
        --check classes that can do BOTH
        if inver == 0 then
            for i=0,grpsize do
                if string.find("ENC MAG WIZ", classShortName(i)) ~= nil then
                    inver = i
                    break

                end    
            end
        end

        if ivuer == 0 then
            for i=grpsize,0,-1 do
                if string.find("ENC MAG WIZ", classShortName(i)) ~= nil then
                    ivuer = i
                    if i == inver then
                        logger.info('\arUnable to Double Invis')
                        mq.exit()  
                    end
                break
                end
            end
        end 

        --catch anyone else in group
        if string.find("WAR MNK ROG BER", classShortName(inver)) ~= nil or string.find("WAR MNK ROG BER", classShortName(ivuer)) ~= nil then
            logger.info('\arUnable to Double Invis')
            mq.exit()
        end

        logger.info('\ag-->\atINVer: \ay',mq.TLO.Group.Member(inver).Name(), '\at IVUer: \ay', mq.TLO.Group.Member(ivuer).Name(),'\ag<--')
        
        --if i am group leader and can INVIS, then do the INVIS thing
        if classShortName(inver) == 'SHM' and inver == 0 then
                mq.cmd('/multiline ; /stopcast; /timed 3 /alt act 630')
            elseif string.find("ENC MAG WIZ", classShortName(inver)) ~= nil then
                mq.cmd('/multiline ; /stopcast; /timed 1 /alt act 1210')
            elseif string.find("RNG DRU", classShortName(inver)) ~= nil then
                mq.cmd('/multiline ; /stopcast; /timed 1 /alt act 518')
        end

        --if i have an INVISER in the group, then 'tell them' do the INVIS thing
        if classShortName(inver) == 'SHM' and inver ~= 0 then
                tell(4,inver,630)
            elseif string.find("ENC MAG WIZ", classShortName(inver)) ~= nil then
                tell(0,inver,1210)
            elseif string.find("RNG DRU", classShortName(inver)) ~= nil then
                tell(5,inver,518)
        end
        
        --if i am group leader and can IVU, then do the IVU thing
        if string.find("CLR NEC PAL SHD", classShortName(ivuer)) ~= nil and ivuer == 0 then
                mq.cmd('/multiline ; /stopcast; /timed 1 /alt activate 1212')
            else
                mq.cmd('/multiline ; /stopcast; /timed 1 /alt activate 280')
        end
        
        --if i have an IVUER in the group, then 'tell them' do the IVU thing
        if string.find("CLR NEC PAL SHD", classShortName(ivuer)) ~= nil and ivuer ~= 0 then
                tell(2,ivuer,1212)    
            else
                tell(2,ivuer,280)
        end
    end
    mq.delay(8000)
end

local function DBLinvis()
    while not all_double_invis() do
        the_invis_thing()
        mq.delay(5000)
    end
end

local function WaitForNav()
    logger.debug('Starting WaitForNav()...')
	while mq.TLO.Navigation.Active() == false do
		mq.delay(10)
	end
	while mq.TLO.Navigation.Active() == true do
		mq.delay(10)
	end
    logger.debug('Exiting WaitForNav()...')
end

local function checkGroupStats()
    if (settings.general.PreManaCheck == false) then return end
	Ready = false
	local groupSize = mq.TLO.Group()
    local firstMsg = true

    while Ready ~= true do
        Ready = true
        for i = groupSize, 0, -1 do
            if mq.TLO.Group.Member(i).PctHPs() < 99 then Ready = false end
            if mq.TLO.Group.Member(i).PctEndurance() < 99 then Ready = false end
            if mq.TLO.Group.Member(i).PctMana() ~= 0 and mq.TLO.Group.Member(i).PctMana() < 99 then Ready = false end
        end

       	if Ready == false then 
            -- Only show the message the first time it runs through this routine
            if firstMsg then 
                logger.info('Group not fully ready.  Sitting to regen...')
                firstMsg = false
            end
            mq.cmd('/noparse /dgga /if (${Me.Standing}) /sit')
            mq.delay(5000)
    	end
    end
end

--- Gets the name of a group member, even if they are out of zone
---@param index integer
---@return string|nil
local function getGroupMemberName(index)
    local member = mq.TLO.Group.Member(index)
    if not member() then return nil end
    local name = member.Name()
    if name and name:len() > 0 then
        return name
    end
    return nil
end

--- Returns a table of group members not in the zone
---@return string[]
local function getGroupMembersNotInZone()
    local missing = {}
    for i = 1, mq.TLO.Me.GroupSize() do
        local name = getGroupMemberName(i)
        if name and not mq.TLO.Spawn("pc = " .. name)() then
            table.insert(missing, name)
        end
    end
    return missing
end


local function ZoneIn(npcName, zoneInPhrase, quest_zone)
    local GroupSize = mq.TLO.Group.Members()

    for g = 1, GroupSize, 1 do
        local Member = mq.TLO.Group.Member(g).Name()
        logger.info('\ay-->%s<--\apShould Be Zoning In Now', Member)
        mq.cmdf('/dex %s /mqtarget %s', Member, npcName)
        mq.delay(2000) -- Add a random delay ?
        mq.cmdf('/dex %s /say %s', Member, zoneInPhrase)
    end

    -- This is to make us the last to zone in
    while mq.TLO.Group.AnyoneMissing() == false do
        mq.delay(2000)
    end
    if mq.TLO.Target.CleanName() ~= npcName then
        mq.cmdf('/mqtarget %s', npcName)
        mq.delay(5000)
        mq.cmdf('/say %s', zoneInPhrase)
    else
        mq.delay(5000)
        mq.cmdf('/say %s', zoneInPhrase)
    end
    local counter = 0
    while mq.TLO.Zone.ShortName() ~= quest_zone do 
        counter = counter + 1
        if counter >= 10 then 
            logger.info('Not able to zone into the %s. Look at the issue and fix it please.', quest_zone)
            os.exit()
        end
        mq.delay(5000)
    end
    zone_name = mq.TLO.Zone.ShortName()
end

local function Task()
    if (task() == nil) then
        if (mq.TLO.Zone.ShortName() ~= request_zone) then
            logger.info('Not In %s to request task.  Move group to that zone and restart.', request_zone)
            os.exit()
        end

        MoveToAndSay(request_npc, request_phrase)

        for index=1, 5 do
            mq.delay(1000)
            mq.doevents()

            task = mq.TLO.Task(task_name)
            if (task() ~= nil) then break end

            if (index >= 5) then
                logger.info('Unable to get quest. Exiting.')
                os.exit()
            end
            logger.info('...waiting for quest.')
        end

        if (task() == nil) then
            logger.info('Unable to get quest. Exiting.')
            os.exit()
        end

        logger.info('\at Got quest.')
    end

    if (task() == nil) then
        logger.info('Problem requesting or getting task.  Exiting.')
        os.exit()
    end

    -- Close task windows on all group members
    mq.cmd('/timed 50 /dgga /squelch /windowstate TaskWnd close')
end

local function WaitForTask()
    local time_since_request = 21600000 - task.Timer()
    local time_to_wait = delay_before_zoning - time_since_request
    logger.debug('TimeSinceReq: \ag%d\ao  TimeToWait: \ag%d\ao', time_since_request, time_to_wait)
    if (time_to_wait > 0) then
        logger.info('\at Waiting for instance generation \aw(\ay%.f second(s)\aw)', time_to_wait / 1000)
        mq.delay(time_to_wait)
    end  
end

--- Gets the name of a group member, even if they are out of zone
---@param index integer
---@return string|nil
local function getGroupMemberName(index)
    local member = mq.TLO.Group.Member(index)
    if not member() then return nil end
    local name = member.Name()
    if name and name:len() > 0 then
        return name
    end
    return nil
end

--- Returns a table of group members not in the zone
---@return string[]
local function getGroupMembersNotInZone()
    local missing = {}
    for i = 1, mq.TLO.Me.GroupSize() do
        local name = getGroupMemberName(i)
        if name and not mq.TLO.Spawn("pc = " .. name)() then
            table.insert(missing, name)
        end
    end
    return missing
end

--- Wait until all group members are in zone, or timeout
---@param timeoutSec number
---@return boolean
local function waitForGroupToZone(timeoutSec)
    local start = os.time()
    while os.difftime(os.time(), start) < timeoutSec do
        local notInZone = getGroupMembersNotInZone()
        if #notInZone == 0 then
            logger.info("All group members are in zone.")
            return true
        end
        logger.info("Still waiting on: " .. table.concat(notInZone, ", "))
        mq.delay(5000)
    end
    logger.info("Timeout waiting for group members to zone.")
    return false
end

local function StartingSetup()
    mq.delay(2000)
    mq.cmd('/cwtn mode chase nosave')
    mq.cmdf('/%s mode manual nosave', my_class)
    mq.cmdf('/%s mode sictank nosave', my_class)
    mq.cmdf('/%s pause off', my_class)
    mq.cmd('/dgga /makemevis')
    mq.cmdf('/%s checkprioritytarget off nosave', my_class)
    mq.cmdf('/%s resetcamp', my_class)
end

local function ClearStartingSetup()
    mq.delay(2000)
    mq.cmd('/cwtn mode chase nosave')
    mq.cmdf('/%s mode sictank nosave', my_class)
    mq.cmdf('/%s pause off', my_class)
    mq.cmdf('/%s checkprioritytarget on nosave', my_class)
end


local function action_openChest()
    mq.cmd('/squelch /nav spawn _chest | log=off')
    while mq.TLO.Nav.Active() do mq.delay(5) end
    mq.cmd('/mqtarget _chest')
    mq.delay(250)
    mq.cmd('/open')
end

-- #endregion

-- #region MainCode

load_settings()

if (settings.general.GroupMessage == 'dannet') then
   logger.info('\aw Group Chat: \ayDanNet\aw.')
elseif (settings.general.GroupMessage == 'bc') then
   logger.info('\aw Group Chat: \ayBC\aw.')
else
   logger.info("Unknown or invalid group command.  Must be either 'dannet' or 'bc'. Ending script. \ar%s", settings.general.GroupMessage)
   return
end

logger.info('\aw Open Chest: \ay%s', settings.general.OpenChest)

if my_class ~= 'WAR' and my_class ~= 'SHD' and my_class ~= 'PAL' then 
	logger.info('You must run the script on a tank class...')
	os.exit()
end

if zone_name == request_zone then 
	if mq.TLO.Spawn(request_npc).Distance() > 40 then 
        logger.info('You are in %s, but too far away from %s to start the mission!  We will attempt to double-invis and run to the mission npc', request_zone, request_npc)
        DBLinvis()
        MoveToAndSay(request_npc, request_phrase)
    end
	Task()
    WaitForTask()    
    ZoneIn(request_npc, zonein_phrase, quest_zone)
    mq.delay(5000)
    waitForGroupToZone(60)
end

zone_name = mq.TLO.Zone.ShortName()

if zone_name ~= quest_zone then 
	logger.info('You are not in the mission...')
	os.exit()
end

-- Close task windows on all group members
mq.cmd('/timed 100 /dgga /squelch /windowstate TaskWnd close')

-- Uninvis and unpause to go ahead and do some buffing
mq.cmd('/dgga /squelch /boxr unpause')
mq.cmd('/dgga /makemevis')
logger.info('Un-Invising and Un-Pausing for buffs to be done')
mq.delay(10000)

-- Check group mana / endurance / hp
checkGroupStats()

-- mq.cmd('/dgga /nav locyxz 336 90 1156.79')
if math.abs(mq.TLO.Me.Y() - 397) > 60 or math.abs(mq.TLO.Me.X() - 109) > 60 then
	mq.cmd('/dgga /nav locyxz 397 109 1156 log=off')
	WaitForNav()
end

logger.info('Doing some setup.')
StartingSetup()

logger.info('Starting the event in 10 seconds!')

mq.delay(10000)

-- Move to trigger mobs
mq.cmd('/dgga /nav locyxz 565 235 1156 log=off')
WaitForNav()

mq.cmd('/squelch /tar soldier npc')
mq.delay(300)
mq.cmd('/say dead')

while mq.TLO.SpawnCount('a spire soldier')() > 0 do
	mq.delay(100)
	if mq.TLO.Me.XTarget(1).CleanName() == mq.TLO.Spawn('a spire soldier').CleanName() and not mq.TLO.Me.Combat() then
		mq.cmd('/xtar 1')
		mq.delay(300)
		mq.cmd('/attack on')
	end
end

mq.cmd('/squelch /nav spawn Usira | log=off')
mq.cmd('/squelch /mqtarget npc Usira')
mq.delay(300)
mq.cmd('/attack on')

while mq.TLO.SpawnCount('Usira xtarhater')() < 1 do
	mq.delay(100)
end

mq.delay(1000)
mq.cmd('/cwtna burnalways on nosave')

local event_zoned = function(line)
    -- zoned so quit
    command = 1
end

local event_failed = function(line)
    -- failed so quit
    command = 1
end

mq.event('Zoned','LOADING, PLEASE WAIT...#*#',event_zoned)
mq.event('Failed','#*#summons overwhelming enemies and your mission fails.#*#',event_failed)

local function StopAttack()
	mq.cmd('/attack off') 
	mq.cmd('/cwtna CheckPriorityTarget off nosave')
	mq.cmdf('/%s CheckPriorityTarget off nosave', mq.TLO.Me.Class.ShortName() )
	mq.cmdf('/%s Mode manual nosave', my_class )
    logger.debug('StopAttack branch...')
	if mq.TLO.Target.CleanName() ~= my_name then mq.cmdf('/mqtarget %s', my_name) end
end

while true do
	mq.doevents()
	
	if command == 1 then
        break
	end

	if mq.TLO.SpawnCount('_chest')() == 1 then
		logger.info('I see the chest! You won!')
		break
	end		

	if mq.TLO.SpawnCount('Usira')() > 0  and math.floor(mq.TLO.Spawn('Usira').PctHPs() or 0) >= 55 and math.floor(mq.TLO.Spawn('Usira').PctHPs() or 0) <= 70 then
		logger.debug('Usira Attack during Tilt Phase branch...')
		if mq.TLO.Target.CleanName() ~= mq.TLO.Spawn('Usira').CleanName() then mq.cmd('/squelch /mqtarget npc Usira') end
		mq.cmdf('/%s mode sictank nosave', my_class )
		mq.delay(100)
        mq.cmd('/squelch /face')
		mq.cmd('/squelch /attack on')
		-- Keep attacking for 5 seconds before checking again
		mq.delay(5000)
	elseif mq.TLO.SpawnCount('Usira')() > 0  and math.floor(mq.TLO.Spawn('Usira').PctHPs() or 0) <= 7 and mq.TLO.SpawnCount('gilded guardian')() == 0 then
		logger.debug('Usira Attack after all gilded guardians are dead branch...')
		if mq.TLO.Target.CleanName() ~= mq.TLO.Spawn('Usira').CleanName() then mq.cmd('/squelch /mqtarget npc Usira') end
		mq.cmdf('/%s mode sictank nosave', my_class )
		mq.delay(100)
		mq.cmd('/squelch /face')
		mq.cmd('/squelch /attack on')
		-- Keep attacking for 5 seconds before checking again
		mq.delay(5000)
	else
		if mq.TLO.SpawnCount('a gilded guardian')() + mq.TLO.SpawnCount('thrall')() +  mq.TLO.SpawnCount('manipulator')() > 0 then 
			logger.debug('In AddsUp section')
			if mq.TLO.Target.CleanName() ~= my_name and mq.TLO.Target.CleanName() ~= mq.TLO.Spawn('Usira').CleanName() then 
				-- We are already targeting and attacking a target, so let's get it dead before switching targets
				mq.cmd('/squelch /face')
				mq.cmd('/attack on')
			elseif mq.TLO.SpawnCount('thrall radius 60')() > 0 then 
				logger.debug('Thrall Attack branch...')
				if mq.TLO.Target.CleanName() ~= mq.TLO.Spawn('thrall').CleanName() then mq.cmd('/squelch /mqtarget npc thrall') end
				mq.delay(100)
				mq.cmd('/squelch /face')
				mq.cmd('/attack on')
			elseif mq.TLO.SpawnCount('a gilded guardian radius 60')() > 0 then 
				logger.debug('Guardian Attack branch...')
				if mq.TLO.Target.CleanName() ~= mq.TLO.Spawn('gilded guardian').CleanName() then mq.cmd('/squelch /mqtarget npc gilded guardian') end
				mq.delay(100)
				mq.cmd('/squelch /face')
				mq.cmd('/attack on')
			elseif mq.TLO.SpawnCount('manipulator radius 60')() > 0 then 
				logger.debug('Manipulator Attack branch...')
				if mq.TLO.Target.CleanName() ~= mq.TLO.Spawn('manipulator').CleanName()  then mq.cmd('/squelch /mqtarget npc manipulator') end
				mq.delay(100)
				mq.cmd('/squelch /face')
				mq.cmd('/attack on')
			else  
				StopAttack()
			end
		else
			logger.debug('Usira Attack branch...')
			if mq.TLO.Target.CleanName() ~= mq.TLO.Spawn('Usira').CleanName() then mq.cmd('/squelch /mptarget npc Usira') end
			mq.cmdf('/%s mode sictank nosave', my_class)
			mq.delay(100)
			mq.cmd('/squelch /face')
			mq.cmd('/attack on')
		end
	end
	
	-- move to the location that seems best for mob aggro and avoiding the neural orb, but only if we are more than 60 ft away
	-- All other toons are on chase mode
	-- a neural spark - North camp = 450 110 South Camp = 330 70
	if mq.TLO.SpawnCount('a neural spark')() > 0 then 
		local sparkLocX = mq.TLO.Spawn('a neural spark').X()
		local sparkLocY = mq.TLO.Spawn('a neural spark').Y()
        if sparkLocX > 0 then -- only move if the spark is on the left side of the room
            if sparkLocY < 450 then 
                CampY = 450
                CampX = 110
                CampZ = 1156
            else 
                CampY = 330
                CampX = 70
                CampZ = 1156
            end
        end
	else 
		CampY = 450
		CampX = 110
		CampZ = 1156
	end

	if math.abs(mq.TLO.Me.Y() - CampY) > 60 or math.abs(mq.TLO.Me.X() - CampX) > 60 then
		if math.random(1000) > 500 then
			mq.cmdf('/dgza /nav locyxz %s %s %s log=off', CampY, CampX, CampZ)
            WaitForNav()
			if mq.TLO.Target() then  mq.cmd('/squelch /face') end
			mq.delay(1000)
		end
	end

	mq.delay(100)
end
-- #endregion 

mq.unevent('Zoned')
mq.unevent('Failed')
ClearStartingSetup()
if (settings.general.OpenChest == true) then action_openChest() end

logger.info('...Ended')