local mq = require('mq')
local DEBUG = false
local my_class = mq.TLO.Me.Class.ShortName()
local Ready = false
local command = 0
local my_name = mq.TLO.Me.CleanName()
local zone_name = mq.TLO.Zone.ShortName()
local CampY = 450
local CampX = 110
local CampZ = 1156

local function WaitForNav()
	-- if DEBUG then print('Starting WaitForNav()...') end
	while mq.TLO.Navigation.Active() == false do
		mq.delay(10)
	end
	while mq.TLO.Navigation.Active() == true do
		mq.delay(10)
	end
	-- if DEBUG then print('Exiting WaitForNav()...') end
end

local function checkGroupStats()
	Ready = true
	local groupSize = mq.TLO.Group()
   
    for i = groupSize, 0, -1 do
		if DEBUG and ( mq.TLO.Group.Member(i).PctHPs() < 99 or  mq.TLO.Group.Member(i).PctEndurance() < 99 or (mq.TLO.Group.Member(i).PctMana() ~= 0 and  mq.TLO.Group.Member(i).PctMana() < 99)) then 
			printf('%s : %s : %s : %s', mq.TLO.Group.Member(i).CleanName(), mq.TLO.Group.Member(i).PctHPs(), mq.TLO.Group.Member(i).PctEndurance(), mq.TLO.Group.Member(i).PctMana() )
		end
		if mq.TLO.Group.Member(i).PctHPs() < 99 then Ready = false end
		if mq.TLO.Group.Member(i).PctEndurance() < 99 then Ready = false end
		if mq.TLO.Group.Member(i).PctMana() ~= 0 and mq.TLO.Group.Member(i).PctMana() < 99 then Ready = false end
    end
	-- mq.delay(5000)
end

if zone_name ~= 'gildedspire_missionone' then 
	print('You are not in the mission...')
	os.exit()
end

if my_class ~= 'WAR' and my_class ~= 'SHD' and my_class ~= 'PAL' then 
	print('You must run the script on a tank class...')
	os.exit()
end

-- Uninvis and unpause to go ahead and do some buffing
mq.cmd('/dgga /boxr unpause')
mq.cmd('/dgga /makemevis')
print('Un-Invising and Un-Pausing for buffs to be done')
mq.delay(10000)

-- Check group mana / endurance / hp
while Ready == false do 
	checkGroupStats()
	mq.cmd('/noparse /dgga /if (${Me.Standing}) /sit')
	mq.delay(5000)
end

-- mq.cmd('/dgga /nav locyxz 336 90 1156.79')
if math.abs(mq.TLO.Me.Y() - 397) > 60 or math.abs(mq.TLO.Me.X() - 109) > 60 then
	mq.cmd('/dgga /nav locyxz 397 109 1156')
	WaitForNav()
end

print('Doing some setup.')

-- mq.cmd('/dgga /lua run xpprep')
mq.delay(2000)
mq.cmd('/cwtn mode 2 nosave')
mq.cmdf('/%s mode 0 nosave', my_class)
mq.cmdf('/%s mode 7 nosave', my_class)
mq.cmdf('/%s pause off', my_class)
mq.cmd('/dgga /makemevis')
mq.cmdf('/%s checkprioritytarget off nosave', my_class)
mq.cmdf('/%s resetcamp', my_class)


print('Starting the event in 10 seconds!')

mq.delay(10000)

-- Move to trigger mobs
mq.cmd('/dgga /nav locyxz 565 235 1156')
WaitForNav()

mq.cmd('/tar soldier')
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

mq.cmd('/nav spawn Usira')
mq.cmd('/tar usira')
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
	mq.cmdf('/%s Mode manual nosave', mq.TLO.Me.Class.ShortName() )
	-- if DEBUG then print('StopAttack branch...') end
	if mq.TLO.Target.CleanName() ~= my_name then mq.cmdf('/target %s', my_name) end
end

