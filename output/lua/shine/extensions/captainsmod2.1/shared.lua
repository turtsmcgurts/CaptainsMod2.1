--[[    TODO
--  1. unpick button
--
--  agree to comm, then go captain and you dont get removed
--  status menu shows NEED COMM
--]]
local Plugin = {}

function Plugin:SetupDataTable()
    self:AddDTVar("boolean", "enabled", true)
    self:AddDTVar("boolean", "islive", false)

    local PlayerData = {
        steamid = "string (64)",
        name = "string (64)"
    }
    local PlayerPickedData = {
        captain_name = "string (64)",
        steamid = "string (64)",
        name = "string (64)"
    }
    local TeamData = {
        team_number = "integer (1 to 2)",
        ready = "integer (1 to 4)", --1 needcapt | 2 needcomm | 3 notready | 4 ready
        name = "string (64)"
    }


    
	self:AddNetworkMessage("SetCaptain", { steamid = "string (255)", team = "integer (1 to 2)" }, "Client" ) --sent by server to client when he is made captain. opens captain men
	self:AddNetworkMessage("AddPlayer", PlayerData, "Client" ) --sent by server to client to add a client to the captains player list
	self:AddNetworkMessage("RemovePlayer", PlayerData, "Client" ) --sent by server to client to remove a client from the captains player list
	self:AddNetworkMessage("CloseCaptainMenu", {}, "Client" ) --sent by server to close the captain menu
	self:AddNetworkMessage("ResetPlayerList", {}, "Client" ) --sent by server to tell a captain to reset their player-list
    self:AddNetworkMessage("ServerUpdateTeam", TeamData, "Client" ) --sent by server to update the clients of a teams ready/name status
    self:AddNetworkMessage("ServerAskComm", {}, "Client" ) --sent by server to ask a player if he would command.
    self:AddNetworkMessage("ServerSetCaptainCheckbox", {value = "boolean"}, "Client" ) --sent by server to force a captains Ready checkbox to true/false

    self:AddNetworkMessage("ClientUpdateTeam", TeamData, "Server" ) --sent by client to update the server of a teams ready/name status
    self:AddNetworkMessage("ClientCommResponse", {marine = "boolean", alien = "boolean"}, "Server" ) --sent by client to tell server yes/no when asked to command for X team
    end

function Plugin:NetworkUpdate( Key, Old, New )
	if Server then return end
    --Print(string.format("sharedkey: %s = %s|%s", tostring(Key), tostring(Old), tostring(New)))	

    if (tostring(Key) == "islive") then
        if (New) then Plugin: KillUI()
        --else Plugin: OpenUI() 
        end 
    end
end

function Plugin:Initialise()
	self.Enabled = true
	return true
end

Shine:RegisterExtension( "captainsmod2.1", Plugin )





