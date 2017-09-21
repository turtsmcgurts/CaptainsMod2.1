local Shine = Shine
local Plugin = Plugin
local SGUI = Shine.GUI

--{{{ Variables
local TEAM_RR = 0
local TEAM_MARINE = 1
local TEAM_ALIEN = 2
local TEAM_SPEC = 3

local CaptainMenu = {}
local ReadyStatusMenu = {}
local LogMenu = {}
local CommMenu = {}

local NetworkSend = {}
local NetworkReceive = {}


local captain_menu_exists = false
local status_menu_exists = false
local log_menu_exists = false
local comm_menu_exists = false

local is_ready = false
local team = TEAM_RR
local team_name = {"Marines", "Aliens"}
local ready_text = {"NEED CAPT", "NEED CAPT"}
local comm = {false, false}

local PlayerSteamIds = {} --PlayerSteamIds[name] = steamid
--local PlayerSteamID = {} --PlayerSteamID[row_index] = steam_id
--local PlayerName = {} --PlayerName[steam_id] = name

local LayoutData = {
	Colours = {
		ModeText = Colour( 1, 1, 1, 1 ),
		TextBorder = Colour( 0, 0, 0, 0 ),
		Text = Colour( 1, 1, 1, 1 ),
		CheckBack = Colour( 0.2, 0.2, 0.2, 1 ),
		Checked = Colour( 0.8, 0.6, 0.1, 1 )
	}
}

--}}}

--{{{ Skin/Colors
local Colors = {
	Background = Colour(0.6, 0.6, 0.6, 0.4),
	Dark = Colour(0.2, 0.2, 0.2, 0.8),
	Highlight = Colour(0.5, 0.5, 0.5, 0.8),
    White = Colour(1.0, 1.0, 1.0, 1.0),
	PanelGray = Colour(0.49, 0.49, 0.49, 0.85)
}
local Skin = {
	Button = {
		ActiveCol = Colors.Highlight,
		InactiveCol = Colors.Dark,
		ModeText = Colour(1, 1, 1, 1)
	},
	Panel = {
		Default = Colors.Background,
		Dark = Colors.Dark,
		Gray = Colors.PanelGray
	}
}

--}}}

