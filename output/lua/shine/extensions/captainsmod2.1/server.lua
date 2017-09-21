local Plugin = Plugin
Plugin.Version = "1.0"

Plugin.HasConfig = true
Plugin.ConfigName = "CaptainMod2.json"
Plugin.DefaultConfig = {
	CountdownTime = 5
}
Plugin.Conflicts = {
    DisableThem = {
		"tournamentmode",
        "pregame"
        },
    DisableUs = {}
}

--{{{ Variables 
local debugmode = false
local solotest = false --for when I am testing alone

local TEAM_RR = 0
local TEAM_MARINE = 1
local TEAM_ALIEN = 2
local TEAM_SPEC = 3

local STATE_COMMS = 1
local STATE_PLAYERS = 2

local NetworkSend = {}
local NetworkReceive = {}

local team_ready = {false, false} --team ready status
local team_name = {"Marines", "Aliens"} --team names

local captain_exists = {false, false} --does a captain exist for this team?
local captain_clients = {0, 0} --the client of each captain
local captain_name = {"", ""} --name of each captain
local captain_steamid = {0, 0} --steamid of each captain
local is_client_captain = {}

local commander_exists = {false, false} --does this team have a comm picked?
local commander_clients = {0, 0} --client for each commander
local commander_name = {"", ""}
local commander_steamid = {0, 0}
local is_client_commander = {} --is_client_commander[CLIENT] = true/false

local picking_state = {} --store each teams picking state. ie picking comm or players
local willing_comm = {} --store a clients commander preference

local player_list = {} -- player_list[steamid] = CLIENT
local bot_list = {} -- bot_list[BOT_NAME]   because we give bots fake steamids, we need this table to identify what the steamid is based on their name
local amount_of_bots = 0

local countdown_time = 5

--}}}


