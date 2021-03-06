PLUGIN.Name = "r-AntiCheat"
PLUGIN.Title = "r-AntiCheat"
PLUGIN.Version = V(0, 0, 15)
PLUGIN.Description = "Anti-Cheat system for Rust 2.0"
PLUGIN.Author = "Reneb"
PLUGIN.HasConfig = true
 
 

function PLUGIN:Init()
	--------------------------------------------------------------------
	-- Initialize the Plugin --
	--------------------------------------------------------------------
	
	PlayerCheck = {}
	mainTimers = {}
	AdminList = {}
	LastTick = time.GetUnixTimestamp()
	LastSave = time.GetUnixTimestamp()
	self:LoadSavedData()
	--------------------------------------------------------------------
	
	command.AddChatCommand( "ac_check", self.Object, "cmdCheck" )
	command.AddChatCommand( "ac_checkall", self.Object, "cmdCheckAll" )
	command.AddChatCommand( "ac_reset", self.Object, "cmdReset" )
	
	
	--------------------------------------------------------------------
	-- Debug Config --
	--------------------------------------------------------------------
	--self.Config = {}
	--self:LoadDefaultConfig()
	--------------------------------------------------------------------
	
	
end

function PLUGIN:OnServerInitialized()
	--------------------------------------------------------------------
	-- Get EBS --
	--------------------------------------------------------------------
	local pluginList = plugins.GetAll()
    for i = 0, pluginList.Length - 1 do
        local pluginTitle = pluginList[i].Object.Title
        if pluginTitle == "Enhanced Ban System" then
            ebs = pluginList[i].Object
            break
        end
    end
    if(not ebs) then
    	print("You may not use r-AntiCheat without Enhanced Ban System.")
    	print("Install it first: http://forum.rustoxide.com/plugins/enhanced-ban-system.693/ ")
    	return false
    end
	--------------------------------------------------------------------
	
	self:checkAllPlayers()
end
--------------------------------------------------------------------
-- Local Functions --
--------------------------------------------------------------------
function PLUGIN:resetTimers()
	for k,v in pairs(mainTimers) do
		if(v) then
			v:Destroy()
		end
	end  
end
local function logWarning(message)
	arrr =  util.TableToArray( { message } )
	util.ConvertAndSetOnArray(arrr, 0, message, UnityEngine.Object._type)
	UnityEngine.Debug.LogWarning.methodarray[0]:Invoke(nil, arrr)
end
local function Distance2D(p1, p2)
    return math.sqrt(math.pow(p1.x - p2.x,2) + math.pow(p1.z - p2.z,2)) 
end
local function DistanceY(p1, p2)
	if(p2.y > p1.y) then
		return math.sqrt(math.pow(p1.y - p2.y,2)) 
	else
		return -math.sqrt(math.pow(p1.y - p2.y,2)) 
	end
end
local function Distance3D(p1, p2)
    return math.sqrt(math.pow(p1.x - p2.x,2) + math.pow(p1.z - p2.z,2) + math.pow(p1.y - p2.y,2)) 
end
local function checkAllTimers()
	for player,v in pairs(mainTimers) do
		if(not player or player == nil) then
			if(v) then
				v:Destroy()
				v = false
			end
		elseif(not player:IsConnected()) then
			if(v) then
				v:Destroy()
				v = false
			end
		end
	end
end
local function RemovePlayerCheck(player)
	if(player == nil or not player) then checkAllTimers() return end
	if(not mainTimers[player]) then checkAllTimers() return end
	mainTimers[player]:Destroy()
	mainTimers[player] = nil
	PlayerCheck[player].jumpHack = nil
	PlayerCheck[player].speedHack = nil
	PlayerCheck[player].hitHack = nil
	PlayerCheck[player] = nil
end
local function RemoveFromAdminList(player)
	AdminList[player] = nil