-- {{{ CaptainMenu
-- {{{ Create / Destroy
function CaptainMenu: Create()
	if(captain_menu_exists) then CaptainMenu: Destroy() end --we don't want duplicate menus opened 
	

    local player = Client.GetLocalPlayer()
	team = player:GetTeamNumber()

	local ScreenWidth = Client.GetScreenWidth()
	local ScreenHeight = Client.GetScreenHeight()
	local amount_of_buttons = 2
	local button_height = ScreenHeight*0.04
	local button_offset = ScreenHeight*0.01
	
    local full_size = Vector (ScreenWidth * 0.22, ScreenHeight, 0.0)
	local small_size = Vector()

	-- PARENT PANEL
	local BasePanel = SGUI:Create("Panel")
	BasePanel:SetAnchor ("TopLeft")
	BasePanel:SetPos	(Vector (ScreenWidth * 0.78, 0.0, 0.0))
	BasePanel:SetSize	(Vector (ScreenWidth * 0.22, ScreenHeight, 0.0))
	BasePanel:SetColour (Colour(0.49, 0.49, 0.49, 0.45))
	self.BasePanel = BasePanel
	local PanelSize = BasePanel:GetSize()		
	self.BasePanel = BasePanel
	
	function BasePanel:ReturnToDefaultPos()
		self:SetPos(Vector(ScreenWidth * 0.865, ScreenHeight * 0.22, 0))
	end
	
	function BasePanel: CallOnRemove()
		SGUI:EnableMouse (false)
	end
	
	-- TITLE BAR
	local TitlePanel = SGUI:Create( "Panel", BasePanel )
	TitlePanel:SetSize(Vector(PanelSize.x, ScreenHeight * 0.03, 0))
	TitlePanel:SetColour (Skin.Panel.Gray)
	TitlePanel:SetAnchor("TopLeft")
	local TitlePanelSize = TitlePanel:GetSize()
	
	local TitleLabel = SGUI:Create("Label", TitlePanel)
	TitleLabel:SetAnchor("CentreMiddle")
	TitleLabel:SetFont(Fonts.kAgencyFB_Small)
	TitleLabel:SetText("Captain Menu")
	TitleLabel:SetTextAlignmentX(GUIItem.Align_Center)
	TitleLabel:SetTextAlignmentY(GUIItem.Align_Center)
	TitleLabel:SetPos( Vector(-18, 0, 0)) 
	TitleLabel:SetColour(Colors.White)
	
	
	-- PLAYER LIST
	local ListPanel = SGUI:Create("Panel", BasePanel)
	ListPanel:SetSize( Vector(PanelSize.x - 6, (PanelSize.y - TitlePanelSize.y) * 0.55, 0))
	ListPanel:SetPos( Vector(3, TitlePanelSize.y + 3, 0))
	ListPanel:SetAnchor("TopLeft")
	ListPanel:SetColour (Colour(0.0, 0.0, 0.0, 0.0))
	local ListPanelSize = ListPanel:GetSize()
	
	self.ListItems = {}
	local List = ListPanel:Add("List")
	List:SetAnchor("TopLeft")
	List:SetPos( Vector(0, 0, 0))
	List:SetColumns(1, "Player List")
	List:SetSpacing(1.0)
	List:SetSize(Vector(ListPanelSize.x, ListPanelSize.y, 0))
	List.ScrollPos = Vector(-10, 0, 0)
	
	self.ListItems = List
	

    -- MINMAX PANEL (needed for the button to function for some reason)
    local MinimizePanel = SGUI:Create("Panel")
    MinimizePanel:SetSize(Vector(ScreenWidth * 0.015, ScreenHeight, 0.0))
    MinimizePanel:SetPos(Vector(ScreenWidth * 0.765, 0.0, 0.0))
    MinimizePanel:SetColour (Colour(0.25, 0.25, 0.25, 0.0))
    MinimizePanel:SetAnchor("TopLeft")
    self.MinimizePanel = MinimizePanel
    local MinimizePanelSize = MinimizePanel:GetSize()
    
        -- MIN/MAX BUTTON
    local MinimizeButton = SGUI:Create( "Button", MinimizePanel)
    MinimizeButton:SetSize(Vector(MinimizePanelSize.x, MinimizePanelSize.y, 0.0))
    MinimizeButton:SetPos(Vector(0.0, 0.0, 0.0))
    MinimizeButton:SetText(">")
    MinimizeButton:SetAnchor("TopLeft")
    MinimizeButton.UseScheme = false
    MinimizeButton:SetActiveCol(Colour(0.50, 0.2, .2, 0.3))
    MinimizeButton:SetInactiveCol(Colour(0.50, 0.2, .2, 0.3))
    MinimizeButton:SetTextColour(Colors.White)
    MinimizeButton:SetFont(Fonts.kAgencyFB_Large)
    local MinimizeButtonSize = MinimizeButton:GetSize()

    function MinimizeButton.DoClick()
        option_menu_minimized = not option_menu_minimized
        
        if (option_menu_minimized) then
            self.BasePanel:SetIsVisible(false)
            
            MinimizePanel: SetPos (Vector(ScreenWidth - (MinimizePanelSize.x - 1), 0.0, 0.0))
            MinimizeButton:SetInactiveCol(Colour(0.50, 0.2, .2, 0.15))
            MinimizeButton:SetTextColour(Colour (0.8, 0.8, 0.8, 0.75))
            MinimizeButton:SetText("<")
        else
            self.BasePanel:SetIsVisible(true)
            
            MinimizePanel:SetPos(Vector(ScreenWidth * 0.765, 0.0, 0.0))
            MinimizeButton:SetInactiveCol(Colour(0.50, 0.2, .2, 0.3))
            MinimizeButton:SetTextColour(Colors.White)
            MinimizeButton:SetText(">")
        end
    end


	-- BUTTONS
	local current_button_num = 0
	
	local ButtonPanel = SGUI:Create("Panel", BasePanel)
	ButtonPanel:SetSize(Vector((PanelSize.x * 0.71), button_height, 0))
	ButtonPanel:SetPos(Vector(PanelSize.x * 0.28, ((TitlePanelSize.y + 3) + ListPanelSize.y + 3), 0))
	ButtonPanel:SetColour(Skin.Panel.Gray)
	ButtonPanel:SetAnchor("TopLeft" )
    ButtonPanel:SetColour(Colour(0.25, 0.25, 0.25, 0.0))
	local ButtonPanelSize = ButtonPanel:GetSize()
	
	local PickButton = SGUI:Create("Button", ButtonPanel)
	local PickButtonSize = PickButton:GetSize()
	PickButton:SetText("Pick Player")
	PickButton:SetAnchor("TopLeft")
	PickButton:SetSize(Vector( ButtonPanelSize.x, button_height, 0))
	PickButton:SetPos(Vector( 0, 0, 0))
	PickButton.UseScheme = false
	PickButton:SetActiveCol(Skin.Button.ActiveCol)
	PickButton:SetInactiveCol(Skin.Button.InactiveCol)
	PickButton:SetTextColour(Colors.White)
	
	function PickButton.DoClick()
		local selected_row = List:GetSelectedRow()
		if(not selected_row) then Print("(PickButton.DoClick) selected_row false") return end
		local index = selected_row.Index
		local Rows = List.Rows
		local steamid = PlayerSteamIds[Rows[index]:GetColumnText(1)]
		Print("Selected row index %i. Player '%s' (%s)", selected_row.Index, Rows[index]:GetColumnText(1), steamid)

		Shared.ConsoleCommand( string.format( "sh_cm_pickplayer %s", steamid ) )
	end

	current_button_num = 1
		
	-- READY CHECKBOX
	local ReadyCheckbox = SGUI:Create ("CheckBox", BasePanel)
	--ReadyCheckbox:SetPos( Vector( ScreenWidth * 0.015, PanelSize.y * 0.96, 0) )
	--ReadyCheckbox:SetSize( Vector( ScreenWidth * 0.0095, ScreenHeight * 0.017, 0) )
	ReadyCheckbox:SetPos(Vector(PanelSize.x * 0.05, ((TitlePanelSize.y + 3) + ListPanelSize.y + 3) + PanelSize.y * 0.008, 0))
	--ReadyCheckbox:SetSize(Vector(ScreenWidth * 0.0095, ScreenHeight * 0.017, 0))
	ReadyCheckbox:SetSize(Vector(ScreenWidth * 0.015, ScreenHeight * 0.025, 0))
	ReadyCheckbox:SetFont(Fonts.kAgencyFB_Small)
	ReadyCheckbox:SetAnchor("TopLeft")
	ReadyCheckbox:AddLabel("Ready")
	ReadyCheckbox:SetChecked(is_ready)
	ReadyCheckbox:SetTextColour(Colors.White)
	
	local ReadyCheckBoxSize = ReadyCheckbox:GetSize()
	
	function ReadyCheckbox:OnChecked(value)
		is_ready = value		
        NetworkSend: SendClientUpdateTeam()
	end	
	self.ReadyCheckbox = ReadyCheckbox

    local NamePanel = SGUI:Create( "Panel", BasePanel)
	NamePanel:SetSize(Vector(PanelSize.x * 0.94, PanelSize.y * 0.035, 0))
	NamePanel:SetPos(Vector(PanelSize.x * 0.03, ((TitlePanelSize.y + 3) + ListPanelSize.y + 3) + (ButtonPanelSize.y + 3), 0)) --the +3s are for spacing
	NamePanel:SetAnchor( "TopLeft" )
    NamePanel:SetColour (Colour(0.25, 0.25, 0.25, 0.0))
	local NamePanelSize = NamePanel:GetSize()

	local NameTextBox = SGUI:Create("TextEntry", NamePanel)
	NameTextBox:SetAnchor ("TopLeft")
	NameTextBox:SetFont(Fonts.kAgencyFB_Small)
	NameTextBox:SetPos(Vector(0, 0, 0))
	NameTextBox:SetSize(Vector(NamePanelSize.x * 0.53, NamePanelSize.y, 0))
    NameTextBox.IsSchemed = false
    NameTextBox:SetBorderSize(Vector2(0, 0))
    NameTextBox:SetDarkColour (Colour(0.49, 0.49, 0.49, 0.45))
    NameTextBox:SetPlaceholderText(string.format(" %s (up to 28 chars)", team_name[team]))
    local NameTextBoxSize = NameTextBox:GetSize()

	local SetNameButton = SGUI:Create("Button", NamePanel)
	local SetNameButtonSize = SetNameButton:GetSize()
	SetNameButton:SetText("Set Team Name")
	SetNameButton:SetAnchor("TopLeft")
	SetNameButton:SetSize(Vector(NamePanelSize.x * 0.47, NamePanelSize.y, 0))
	SetNameButton:SetPos(Vector(NameTextBoxSize.x * 1.02, 0, 0))
	SetNameButton.UseScheme = false
	SetNameButton:SetActiveCol(Skin.Button.ActiveCol)
	SetNameButton:SetInactiveCol(Skin.Button.InactiveCol)
	PickButton:SetTextColour(Colors.White)
	
	function SetNameButton.DoClick()
        local text = NameTextBox:GetText()
        if (string.len(text) > 0 and string.len(text) <= 28 and text ~= team_name[team]) then
            team_name[team] = text
            NetworkSend: SendClientUpdateTeam()
        end
	end

	--[[local NameLabel = SGUI:Create("Label", NamePanel)
	NameLabel:SetAnchor("CentreLeft")
	NameLabel:SetFont(Fonts.kAgencyFB_Small)
	NameLabel:SetText("Team Name")
    local NameLabelSize = NameLabel:GetSize()
	NameLabel:SetPos(Vector(0, -(NameLabelSize.y/2), 0))
	--NameLabel:SetTextAlignmentX(GUIItem.Align_Center)
    --NameLabel:SetTextAlignmentY(GUIItem.Align_Center)
	NameLabel:SetColour(Skin.BrightText) --]]
	
	captain_menu_exists = true --record the menu being opened
end
function CaptainMenu: Destroy()
    if (not captain_menu_exists) then return end

	self.BasePanel: SetParent()
	self.BasePanel: Destroy()
    self.MinimizePanel: Destroy()

	captain_menu_exists = false
    is_ready = false
    team_name[team] = team == TEAM_MARINE and "Marines" or team == TEAM_ALIEN and "Aliens" or ""
end
-- }}}
function Plugin: ToggleCheckbox()
	--local AlltalkCheckbox = self.AlltalkCheckbox
	CaptainMenu.AlltalkCheckbox: SetChecked(false)
end
function CaptainMenu: AddToList (steamid, name)
	if (not captain_menu_exists) then return end

	CaptainMenu: RemoveFromList(steamid, name)
	
	local steamid = steamid
	local List = self.ListItems
	local Rows = List.Rows
	
	PlayerSteamIds[name] = steamid
	List:AddRow(name)
end
function CaptainMenu: RemoveFromList (steamid, name)
	if (not captain_menu_exists) then return end

	local List = self.ListItems
	local Rows = List.Rows

	for i = 1, List.RowCount do
		local name1 = Rows[i]:GetColumnText(1)
		local target_steamid = PlayerSteamIds[name1]
		if (target_steamid == steamid) then
			List:RemoveRow(i)	
			break
		end
	end
end
function CaptainMenu: ClearList()
	if (not captain_menu_exists) then return end
	local List = self.ListItems
	local Rows = List.Rows

    local count = List.RowCount - 1

	for i = 1, count do
		local name = Rows[i]:GetColumnText(1)
        PlayerSteamIds[name] = nil
		List:RemoveRow(i)	
	end



	--for i = 1, #List do
	--	List[i] = nil
    --    List:RemoveRow(i)
	--end
end


-- }}}