--{{{ NetworkSend - SetCaptain, RemoveCaptain, AddPlayer, RemovePlayer, CloseCaptainMenu, ServerUpdateTeam
function NetworkSend: SetCaptain(Client)
    if (not Plugin.dt.enabled) then return end
    if (not Client) then return end

    local Player = Client:GetControllingPlayer()
    local name = Player:GetName()
    local team_number = Player:GetTeamNumber()
    local steamid = Client:GetUserId()

    if (not Plugin: IsPlayerOnTeam(Client)) then Plugin:NotifyGeneric(Player, "You must be a marine or alien to captain.") return end
    if (captain_exists[team_number]) then Plugin:NotifyGeneric(Player, string.format("%ss already have a captain. (%s)", Plugin:GetTeamName(team_number, true), captain_name[team_number])) return end

    captain_exists[team_number] = true
    captain_clients[team_number] = Client
    captain_name[team_number] = name
    captain_steamid[team_number] = steamid
    is_client_captain[steamid] = true
    
    Plugin: NotifyGeneric(nil, string.format("%s is captain for %ss.", name, Plugin:GetTeamName(team_number, false)))
    Plugin: NotifyGeneric(Player, "You must pick a commander first, wait for people to volunteer.")

    picking_state[team_number] = STATE_COMMS
    --picking_state[team_number] = STATE_PLAYERS
    NetworkSend: ServerUpdateTeam(nil, team_number, false)

	Plugin:SendNetworkMessage(Player, "SetCaptain", {steamid = steamid, team = team_number}, true)

    Plugin: PopulatePlayerList(Client, true)
end
function NetworkSend: RemoveCaptain(Client, notify)
    if (not Plugin.dt.enabled) then return end
    if (not Client) then return end

    local Player = Client:GetControllingPlayer()
    local name = Player:GetName()
    local team_number = Player:GetTeamNumber()
    local steamid = Client:GetUserId()
    if (not is_client_captain[steamid]) then return end

    if (team_number == -1) then --he disconnected
        if (captain_clients[TEAM_MARINE] == Client) then team_number = TEAM_MARINE
        elseif (captain_clients[TEAM_ALIEN] == Client) then team_number = TEAM_ALIEN end
    end

    captain_exists[team_number] = false
    captain_clients[team_number] = 0
    captain_name[team_number] = ""
    captain_steamid[team_number] = 0
    is_client_captain[steamid] = false

    team_ready[team_number] = false
    team_name[team_number] = string.format("%ss", Plugin: GetTeamName(team_number, true))

    NetworkSend: ServerUpdateTeam(nil, team_number, false)

    if (team_number ~= -1) then
        NetworkSend: CloseCaptainMenu(Client)
    end

    if (notify) then
        Plugin: NotifyGeneric(nil, string.format("%s is no longer captain for %ss.", name, Plugin:GetTeamName(team_number, false)))
    end
end
function NetworkSend: AddPlayer(Client, force)
	if (not Plugin.dt.enabled) then return end
	if (not Client) then return end
	
    local Player = Client:GetControllingPlayer()
	local player_index = Player:GetClient()
	local player_steamid = player_index:GetUserId()
	local player_name_marine = Player:GetName()
    local player_name_alien = Player:GetName()
    local player_team = Player:GetTeamNumber()

    if (not player_team == TEAM_RR and not force) then return end

    if (Client:GetIsVirtual()) then
        player_steamid = bot_list[Player:GetName()]
    end


    if (picking_state[TEAM_MARINE] == STATE_COMMS) then --only add willing commanders during the commander picking stage
        player_name_marine = string.format("(comm) %s", player_name_marine)

        if ((captain_exists[TEAM_MARINE] and willing_comm[Client][TEAM_MARINE]) or (force and player_team == TEAM_MARINE)) then
            Plugin:SendNetworkMessage(captain_clients[TEAM_MARINE], "AddPlayer", { steamid = player_steamid, name = player_name_marine}, true)
        end
    else
        if (captain_exists[TEAM_MARINE]) then
            Plugin:SendNetworkMessage(captain_clients[TEAM_MARINE], "AddPlayer", { steamid = player_steamid, name = player_name_marine}, true)
        end
    end

    if (picking_state[TEAM_ALIEN] == STATE_COMMS) then
        player_name_alien = string.format("(comm) %s", player_name_alien)

        --Plugin: NotifyGeneric(nil, string.format("%s %s %s %s", tostring(captain_exists[TEAM_ALIEN]), tostring(willing_comm[Client][TEAM_ALIEN]), tostring(force), player_team == TEAM_ALIEN and "true"))

        if ((captain_exists[TEAM_ALIEN] and willing_comm[Client][TEAM_ALIEN]) or (force and player_team == TEAM_ALIEN)) then
            Plugin:SendNetworkMessage(captain_clients[TEAM_ALIEN], "AddPlayer", { steamid = player_steamid, name = player_name_alien}, true)
        end 
    else
        if (captain_exists[TEAM_ALIEN]) then
            Plugin:SendNetworkMessage(captain_clients[TEAM_ALIEN], "AddPlayer", { steamid = player_steamid, name = player_name_alien}, true)
        end
    end
end
function NetworkSend: RemovePlayer(Client)
    if (not Plugin.dt.enabled) then return end
	if (not Client) then return end
	
    local Player = Client:GetControllingPlayer()
	local player_index = Player:GetClient()
	local player_steamid = player_index:GetUserId()
	local player_name = Player:GetName()


    if (Client:GetIsVirtual()) then
        player_steamid = bot_list[player_name]
    end

    if (captain_exists[TEAM_MARINE]) then
        if (willing_comm[Client][TEAM_MARINE] and picking_state[TEAM_MARINE] == STATE_COMMS) then
            player_name = string.format("(comm) %s", player_name)
        end
		Plugin:SendNetworkMessage(captain_clients[TEAM_MARINE], "RemovePlayer", { steamid = player_steamid, name = player_name}, true)
    end
    if (captain_exists[TEAM_ALIEN]) then
        if (willing_comm[Client][TEAM_ALIEN] and picking_state[TEAM_ALIEN] == STATE_COMMS) then
            player_name = string.format("(comm) %s", player_name)
        end
    	Plugin:SendNetworkMessage(captain_clients[TEAM_ALIEN], "RemovePlayer", { steamid = player_steamid, name = player_name}, true)
    end
end
function NetworkSend: CloseCaptainMenu(Client)
	--Tell this client to close his captain menu if he hasn't already
	if (not Plugin.dt.enabled) then return end
	if (not Client) then return end
	Plugin:SendNetworkMessage(Client, "CloseCaptainMenu", {}, true)
end
function NetworkSend: CloseReadyStatusMenu(Client)
	--Tell this client to close his captain menu if he hasn't already
	if (not Plugin.dt.enabled) then return end
	if (not Client) then return end
	Plugin: SendNetworkMessage(Client, "CloseReadyStatusMenu", {}, true)
end
function NetworkSend: ServerAskComm(Client)
    -- ask this client if they would like to command
	if (not Plugin.dt.enabled) then return end
	Plugin:SendNetworkMessage(Client, "ServerAskComm", {}, true)
end
function NetworkSend: ServerUpdateTeam(Client, team, force_client)
    -- update the clients ReadyStatusMenu for this team
	if (not Plugin.dt.enabled) then return end
    if (team == -1) then --send both teams
        local marine_rdy = team_ready[TEAM_MARINE] and 4 or 3
        local alien_rdy = team_ready[TEAM_ALIEN] and 4 or 3


        if (not Plugin:DoesTeamHaveComm(TEAM_MARINE)) then marine_rdy = 2 end
        if (not Plugin:DoesTeamHaveComm(TEAM_ALIEN)) then alien_rdy = 2 end

        if (not captain_exists[TEAM_MARINE]) then marine_rdy = 1 end
        if (not captain_exists[TEAM_ALIEN]) then alien_rdy = 1 end

        Plugin:SendNetworkMessage(Client, "ServerUpdateTeam", {team_number = TEAM_MARINE, ready = marine_rdy, name = team_name[TEAM_MARINE]}, true)
	    Plugin:SendNetworkMessage(Client, "ServerUpdateTeam", {team_number = TEAM_ALIEN, ready = alien_rdy, name = team_name[TEAM_ALIEN]}, true)
    else
        local rdy = team_ready[team] and 4 or 3
        if (not Plugin:DoesTeamHaveComm(team)) then rdy = 2 end
        if (not captain_exists[team]) then rdy = 1 end

	    Plugin:SendNetworkMessage(Client, "ServerUpdateTeam", {team_number = team, ready = rdy, name = team_name[team]}, true)
    end

    if (force_client) then
        NetworkSend: ServerSetCaptainCheckbox(Client, isready)
    end
end
function NetworkSend: ServerSetCaptainCheckbox(Client, isready)
    -- ask this client if they would like to command
	if (not Plugin.dt.enabled) then return end
	Plugin:SendNetworkMessage(Client, "ServerSetCaptainCheckbox", {value = isready}, true)
end
function NetworkSend: ServerResetPlayerList(Client)
	Plugin:SendNetworkMessage(Client, "ResetPlayerList", {}, true)
end
--}}}
-- {{{ NetworkReceive - ClientUpdateTeam, ClientCommResponse
function Plugin: ReceiveClientUpdateTeam(Client, Message)
    -- Update server with a captains ready/team name status
    if (not self.dt.enabled) then return end
    if (not Client) then return end
    local rdy = (Message.ready == 3 and false) or (Message.ready == 4 and true) or false

    --Print(string.format("ready: %s & %s  |  name: %s & %s", team_ready[Message.team_number], Message.ready, team_name[Message.team_number], Message.name))
    if (team_ready[Message.team_number] == rdy and team_name[Message.team_number] ~= Message.name) then --ready status hasn't changed, name has
        Plugin: NotifyGeneric(nil, string.format("%s are now known as the %s.", team_name[Message.team_number], Message.name))
    else
        if (not Plugin: DoesTeamHaveComm(Message.team_number) and rdy) then
            Plugin: NotifyRed(Client, string.format("Nobody in the %s!", (Message.team_number == TEAM_MARINE and "chair") or (Message.team_number == TEAM_ALIEN and "hive")))
            NetworkSend: ServerSetCaptainCheckbox(Client, false)
            team_ready[Message.team_number] = false

            return
        end
        Plugin: NotifyGeneric(nil, string.format("%s %s.", Message.name, rdy == true and "are ready" or rdy == false and "are no longer ready" or ""))
    end

    team_ready[Message.team_number] = rdy
    team_name[Message.team_number] = Message.name

    NetworkSend: ServerUpdateTeam(nil, Message.team_number, false)
    if (debugmode and solotest) then
        if (Message.ready) then
            team_ready[TEAM_MARINE] = true
            team_ready[TEAM_ALIEN] = true
        end
    end

    Plugin: CheckStart()
    --Plugin: NotifyTeamStatusChange() --inform all the clients of a change
end
function Plugin: ReceiveClientCommResponse(Client, Message)
    -- update server with the response of a client when asked to command
    if (not Plugin.dt.enabled) then return end
    if (not Client) then return end


    local Player = Client:GetControllingPlayer()
    local team = Player:GetTeamNumber()
    local name = Player:GetName()
    local steamid = Client:GetUserId()
    
    --Print(string.format("Name: %s | marine_comm: %s | alien_comm: %s", name, tostring(Message.marine), tostring(Message.alien)))

    willing_comm[Client][TEAM_MARINE] = Message.marine
    willing_comm[Client][TEAM_ALIEN] = Message.alien
    NetworkSend: AddPlayer(Client, false)
end
-- }}}