while true do
	mq.doevents()
	
	if command == 1 then
        break
	end

	if mq.TLO.SpawnCount('_chest')() == 1 then
		print('I see the chest! You won!')
		break
	end		

	if mq.TLO.SpawnCount('Usira')() > 0  and math.floor(mq.TLO.Spawn('Usira').PctHPs() or 0) >= 50 and math.floor(mq.TLO.Spawn('Usira').PctHPs() or 0) <= 75 then
		if DEBUG then print('Usira Attack during Tilt Phase branch...') end
		if mq.TLO.Target.CleanName() ~= mq.TLO.Spawn('Usira').CleanName() then mq.cmd('/target Usira') end
		mq.cmdf('/%s Mode sictank nosave', mq.TLO.Me.Class.ShortName() )
		mq.delay(100)
		mq.cmd('/attack on')
		-- Keep attacking for 5 seconds before checking again
		mq.delay(5000)
	elseif mq.TLO.SpawnCount('Usira')() > 0  and math.floor(mq.TLO.Spawn('Usira').PctHPs() or 0) <= 7 and mq.TLO.SpawnCount('gilded guardian') == 0 then
		if DEBUG then print('Usira Attack during Tilt Phase branch...') end
		if mq.TLO.Target.CleanName() ~= mq.TLO.Spawn('Usira').CleanName() then mq.cmd('/target Usira') end
		mq.cmdf('/%s Mode sictank nosave', mq.TLO.Me.Class.ShortName() )
		mq.delay(100)
		mq.cmd('/attack on')
		-- Keep attacking for 5 seconds before checking again
		mq.delay(5000)
	else
		if mq.TLO.SpawnCount('a gilded guardian')() + mq.TLO.SpawnCount('thrall')() +  mq.TLO.SpawnCount('manipulator')() > 0 then 
			if DEBUG then print('In AddsUp section') end
			if mq.TLO.Target.CleanName() ~= my_name and mq.TLO.Target.CleanName() ~= mq.TLO.Spawn('Usira').CleanName() then 
				-- We are already targeting and attacking a target, so let's get it dead before switchign targets
				mq.cmd('/face')
				mq.cmd('/attack on')
			elseif mq.TLO.SpawnCount('thrall radius 60')() > 0 then 
				if DEBUG then print('Thrall Attack branch...') end
				if mq.TLO.Target.CleanName() ~= mq.TLO.Spawn('thrall').CleanName() then mq.cmd('/target thrall') end
				mq.delay(100)
				mq.cmd('/face')
				mq.cmd('/attack on')
			elseif mq.TLO.SpawnCount('a gilded guardian radius 60')() > 0 then 
				-- if DEBUG then print('Guardian Attack branch...') end
				if mq.TLO.Target.CleanName() ~= mq.TLO.Spawn('gilded guardian').CleanName() then mq.cmd('/target gilded guardian') end
				mq.delay(100)
				mq.cmd('/face')
				mq.cmd('/attack on')
			elseif mq.TLO.SpawnCount('manipulator radius 60')() > 0 then 
				if DEBUG then print('Manipulator Attack branch...') end
				if mq.TLO.Target.CleanName() ~= mq.TLO.Spawn('manipulator').CleanName()  then mq.cmd('/target manipulator') end
				mq.delay(100)
				mq.cmd('/face')
				mq.cmd('/attack on')
			else  
				StopAttack()
			end
		else
			if DEBUG then print('Usira Attack branch...') end
			if mq.TLO.Target.CleanName() ~= mq.TLO.Spawn('Usira').CleanName() then mq.cmd('/target Usira') end
			mq.cmdf('/%s Mode sictank nosave', mq.TLO.Me.Class.ShortName() )
			mq.delay(100)
			mq.cmd('/face')
			mq.cmd('/attack on')
		end
	end
	
	-- move to the location that seems best for mob aggro and avoiding the neural orb, but only if we are more than 60 ft away
	-- All other toons are on chase mode
	-- a neural spark - North camp = 450 110 South Camp = 330 70
	if mq.TLO.SpawnCount('a neural spark')() > 0 then 
		local sparkLocX = mq.TLO.Spawn('a neural spark').X()
		local sparkLocY = mq.TLO.Spawn('a neural spark').Y()
		if sparkLocY < 450 then 
			CampY = 450
			CampX = 110
			CampZ = 1156
		else 
			CampY = 330
			CampX = 70
			CampZ = 1156
		end
	else 
		CampY = 450
		CampX = 110
		CampZ = 1156
	end

	if math.abs(mq.TLO.Me.Y() - CampY) > 60 or math.abs(mq.TLO.Me.X() - CampX) > 60 then
		if math.random(1000) > 500 then
			mq.cmdf('/dgza /nav locyxz %s %s %s log=off', CampY, CampX, CampZ)
			mq.cmdf('/dgza /timed 5 /nav locyxz %s %s %s log=off', CampY, CampX, CampZ)
			mq.cmdf('/dgza /timed 5 /nav locyxz %s %s %s log=off', CampY, CampX, CampZ)
			mq.cmdf('/dgza /timed 10 /nav locyxz %s %s %s log=off', CampY, CampX, CampZ)
			mq.cmdf('/dgza /timed 15 /nav locyxz %s %s %s log=off', CampY, CampX, CampZ)
			mq.cmdf('/dgza /timed 20 /nav locyxz %s %s %s log=off', CampY, CampX, CampZ)
			mq.cmd('/attack off')
			mq.cmd('/face')
			mq.delay(1000)
		end
	end

	mq.delay(100)
end

mq.unevent('Zoned')
mq.unevent('Failed')
print('...Ended')