local rowPaintFunctions = {
	function(width, height)
	end,

	function(width, height)
		surface.SetDrawColor(30, 30, 30, 25)
		surface.DrawRect(0, 0, width, height)
	end
}

-- character icon
-- we can't customize the rendering of ModelImage so we have to do it ourselves
local PANEL = {}
local BODYGROUPS_EMPTY = "000000000"

AccessorFunc(PANEL, "model", "Model", FORCE_STRING)
AccessorFunc(PANEL, "bHidden", "Hidden", FORCE_BOOL)

function PANEL:Init()
	self:SetSize(64, 64)
	self.bodygroups = BODYGROUPS_EMPTY
end

function PANEL:SetModel(model, skin, bodygroups)
	model = model:gsub("\\", "/")

	if (isstring(bodygroups)) then
		if (bodygroups:len() == 9) then
			for i = 1, bodygroups:len() do
				self:SetBodygroup(i, tonumber(bodygroups[i]) or 0)
			end
		else
			self.bodygroups = BODYGROUPS_EMPTY
		end
	end

	self.model = model
	self.skin = skin
	self.path = "materials/spawnicons/" ..
		model:sub(1, #model - 4) .. -- remove extension
		((isnumber(skin) and skin > 0) and ("_skin" .. tostring(skin)) or "") .. -- skin number
		(self.bodygroups != BODYGROUPS_EMPTY and ("_" .. self.bodygroups) or "") .. -- bodygroups
		".png"

	local material = Material(self.path, "smooth")

	-- we don't have a cached spawnicon texture, so we need to forcefully generate one
	if (material:IsError()) then
		self.id = "ixScoreboardIcon" .. self.path
		self.renderer = self:Add("ModelImage")
		self.renderer:SetVisible(false)
		self.renderer:SetModel(model, skin, self.bodygroups)
		self.renderer:RebuildSpawnIcon()

		-- this is the only way to get a callback for generated spawn icons, it's bad but it's only done once
		hook.Add("SpawniconGenerated", self.id, function(lastModel, filePath, modelsLeft)
			filePath = filePath:gsub("\\", "/"):lower()

			if (filePath == self.path) then
				hook.Remove("SpawniconGenerated", self.id)

				self.material = Material(filePath, "smooth")
				self.renderer:Remove()
			end
		end)
	else
		self.material = material
	end
end

function PANEL:SetBodygroup(k, v)
	if (k < 0 or k > 8 or v < 0 or v > 9) then
		return
	end

	self.bodygroups = self.bodygroups:SetChar(k + 1, v)
end

function PANEL:GetModel()
	return self.model or "models/error.mdl"
end

function PANEL:GetSkin()
	return self.skin or 1
end

function PANEL:DoClick()
end

function PANEL:DoRightClick()
end

function PANEL:OnMouseReleased(key)
	if (key == MOUSE_LEFT) then
		self:DoClick()
	elseif (key == MOUSE_RIGHT) then
		self:DoRightClick()
	end
end

function PANEL:Paint(width, height)
	if (!self.material) then
		return
	end

	surface.SetMaterial(self.material)
	surface.SetDrawColor(self.bHidden and color_black or color_white)
	surface.DrawTexturedRect(0, 0, width, height)
end

function PANEL:Remove()
	if (self.id) then
		hook.Remove("SpawniconGenerated", self.id)
	end
end

vgui.Register("ixScoreboardIcon", PANEL, "Panel")

-- player row
PANEL = {}

AccessorFunc(PANEL, "paintFunction", "BackgroundPaintFunction")

function PANEL:Init()
	self:SetTall(64)

	self.icon = self:Add("ixScoreboardIcon")
	self.icon:Dock(LEFT)
	self.icon.DoRightClick = function()
		local client = self.player

		if (!IsValid(client)) then
			return
		end

		local menu = DermaMenu()

		menu:AddOption(L("viewProfile"), function()
			client:ShowProfile()
		end)

		menu:AddOption(L("copySteamID"), function()
			SetClipboardText(client:IsBot() and client:EntIndex() or client:SteamID())
		end)

		hook.Run("PopulateScoreboardPlayerMenu", client, menu)
		menu:Open()
	end

	self.icon:SetHelixTooltip(function(tooltip)
		local client = self.player

		if (IsValid(self) and IsValid(client)) then
			ix.hud.PopulatePlayerTooltip(tooltip, client)
		end
	end)

	self.name = self:Add("DLabel")
	self.name:DockMargin(4, 4, 0, 0)
	self.name:Dock(TOP)
	self.name:SetTextColor(color_white)
	self.name:SetFont("ixGenericFont")

	self.description = self:Add("DLabel")
	self.description:DockMargin(5, 0, 0, 0)
	self.description:Dock(TOP)
	self.description:SetTextColor(color_white)
	self.description:SetFont("ixSmallFont")

	self.paintFunction = rowPaintFunctions[1]
	self.nextThink = CurTime() + 1
end

function PANEL:Update()
	local client = self.player
	local model = client:GetModel()
	local skin = client:GetSkin()
	local name = client:GetName()
	local description = hook.Run("GetCharacterDescription", client) or
		(client:GetCharacter() and client:GetCharacter():GetDescription()) or ""

	local bRecognize = false
	local localCharacter = LocalPlayer():GetCharacter()
	local character = IsValid(self.player) and self.player:GetCharacter()

	if (localCharacter and character) then
		bRecognize = hook.Run("IsCharacterRecognized", localCharacter, character:GetID())
			or hook.Run("IsPlayerRecognized", self.player)
	end

	self.icon:SetHidden(!bRecognize)
	self:SetZPos(bRecognize and 1 or 2)

	-- no easy way to check bodygroups so we'll just set them anyway
	for _, v in pairs(client:GetBodyGroups()) do
		self.icon:SetBodygroup(v.id, client:GetBodygroup(v.id))
	end

	if (self.icon:GetModel() != model or self.icon:GetSkin() != skin) then
		self.icon:SetModel(model, skin)
		self.icon:SetTooltip(nil)
	end

	if (self.name:GetText() != name) then
		self.name:SetText(name)
		self.name:SizeToContents()
	end

	if (self.description:GetText() != description) then
		self.description:SetText(description)
		self.description:SizeToContents()
	end
end

function PANEL:Think()
	if (CurTime() >= self.nextThink) then
		local client = self.player

		if (!IsValid(client) or !client:GetCharacter() or self.character != client:GetCharacter() or self.team != client:Team()) then
			self:Remove()
			self:GetParent():SizeToContents()
		end

		self.nextThink = CurTime() + 1
	end
end

function PANEL:SetPlayer(client)
	self.player = client
	self.team = client:Team()
	self.character = client:GetCharacter()

	self:Update()
end

function PANEL:Paint(width, height)
	self.paintFunction(width, height)
end

vgui.Register("ixScoreboardRow", PANEL, "EditablePanel")

-- charclass grouping
PANEL = {}

AccessorFunc(PANEL, "_charclass", "Charclass")

function PANEL:Init()
	self:DockMargin(0, 0, 0, 16)
	self:SetTall(32)

	self.nextThink = 0
end

function PANEL:AddPlayer(client, index)
	if (!IsValid(client) or !client:GetCharacter() or hook.Run("ShouldShowPlayerOnScoreboard", client) == false) then
		return false
	end

	local id = index % 2 == 0 and 1 or 2
	local panel = self:Add("ixScoreboardRow")
	panel:SetPlayer(client)
	panel:Dock(TOP)
	panel:SetZPos(2)
	panel:SetBackgroundPaintFunction(rowPaintFunctions[id])

	self:SizeToContents()
	client.ixScoreboardSlot = panel

	return true
end

function PANEL:SetCharclass(charclass)
	self:SetColor(charclass.DisplayColor)
	self:SetText(L(charclass.DisplayName))

	self._charclass = charclass
end

function PANEL:Update()
	local charclass = self._charclass
	local players = ix.charclass.GetPlayersOfClass(charclass)

	if #players == 0 then
		self:SetVisible(false)
		self:GetParent():InvalidateLayout()
	else
		local bHasPlayers

		for k, v in ipairs(players) do
			if (IsValid(v.ixScoreboardSlot)) then
				v.ixScoreboardSlot:Update()
				bHasPlayers = true
			elseif (self:AddPlayer(v, k)) then
				bHasPlayers = true
			end
		end

		self:SetVisible(bHasPlayers)
	end
end

vgui.Register("ixScoreboardCharclass", PANEL, "ixCategoryPanel")

-- main scoreboard panel
PANEL = {}

function PANEL:Init()
	if (IsValid(ix.gui.scoreboard)) then
		ix.gui.scoreboard:Remove()
	end

	self:Dock(FILL)

	local charclasses_sorted = {}
	for _, class in SortedPairs(ix.charclass.list) do
		table.insert(charclasses_sorted, class)
	end

	self.SubPanels = {}
	self.nextThink = 0

	for i, charclass in ipairs(charclasses_sorted) do
		local panel = self:Add("ixScoreboardCharclass")
		panel:SetCharclass(charclass)
		panel:Dock(TOP)

		self.SubPanels[i] = panel
	end

	ix.gui.scoreboard = self
end

function PANEL:Think()
	if (CurTime() >= self.nextThink) then
		for i, panel in ipairs(self.SubPanels) do
			panel:Update()
		end

		self.nextThink = CurTime() + 0.5
	end
end

vgui.Register("ixScoreboard", PANEL, "DScrollPanel")

hook.Add("CreateMenuButtons", "ixScoreboard", function(tabs)
	tabs["scoreboard"] = function(container)
		container:Add("ixScoreboard")
	end
end)