--{{{ Starting Process - StartGame / CheckStart / StartCountdown / CheckCommanders / CheckReady
function Plugin: CheckGameStart(Gamerules)
    if (not self.dt.enabled) then return end

	local State = Gamerules:GetGameState()
    
    if (State == kGameState.PreGame or State == kGameState.NotStarted) then
        self.GameStarted = false
        return false
    end
end
function Plugin: StartGame(Gamerules)
	Gamerules:ResetGame()
	Gamerules:SetGameState(kGameState.Countdown)
	Gamerules.countdownTime = 5
	Gamerules.lastCountdownPlayed = nil

    Plugin: DestroyUIForAll()
    
    self.dt.islive = true
end
function Plugin: EndGame(Gamerules, WinningTeam)
    Plugin: NotifyDebug(nil, "Game ended", false)

    local winner = WinningTeam:GetTeamNumber()
    if (winner == TEAM_MARINE) then
        Plugin: NotifyMarineTeamColor(nil, " won the round!", false)
    elseif (winner == TEAM_ALIEN) then
        Plugin: NotifyAlienTeamColor(nil, " won the round!", false)
    end

    if (captain_exists[TEAM_MARINE]) then
        NetworkSend: RemoveCaptain(captain_clients[TEAM_MARINE], false)
    end
    if (captain_exists[TEAM_ALIEN]) then
        NetworkSend: RemoveCaptain(captain_clients[TEAM_ALIEN], false)
    end


    self.dt.islive = false

    self:SimpleTimer(8, function()
        NetworkSend: ServerAskComm(nil)
    end)
end
function Plugin: CheckStart()
    if (Plugin: CheckReady()) then
        if (Plugin: CheckCommanders()) then
            Plugin: StartCountdown()
        else
            countdown_time = Plugin.Config.CountdownTime
        end
    else
        countdown_time = Plugin.Config.CountdownTime
    end
end
function Plugin: StartCountdown()
    local cd_time = Plugin.Config.CountdownTime
    local curr_time = countdown_time

    countdown_time = countdown_time - 1

    if (curr_time >= 1 and curr_time <= cd_time) then
        Plugin: NotifyGeneric(nil, string.format("Starting in %i", curr_time))
    elseif (curr_time < 1) then
        countdown_time = cd_time
        Plugin: StartGame(GetGamerules())
    end

    self:SimpleTimer(1, function()
        if (curr_time >= 1) then
            Plugin: CheckStart()
        end
    end)
end
function Plugin: CheckCommanders()
    if (not debugmode) then
        local marine_comm = GetGamerules():GetTeam(TEAM_MARINE):GetCommander()
        local alien_comm = GetGamerules():GetTeam(TEAM_ALIEN):GetCommander()

        if (not marine_comm) then
            team_ready[TEAM_MARINE] = false
            --Plugin: NotifyGeneric(captain_clients[TEAM_MARINE], "You are missing a commander.")
            Plugin: NotifyGeneric(nil, "Marines are missing a commander. No longer ready.")
            NetworkSend: ServerUpdateTeam(nil, TEAM_MARINE, true)
            NetworkSend: ServerSetCaptainCheckbox(captain_clients[TEAM_MARINE], false)
        end
        if (not alien_comm) then
            team_ready[TEAM_ALIEN] = false
            --Plugin: NotifyGeneric(captain_clients[TEAM_ALIEN], "You are missing a commander.")
            Plugin: NotifyGeneric(nil, "Aliens are missing a commander. No longer ready.")
            NetworkSend: ServerUpdateTeam(nil, TEAM_ALIEN, true)
            NetworkSend: ServerSetCaptainCheckbox(captain_clients[TEAM_ALIEN], false)
        end

        if (marine_comm and alien_comm) then return true end
    else
        return true
    end
    return false
end
function Plugin: CheckReady()
    --Plugin: NotifyGeneric(nil, string.format("CheckReady: %s  |  %s", tostring(team_ready[TEAM_MARINE]), tostring(team_ready[TEAM_ALIEN])))
    if (team_ready[TEAM_MARINE] and team_ready[TEAM_ALIEN]) then return true end

    return false
end
--}}}