end
local function canCheck(player)
	if(not player or player == nil) then checkAllTimers() return false end
	if(not player:IsConnected()) then RemovePlayerCheck(player) return false end
	if(not player:IsAlive()) then return false end
	if(player:IsSleeping()) then return false end
	if(PlayerData[rust.UserIDFromPlayer(player)].timeLeft < 2) then RemovePlayerCheck(player) return false end
	return true
end
local function replaceMessage(msg,player,height,speed,hits)
	msg = string.gsub(msg, "{player}", tostring(player.displayName) )
	if(tonumber(height) ~= nil) then
		msg = string.gsub(msg, "{height}", tostring(math.ceil(height*100)/100) )
	end
	if(tonumber(speed) ~= nil) then
		msg = string.gsub(msg, "{speed}", tostring(math.ceil(speed*100)/100) )
	end
	if(tonumber(hits) ~= nil) then
		msg = string.gsub(msg, "{hits}", tostring(math.ceil(hits*100)/100) )
	end
	return msg
end
local function hasAtLeastOneData(data)
	for k,v in pairs(data) do
		return true
	end
	return false
end

function PLUGIN:checkAllPlayers()
	for k,v in pairs(PlayerCheck) do
		for u,i in pairs(v) do
			PlayerCheck[k][u] = nil
		end
		PlayerCheck[k] = nil
	end
	PlayerCheck = nil
	PlayerCheck = {}
	
	local it = global.BasePlayer.activePlayerList
	for i=0, it.Count-1 do
		PlayerData[rust.UserIDFromPlayer(it[i])] = {
			timeLeft = self.Config.AntiCheat.timeToCheck
		}  
		PlayerCheck[it[i]] = {}
		PlayerCheck[it[i]].lastPos= it[i].transform.position
		PlayerCheck[it[i]].lastTick= time.GetUnixTimestamp()
		PlayerCheck[it[i]].jumpHack = {}
		PlayerCheck[it[i]].jumpHack.lastDetection = 0
		PlayerCheck[it[i]].jumpHack.detectionAmount = 0
		PlayerCheck[it[i]].speedHack = {}
		PlayerCheck[it[i]].speedHack.lastDetection = 0
		PlayerCheck[it[i]].speedHack.detectionAmount = 0 
		PlayerCheck[it[i]].hitHack = {}
		PlayerCheck[it[i]].hitHack.lastDetection = time.GetUnixTimestamp()
		PlayerCheck[it[i]].hitHack.hitsLastSecond = 0
		PlayerCheck[it[i]].hitHack.detectionAmount = 0
		mainTimers[it[i]] = timer.Repeat(2, 0, function() self:checkPlayer(it[i]) end)  
    end
end 
--------------------------------------------------------------------

--------------------------------------------------------------------
-- Destroy main timer when plugin is reloaded & reset the tables (to diminish resource usage) --
--------------------------------------------------------------------
function PLUGIN:Unload()
	self:SaveData()
	PlayerCheck = {}
	for k,v in pairs(mainTimers) do
		if(v) then
			v:Destroy()
		end
	end
end
--------------------------------------------------------------------
--------------------------------------------------------------------
-- load and save players data --
--------------------------------------------------------------------

function PLUGIN:LoadSavedData()
    PlayerData = datafile.GetDataTable( "ranticheat" )
    PlayerData = PlayerData or {}
end
function PLUGIN:SaveData() 
    datafile.SaveDataTable( "ranticheat" )
    LastSave = time.GetUnixTimestamp()
end

--------------------------------------------------------------------
-- When the player wakes up, start checking him --
--------------------------------------------------------------------