-- {{{ ReadyStatusMenu
function ReadyStatusMenu: Create()
	if (status_menu_exists) then ReadyStatusMenu: Destroy() end
		
	local ScreenWidth = Client.GetScreenWidth()
	local ScreenHeight = Client.GetScreenHeight()
	
	local team_name_font = Fonts.kAgencyFB_Small --assuming 1080p
	local team_ready_font = Fonts.kAgencyFB_Large  --assuming 1080p
	
	if (ScreenWidth <= 800) then
		team_name_font = Fonts.kAgencyFB_Tiny
		team_ready_font = Fonts.kAgencyFB_Small
	elseif (ScreenWidth <= 1280) then
		team_name_font = Fonts.kAgencyFB_Tiny
		team_ready_font = Fonts.kAgencyFB_Medium
	elseif (ScreenWidth <= 1600) then
		team_name_font = Fonts.kAgencyFB_Small
		team_ready_font = Fonts.kAgencyFB_Medium
	elseif (ScreenWidth <= 1920) then
		team_name_font = Fonts.kAgencyFB_Small
		team_ready_font = Fonts.kAgencyFB_Large
	end
	
	-- PARENT PANEL
	local BasePanel = SGUI:Create("Panel")
	BasePanel:SetAnchor ("TopLeft")
	BasePanel:SetSize(Vector(ScreenWidth * 0.35, ScreenHeight * 0.05, 0))
	local PanelSize = BasePanel:GetSize()	
	BasePanel:SetPos(Vector((ScreenWidth / 2) - (PanelSize.x / 2), ScreenHeight * 0.01, 0))
	BasePanel:SetColour(Colour(Colour( 0.49, 0.49, 0.49, 0.3 )))
	self.BasePanel = BasePanel	
	
	
	-- MARINE PANEL
	local MarinePanel = SGUI:Create( "Panel", BasePanel )
	MarinePanel:SetAnchor ("TopLeft")
	MarinePanel:SetSize(Vector((PanelSize.x/2) - (ScreenWidth * 0.003), PanelSize.y * 0.73, 0))
	local MarinePanelSize = MarinePanel:GetSize()	
	MarinePanel:SetPos(Vector(ScreenWidth * 0.003, (PanelSize.y/2) - (MarinePanelSize.y/2), 0))
	MarinePanel:SetColour(Colour(0.3, 0.69, 1.0, 0.3 ))
    self.MarinePanel = MarinePanel
	
	-- MARINE READY LABEL
	local MarineReadyLabel = SGUI:Create("Label", MarinePanel)
	MarineReadyLabel:SetAnchor("TopRight")
	MarineReadyLabel:SetFont(team_ready_font)
	MarineReadyLabel:SetText(ready_text[TEAM_MARINE])
	local MarineReadyLabelSize = MarineReadyLabel:GetSize()
	MarineReadyLabel:SetPos(Vector(-(MarineReadyLabelSize.x + ScreenWidth*0.003), (MarinePanelSize.y / 2) - (MarineReadyLabelSize.y / 2), 0))
	MarineReadyLabel:SetColour(Colors.White)
    self.MarineReadyLabel = MarineReadyLabel
	
	-- MARINE NAME LABEL
	local MarineNameLabel = SGUI:Create("Label", MarinePanel)
	MarineNameLabel:SetAnchor("TopLeft")
	MarineNameLabel:SetFont(team_name_font)
	MarineNameLabel:SetText(team_name[TEAM_MARINE])
	local MarineNameLabelSize = MarineNameLabel:GetSize()
	MarineNameLabel:SetPos( Vector(ScreenWidth*0.003, (MarinePanelSize.y / 2) - (MarineNameLabelSize.y / 2), 0))
	MarineNameLabel:SetColour(Colors.White)
    self.MarineNameLabel = MarineNameLabel
	
	
	-- ALIEN PANEL
	local AlienPanel = SGUI:Create( "Panel", BasePanel )
	AlienPanel:SetAnchor ("TopLeft")
	AlienPanel:SetSize(Vector((PanelSize.x/2) - (ScreenWidth * 0.0045), PanelSize.y * 0.73, 0))
	local AlienPanelSize = AlienPanel:GetSize()	
	AlienPanel:SetPos(Vector((ScreenWidth * 0.003) + (AlienPanelSize.x + ScreenWidth * 0.003), (PanelSize.y/2) - (AlienPanelSize.y/2), 0))
	AlienPanel:SetColour(Colour(1.0, 0.49, 0.0, 0.3 ))
    self.AlienPanel = AlienPanel
	
	--ALIEN READY LABEL
	local AlienReadyLabel = SGUI:Create("Label", AlienPanel)
	AlienReadyLabel:SetAnchor("TopLeft")
	AlienReadyLabel:SetFont(team_ready_font)
	AlienReadyLabel:SetText(ready_text[TEAM_ALIEN])
	local AlienReadyLabelSize = AlienReadyLabel:GetSize()
	AlienReadyLabel:SetPos( Vector(ScreenWidth*0.003, (AlienPanelSize.y / 2) - (AlienReadyLabelSize.y / 2), 0))
	AlienReadyLabel:SetColour(Colors.White)
	self.AlienReadyLabel = AlienReadyLabel

	--ALIEN NAME LABEL
	local AlienNameLabel = SGUI:Create("Label", AlienPanel)
	AlienNameLabel:SetAnchor("TopRight")
	AlienNameLabel:SetFont(team_name_font)
	AlienNameLabel:SetText(team_name[TEAM_ALIEN])
	local AlienNameLabelSize = AlienNameLabel:GetSize()
	AlienNameLabel:SetPos(Vector(-(AlienNameLabelSize.x + ScreenWidth*0.003), (AlienPanelSize.y / 2) - (AlienNameLabelSize.y / 2), 0))
	AlienNameLabel:SetColour(Colors.White)
	self.AlienNameLabel = AlienNameLabel

	status_menu_exists = true
end
function ReadyStatusMenu: Destroy()
	self.BasePanel: SetParent()
	self.BasePanel: Destroy()
	
	status_menu_exists = false
end
function ReadyStatusMenu: ToggleHide(bool)
	Print(string.format("SetIsVisible: %s", tostring(bool)))
	self.BasePanel: SetIsVisible(bool)
	--self:SetIsVisible (bool)
end
-- }}}

