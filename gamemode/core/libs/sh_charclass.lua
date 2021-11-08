local CHAR = ix.meta.character
local META = META or {}

ix.charclass = ix.charclass or {}
ix.charclass.list = ix.charclass.list or {}

local function CreateDefaultCharclass(ident, index)
    return setmetatable({
        Name = ident,
        Team = index,
        DisplayName = "<unnamed>",
        DisplayDesc = "<this character class has no description>",
        DisplayColor = Color(100,100,255)
    }, {__index = META})
end

function ix.charclass.LoadFromDir(directory)
    for _, v in ipairs(file.Find(directory.."/*.lua", "LUA")) do
        -- Get the name without the "sh_" prefix and ".lua" suffix.
        local niceName = v:sub(4, -5)
        local index = table.Count(ix.charclass.list) + 1

        CHARCLASS = CreateDefaultCharclass(niceName, index)

        ix.util.Include(directory.."/"..v, "shared")

        team.SetUp(CHARCLASS.Team, CHARCLASS.DisplayName, CHARCLASS.DisplayColor)

        ix.charclass.list[niceName] = CHARCLASS
        CHARCLASS = nil

    end
end

function ix.charclass.Get(ident)
    return ix.charclass.list[ident]
end

function ix.charclass.GetPlayersOfClass(ident)
    local class = istable(ident) and ident or ix.charclass.list[ident]
    return class and team.GetPlayers(class.Team)
end

if SERVER then
    local function OnCharacterSwitch(ply, char_old, char_new)
        local class_old = char_old and char_old:GetCharClassTable()
        local class_new = char_new and char_new:GetCharClassTable()

        if class_old ~= nil and class_old.OnSwitchedFrom ~= nil then
            class_old:OnSwitchedFrom(char_old)
        end

        if class_new ~= nil and class_new.OnSwitchedTo ~= nil then
            class_new:OnSwitchedTo(char_new)
        end
    end

    hook.Add("PlayerLoadedCharacter", "NLS.CharClass", function(ply, char_new, char_old)
        OnCharacterSwitch(ply, char_old, char_new)
    end)

    hook.Add("OnCharacterDisconnect", "NLS.CharClass", function(ply, char)
        OnCharacterSwitch(ply, char, nil)
    end)

    hook.Add("PreCharacterDeleted", "NLS.CharClass", function(ply, char)
        OnCharacterSwitch(ply, char, nil)
    end)
end

-- function CHARCLASS:OnSwitchedTo(character)
-- function CHARCLASS:OnSwitchedFrom(character)
-- function CHARCLASS:GetDefaultName(ply)
-- function CHARCLASS:OnSpawn(ply)
-- CHARCLASS.DefaultWeapons = { "weapon_crowbar" }
-- function CHARCLASS:GetValidModels(ply)

-- PrePlayerLoadedCharacter
-- PlayerLoadedCharacter
-- CharacterLoaded
-- OnCharacterDisconnect
-- CharacterDeleted


function CHAR:GetCharClassTable()
    local ident = self:GetCharClass()
    return ident and ix.charclass.Get(ident)
end

function META:PickRandomModel(ply)
    if self.GetValidModels == nil then
        -- TODO: unrestricted picking
        Error("Unrestricted picking unimplemented")
        return
    end

    local models = self:GetValidModels(ply)

    return models[math.random(#models)]
end