function PLUGIN:OnRunCommand(arg, wantsfeedback)
    if (not arg) then return end
    if (not arg.connection) then return end
    if (not arg.connection.player) then return end
    if (not arg.cmd) then return end
    if (not arg.cmd.name) then return end
    if(arg.cmd.name ~= "wakeup") then return end
    if(not ebs) then return end
    if(arg.connection.player == nil) then return end
	if(not arg.connection.player:IsSleeping()) then return end
	if(arg.connection.player:IsSpectating()) then return end
	if(self.Config.ignoreAdmins and arg.connection.player:GetComponent("BaseNetworkable").net.connection.authLevel > 0) then return end
	if(not mainTimers[arg.connection.player]) then
		if(not PlayerData[rust.UserIDFromPlayer(arg.connection.player)]) then
			PlayerData[rust.UserIDFromPlayer(arg.connection.player)] = {
				timeLeft = self.Config.AntiCheat.timeToCheck
			}
		elseif(PlayerData[rust.UserIDFromPlayer(arg.connection.player)].timeLeft < 2 and not self.Config.AntiCheat.permanent) then 
			return 
		end
		PlayerCheck[arg.connection.player] = {}
		PlayerCheck[arg.connection.player].lastPos=arg.connection.player.transform.position
		PlayerCheck[arg.connection.player].lastTick=time.GetUnixTimestamp()
		PlayerCheck[arg.connection.player].jumpHack = {}
		PlayerCheck[arg.connection.player].jumpHack.lastDetection = 0
		PlayerCheck[arg.connection.player].jumpHack.detectionAmount = 0
		PlayerCheck[arg.connection.player].speedHack = {}
		PlayerCheck[arg.connection.player].speedHack.lastDetection = 0
		PlayerCheck[arg.connection.player].speedHack.detectionAmount = 0
		PlayerCheck[arg.connection.player].hitHack = {}
		PlayerCheck[arg.connection.player].hitHack.lastDetection = time.GetUnixTimestamp()
		PlayerCheck[arg.connection.player].hitHack.hitsLastSecond = 0
		PlayerCheck[arg.connection.player].hitHack.detectionAmount = 0
		mainTimers[arg.connection.player] = timer.Repeat(2, 0, function() self:checkPlayer(arg.connection.player) end)
	else
		if(PlayerCheck[arg.connection.player]) then
			PlayerCheck[arg.connection.player].lastPos=arg.connection.player.transform.position
			PlayerCheck[arg.connection.player].lastTick=time.GetUnixTimestamp()
		end
	end
	return
end
--------------------------------------------------------------------

--------------------------------------------------------------------
-- Get All Admins on Connection & Disconnection--
--------------------------------------------------------------------
function PLUGIN:OnPlayerInit( player )
	if(player:GetComponent("BaseNetworkable").net.connection.authLevel > 0) then AdminList[player] = true end
end

function PLUGIN:OnPlayerDisconnected(player,connection)
	if(AdminList[player]) then
		RemoveFromAdminList(player)
	end
	if(PlayerCheck[player]) then
		if(mainTimers[player]) then
			mainTimers[player]:Destroy()
			mainTimers[player] = nil
		end
		PlayerCheck[player].jumpHack = nil
		PlayerCheck[player].speedHack = nil
		PlayerCheck[player].hitHack = nil
		PlayerCheck[player] = nil
	end
	if( (time.GetUnixTimestamp() - LastSave) > 300) then
		self:SaveData()
	end
end
--------------------------------------------------------------------