-- {{{ Commander - SetComm / RemoveComm
function Plugin: CommLoginPlayer (Building, Player)
    local team = Player:GetTeamNumber()

    self:SimpleTimer(0.1, function()
        NetworkSend: ServerUpdateTeam(nil, team, false)
    end)
end
function Plugin: CommLogout(Building)
     self:SimpleTimer(0.1, function()
        NetworkSend: ServerUpdateTeam(nil, -1, false)
    end)
end
function Plugin: SetComm(Captain, Client)
    if (not self.dt.enabled) then return end
    if (not Client) then return end
    
    local Player = Client:GetControllingPlayer()
    local team = Player:GetTeamNumber()
    local name = Player:GetName()
    local steamid = Client:GetUserId()

    if (team ~= TEAM_RR) then return end --make sure the selected player is available (in ready room)

    local CaptPlayer = Captain:GetControllingPlayer()
    local CaptTeam = CaptPlayer:GetTeamNumber()
    local CaptName = CaptPlayer:GetName()

    if (commander_exists[CaptTeam]) then Plugin: NotifyGeneric(CaptPlayer, "You've already chosen a commander.") return end --team already chose a commander

    commander_exists[CaptTeam] = true
    commander_clients[CaptTeam] = Client
    commander_name[CaptTeam] = name
    commander_steamid[CaptTeam] = steamid
    is_client_commander[Client] = true

	Plugin: NotifyDebug(nil, "%s chose %s to command %s", true, CaptName, name, Plugin: GetTeamName(CaptTeam, false)) --use a debug message because the "DoYouAccept" response will send the actual chat message.


end
function Plugin: RemoveComm(Client)
    if (not self.dt.enabled) then return end
    if (not Client) then return end

    local team

    if (commander_clients[TEAM_MARINE] == Client) then
        team = TEAM_MARINE
    elseif (commander_clients[TEAM_ALIEN] == Client) then
        team = TEAM_ALIEN
    end

    commander_exists[team] = false
    commander_clients[team] = 0
    commander_name[team] = ""
    commander_steamid[team] = 0
    is_client_commander[Client] = false

    if (team == TEAM_MARINE) then Plugin: NotifyMarineTeamColor(nil, " is no longer commander. (Disconnect)", false)
    elseif (team == TEAM_ALIEN) then Plugin: NotifyAlienTeamColor(nil, " is no longer commander. (Disconnect)", false )end
end
-- }}}

