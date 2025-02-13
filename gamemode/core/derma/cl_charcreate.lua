
local padding = ScreenScale(32)

-- create character panel
DEFINE_BASECLASS("ixCharMenuPanel")
local PANEL = {}

function PANEL:Init()
	local parent = self:GetParent()
	local halfWidth = parent:GetWide() * 0.5 - (padding * 2)
	local halfHeight = parent:GetTall() * 0.5 - (padding * 2)
	local modelFOV = (ScrW() > ScrH() * 1.8) and 100 or 78

	self:ResetPayload(true)

	self.charclassButtons = {}
	self.repopulatePanels = {}

	-- charclass selection subpanel
	self.charclassPanel = self:AddSubpanel("charclass", true)
	self.charclassPanel:SetTitle("chooseCharclass")
	self.charclassPanel.OnSetActive = function()
		-- if we only have one charclass, we are always selecting that one so we can skip to the description section
		if (#self.charclassButtons == 1) then
			self:SetActiveSubpanel("description", 0)
		end
	end

	local modelList = self.charclassPanel:Add("Panel")
	modelList:Dock(RIGHT)
	modelList:SetSize(halfWidth + padding * 2, halfHeight)

	local proceed = modelList:Add("ixMenuButton")
	proceed:SetText("proceed")
	proceed:SetContentAlignment(6)
	proceed:Dock(BOTTOM)
	proceed:SizeToContents()
	proceed.DoClick = function()
		self.progress:IncrementProgress()

		self:Populate()
		self:SetActiveSubpanel("description")
	end

	self.charclassModel = modelList:Add("ixModelPanel")
	self.charclassModel:Dock(FILL)
	self.charclassModel:SetModel("models/error.mdl")
	self.charclassModel:SetFOV(modelFOV)
	self.charclassModel.PaintModel = self.charclassModel.Paint

	self.charclassButtonsPanel = self.charclassPanel:Add("ixCharMenuButtonList")
	self.charclassButtonsPanel:SetWide(halfWidth)
	self.charclassButtonsPanel:Dock(FILL)

	local charclassBack = self.charclassPanel:Add("ixMenuButton")
	charclassBack:SetText("return")
	charclassBack:SizeToContents()
	charclassBack:Dock(BOTTOM)
	charclassBack.DoClick = function()
		self.progress:DecrementProgress()

		self:SetActiveSubpanel("charclass", 0)
		self:SlideDown()

		parent.mainPanel:Undim()
	end

	-- character customization subpanel
	self.description = self:AddSubpanel("description")
	self.description:SetTitle("chooseDescription")

	local descriptionModelList = self.description:Add("Panel")
	descriptionModelList:Dock(LEFT)
	descriptionModelList:SetSize(halfWidth, halfHeight)

	local descriptionBack = descriptionModelList:Add("ixMenuButton")
	descriptionBack:SetText("return")
	descriptionBack:SetContentAlignment(4)
	descriptionBack:SizeToContents()
	descriptionBack:Dock(BOTTOM)
	descriptionBack.DoClick = function()
		self.progress:DecrementProgress()

		if (#self.charclassButtons == 1) then
			charclassBack:DoClick()
		else
			self:SetActiveSubpanel("charclass")
		end
	end

	self.descriptionModel = descriptionModelList:Add("ixModelPanel")
	self.descriptionModel:Dock(FILL)
	self.descriptionModel:SetModel(self.charclassModel:GetModel())
	self.descriptionModel:SetFOV(modelFOV - 13)
	self.descriptionModel.PaintModel = self.descriptionModel.Paint

	self.descriptionPanel = self.description:Add("Panel")
	self.descriptionPanel:SetWide(halfWidth + padding * 2)
	self.descriptionPanel:Dock(RIGHT)

	local descriptionProceed = self.descriptionPanel:Add("ixMenuButton")
	descriptionProceed:SetText("proceed")
	descriptionProceed:SetContentAlignment(6)
	descriptionProceed:SizeToContents()
	descriptionProceed:Dock(BOTTOM)
	descriptionProceed.DoClick = function()
		if (self:VerifyProgression("description")) then
			-- there are no panels on the attributes section other than the create button, so we can just create the character
			if (#self.attributesPanel:GetChildren() < 2) then
				self:SendPayload()
				return
			end

			self.progress:IncrementProgress()
			self:SetActiveSubpanel("attributes")
		end
	end

	-- attributes subpanel
	self.attributes = self:AddSubpanel("attributes")
	self.attributes:SetTitle("chooseSkills")

	local attributesModelList = self.attributes:Add("Panel")
	attributesModelList:Dock(LEFT)
	attributesModelList:SetSize(halfWidth, halfHeight)

	local attributesBack = attributesModelList:Add("ixMenuButton")
	attributesBack:SetText("return")
	attributesBack:SetContentAlignment(4)
	attributesBack:SizeToContents()
	attributesBack:Dock(BOTTOM)
	attributesBack.DoClick = function()
		self.progress:DecrementProgress()
		self:SetActiveSubpanel("description")
	end

	self.attributesModel = attributesModelList:Add("ixModelPanel")
	self.attributesModel:Dock(FILL)
	self.attributesModel:SetModel(self.charclassModel:GetModel())
	self.attributesModel:SetFOV(modelFOV - 13)
	self.attributesModel.PaintModel = self.attributesModel.Paint

	self.attributesPanel = self.attributes:Add("Panel")
	self.attributesPanel:SetWide(halfWidth + padding * 2)
	self.attributesPanel:Dock(RIGHT)

	local create = self.attributesPanel:Add("ixMenuButton")
	create:SetText("finish")
	create:SetContentAlignment(6)
	create:SizeToContents()
	create:Dock(BOTTOM)
	create.DoClick = function()
		self:SendPayload()
	end

	-- creation progress panel
	self.progress = self:Add("ixSegmentedProgress")
	self.progress:SetBarColor(ix.config.Get("color"))
	self.progress:SetSize(parent:GetWide(), 0)
	self.progress:SizeToContents()
	self.progress:SetPos(0, parent:GetTall() - self.progress:GetTall())

	-- setup payload hooks
	self:AddPayloadHook("model", function(model)

		-- assuming bodygroups
		if (istable(model)) then
			self.charclassModel:SetModel(model[1], model[2] or 0, model[3])
			self.descriptionModel:SetModel(model[1], model[2] or 0, model[3])
			self.attributesModel:SetModel(model[1], model[2] or 0, model[3])
		elseif (isstring(model)) then
			self.charclassModel:SetModel(model)
			self.descriptionModel:SetModel(model)
			self.attributesModel:SetModel(model)
		else
			ErrorNoHalt("CharCreate: invalid model ",model," , key = ",value)
		end
	end)

	-- setup character creation hooks
	net.Receive("ixCharacterAuthed", function()
		timer.Remove("ixCharacterCreateTimeout")
		self.awaitingResponse = false

		local id = net.ReadUInt(32)
		local indices = net.ReadUInt(6)
		local charList = {}

		for _ = 1, indices do
			charList[#charList + 1] = net.ReadUInt(32)
		end

		ix.characters = charList

		self:SlideDown()

		if (!IsValid(self) or !IsValid(parent)) then
			return
		end

		if (LocalPlayer():GetCharacter()) then
			parent.mainPanel:Undim()
			parent:ShowNotice(2, L("charCreated"))
		elseif (id) then
			self.bMenuShouldClose = true

			net.Start("ixCharacterChoose")
				net.WriteUInt(id, 32)
			net.SendToServer()
		else
			self:SlideDown()
		end
	end)

	net.Receive("ixCharacterAuthFailed", function()
		timer.Remove("ixCharacterCreateTimeout")
		self.awaitingResponse = false

		local fault = net.ReadString()
		local args = net.ReadTable()

		self:SlideDown()

		parent.mainPanel:Undim()
		parent:ShowNotice(3, L(fault, unpack(args)))
	end)
end

function PANEL:SendPayload()
	if (self.awaitingResponse or !self:VerifyProgression()) then
		return
	end

	self.awaitingResponse = true

	timer.Create("ixCharacterCreateTimeout", 10, 1, function()
		if (IsValid(self) and self.awaitingResponse) then
			local parent = self:GetParent()

			self.awaitingResponse = false
			self:SlideDown()

			parent.mainPanel:Undim()
			parent:ShowNotice(3, L("unknownError"))
		end
	end)

	self.payload:Prepare()

	net.Start("ixCharacterCreate")
	net.WriteUInt(table.Count(self.payload), 8)

	for k, v in pairs(self.payload) do
		net.WriteString(k)
		net.WriteType(v)
	end

	net.SendToServer()
end

function PANEL:OnSlideUp()
	self:ResetPayload()
	self:Populate()
	self.progress:SetProgress(1)

	-- the charclass subpanel will skip to next subpanel if there is only one charclass to choose from,
	-- so we don't have to worry about it here
	self:SetActiveSubpanel("charclass", 0)
end

function PANEL:OnSlideDown()
end

function PANEL:ResetPayload(bWithHooks)
	if (bWithHooks) then
		self.hooks = {}
	end

	self.payload = {}

	-- TODO: eh..
	function self.payload.Set(payload, key, value)
		self:SetPayload(key, value)
	end

	function self.payload.AddHook(payload, key, callback)
		self:AddPayloadHook(key, callback)
	end

	function self.payload.Prepare(payload)
		self.payload.Set = nil
		self.payload.AddHook = nil
		self.payload.Prepare = nil
	end
end

function PANEL:SetPayload(key, value)
	self.payload[key] = value
	self:RunPayloadHook(key, value)
end

function PANEL:AddPayloadHook(key, callback)
	if (!self.hooks[key]) then
		self.hooks[key] = {}
	end

	self.hooks[key][#self.hooks[key] + 1] = callback
end

function PANEL:RunPayloadHook(key, value)
	local hooks = self.hooks[key] or {}

	for _, v in ipairs(hooks) do
		v(value)
	end
end

function PANEL:GetContainerPanel(name)
	-- TODO: yuck
	if (name == "description") then
		return self.descriptionPanel
	elseif (name == "attributes") then
		return self.attributesPanel
	end

	return self.descriptionPanel
end

function PANEL:AttachCleanup(panel)
	self.repopulatePanels[#self.repopulatePanels + 1] = panel
end

function PANEL:Populate()
	if (!self.bInitialPopulate) then
		-- setup buttons for the faction panel
		-- TODO: make this a bit less janky
		local lastSelected

		for _, v in pairs(self.charclassButtons) do
			if (v:GetSelected()) then
				lastSelected = v._charclass
			end

			if (IsValid(v)) then
				v:Remove()
			end
		end

		self.charclassButtons = {}

		for сс_ident, cc in SortedPairsByMemberValue(ix.charclass.list, "DisplayName") do
			local button = self.charclassButtonsPanel:Add("ixMenuSelectionButton")
			button:SetBackgroundColor(cc.DisplayColor or color_white)
			button:SetText(L(cc.DisplayName):utf8upper())
			button:SizeToContents()
			button:SetButtonList(self.charclassButtons)
			button._charclass = сс_ident
			button.OnSelected = function(panel)
				self.payload:Set("CharClass", panel._charclass)
				self.payload:Set("model", cc:PickRandomModel(LocalPlayer()))
			end

			if ((lastSelected and lastSelected == сс_ident) or (!lastSelected and cc.IsDefault)) then
				button:SetSelected(true)
				lastSelected = сс_ident
			end
		end
	end

	-- remove panels created for character vars
	for i = 1, #self.repopulatePanels do
		self.repopulatePanels[i]:Remove()
	end

	self.repopulatePanels = {}

	-- payload is empty because we attempted to send it - for whatever reason we're back here again so we need to repopulate
	if (!self.payload["CharClass"]) then
		for _, v in pairs(self.charclassButtons) do
			if (v:GetSelected()) then
				v:SetSelected(true)
				break
			end
		end
	end

	self.charclassButtonsPanel:SizeToContents()

	local zPos = 1

	-- set up character vars
	for k, v in SortedPairsByMemberValue(ix.char.vars, "index") do
		if (!v.bNoDisplay and k != "__SortedIndex") then
			local container = self:GetContainerPanel(v.category or "description")

			if (v.ShouldDisplay and v:ShouldDisplay(container, self.payload) == false) then
				continue
			end

			local panel

			-- if the var has a custom way of displaying, we'll use that instead
			if (v.OnDisplay) then
				panel = v:OnDisplay(container, self.payload)
			elseif (isstring(v.default)) then
				panel = container:Add("ixTextEntry")
				panel:Dock(TOP)
				panel:SetFont("ixMenuButtonHugeFont")
				panel:SetUpdateOnType(true)
				panel.OnValueChange = function(this, text)
					self.payload:Set(k, text)
				end
			end

			if (IsValid(panel)) then
				-- add label for entry
				local label = container:Add("DLabel")
				label:SetFont("ixMenuButtonLabelFont")
				label:SetText(L(k):utf8upper())
				label:SizeToContents()
				label:DockMargin(0, 16, 0, 2)
				label:Dock(TOP)

				-- we need to set the docking order so the label is above the panel
				label:SetZPos(zPos - 1)
				panel:SetZPos(zPos)

				self:AttachCleanup(label)
				self:AttachCleanup(panel)

				if (v.OnPostSetup) then
					v:OnPostSetup(panel, self.payload)
				end

				zPos = zPos + 2
			end
		end
	end

	if (!self.bInitialPopulate) then
		-- setup progress bar segments
		if (#self.charclassButtons > 1) then
			self.progress:AddSegment("@charclass")
		end

		self.progress:AddSegment("@description")

		if (#self.attributesPanel:GetChildren() > 1) then
			self.progress:AddSegment("@skills")
		end

		-- we don't need to show the progress bar if there's only one segment
		if (#self.progress:GetSegments() == 1) then
			self.progress:SetVisible(false)
		end
	end

	self.bInitialPopulate = true
end

function PANEL:VerifyProgression(name)
	for k, v in SortedPairsByMemberValue(ix.char.vars, "index") do
		if (name ~= nil and (v.category or "description") != name) then
			continue
		end

		local value = self.payload[k]

		if (!v.bNoDisplay or v.OnValidate) then
			if (v.OnValidate) then
				local result = {v:OnValidate(value, self.payload, LocalPlayer())}

				if (result[1] == false) then
					self:GetParent():ShowNotice(3, L(unpack(result, 2)))
					return false
				end
			end

			self.payload[k] = value
		end
	end

	return true
end

function PANEL:Paint(width, height)
	derma.SkinFunc("PaintCharacterCreateBackground", self, width, height)
	BaseClass.Paint(self, width, height)
end

vgui.Register("ixCharMenuNew", PANEL, "ixCharMenuPanel")