--------------------------------------------------------------------
-- Default Configs --
--------------------------------------------------------------------
function PLUGIN:LoadDefaultConfig()
	self.Config.chatName = "r-AntiCheat"
	self.Config.ignoreAdmins = true 
	self.Config.debug = false
	
	self.Config.Messages = {}
	self.Config.Messages.NoPrivilegeMessage = "You don't have enough privileges to use this command"
	self.Config.Messages.DatafileReset = "The datafile was successfully resetted" 
	self.Config.Messages.CheckAllPlayers = "Checking all players" 
	self.Config.Messages.CheckPlayer = "{player} is being checked for hacks" 
	
	self.Config.Commands = {}
	self.Config.Commands.checkAuthLevel = 1
	self.Config.Commands.checkAllAuthLevel = 2
	self.Config.Commands.resetAuthLevel = 2
	
	self.Config.BroadcastDetections = {}
	self.Config.BroadcastDetections.toPlayers = false
	--self.Config.BroadcastDetections.toHacker = false
	self.Config.BroadcastDetections.toAdmins = true
	self.Config.BroadcastDetections.toConsole = true
	
	self.Config.BroadcastBans = {}
	self.Config.BroadcastBans.toPlayers = false
	--self.Config.BroadcastBans.toHacker = true
	self.Config.BroadcastBans.toAdmins = true
	self.Config.BroadcastBans.toConsole = true
	
	self.Config.BroadcastKicks = {}
	self.Config.BroadcastKicks.toPlayers = false
	--self.Config.BroadcastKicks.toHacker = true
	self.Config.BroadcastKicks.toAdmins = true
	self.Config.BroadcastKicks.toConsole = true
	
	self.Config.AntiCheat = {}
	self.Config.AntiCheat.timeToCheck = 1800
	self.Config.AntiCheat.permanent = false
	
	self.Config.AntiCheat.antiSpeedHack = {}
	self.Config.AntiCheat.antiSpeedHack.activated = true
	-- speedPerSecond is the max 2D speed that is allowed per second. Max speed for normal players is 4-6m/s
	self.Config.AntiCheat.antiSpeedHack.speedPerSecond = 8
	self.Config.AntiCheat.antiSpeedHack.ignoreSpeed = 200
	self.Config.AntiCheat.antiSpeedHack.ignoreSlideSpeed = -3
	self.Config.AntiCheat.antiSpeedHack.detectionsBeforePunish = 3
	self.Config.AntiCheat.antiSpeedHack.DetectionMessage = "{player} is running fast ({speed}m/s)"
	self.Config.AntiCheat.antiSpeedHack.punish = {}
	self.Config.AntiCheat.antiSpeedHack.punish.byBan = true
	self.Config.AntiCheat.antiSpeedHack.punish.byKick = true
	self.Config.AntiCheat.antiSpeedHack.punish.kickMessage = "{player} was kicked for speedhacking ({speed}m/s)"
	self.Config.AntiCheat.antiSpeedHack.punish.banMessage = "{player} was banned for speedhacking ({speed}m/s)"
	
	self.Config.AntiCheat.antiSuperJump = {}
	self.Config.AntiCheat.antiSuperJump.activated = true
	-- speedPerSecond is the max Height speed that is allowed per second. Max speed for normal players is 1-2m/s
	self.Config.AntiCheat.antiSuperJump.speedPerSecond = 5
	self.Config.AntiCheat.antiSuperJump.ignoreSpeed = 100
	self.Config.AntiCheat.antiSuperJump.detectionsBeforePunish = 2
	self.Config.AntiCheat.antiSuperJump.DetectionMessage = "{player} jumped very high ({height}m)"
	self.Config.AntiCheat.antiSuperJump.punish = {}
	self.Config.AntiCheat.antiSuperJump.punish.byBan = true
	self.Config.AntiCheat.antiSuperJump.punish.byKick = true
	self.Config.AntiCheat.antiSuperJump.punish.kickMessage = "{player} was kicked for super Jumping ({height}m)"
	self.Config.AntiCheat.antiSuperJump.punish.banMessage = "{player} was banned for super Jumping ({height}m)"

	self.Config.AntiCheat.antiSpeedHit = {}
	self.Config.AntiCheat.antiSpeedHit.activated = true
	self.Config.AntiCheat.antiSpeedHit.hitsPerSecond = 3
	self.Config.AntiCheat.antiSpeedHit.dectectionsBeforePunish = 3
	self.Config.AntiCheat.antiSpeedHit.DetectionMessage = "{player} is hitting very fast ({hits} hits/s)"
	self.Config.AntiCheat.antiSpeedHit.punish = {}
	self.Config.AntiCheat.antiSpeedHit.punish.byBan = true
	self.Config.AntiCheat.antiSpeedHit.punish.byKick = true
	self.Config.AntiCheat.antiSpeedHit.punish.kickMessage = "{player} was kicked for Super Speed Attack ({hits}m/s)"
	self.Config.AntiCheat.antiSpeedHit.punish.banMessage = "{player} was banned for Super Speed Attack ({hits}m/s)"
	
	--self.Config.AntiCheat.antiFlyHack = {}
	--self.Config.AntiCheat.antiFlyHack.activated = true