-- custom made log menu to allow for multiple colors
-- {{{ LogMenu
function LogMenu: Create()
	if (log_menu_exists) then LogMenu: Destroy() end
	
	local ScreenWidth = Client.GetScreenWidth()
	local ScreenHeight = Client.GetScreenHeight()
	local full_size = Vector(ScreenWidth * 0.29, ScreenHeight * 0.3, 0) --maximized
	
	if (ScreenWidth <= 1280 or ScreenHeight <= 720) then
		ScreenWidth = 1280
		ScreenHeight = 720
	end
	
	-- PARENT PANEL
	local BasePanel = SGUI:Create("Panel")
	BasePanel:SetAnchor ("TopLeft")
	BasePanel:SetSize	(full_size)
	
	local PanelSize = BasePanel:GetSize()
	BasePanel:SetPos	(Vector(Client.GetScreenWidth() * 0.015, Client.GetScreenHeight() * 0.08, 0)) --on the topleft
	--BasePanel:SetPos	(Vector((Client.GetScreenWidth()/2) - (PanelSize.x/2), (Client.GetScreenHeight()/2) - (PanelSize.y/2), 0)) --centered
	--BasePanel:SkinColour()
	BasePanel:SetColour (Colour(0.49, 0.49, 0.49, 0.45))
	BasePanel:SetDraggable(true)
	self.BasePanel = BasePanel
	local Skin = SGUI:GetSkin()
	
	
	-- TITLE BAR
	local TitlePanel = SGUI:Create( "Panel", BasePanel )
	TitlePanel:SetSize( Vector( PanelSize.x, ScreenHeight * 0.025, 0 ) )
	TitlePanel:SetColour (Colour(0.25, 0.25, 0.25, 0.78))
	TitlePanel:SetAnchor( "TopLeft" )
	local TitlePanelSize = TitlePanel:GetSize()
	
	local small_size = Vector(ScreenWidth * 0.29, TitlePanelSize.y, 0) --minimized
	
	if(minimized) then
		BasePanel:SetSize	(small_size)
	else
		BasePanel:SetSize	(full_size)
	end

	local CloseButton = SGUI:Create( "Button", BasePanel )
	CloseButton:SetSize( Vector( ScreenWidth * 0.012, ScreenHeight * 0.021, 0 ) )
	CloseButton:SetPos( Vector( -(ScreenWidth * 0.013), ScreenHeight * 0.002, 0 ) )
	CloseButton:SetText( "X" )
	CloseButton:SetAnchor( "TopRight" )
	CloseButton.UseScheme = false
	CloseButton:SetActiveCol( Skin.CloseButtonActive )
	CloseButton:SetInactiveCol( Skin.CloseButtonInactive )
	CloseButton:SetTextColour( Skin.BrightText )
	local CloseButtonSize = CloseButton:GetSize()

	function CloseButton.DoClick()
		LogMenu: Destroy()
	end 
	
	
	local MinMaxButton = SGUI:Create( "Button", BasePanel )
	MinMaxButton:SetSize( Vector( ScreenWidth * 0.012, ScreenHeight * 0.021, 0 ) )
	MinMaxButton:SetPos( Vector( -(ScreenWidth * 0.013) - (CloseButtonSize.x + (ScreenWidth * 0.003)), ScreenHeight * 0.002, 0 ) )
	MinMaxButton:SetText( "_" )
	MinMaxButton:SetAnchor( "TopRight" )
	MinMaxButton.UseScheme = false
	MinMaxButton:SetActiveCol( Skin.CloseButtonActive )
	MinMaxButton:SetInactiveCol( Skin.CloseButtonInactive )
	MinMaxButton:SetTextColour( Skin.BrightText )
	local MinMaxButtonSize = MinMaxButton:GetSize()

	function MinMaxButton.DoClick()
		--LogMenu: Destroy()
		minimized = not minimized
		
		if (minimized) then
			self.BasePanel:SetSize(small_size)
			self.ListPanel:SetIsVisible(false)
		else
			self.BasePanel:SetSize(full_size)
			self.ListPanel:SetIsVisible(true)
		end
	end
	
	
	local TitleLabel = SGUI:Create( "Label", TitlePanel )
	TitleLabel:SetAnchor( "CentreMiddle" )
	TitleLabel:SetFont( Fonts.kAgencyFB_Small )
	TitleLabel:SetText( "Log Window" )
	TitleLabel:SetTextAlignmentX( GUIItem.Align_Center )
	TitleLabel:SetTextAlignmentY( GUIItem.Align_Center )
	TitleLabel:SetPos( Vector( -18, 0, 0 ) )
	TitleLabel:SetColour( Skin.BrightText )
	
	log_menu_exists = true
end
function LogMenu: Destroy()
	self.BasePanel: SetParent()
	self.BasePanel: Destroy()
	
	log_menu_exists = false
end
function LogMenu: AddMessage(message)
	if (not log_menu_exists) then LogMenu: Create() end
	local time = os.date ("%H:%M:%S")
	message = string.format("%s  %s", time, message)
end
function LogMenu: ClearMessages()
end
--}}}

