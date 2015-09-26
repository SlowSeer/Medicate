-----------------------------------------------------------------------------------------------
-- Client Lua Script for Medicate
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"
require "GameLib"
require "Unit"
require "Spell"


local mainWindow = ""
local strResource = ""

local batteryStyle = "_matte"

local restored = false

local myUserSettings = 
{
	--General Settings
	"setStyle",
	"setBatteryStyle",
	"setLock",
	"setShowFocusNumber",
	"setFocusNumberColor",
	"setFocusBarColor",
	"setPosY",
	"setPosX"
}

local Medicate = {}


function Medicate:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end


function Medicate:Init()
    Apollo.RegisterAddon(self, true, "Medicate", nil)
end


function Medicate:OnLoad()
	-- Wait for xml to load
	self.xmlDoc = XmlDoc.CreateFromFile("Medicate.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self)
	
	-- Register /medicate
	Apollo.RegisterSlashCommand("medicate", "SlashMedicate", self)
			
	-- Default Settings
	self:SetDefaults();
end


function Medicate:SetDefaults()		
	self.setStyle = 2; -- default style
	self.setBatteryStyle = 1;
	
	self.setShowFocusNumber = true;
	self.setFocusNumberColor = "FFFFFF";
	self.setFocusBarColor = "FFFFFF";
	self.setLock = false; -- false on initial load so it can be moved then locked.
end


function Medicate:OnSave(eType)
	if eType ~= GameLib.CodeEnumAddonSaveLevel.Character then return end

	local tSave = {}
	for idx,property in ipairs(myUserSettings) do tSave[property] = self[property] end

	return tSave
end


function Medicate:OnRestore(eType, t)
	for idx,property in ipairs(myUserSettings) do
		if t[property] ~= nil then self[property] = t[property] end
	end	
end


function Medicate:OnDocumentReady()
	if self.xmlDoc == nil then return end
	
	self.documentLoaded = true
	self:OnRequiredFlagsChanged()
end


function Medicate:OnRequiredFlagsChanged()
	if self.documentLoaded == true then
		if GameLib.GetPlayerUnit() then
			self:OnCharacterCreated()
		else
			Apollo.RegisterEventHandler("CharacterCreated", "OnCharacterCreated", self)
		end
	end
end


function Medicate:OnCharacterCreated()
	local unitPlayer = GameLib.GetPlayerUnit()
	
	-- Make sure we have a player and the player is a medic.
	if not unitPlayer or unitPlayer:GetClassId() ~= GameLib.CodeEnumClass.Medic then
		if self.wndMain then self.wndMain:Destroy() end
		return
	end
	
	Apollo.RegisterEventHandler("VarChange_FrameCount", "OnFrame", self)
	
    self.wndMain = Apollo.LoadForm(self.xmlDoc, "MedicResourceForm", nil, self)
	self.wndMain:ToFront()
    self.wndMain:Show(false)

	-- keep rReference to the main window.
	mainWindow = self.wndMain

	self.wndSettingsForm = Apollo.LoadForm(self.xmlDoc, "SettingsForm", nil, self)
	self.wndSettingsMain = Apollo.LoadForm(self.xmlDoc, "SettingsMain", self.wndSettingsForm:FindChild("SettingsContainer"), self)
	self.wndSettingsForm:Show(false)

	-- Load Styles
	Medicate:LoadStyle1()
	Medicate:LoadStyle2()

	--self:SettingsChanged()
	
	-- Set Bind Point
	local nLeft, nTop, nRight, nBottom = self.wndMain:GetRect()
	Apollo.SetGlobalAnchor("CastingBarBottom", 0.0, nTop - 15, true)
	
end


-- On Each Frame
function Medicate:OnFrame()

	-- First frame set-up, used because OnRestore is a bit iffy.
	if restored == false then 
		self:RefreshSettings()
		self:SettingsChanged() -- Sets restored to true.
		
		-- restore position
		if self.setPosX ~= nil and self.setPosY ~= nil then
			self.wndMain:SetAnchorOffsets(
				self.setPosX , 
				self.setPosY , 
				self.setPosX + self.wndMain:GetWidth(), 
				self.setPosY + self.wndMain:GetHeight())
		end
	end
		
	
	local unitPlayer = GameLib.GetPlayerUnit()
	
	if not unitPlayer then
		return
	elseif unitPlayer:GetClassId() ~= GameLib.CodeEnumClass.Medic then
		if self.wndMain then
			self.wndMain:Destroy()
		end
		return
	end

	if not self.wndMain:IsValid() then
		return
	end

	if not self.wndMain:IsVisible() then
		self.wndMain:Show(true)
	end

	if self.setStyle == 1 then
		self:DrawStyle1(unitPlayer) -- Style 1: Battery Pack
	else
		self:DrawStyle2(unitPlayer) -- Style 2: Eldan Cores
	end

	
	-- Resource 2 (Focus)
	local nFocusMax = unitPlayer:GetMaxFocus()
	local nFocusCurrent = unitPlayer:GetFocus()
	self.wndMain:FindChild("ManaProgressBar"):SetMax(nFocusMax)
	self.wndMain:FindChild("ManaProgressBar"):SetProgress(nFocusCurrent)
	if nManaCurrent == nManaMax then
		self.wndMain:FindChild("ManaProgressText"):SetText(nFocusMax)
	else
		--self.wndMain:FindChild("ManaProgressText"):SetText(string.format("%.02f/%s", nManaCurrent, nManaMax))
		self.wndMain:FindChild("ManaProgressText"):SetText(String_GetWeaselString(Apollo.GetString("Achievements_ProgressBarProgress"), math.floor(nFocusCurrent), nFocusMax))	
	end

	local strFocus = String_GetWeaselString(Apollo.GetString("Medic_FocusTooltip"), nFocusCurrent, nFocusMax)
	self.wndMain:FindChild("ManaProgressBar"):SetTooltip(string.format("<T Font=\"CRB_InterfaceSmall\">%s</T>", strFocus))
end


-- Settings have changed! Update the addon with the new settings.
-- Show/Hide the correct styles
function Medicate:SettingsChanged()
	-- Hide all styles
	mainWindow:FindChild("Style_1"):Show(false)
	mainWindow:FindChild("Style_2"):Show(false)
	self:EnableBatteryStyle(false)
	
	if self.setStyle == 1 then
		mainWindow:FindChild("Style_1"):Show(true)
		self:EnableBatteryStyle(true)
	else
		mainWindow:FindChild("Style_2"):Show(true)
	end

	
	if self.setBatteryStyle == 1 then
		batteryStyle = "_gloss";
	else
		batteryStyle = "_matte";
	end
	
	self.wndMain:FindChild("ManaProgressText"):Show(self.setShowFocusNumber)
	self.wndMain:FindChild("ManaProgressText"):SetTextColor(ApolloColor.new("FF" .. self.setFocusNumberColor))
	self.wndMain:FindChild("ManaProgressBar"):SetBarColor(ApolloColor.new("FF" .. self.setFocusBarColor))

	self.wndMain:SetStyle("Moveable", not self.setLock)
	self.wndMain:SetStyle("IgnoreMouse", self.setLock)
	
	restored = true;
end


-- Set-up the settings form on first frame to mirror the saved settings.
function Medicate:RefreshSettings()
	if self.setStyle == 1 then
		self.wndSettingsForm:FindChild("Button_Battery"):SetCheck(true)
	else
		self.wndSettingsForm:FindChild("Button_Eldan"):SetCheck(true)
	end

	
	if self.setBatteryStyle == 1 then
		self.wndSettingsForm:FindChild("Button_Battery_Gloss"):SetCheck(true)
	else
		self.wndSettingsForm:FindChild("Button_Battery_Matte"):SetCheck(true)
	end
	
	self.wndSettingsForm:FindChild("Button_ShowFocusNumber"):SetCheck(self.setShowFocusNumber)
	
	if self.setFocusNumberColor ~= nil then 
		self.wndSettingsForm:FindChild("Edit_FocusNumberColor"):SetText(self.setFocusNumberColor)
		self.wndSettingsForm:FindChild("Label_FocusNumberColor"):SetTextColor(ApolloColor.new("FF" .. self.setFocusNumberColor)) end
		
	if self.setFocusBarColor ~= nil then 
		self.wndSettingsForm:FindChild("Edit_FocusBarColor"):SetText(self.setFocusBarColor)
		self.wndSettingsForm:FindChild("Label_FocusBarColor"):SetTextColor(ApolloColor.new("FF" .. self.setFocusBarColor)) end
		
		self.wndSettingsForm:FindChild("Button_Lock"):SetCheck(self.setLock)
end


-- Enable battery style checkboxes only when selected.
function Medicate:EnableBatteryStyle(enabled)
	if enabled then
		self.wndSettingsForm:FindChild("BatteryStyleContainer"):Enable(true)
		self.wndSettingsForm:FindChild("BatteryStyleContainer"):SetOpacity(1)	
	else
		self.wndSettingsForm:FindChild("BatteryStyleContainer"):Enable(false)
		self.wndSettingsForm:FindChild("BatteryStyleContainer"):SetOpacity(0.2)
	end
end


function Medicate:OnConfigure()
	self:SlashMedicate()
end


function Medicate:SlashMedicate()
	self.wndSettingsForm:Show(true)
end


-----------------------------------------------------------------------------------------------
-- STYLE 1
-----------------------------------------------------------------------------------------------

function Medicate:LoadStyle1()
	local styleWnd = mainWindow:FindChild("Style_1")
	
	self.tCores1 = {} -- windows

	for idx = 1,4 do
		self.tCores1[idx] = { wnd = styleWnd:FindChild("ResourceContainer" .. idx) }
		self.tCores1[idx].wnd:SetTooltip(strResource)
	end
end

function Medicate:DrawStyle1(unitPlayer)
	local myCores = self.tCores1
	
	local nResourceCurr = unitPlayer:GetResource(1)
	local nResourceMax = unitPlayer:GetMaxResource(1)

	local myBuffs = unitPlayer:GetBuffs()
	local goodBuffs = myBuffs["arBeneficial"]
	local buffCount = 0
	
	--Event_FireGenericEvent("SendVarToRover", "goodBuffs ", goodBuffs)
	
	for key, value in pairs(goodBuffs) do
		if value["splEffect"]:GetId() == 42569 then -- POWER CHARGE = 42569 
			buffCount = value.nCount
		end
	end

	for idx = 1, #myCores do
		
		if idx <= nResourceCurr then
			myCores[idx].wnd:SetSprite("Battery_3" .. batteryStyle)
		else
			if idx == nResourceCurr + 1 then
				myCores[idx].wnd:SetSprite("Battery_" .. buffCount .. batteryStyle)
			else
				myCores[idx].wnd:SetSprite("Battery_0" .. batteryStyle)
			end
		end
	end	
end


-----------------------------------------------------------------------------------------------
-- STYLE 2
-----------------------------------------------------------------------------------------------

function Medicate:LoadStyle2()
	local styleWnd = mainWindow:FindChild("Style_2");
	
	self.tCores2 = {} -- windows
	
	for idx = 1,4 do
		self.tCores2[idx] = {
			wnd =  Apollo.LoadForm("Medicate.xml", "CoreStyle2",  styleWnd:FindChild("ResourceContainer" .. idx), self)			
		}
		self.tCores2[idx].wnd:SetTooltip(strResource)
		self.tCores2[idx].wnd:FindChild("ChargeBar"):SetMax(30)
		self.tCores2[idx].wnd:FindChild("ChargeBar"):SetProgress(0)
	end
end

function Medicate:DrawStyle2(unitPlayer)
	local myCores = self.tCores2
	
	local nResourceCurr = unitPlayer:GetResource(1)
	local nResourceMax = unitPlayer:GetMaxResource(1)

	local myBuffs = unitPlayer:GetBuffs()
	local buffCount = 0
	local goodBuffs = myBuffs["arBeneficial"]
	
	for key, value in pairs(goodBuffs) do
		if value["splEffect"]:GetId() == 42569 then -- POWER CHARGE = 42569 
			buffCount = value.nCount
		end
	end

	for idx = 1, #myCores do
		
		if idx <= nResourceCurr then
			myCores[idx].wnd:FindChild("On"):Show(true)
			myCores[idx].wnd:FindChild("ChargeBar"):SetProgress(29, 50)
		else
			myCores[idx].wnd:FindChild("On"):Show(false)
			
			if idx == nResourceCurr + 1 then
				myCores[idx].wnd:FindChild("ChargeBar"):SetProgress(buffCount*10, 50)
			else
				myCores[idx].wnd:FindChild("ChargeBar"):SetProgress(0, 90)
			end
		end
	end	
end


---------------------------------------------------------------------------------------------------
-- MedicResourceForm Functions
---------------------------------------------------------------------------------------------------

function Medicate:OpenSettings( wndHandler, wndControl, eMouseButton )
	self.wndSettingsForm:Show(not self.wndSettingsForm:IsShown())
end

function Medicate:CloseSettings( wndHandler, wndControl, eMouseButton )
	self.wndSettingsForm:Show(false)
end

function Medicate:WindowMove( wndHandler, wndControl, nOldLeft, nOldTop, nOldRight, nOldBottom )
	local myPos = { }
	myPos[1], myPos[2], myPos[3], myPos[4] = self.wndMain:GetAnchorOffsets()
	
	self.setPosX = myPos[1];
	self.setPosY = myPos[2];
end

---------------------------------------------------------------------------------------------------
-- SettingsMain Functions
---------------------------------------------------------------------------------------------------

-- ACTUATOR STYLE SETTINGS

function Medicate:Button_Eldan( wndHandler, wndControl, eMouseButton )
	self.setStyle = 2; self:SettingsChanged();
end

function Medicate:Button_Battery( wndHandler, wndControl, eMouseButton )
	self.setStyle = 1; self:SettingsChanged();
end

function Medicate:Button_Battery_Gloss( wndHandler, wndControl, eMouseButton )
	self.setBatteryStyle = 1; self:SettingsChanged();
end

function Medicate:Button_Battery_Matte( wndHandler, wndControl, eMouseButton )
	self.setBatteryStyle = 2; self:SettingsChanged();
end

-- FOCUS BAR SETTINGS

function Medicate:Button_ShowFocusNumber( wndHandler, wndControl, eMouseButton )
	self.setShowFocusNumber = wndControl:IsChecked(); self:SettingsChanged();
end

function Medicate:Edit_FocusNumberColor()
	local colorString = self.wndSettingsForm:FindChild("Edit_FocusNumberColor"):GetText()
	if string.len(colorString) > 6 then self.wndSettingsForm:FindChild("Edit_FocusNumberColor"):SetText(string.sub(colorString, 0, 6)) end	
	self.wndSettingsForm:FindChild("Label_FocusNumberColor"):SetTextColor(ApolloColor.new("FF"..colorString));
	self.setFocusNumberColor = colorString; self:SettingsChanged();
end

function Medicate:Edit_FocusBarColor()
	local colorString = self.wndSettingsForm:FindChild("Edit_FocusBarColor"):GetText()
	if string.len(colorString) > 6 then self.wndSettingsForm:FindChild("Edit_FocusBarColor"):SetText(string.sub(colorString, 0, 6)) end	
	self.wndSettingsForm:FindChild("Label_FocusBarColor"):SetTextColor(ApolloColor.new("FF"..colorString));
	self.setFocusBarColor = colorString; self:SettingsChanged();
end

function Medicate:Button_Lock( wndHandler, wndControl, eMouseButton )
	self.setLock = wndControl:IsChecked(); self:SettingsChanged();
end

-----------------------------------------------------------------------------------------------
-- Medicate Instance
-----------------------------------------------------------------------------------------------
local MedicateInst = Medicate:new()
MedicateInst:Init()