end
--------------------------------------------------------------------
function PLUGIN:cmdCheck(player,cmd,args)
	if(player:GetComponent("BaseNetworkable").net.connection.authLevel < self.Config.Commands.checkAuthLevel) then
		rust.SendChatMessage(player,self.Config.NoPrivilegeMessage)
		return
	end
	if(args.Length ==0) then return false end
	success, err = self:FindPlayer( args[0] )
	if(not success) then rust.SendChatMessage(player,err) return end
	
	if(mainTimers[success]) then mainTimers[success]:Destroy() end
	
	PlayerData[rust.UserIDFromPlayer(success)] = {
			timeLeft = self.Config.AntiCheat.timeToCheck
	}
	PlayerCheck[success] = {}
	PlayerCheck[success].lastPos=arg.connection.player.transform.position
	PlayerCheck[success].lastTick=time.GetUnixTimestamp()
	PlayerCheck[success].jumpHack = {}
	PlayerCheck[success].jumpHack.lastDetection = 0
	PlayerCheck[success].jumpHack.detectionAmount = 0
	
	PlayerCheck[success].speedHack = {}
	PlayerCheck[success].speedHack.lastDetection = 0
	PlayerCheck[success].speedHack.detectionAmount = 0
	
	PlayerCheck[success].hitHack = {}
	PlayerCheck[success].hitHack.lastDetection = time.GetUnixTimestamp()
	PlayerCheck[success].hitHack.hitsLastSecond = 0
	PlayerCheck[success].hitHack.detectionAmount = 0
	
	mainTimers[success] = timer.Repeat(2, 0, function() self:checkPlayer(success) end)
	
	rust.SendChatMessage(player,replaceMessage(self.Config.Messages.CheckPlayer,success,nil,nil,nil))
end
function PLUGIN:cmdCheckAll(player,cmd,args)
	if(player:GetComponent("BaseNetworkable").net.connection.authLevel < self.Config.Commands.checkAllAuthLevel) then
		rust.SendChatMessage(player,self.Config.NoPrivilegeMessage)
		return
	end 
	self:resetTimers()
	self:checkAllPlayers()
	rust.SendChatMessage(player,self.Config.Messages.CheckAllPlayers)
end
function PLUGIN:cmdReset(player,cmd,args)
	if(player:GetComponent("BaseNetworkable").net.connection.authLevel < self.Config.Commands.resetAuthLevel) then
		rust.SendChatMessage(player,self.Config.NoPrivilegeMessage)
		return
	end
	for k,v in pairs(PlayerData) do
		for u,i in pairs(v) do
			PlayerData[k][u] = nil
		end
		PlayerData[k] = nil
	end
	PlayerData = nil
	PlayerData = {}
	self:SaveData()
	self:resetTimers()
	self:checkAllPlayers()
	rust.SendChatMessage(player,self.Config.Messages.DatafileReset)
