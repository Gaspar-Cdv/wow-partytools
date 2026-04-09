------------------------
--- Utils functions
------------------------

local BUTTON_SIZE = 20
local BUTTON_SPACING = 6
local FRAME_PADDING = 16

local function CreateMovableFrame(name, width, height, point, relativeTo, relativePoint, x, y)
	local frame = CreateFrame("Frame", name, UIParent, "BackdropTemplate")
	frame:SetSize(width, height)
	frame:SetPoint(point, relativeTo, relativePoint, x, y)
	frame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
	frame:SetBackdropColor(0.08, 0.08, 0.08, 0.85)
	frame:SetMovable(true)
	frame:SetClampedToScreen(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
	return frame
end

local function CreateButton(parent, texture, xOffset, template)
	local button = CreateFrame("Button", nil, parent, template or "BackdropTemplate")
	button:SetSize(BUTTON_SIZE, BUTTON_SIZE)
	button:SetNormalTexture(texture)

    button:RegisterForClicks("LeftButtonDown", "RightButtonDown")

	if not parent._lastButton then
		button:SetPoint("LEFT", parent, "LEFT", xOffset or BUTTON_SPACING, 0)
	else
		button:SetPoint("LEFT", parent._lastButton, "RIGHT", xOffset or BUTTON_SPACING, 0)
	end

	parent._lastButton = button
	return button
end

local function getContainerSize(numberOfItems)
    return (numberOfItems * BUTTON_SIZE) + (numberOfItems * BUTTON_SPACING) + (2 * FRAME_PADDING)
end

------------------------
--- World markers bar
------------------------

local worldFrame = CreateMovableFrame("PartyToolsWorldMarkersFrame", getContainerSize(9), 36, "TOPLEFT", UIParent, "TOPLEFT", 0, 0)

local worldMarkers = {
	{ marker = 1, tex = {0.25, 0.5, 0.25, 0.5} }, -- Square
	{ marker = 2, tex = {0.75, 1, 0, 0.25} },    -- Triangle
	{ marker = 3, tex = {0.5, 0.75, 0, 0.25} },  -- Diamond
	{ marker = 4, tex = {0.5, 0.75, 0.25, 0.5} },-- Cross
	{ marker = 5, tex = {0, 0.25, 0, 0.25} },    -- Star
	{ marker = 6, tex = {0.25, 0.5, 0, 0.25} },  -- Circle
	{ marker = 7, tex = {0, 0.25, 0.25, 0.5} },  -- Moon
	{ marker = 8, tex = {0.75, 1, 0.25, 0.5} },  -- Skull
}

for index, data in ipairs(worldMarkers) do
	local offset = BUTTON_SPACING
    if index == 1 then
        offset = offset + FRAME_PADDING
    end
	local button = CreateButton(worldFrame, "Interface\\TargetingFrame\\UI-RaidTargetingIcons", offset, "SecureActionButtonTemplate")

    button:SetNormalTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
    button:GetNormalTexture():SetTexCoord(unpack(data.tex))

	button:SetAttribute("type1", "worldmarker")
	button:SetAttribute("marker1", data.marker)
	button:SetAttribute("action1", "set")

	button:SetAttribute("type2", "worldmarker")
	button:SetAttribute("marker2", data.marker)
	button:SetAttribute("action2", "clear")
end

local clearWorldMarkers = CreateButton(
	worldFrame,
	"Interface\\AddOns\\PartyTools\\img\\icon_reset.tga",
	6,
	"SecureActionButtonTemplate"
)
clearWorldMarkers:SetAttribute("type1", "worldmarker")
clearWorldMarkers:SetAttribute("marker1", "all")
clearWorldMarkers:SetAttribute("action1", "clear")

------------------------
--- Tools bar
------------------------

local toolsFrame = CreateMovableFrame("PartyToolsRaidToolsFrame", getContainerSize(4), 36, "TOPLEFT", worldFrame, "TOPRIGHT", 2, 0)

-- Ready Check
local readyCheckBtn = CreateButton(toolsFrame, "Interface\\RaidFrame\\ReadyCheck-Waiting", FRAME_PADDING)
readyCheckBtn:SetScript("OnClick", DoReadyCheck)

-- Role Check
local roleCheckBtn = CreateButton(toolsFrame, "Interface\\AddOns\\PartyTools\\img\\icon_roleCheck.tga")
roleCheckBtn:SetScript("OnClick", InitiateRolePoll)

-- Assign Tank Icon
local assignTankIconBtn = CreateButton(toolsFrame, "Interface\\AddOns\\PartyTools\\img\\icon_mainTank.tga", BUTTON_SPACING, "SecureActionButtonTemplate")

assignTankIconBtn:SetAttribute("type1", "macro")
assignTankIconBtn:SetAttribute("type2", "macro")

-- Countdown
local countdownBtn = CreateButton(toolsFrame, "Interface\\AddOns\\PartyTools\\img\\icon_timer.tga")
countdownBtn:SetScript("OnClick", function(self, button)
       if button == "LeftButton" then
	       C_PartyInfo.DoCountdown(10)
       elseif button == "RightButton" then
	       C_PartyInfo.DoCountdown(0)
       end
end)

------------------------
--- Events
------------------------

-- Update the tank icon macro to target the first tank in the group
local function UpdateTankMacro()
    if not IsInGroup() then
        return
    end

    local groupType = IsInRaid() and "raid" or "party"
    local numGroup = IsInRaid() and GetNumGroupMembers() or GetNumSubgroupMembers()
    local tank1, tank2

    if not IsInRaid() and GetNumGroupMembers() ~= GetNumSubgroupMembers() and UnitGroupRolesAssigned("player") == "TANK" then
        -- it may happen that the current player is not part of the subgroup
        tank1 = "player"
    end

    for i = 1, numGroup do
        local unit = groupType .. i
        if UnitGroupRolesAssigned(unit) == "TANK" then
            if not tank1 then
                tank1 = unit
            else
                tank2 = unit
                break
            end
        end
    end

    local leftClickMacros = {}
    local rightClickMacros = {}

    if tank1 then
        table.insert(leftClickMacros, "/targetmarker [@" .. tank1 .. "] 6")
        table.insert(rightClickMacros, "/targetmarker [@" .. tank1 .. "] 0")
    end

    if tank2 then
        table.insert(leftClickMacros, "/targetmarker [@" .. tank2 .. "] 2")
        table.insert(rightClickMacros, "/targetmarker [@" .. tank2 .. "] 0")
    end

    assignTankIconBtn:SetAttribute("macrotext1", table.concat(leftClickMacros, "\n"))
    assignTankIconBtn:SetAttribute("macrotext2", table.concat(rightClickMacros, "\n"))
end

-- Show/hide frames based on group status
local function UpdatePartyToolsVisibility()
	if IsInGroup() or IsInRaid() then
		worldFrame:Show()
		toolsFrame:Show()
	else
		worldFrame:Hide()
		toolsFrame:Hide()
	end
end

-- Register events
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:SetScript("OnEvent", function()
    UpdatePartyToolsVisibility()
    UpdateTankMacro()
end)

-- Hide the default raid frame manager
hooksecurefunc("CompactRaidFrameManager_UpdateShown", function()
    if CompactRaidFrameManager then
        local isProtected = CompactRaidFrameManager:IsProtected()
        if not isProtected then
        CompactRaidFrameManager:Hide()
        end
    end
end)