--{{{ PickPlayer / JoinTeam / PopulatePlayerList / NotifyTeamStatusChange
function Plugin: PickPlayer(Client, Target)
    if (not self.dt.enabled) then return end
    if (not Client or not Target) then return end

    local steamid = Client:GetUserId()
    if (not is_client_captain[steamid]) then return end

    local cPlayer = Client:GetControllingPlayer()
    local cTeam = cPlayer:GetTeamNumber()
    local tPlayer = Target:GetControllingPlayer()
    local tClient = tPlayer:GetClient()
    local tName = tPlayer:GetName()
    local tSteamid = Target:GetUserId()
    local team_name = Plugin:GetTeamName(cTeam, false)

	if (cteam == TEAM_MARINE) then
        if (picking_state[TEAM_MARINE] == STATE_COMMS and (willing_comm[Target][TEAM_MARINE] or is_client_captain[tSteamid])) then --picked as comm
            NetworkSend: ServerResetPlayerList(Client)
            Plugin: NotifyMarine (nil, string.format("%s was picked as marine commander.", tName))
        else
		    Plugin: NotifyMarine (nil, string.format("%s was picked for marine.", tName))
        end
	elseif (cTeam == TEAM_ALIEN) then
        if (picking_state[TEAM_ALIEN] == STATE_COMMS and (willing_comm[Target][TEAM_ALIEN] or is_client_captain[tSteamid])) then --picked as comm
            NetworkSend: ServerResetPlayerList(Client)
            Plugin: NotifyAlien (nil, string.format("%s was picked as alien commander.", tName))
        else
		    Plugin: NotifyAlien (nil, string.format("%s was picked for alien.", tName))
        end
	end

    if (picking_state[cTeam] == STATE_COMMS) then
        picking_state[cTeam] = STATE_PLAYERS --he's picked a commander, so change the state to players.
        Plugin: PopulatePlayerList(Client, false)
    end

    GetGamerules():JoinTeam(tPlayer, cTeam, nil, true)
end
function Plugin: JoinTeam(Gamerules, Player, new_team, Force, ShineForce) 
	if (not self.dt.enabled) then return end
	if (not Player) then return end
	
	local Client = Player:GetClient()
	local player_steamid = Client:GetUserId()
	local old_team = Player:GetTeamNumber()
	
    if (self.dt.islive) then
        if (new_team == TEAM_MARINE) then
            --Plugin: NotifyGeneric (nil, string.format("%s joined %s.", Player:GetName(), newteam == TEAM_MARINE and "marines" or "aliens"))
            Plugin: NotifyMarine(nil, string.format("%s joined marines.", Player:GetName()))
        elseif (new_team == TEAM_ALIEN) then
            Plugin: NotifyAlien(nil, string.format("%s joined aliens.", Player:GetName()))
        elseif (new_team == TEAM_RR) then
            Plugin: NotifyGeneric (nil, string.format("%s left the %s.", Player:GetName(), old_team == TEAM_MARINE and "marines" or "aliens"))
            if (is_client_captain[player_steamid]) then
                NetworkSend: RemoveCaptain(Client, true)
            end
        end
        return
    end

	Plugin: NotifyDebug(nil, "%s joined %s.", true, Player:GetName(), new_team == TEAM_MARINE and "marines" or new_team == TEAM_ALIEN and "aliens" or new_team == TEAM_RR and "readyroom" or "")

    if(new_team == TEAM_RR) then
		--check if he's captain. remove him as captain if so.
		if(is_client_captain[player_steamid]) then
			NetworkSend: RemoveCaptain(Client, true)
		end
		NetworkSend: AddPlayer(Client, false)

	elseif (new_team == TEAM_MARINE or new_team == TEAM_ALIEN) then
		NetworkSend: RemovePlayer(Client)
	elseif (new_team == TEAM_SPEC) then
		NetworkSend: RemovePlayer(Client)
	end
end
function Plugin: PopulatePlayerList(Client, show_self)
	if (not self.dt.enabled) then return end
    if (not is_client_captain[Client:GetUserId()]) then return end
	
	for _, target_client in ipairs(Shine:GetAllClients()) do
        local Player = target_client:GetControllingPlayer()
		local team_number = Player:GetTeamNumber()
		if(team_number == TEAM_RR) then
			--loop through server looking for people in the readyroom.
			NetworkSend: AddPlayer(target_client, false)	
		end
	end

    if (show_self) then
        NetworkSend: AddPlayer(Client, true)
    end
end
function Plugin: NotifyTeamStatusChange()
    if (not self.dt.enabled) then return end

	for _, target_client in ipairs(Shine:GetAllClients()) do
        NetworkSend: ServerUpdateTeam(Client, -1, false)
	end

end

--}}}
--{{{ Misc Functions - GiveBotFakeSteamid / IsPlayerOnTeam / GetOppositeTeam / GetTeamName
function Plugin: DoesClientExist(steamid) --to check if somebody crashed 
	for _, target_client in ipairs(Shine:GetAllClients()) do
        target_steamid = target_client:GetUserId()
        if (steamid == target_steamid) then
            return true
        end
    end

    return false
end
function Plugin: GiveBotFakeSteamid(Client)
	--local client = player:GetClient()
	local Player = Client:GetControllingPlayer()
	local player_steamid = Client:GetUserId()
	local random_id = math.random(4000, 8000000)
	amount_of_bots = amount_of_bots + 1
	
	player_list[random_id] = Client
	bot_list[Player: GetName()] = random_id
	
	Plugin: NotifyDebug(nil, "Gave '%s' the fake id '%i'", true, Player: GetName(), random_id)
end
function Plugin: DoesTeamHaveComm(team_number)
    local team = GetGamerules():GetTeam(team_number)
    local comm = team:GetHasCommander()

    if (comm) then 
        return true
    else
        return false
    end

    return false
end
function Plugin: IsPlayerOnTeam(Client)
	local Player = Client:GetControllingPlayer()
	local team_number = Player:GetTeamNumber()
	
	if(team_number == 1 or team_number == 2) then return true end
end
function Plugin: GetOppositeTeam(team_number)
	if(team_number == 0 or team_number == 3) then return 0 end
	
	if(team_number == 1) then
		return 2
	elseif(team_number == 2) then
		return 1
	end
end
function Plugin: GetTeamName(team_number, capital)

	if(team_number == 0) then
		if(capital) then
			return "ReadyRoom"
		else
			return "readyroom"
		end
	elseif(team_number == 1) then
		if(capital)then
			return "Marine"
		else
			return "marine"
		end
	elseif(team_number == 2) then
		if(capital)then
			return "Alien"
		else
			return "alien"
		end
	elseif(team_number == 3) then
		if(capital)then
			return "Spectate"
		else
			return "spectate"
		end
	end
end
function Plugin: DestroyUIForAll()
	for _, target_client in ipairs(Shine:GetAllClients()) do
        NetworkSend: CloseReadyStatusMenu(target_client)
        
        if (is_client_captain[target_client]) then
            NetworkSend: CloseCaptainMenu(target_client)
        end
    end
end
--}}}