end

	
function PLUGIN:DetectedPlayer(player,acType,dist2d,dist3d,distY,newTick)
	if(acType == 1) then
		if( (newTick - PlayerCheck[player].speedHack.lastDetection) < 3) then
			-- This way it will ignore lag detections (2nd fail safe agaisnt lags)
			-- and will also make that it needs detections in a row
			PlayerCheck[player].speedHack.lastDetection = newTick
			PlayerCheck[player].speedHack.detectionAmount =  PlayerCheck[player].speedHack.detectionAmount + 1
		else
			PlayerCheck[player].speedHack.lastDetection = newTick
			PlayerCheck[player].speedHack.detectionAmount =  0
		end
		if(PlayerCheck[player].speedHack.detectionAmount > 0) then
			self:SendDetection(player,acType,dist2d,distY)
			if(PlayerCheck[player].speedHack.detectionAmount >= self.Config.AntiCheat.antiSpeedHack.detectionsBeforePunish) then
				self:punishPlayer(player,acType,dist2d,distY)
			end
		end
	elseif(acType == 2) then
		PlayerCheck[player].jumpHack.lastDetection = newTick
		PlayerCheck[player].jumpHack.detectionAmount = PlayerCheck[player].jumpHack.detectionAmount + 1
		self:SendDetection(player,acType,dist2d,distY)
		if(PlayerCheck[player].jumpHack.detectionAmount >= self.Config.AntiCheat.antiSuperJump.detectionsBeforePunish) then
			self:punishPlayer(player,acType,dist2d,distY)
		end
	elseif(acType == 3) then
		PlayerCheck[player].hitHack.detectionAmount = PlayerCheck[player].hitHack.detectionAmount + 1
		PlayerCheck[player].hitHack.lastDetection = PlayerCheck[player].hitHack.lastDetection + 1
		self:SendDetection(player,acType,dist2d,distY)
		if(PlayerCheck[player].hitHack.detectionAmount >=  self.Config.AntiCheat.antiSpeedHit.dectectionsBeforePunish) then
			self:punishPlayer(player,acType,dist2d,distY)
		end
		PlayerCheck[player].hitHack.hitsLastSecond = 0
	end
end

function PLUGIN:punishPlayer(player,acType,dist2d,distY)
	if(acType == 1) then
		if(self.Config.AntiCheat.antiSpeedHack.punish.byBan) then
			msg = replaceMessage(self.Config.AntiCheat.antiSpeedHack.punish.banMessage,player,distY,dist2d)
			self:SendBan(player,acType,dist2d,distY)
			ebs:Ban(nil, player, "r-Speedhack ("..dist2d.."m/s)", false)
			
		elseif(self.Config.AntiCheat.antiSpeedHack.punish.byKick) then
			msg = replaceMessage(self.Config.AntiCheat.antiSpeedHack.punish.kickMessage,player,distY,dist2d)
			self:SendKick(player,acType,dist2d,distY)
			ebs:Kick(nil, player, "r-Speedhack ("..dist2d.."m/s)")
			
		end
		RemovePlayerCheck(player)
	elseif(acType == 2) then
		if(self.Config.AntiCheat.antiSuperJump.punish.byBan) then
			msg = replaceMessage(self.Config.AntiCheat.antiSuperJump.punish.banMessage,player,distY,dist2d)
			self:SendBan(player,acType,dist2d,distY)
			ebs:Ban(nil, player, "r-Superjump ("..distY.."m/s)", false)
			
		elseif(self.Config.AntiCheat.antiSuperJump.punish.byKick) then
			msg = replaceMessage(self.Config.AntiCheat.antiSuperJump.punish.kickMessage,player,distY,dist2d)
			self:SendKick(player,acType,dist2d,distY)
			ebs:Kick(nil, player, "r-Superjump ("..distY.."m/s)")
			
		end
		RemovePlayerCheck(player)
	elseif(acType == 3) then
		if(self.Config.AntiCheat.antiSpeedHit.punish.byBan) then
			msg = replaceMessage(self.Config.AntiCheat.antiSpeedHit.punish.banMessage,player,distY,dist2d,PlayerCheck[player].hitHack.hitsLastSecond)
			self:SendBan(player,acType,dist2d,distY)
			ebs:Ban(nil, player, "r-SuperSpeedHit ("..PlayerCheck[player].hitHack.hitsLastSecond.."m/s)", false)
			
		elseif(self.Config.AntiCheat.antiSpeedHit.punish.byKick) then
			msg = replaceMessage(self.Config.AntiCheat.antiSpeedHit.punish.kickMessage,player,distY,dist2d,PlayerCheck[player].hitHack.hitsLastSecond)
			self:SendKick(player,acType,dist2d,distY)
			ebs:Kick(nil, player, "r-SuperSpeedHit ("..PlayerCheck[player].hitHack.hitsLastSecond.."m/s)")
		end
		RemovePlayerCheck(player)
	end
end
function PLUGIN:BroadcastAdmins(msg)
	for player,abool in pairs(AdminList) do
		if(abool) then
			rust.SendChatMessage(player,msg)
		end
	end