-- {{{ CommMenu
-- {{{ Create / Destroy
function CommMenu: Create(team)
	if(comm_menu_exists) then CommMenu: Destroy() end --we don't want duplicate menus opened 
	
	local ScreenWidth = Client.GetScreenWidth()
	local ScreenHeight = Client.GetScreenHeight()

    local BasePanelHeight = ScreenHeight * 0.085
	local TitlePanelHeight = ScreenHeight * 0.03

	-- PARENT PANEL
	local BasePanel = SGUI:Create("Panel")
	BasePanel:SetAnchor ("TopLeft")
	BasePanel:SetSize	(Vector(ScreenWidth * 0.14, BasePanelHeight, 0))
	local PanelSize = BasePanel:GetSize()		
	BasePanel:SetPos	(Vector((ScreenWidth/2) - (PanelSize.x/2), ScreenHeight * 0.75, 0))	
    --BasePanel:SetPos	(Vector (ScreenWidth * 0.78, 0.0, 0.0))
	--BasePanel:SetSize	(Vector (ScreenWidth * 0.22, ScreenHeight, 0.0))
	BasePanel:SetColour (Colour(0.49, 0.49, 0.49, 0.45))
    BasePanel:SetDraggable(true)
	self.BasePanel = BasePanel
	self.BasePanel = BasePanel
	
	-- TITLE BAR
	local TitlePanel = SGUI:Create( "Panel", BasePanel )
	TitlePanel:SetSize(Vector(PanelSize.x, TitlePanelHeight, 0))
	TitlePanel:SetColour(Skin.Panel.Gray)
	TitlePanel:SetAnchor("TopLeft")
	local TitlePanelSize = TitlePanel:GetSize()
	
	local TitleLabel = SGUI:Create("Label", TitlePanel)
	TitleLabel:SetAnchor("CentreMiddle")
	TitleLabel:SetFont(Fonts.kAgencyFB_Small)
	TitleLabel:SetText("I am okay commanding...")
	TitleLabel:SetTextAlignmentX(GUIItem.Align_Center)
	TitleLabel:SetTextAlignmentY(GUIItem.Align_Center)
	TitleLabel:SetPos(Vector( -18, 0, 0))
	TitleLabel:SetColour(Colors.White)

    local checkbox_offset = PanelSize.y * 0.075
    local checkbox_y = TitlePanelSize.y + checkbox_offset 

	-- MARINES CHECKBOX
	local MarinesCheckbox = SGUI:Create ("CheckBox", BasePanel)
	MarinesCheckbox:SetPos(Vector(PanelSize.x * 0.04, checkbox_y, 0))
	MarinesCheckbox:SetSize(Vector( 15, 15, 0))
	MarinesCheckbox:SetFont(Fonts.kAgencyFB_Small)
	MarinesCheckbox:SetAnchor("TopLeft")
	MarinesCheckbox:AddLabel("Marines")
	--MarinesCheckbox:SetCheckedColour( LayoutData.Colours.Checked )
	--MarinesCheckbox:SetBackgroundColour (LayoutData.Colours.CheckBack)
	MarinesCheckbox:SetChecked(false)
	MarinesCheckbox:SetTextColour (Colors.White)
	
	local MarinesCheckboxSize = MarinesCheckbox:GetSize()

	function MarinesCheckbox:OnChecked(value)	
        comm[TEAM_MARINE] = value
	end	
	self.MarinesCheckbox = MarinesCheckbox

    --checkbox_y = checkbox_y + MarinesCheckboxSize.y + checkbox_offset


	-- MARINES CHECKBOX
	local AliensCheckbox = SGUI:Create ("CheckBox", BasePanel)
	AliensCheckbox:SetPos(Vector( PanelSize.x * 0.55, checkbox_y, 0))
	AliensCheckbox:SetSize(Vector( 15, 15, 0))
	AliensCheckbox:SetFont(Fonts.kAgencyFB_Small)
	AliensCheckbox:SetAnchor("TopLeft")
	AliensCheckbox:AddLabel("Aliens")
	--AliensCheckbox:SetCheckedColour(LayoutData.Colours.Checked)
	--AliensCheckbox:SetBackgroundColour(LayoutData.Colours.CheckBack)
	AliensCheckbox:SetChecked(false)
	AliensCheckbox:SetTextColour(Colors.White)
	
	local AliensCheckboxSize = AliensCheckbox:GetSize()

	function AliensCheckbox:OnChecked(value)	
        comm[TEAM_ALIEN] = value
	end	
	self.AliensCheckbox = AliensCheckbox



    local ButtonPanel = SGUI:Create( "Panel", BasePanel )
	ButtonPanel:SetSize( Vector( PanelSize.x * 0.94, PanelSize.y * 0.2, 0 ) )
	--ButtonPanel:SetPos( Vector( 0, TitlePanelSize.y + MarinesCheckboxSize.y + (PanelSize.y * 0.2), 0 ) )
	local ButtonPanelSize = ButtonPanel:GetSize()
	ButtonPanel:SetPos( Vector( PanelSize.x * 0.03, -(ButtonPanelSize.y + PanelSize.y * 0.05), 0 ) )
	ButtonPanel:SetAnchor( "BottomLeft" )
	ButtonPanel:SetColour (Colour(0.49, 0.49, 0.49, 0.45))
	local ButtonPanelSize = ButtonPanel:GetSize()

    local AgreeButton = SGUI:Create("Button", ButtonPanel)
	AgreeButton:SetText("OK" )
	AgreeButton:SetAnchor("TopLeft")
	AgreeButton:SetSize(Vector( ButtonPanelSize.x, ButtonPanelSize.y, 0))
	AgreeButton:SetPos(Vector(0, 0, 0))
	AgreeButton.UseScheme = false
	AgreeButton:SetActiveCol(Skin.Button.ActiveCol)
	AgreeButton:SetInactiveCol(Skin.Button.InactiveCol)
	AgreeButton:SetTextColour(Skin.Button.ModeText)
	
	local AgreeButtonSize = AgreeButton:GetSize()
	function AgreeButton.DoClick()
        NetworkSend: SendClientCommResponse(comm[TEAM_MARINE], comm[TEAM_ALIEN])
        CommMenu: Destroy()
	end

	comm_menu_exists = true --record the menu being opened
end
function CommMenu: Destroy()
    if (not comm_menu_exists) then return end

	self.BasePanel: SetParent()
	self.BasePanel: Destroy()

	comm_menu_exists = false
end
-- }}}
-- }}}

