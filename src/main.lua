local mods = rom.mods
mods['SGG_Modding-ENVY'].auto()

---@diagnostic disable: lowercase-global
rom = rom
_PLUGIN = _PLUGIN
game = rom.game
modutil = mods['SGG_Modding-ModUtil']
chalk = mods['SGG_Modding-Chalk']
reload = mods['SGG_Modding-ReLoad']
local lib = mods['adamant-ModpackLib']

config = chalk.auto('config.lua')
public.config = config

local backup, revert = lib.createBackupSystem()

-- =============================================================================
-- UTILITIES
-- =============================================================================


local function DeepCompare(a, b)
    if a == b then return true end
    if type(a) ~= type(b) then return false end
    if type(a) ~= "table" then return false end
    for key, value in pairs(a) do
        if not DeepCompare(value, b[key]) then return false end
    end
    for key in pairs(b) do
        if a[key] == nil then return false end
    end
    return true
end

local function ListContainsEquivalent(list, template)
    if type(list) ~= "table" then return false end
    for _, entry in ipairs(list) do
        if DeepCompare(entry, template) then return true end
    end
    return false
end

-- =============================================================================
-- MODULE DEFINITION
-- =============================================================================

public.definition = {
    id       = "SeleneFix",
    name     = "Aspect of Selene Fix",
    category = "Bug Fixes",
    group    = "Weapons & Attacks",
    tooltip  = "Aspect of Selene properly registers its hex so you get offered PoS directly. Skyfall is full moonglow.",
    default  = true,
    dataMutation = true,
    modpack = "h2-modpack",
}

-- =============================================================================
-- MODULE LOGIC
-- =============================================================================

local function apply()
    backup(NamedRequirementsData, "SpellDropRequirements")
    local seleneReq = {
        PathFalse = { "CurrentRun", "Hero", "TraitDictionary", "SuitHexAspect" }
    }
    if not ListContainsEquivalent(NamedRequirementsData.SpellDropRequirements, seleneReq) then
        table.insert(NamedRequirementsData.SpellDropRequirements, seleneReq)
    end
end

local function registerHooks()
    modutil.mod.Path.Wrap("StartNewRun", function(baseFunc, prevRun, args)
        if not lib.isEnabled(config, public.definition.modpack) then return baseFunc(prevRun, args) end
        local currentRun = baseFunc(prevRun, args)
        if HeroHasTrait("SuitHexAspect") then
            RecordUse(nil, "SpellDrop")
        end
        return currentRun
    end)

    modutil.mod.Path.Wrap("SpawnRoomReward", function(base, eventSource, args)
        if not lib.isEnabled(config, public.definition.modpack) then return base(eventSource, args) end
        if HeroHasTrait("SuitHexAspect") and HeroHasTrait("SpellTalentKeepsake") and game.CurrentRun.CurrentRoom.BiomeStartRoom then
            args = args or {}
            if args.WaitUntilPickup then
                args.RewardOverride = "TalentDrop"
                args.LootName = nil
            end
        end
        return base(eventSource, args)
    end)
end

-- =============================================================================
-- Wiring
-- =============================================================================

public.definition.apply = apply
public.definition.revert = revert

local loader = reload.auto_single()

modutil.once_loaded.game(function()
    loader.load(function()
        import_as_fallback(rom.game)
        registerHooks()
        if lib.isEnabled(config, public.definition.modpack) then apply() end
        if public.definition.dataMutation and not lib.isCoordinated(public.definition.modpack) then
            SetupRunData()
        end
    end)
end)

local uiCallback = lib.standaloneUI(public.definition, config, apply, revert)
rom.gui.add_to_menu_bar(uiCallback)