end
function PLUGIN:SendDetection(player,acType,dist,height)
	msg = ""
	if(acType == 1) then
		msg = replaceMessage(self.Config.AntiCheat.antiSpeedHack.DetectionMessage,player,height,dist,nil)
	elseif(acType == 2) then
		msg = replaceMessage(self.Config.AntiCheat.antiSuperJump.DetectionMessage,player,height,dist,nil)
	elseif(acType == 3) then
		msg = replaceMessage(self.Config.AntiCheat.antiSpeedHit.DetectionMessage,player,height,dist,PlayerCheck[player].hitHack.hitsLastSecond)
	end
	if(self.Config.BroadcastDetections.toPlayers) then
		rust.BroadcastChat(self.Config.chatName,msg)
	elseif(self.Config.BroadcastDetections.toAdmins) then
		self:BroadcastAdmins(msg)
	end
	if(self.Config.BroadcastDetections.toConsole) then
		print(msg)
	end
end
function PLUGIN:SendBan(player,acType,dist,height)
	msg = ""
	if(acType == 1) then
		msg = replaceMessage(self.Config.AntiCheat.antiSpeedHack.punish.banMessage,player,height,dist)
	elseif(acType == 2) then
		msg = replaceMessage(self.Config.AntiCheat.antiSuperJump.punish.banMessage,player,height,dist)
	elseif(acType == 3) then
		msg = replaceMessage(self.Config.AntiCheat.antiSpeedHit.punish.banMessage,player,height,dist,PlayerCheck[player].hitHack.hitsLastSecond)
	end
	if(self.Config.BroadcastBans.toPlayers) then
		rust.BroadcastChat(self.Config.chatName,msg)
	elseif(self.Config.BroadcastBans.toAdmins) then
		self:BroadcastAdmins(msg)
	end
	if(self.Config.BroadcastBans.toConsole) then
		print(msg)
	end
	logWarning(msg)
end
function PLUGIN:SendKick(player,acType,dist,height)
	msg = ""
	if(acType == 1) then
		msg = replaceMessage(self.Config.AntiCheat.antiSpeedHack.punish.kickMessage,player,height,dist)
	elseif(acType == 2) then
		msg = replaceMessage(self.Config.AntiCheat.antiSuperJump.punish.kickMessage,player,height,dist)
	elseif(acType == 3) then
		msg = replaceMessage(self.Config.AntiCheat.antiSpeedHit.punish.kickMessage,player,height,dist,PlayerCheck[player].hitHack.hitsLastSecond)
	end
	if(self.Config.BroadcastKicks.toPlayers) then
		rust.BroadcastChat(self.Config.chatName,msg)
	elseif(self.Config.BroadcastKicks.toAdmins) then
		self:BroadcastAdmins(msg)
	end
	if(self.Config.BroadcastKicks.toConsole) then
		print(msg)
	end
	logWarning(msg)