--{{{ NetworkSend - ClientUpdateTeam
function NetworkSend: SendClientCommResponse(marine_response, alien_response)
    --Print(string.format("(CLIENT) marine: %s | alien: %s", tostring(marine_response), tostring(alien_response)))
    Plugin: SendNetworkMessage("ClientCommResponse", {marine = marine_response, alien = alien_response}, true)    
end
function NetworkSend: SendClientUpdateTeam()
    --Print(string.format("team_number: %i  |  name: %s  |  ready: %s", team, team_name[team], tostring(is_ready)))
    local rdy = is_ready == true and "4" or "3"
    --Print(string.format("%s %i", tostring(is_ready), rdy))
	Plugin: SendNetworkMessage("ClientUpdateTeam", {team_number = team, name = team_name[team], ready = rdy}, true)    
end

--}}}
--{{{NetworkReceive - SetCaptain / AddPlayer / RemovePlayer / CloseCaptainMenu / ServerAskComm
function Plugin: ReceiveSetCaptain(Message)
    team = Message.team
    CaptainMenu: Create()
end
function Plugin: ReceiveAddPlayer(Message)
   CaptainMenu: AddToList(Message.steamid, Message.name) 
end
function Plugin: ReceiveRemovePlayer(Message)
   CaptainMenu: RemoveFromList(Message.steamid, Message.name) 
end
function Plugin:ReceiveCloseCaptainMenu(Message)	
	CaptainMenu:Destroy()
end
function Plugin:ReceiveServerAskComm(Message)	
	--server asking us to command for Message.team_number
    CommMenu: Create() 
end
function Plugin:ReceiveServerSetCaptainCheckbox(Message)	
	CaptainMenu.ReadyCheckbox: SetChecked(false)
end
function Plugin:ReceiveServerUpdateTeam(Message)	
    if (self.dt.islive) then return end

	--server informing us about team status changes (name, ready)
    local ScreenWidth = Client.GetScreenWidth()
	local ScreenHeight = Client.GetScreenHeight()

    --Print(string.format("team:%i   |   ready %i", Message.team_number, Message.ready))

    if (not status_menu_exists) then ReadyStatusMenu:Create() end

    if (Message.team_number == TEAM_MARINE) then
        if (Message.ready == 4) then
            ReadyStatusMenu.MarineReadyLabel:SetText("READY") 
        elseif (Message.ready == 3) then
            ReadyStatusMenu.MarineReadyLabel:SetText("NOT READY") 
        elseif (Message.ready == 2) then
            ReadyStatusMenu.MarineReadyLabel:SetText("NEED COMM")
        elseif (Message.ready == 1) then
            ReadyStatusMenu.MarineReadyLabel:SetText("NEED CAPT")
        end
        
        local MarinePanelSize = ReadyStatusMenu.MarinePanel:GetSize()
        local MarineReadyLabelSize = ReadyStatusMenu.MarineReadyLabel:GetSize()
        ReadyStatusMenu.MarineReadyLabel:SetPos( Vector( -(MarineReadyLabelSize.x + ScreenWidth*0.003), (MarinePanelSize.y / 2) - (MarineReadyLabelSize.y / 2), 0 ) )


        ReadyStatusMenu.MarineNameLabel:SetText(Message.name)

    elseif (Message.team_number == TEAM_ALIEN) then
        if (Message.ready == 4) then
            ReadyStatusMenu.AlienReadyLabel:SetText("READY") 
        elseif (Message.ready == 3) then
            ReadyStatusMenu.AlienReadyLabel:SetText("NOT READY") 
        elseif (Message.ready == 2) then
            ReadyStatusMenu.AlienReadyLabel:SetText("NEED COMM")
        elseif (Message.ready == 1) then
            ReadyStatusMenu.AlienReadyLabel:SetText("NEED CAPT")
        end
        ReadyStatusMenu.AlienNameLabel:SetText(Message.name)

        local AlienPanelSize = ReadyStatusMenu.AlienPanel:GetSize()
        local AlienNameLabelSize = ReadyStatusMenu.AlienNameLabel:GetSize()
        ReadyStatusMenu.AlienNameLabel:SetPos( Vector( -(AlienNameLabelSize.x + ScreenWidth*0.003), (AlienPanelSize.y / 2) - (AlienNameLabelSize.y / 2), 0 ) )

        ReadyStatusMenu.AlienNameLabel:SetText(Message.name)
    end
end
function Plugin: ReceiveResetPlayerList(Message)
    CaptainMenu: ClearList()
end
--}}}

--{{{ Misc
function Plugin: KillUI()
    if (captain_menu_exists) then CaptainMenu: Destroy() end
    if (status_menu_exists) then ReadyStatusMenu: Destroy() end
    if (log_menu_exists) then LogMenu: Destroy() end
    if (comm_menu_exists) then CommMenu: Destroy() end
end
function Plugin: OpenUI()
    ReadyStatusMenu: Create()
end

function Plugin: Initialise()
	self.Enabled = true
    --CommMenu: Create("marine")
    --ReadyStatusMenu: Create()
	return true
end
function Plugin: Cleanup()
	Plugin: KillUI()
	self.BaseClass.Cleanup( self )
end

function Plugin:OnResolutionChanged()
	if(not self.dt.enabled) then return end

    if (captain_menu_exists) then CaptainMenu: Create() end
    if (status_menu_exists) then ReadyStatusMenu: Create() end
    if (log_menu_exists) then LogMenu: Create() end
    if (comm_menu_exists) then CommMenu: Create() end
end

Shine.VoteMenu:EditPage( "Main", function( self )
    self:AddSideButton( "Captain Menu", function()
		Shared.ConsoleCommand( string.format( "sh_cm_captain") )
    end )
end ) 
--}}}

