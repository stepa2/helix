
local PLUGIN = PLUGIN

PLUGIN.name = "Spawns"
PLUGIN.description = "Spawn points for factions."
PLUGIN.author = "Chessnut"
PLUGIN.spawns = PLUGIN.spawns or {}

function PLUGIN:PlayerLoadout(client)
	local character = client:GetCharacter()

	if (self.spawns and !table.IsEmpty(self.spawns) and character) then
		local points

		for k, v in ipairs(ix.faction.indices) do
			if (k == client:Team()) then
				points = self.spawns[v.uniqueID] or {}

				break
			end
		end

		if (points) then
			points = points["default"]

			if (points and !table.IsEmpty(points)) then
				local position = table.Random(points)

				client:SetPos(position)
			end
		end
	end
end

function PLUGIN:LoadData()
	self.spawns = self:GetData() or {}
end

function PLUGIN:SaveSpawns()
	self:SetData(self.spawns)
end

ix.command.Add("SpawnAdd", {
	description = "@cmdSpawnAdd",
	privilege = "Manage Spawn Points",
	adminOnly = true,
	arguments = {
		ix.type.string
	},
	OnRun = function(self, client, name)
		local info = ix.faction.indices[name:lower()]
		local info2
		local faction

		if (!info) then
			for _, v in ipairs(ix.faction.indices) do
				if (ix.util.StringMatches(v.uniqueID, name) or ix.util.StringMatches(L(v.name, client), name)) then
					faction = v.uniqueID
					info = v

					break
				end
			end
		end

		if (info) then
			PLUGIN.spawns[faction] = PLUGIN.spawns[faction] or {}
			PLUGIN.spawns[faction].default = PLUGIN.spawns[faction].default or {}

			table.insert(PLUGIN.spawns[faction].default, client:GetPos())

			PLUGIN:SaveSpawns()

			name = L(info.name, client)

			if (info2) then
				name = name .. " (" .. L(info2.name, client) .. ")"
			end

			return "@spawnAdded", name
		else
			return "@invalidFaction"
		end
	end
})

ix.command.Add("SpawnRemove", {
	description = "@cmdSpawnRemove",
	privilege = "Manage Spawn Points",
	adminOnly = true,
	arguments = bit.bor(ix.type.number, ix.type.optional),
	OnRun = function(self, client, radius)
		radius = radius or 120

		local position = client:GetPos()
		local i = 0

		for _, v in pairs(PLUGIN.spawns) do
			for _, v2 in pairs(v) do
				for k3, v3 in pairs(v2) do
					if (v3:Distance(position) <= radius) then
						v2[k3] = nil
						i = i + 1
					end
				end
			end
		end

		if (i > 0) then
			PLUGIN:SaveSpawns()
		end

		return "@spawnDeleted", i
	end
})