end
function PLUGIN:checkPlayer(player)
	newTime = time.GetUnixTimestamp()
	if(player == nil or not player) then checkAllTimers() end
	if( canCheck(player) ) then
		deltaTime = newTime - PlayerCheck[player].lastTick 
		-- Using deltaTime as a workaround lags as deltatime will be greater when lags occur
		-- Get the 2D distance with x and z 
		dist2d = Distance2D(PlayerCheck[player].lastPos,player.transform.position)/deltaTime
		-- Get the 3D distance with x y and z
		dist3d = Distance3D(PlayerCheck[player].lastPos,player.transform.position)/deltaTime
		-- Get the 1D distance with only y
		distY = DistanceY(PlayerCheck[player].lastPos,player.transform.position)/deltaTime
		
		-- Anti Speedhack part
		if(self.Config.AntiCheat.antiSpeedHack.activated) then
			-- Here we detected someone running in 2D too fast, but not tooooo fast (as it might be a teleportation).
			if(dist2d > self.Config.AntiCheat.antiSpeedHack.speedPerSecond and dist2d < self.Config.AntiCheat.antiSpeedHack.ignoreSpeed) then
				-- Now we have to check that the player didn't slide from a rock, -3m/s is the limit of the slide so over it the player can't be sliding
				if(distY > self.Config.AntiCheat.antiSpeedHack.ignoreSlideSpeed) then
					-- Here we detect a speed !!! must do stuff!
					self:DetectedPlayer(player,1,dist2d,dist3d,distY,newTime)
				end
			end
		end
		
		if(self.Config.AntiCheat.antiSuperJump.activated) then
			-- So lets start by detecting players that go up too fast & are jumping (we never know)
			if(distY > self.Config.AntiCheat.antiSuperJump.speedPerSecond and not player:IsOnGround()) then
				-- Now we want to ignore teleportations
				if(dist2d < self.Config.AntiCheat.antiSuperJump.ignoreSpeed) then
					-- Voila this should be a superjump detection!! must do stuff!
					self:DetectedPlayer(player,2,dist2d,dist3d,distY,newTime)
				end
			end
		end
		-- No flyhack at the moment
		if(self.Config.debug) then
			rust.SendChatMessage(player,self.Config.chatName,"2D:" .. tostring(math.ceil(dist2d*100)/100) .. " - Y:" .. tostring(math.ceil(distY*100)/100) .. " - 3D:" .. tostring(math.ceil(dist3d*100)/100))
		end
		PlayerCheck[player].lastPos=player.transform.position
		PlayerCheck[player].lastTick=newTime
		if(not self.Config.AntiCheat.permanent) then
			PlayerData[rust.UserIDFromPlayer(player)].timeLeft = PlayerData[rust.UserIDFromPlayer(player)].timeLeft - 2
		end
	else
		if(PlayerCheck[player]) then
			PlayerCheck[player].lastPos=player.transform.position
		end
	end
end
function PLUGIN:OnPlayerAttack(player,hitinfo)
	if(not self.Config.AntiCheat.antiSpeedHit.activated) then return end
	if(not ebs) then return end
	if(not PlayerCheck[player]) then return end
	if(hitinfo.HitEntity and hitinfo.HitEntity:GetComponentInParent(global.BuildingBlock._type)) then
		if(hitinfo.Weapon and hitinfo.Weapon:GetComponent(global.BaseMelee._type)) then
			if(PlayerCheck[player].hitHack.lastDetection >= time.GetUnixTimestamp()) then
				PlayerCheck[player].hitHack.hitsLastSecond = PlayerCheck[player].hitHack.hitsLastSecond + 1
				if(PlayerCheck[player].hitHack.hitsLastSecond >= self.Config.AntiCheat.antiSpeedHit.hitsPerSecond) then
					self:DetectedPlayer(player,3,nil,nil,nil,nil)
					
					return
				end
				PlayerCheck[player].hitHack.lastDetection = time.GetUnixTimestamp()
			else
				PlayerCheck[player].hitHack.hitsLastSecond = 0
				PlayerCheck[player].hitHack.lastDetection = time.GetUnixTimestamp()
				PlayerCheck[player].hitHack.detectionAmount = 0
			end
		end
	end
end


function PLUGIN:FindPlayer( target )
	local steamid = false
	if(tonumber(target) ~= nil and string.len(target) == 17) then
		steamid = target
	end
	local targetplayer = false
	local allBasePlayer = UnityEngine.Object.FindObjectsOfTypeAll(global.BasePlayer._type)
	for i = 0, tonumber(allBasePlayer.Length - 1) do
		local currentplayer = allBasePlayer[ i ];
		if(steamid) then
			if(steamid == rust.UserIDFromPlayer(currentplayer)) then
				return currentplayer
			end
		else
			if(currentplayer.displayName == target) then
				return currentplayer
			elseif(string.find(currentplayer.displayName,target)) then
				if(targetplayer) then
					return false, "Multiple Players Found"
				end
				targetplayer = currentplayer
			end
		end
	end
	if(not targetplayer) then return false, "No players found" end
	return targetplayer
end