---{{{ Shine Misc - CreateCommands / Initialise / Cleanup
function Plugin: ClientConnect (Client)
	--ClientConfirmConnect stopped working for bots, so we need to do this.
	local steamid = Client:GetUserId()
	local Player = Client:GetControllingPlayer()
	local player_name = Player: GetName()

    
    willing_comm[Client] = {}
    willing_comm[Client][TEAM_MARINE] = false
    willing_comm[Client][TEAM_ALIEN] = false

    self:SimpleTimer(1, function()
        if (Client:GetIsVirtual()) then
            Plugin: GiveBotFakeSteamid(Client) 

            --default bots to have marine comm set to true for testing
            willing_comm[Client][TEAM_MARINE] = true
            willing_comm[Client][TEAM_ALIEN] = false
        end
    end)
end
function Plugin: ClientConfirmConnect (Client)
	--if (not Client) then return end
	local steamid = Client:GetUserId()
	local Player = Client:GetControllingPlayer()
	local player_name = Player: GetName()

    is_client_captain[steamid] = false
    is_client_commander[steamid] = false


    Plugin: NotifyGeneric(nil, string.format("%s connected.", player_name))
    NetworkSend: ServerAskComm(Client)
    NetworkSend: ServerUpdateTeam(Client, -1, false)
    NetworkSend: AddPlayer(Client, false)

    Plugin: NotifyDebug(Player, "debugmode is on.", true)
end
function Plugin: ClientDisconnect(Client)
    if (not self.dt.enabled) then return end
    
    local name = Client:GetControllingPlayer():GetName()
    local steamid = Client:GetUserId()

	--Plugin: NotifyDebug(nil, "%s disconnected. iscaptain: %s | iscomm: %s | islive %s", true, name, tostring(is_client_captain[steamid]), tostring(is_client_commander[steamid]), tostring(self.dt.islive))
    --Print(string.format("(Disconnect) Name: %s | team: %i", name, team))

    if  (is_client_captain[steamid]) then
        NetworkSend: RemoveCaptain(Client, true)
    end

    --if (is_client_commander[steamid]) then
    --    Plugin: RemoveComm(Client)
    --end

    if (self.dt.islive) then
        Plugin: NotifyGeneric(nil, string.format("%s has disconnected. (%s)", name))
    end

    --if (not self.dt.islive and (team == TEAM_MARINE or team == TEAM_ALIEN) and captain_exists[team]) then
    --    Plugin: NotifyGeneric(captain_clients[team]:GetControllingPlayer(), string.format("%s has disconnected while on your team.", name))
    --end
end
function Plugin: CreateCommands()
	local function Captain(Client)
		if (not self.dt.enabled) then return end
		if (not Client) then return end
        if (self.dt.islive) then Plugin: NotifyRed(Client, "Game is already live.") end
        
		local Player = Client:GetControllingPlayer()
		local team_number = Player:GetTeamNumber()
        local steamid = Client:GetUserId()

        if (team_number ~= TEAM_MARINE and team_number ~= TEAM_ALIEN) then return end
				
		if(captain_exists[team_number]) then
            if (not Plugin:DoesClientExist(captain_steamid[team_number])) then
                NetworkSend: RemoveCaptain(captain_clients[team_number])
                NetworkSend: SetCaptain(Client)
                return
            end
			if(captain_clients[team_number] == Client) then --is this person a captain?
				NetworkSend: RemoveCaptain(Client, true)
				return
			else
				self:NotifyGeneric(Player, string.format("%s is already captain for %s", true, captain_name[team_number], Plugin:GetTeamName(team_number)))
				return
			end
		end
		
		--they are OK to set as captain.
		NetworkSend: SetCaptain(Client)
	end
	local CommandCaptain = self:BindCommand("sh_cm_captain", { "cpt", "captain", "capt" }, Captain, true )
	CommandCaptain:Help( "Volunteer as the captain for your team." )

	local function Ready(Client)
		if (not self.dt.enabled) then return end
		if (not Client) then return end
		local Player = Client:GetControllingPlayer()
		local team_number = Player:GetTeamNumber()
        local steamid = Client:GetUserId()

        if (not is_client_captain[steamid]) then self:NotifyGeneric(Player, "You are not a captain.") return end
        if (team_number ~= TEAM_MARINE and team_number ~= TEAM_ALIEN) then return end
				
		if(captain_exists[team_number]) then
			if(captain_clients[team_number] == Client) then --is this person a captain?
                    team_ready[team_number] = not team_ready[team_number]
                    NetworkSend: ServerUpdateTeam(Client, team_number, true)
				return
			end
		end
	end
	local CommandReady = self:BindCommand("sh_cm_ready", { "rdy", "ready"}, Ready, true )
	CommandReady:Help( "Volunteer as the captain for your team." )
	local function PickPlayerCommand( client, target )
		local target_player = target:GetControllingPlayer()
		local target_client = target_player: GetClient()
		Plugin: PickPlayer(client, target_client)
	end
	local CommandAddPlayer = self:BindCommand( "sh_cm_pickplayer", "captainpickplayer", PickPlayerCommand, true )
	CommandAddPlayer:AddParam{ Type = "client", NotSelf = false, IgnoreCanTarget = true }
	CommandAddPlayer:Help( "<player> Picks the given player for your team [this command is only available for captains]" )

	local function TestCmd(Client)
		if (not Client) then return end
		local steamid = Client:GetUserId()
		local player = Client:GetControllingPlayer()
		local team_number = player:GetTeamNumber()

        NetworkSend: SetCaptain(Client)
	end
	local CommandTestCmd = self:BindCommand("sh_testcmd", { "t" }, TestCmd, true)
	CommandTestCmd:Help( "do not use" )
end
function Plugin: Initialise()
	Plugin: CreateCommands()
	
    --picking_state[TEAM_MARINE] = STATE_COMMS
    --picking_state[TEAM_ALIEN] = STATE_COMMS
    team_ready[TEAM_MARINE] = false
    team_ready[TEAM_ALIEN] = false

	return true
end
function Plugin: Cleanup()
	--self.Disable()
	self.Enabled = false
end

function Plugin: NotifyRed(Player, String)
	Shine:NotifyColour( Player, 255, 0, 0, String)
end
function Plugin: NotifyGeneric(Player, String)
	Shine:NotifyColour( Player, 255, 255, 255, String)
end
function Plugin: NotifyMarine(Player, String)
	Shine:NotifyColour( Player, 76, 175, 255, String)
end
function Plugin: NotifyAlien(Player, String)
	Shine:NotifyColour( Player, 255, 125, 0, String)
end
function Plugin: NotifyDebug (player, string, format, ...)
    if (debugmode) then
        Shine: NotifyDualColour (player, 187, 15, 23, "[DEBUG]", 255, 255, 255, string, format, ...)
    end
end
function Plugin: NotifyMarineTeamColor(Player, string, format, ...)
    Shine: NotifyDualColour (Player, 76, 175, 255, team_name[TEAM_MARINE], 255, 255, 255, string, format, ...)
end
function Plugin: NotifyAlienTeamColor(Player, string, format, ...)
    Shine: NotifyDualColour (Player, 255, 125, 0, team_name[TEAM_ALIEN], 255, 255, 255, string, format, ...)
end

--}}}
