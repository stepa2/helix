local CHAR = ix.meta.character

ix.charclass = ix.charclass or {}
ix.charclass.list = ix.charclass.list or {}

local function CreateDefaultCharclass(niceName)
    return {
        Name = niceName,
        DisplayName = "<unnamed>",
        DisplayDesc = "<this character class has no description>",
        DisplayColor = Color(100,100,255)
    }
end

function ix.charclass.LoadFromDir(directory)
    for _, v in ipairs(file.Find(directory.."/*.lua", "LUA")) do
        -- Get the name without the "sh_" prefix and ".lua" suffix.
        local niceName = v:sub(4, -5)


        CHARCLASS = CreateDefaultCharclass(niceName)

        ix.util.Include(directory.."/"..v, "shared")

        ix.charclass.list[niceName] = CHARCLASS
        CHARCLASS = nil

    end
end

function ix.charclass.Get(ident)
    return ix.charclass.list[ident]
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

ix.char.RegisterVar("CharClass", {
    field = "CharClass",
    fieldType = ix.type.string,
    OnValidate = function(self, value, all_values, ply)
        if ix.charclass.Get(value) == nil then
            return false, "incorrect", "charclass"
        end
    end
})

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