-- Pardona's UI – Frame-Analyse (/pui frames [modul])
-- Schreibt je Modul einen Abschnitt nach PardonasUIDB.debug[modul] (nur dieser Abschnitt wird
-- überschrieben). Grundlage für die Skins: welche Frames, Regionen und Funktionen der
-- Forever-Client tatsächlich hat. Nur lesend, alles in pcall; Werte werden nur per
-- type()/tostring() aufgenommen, nie verrechnet oder verglichen.

local _, ns = ...
local L = ns.L

local MAX_REGIONS = 40
local MAX_CHILDREN = 40
local MAX_DEPTH = 2     -- 0 = Kandidat, 1 = Kinder, 2 = Enkel (deren Kinder nur Typ/Name)

local ORDER = { "minimap", "auras", "loot", "grouploot", "trade" }

local CANDIDATES = {
    minimap = {
        "Minimap", "MinimapCluster", "MinimapBackdrop", "MinimapBorder", "MinimapBorderTop",
        "MinimapCompassTexture", "MinimapCluster.BorderTop", "MinimapCluster.ZoneTextButton",
        "MinimapZoneText", "MinimapZoneTextButton", "MinimapCluster.Tracking", "MiniMapTracking",
        "MiniMapTrackingButton", "MinimapCluster.IndicatorFrame", "MinimapCluster.IndicatorFrame.MailFrame",
        "MiniMapMailFrame", "GameTimeFrame", "TimeManagerClockButton", "Minimap.ZoomIn", "Minimap.ZoomOut",
        "MinimapZoomIn", "MinimapZoomOut", "MiniMapWorldMapButton", "ExpansionLandingPageMinimapButton",
        "AddonCompartmentFrame", "QueueStatusButton", "MiniMapLFGFrame",
    },
    auras = {
        "BuffFrame", "BuffFrame.AuraContainer", "DebuffFrame", "DebuffFrame.AuraContainer",
        "TemporaryEnchantFrame", "BuffButton1", "DebuffButton1", "TempEnchant1",
        "BuffFrame.auraFrames.1", "BuffFrame.auraFrames.2",
        "DebuffFrame.auraFrames.1", "DebuffFrame.auraFrames.2",
    },
    loot = {
        "LootFrame", "LootFrame.NineSlice", "LootFrame.ScrollBox", "LootFrame.TitleContainer",
        "LootButton1", "LootFrameInset",
    },
    grouploot = {
        "GroupLootContainer", "GroupLootFrame1", "GroupLootFrame1.Timer", "GroupLootFrame1.IconFrame",
        "GroupLootFrame1.NeedButton", "GroupLootFrame1.GreedButton", "GroupLootFrame1.PassButton",
    },
    trade = {
        "TradeFrame", "TradeFrame.NineSlice", "TradeFrame.PortraitContainer", "TradeFramePlayerPortrait",
        "TradeFrameRecipientPortrait", "TradePlayerItem1", "TradePlayerItem1ItemButton",
        "TradeRecipientItem1", "TradePlayerInputMoneyFrame", "TradeRecipientMoneyFrame",
        "TradeFrameTradeButton", "TradeFrameCancelButton",
    },
}

-- Gibt es diese Funktionen? (Ansatzpunkte für hooksecurefunc)
local FUNCTIONS = {
    minimap   = { "GetMinimapShape", "Minimap.SetMaskTexture" },
    auras     = { "BuffFrame.Update", "AuraButton_Update" },
    loot      = { "LootFrame_Update", "LootFrame.Update" },
    grouploot = { "GroupLootFrame_OnShow", "GroupLootContainer_Update" },
    trade     = { "TradeFrame_Update" },
}

---------------------------------------------------------------------------
-- Sicheres Lesen
---------------------------------------------------------------------------
-- Wert für die SavedVariables: Zeichenkette per tostring(), sonst nur der Typ
local function Val(v)
    if v == nil then return nil end
    if ns.IsSecret(v) then return "<secret>" end
    local t = type(v)
    if t == "string" or t == "number" or t == "boolean" then return tostring(v) end
    return t
end

-- Methode geschützt aufrufen; bis zu zwei Rückgabewerte
local function Get(obj, method)
    local fn = ns.GetField(obj, method)
    if type(fn) ~= "function" then return nil end
    local ok, a, b = pcall(fn, obj)
    if not ok then return nil end
    return a, b
end

-- Methode mit beliebig vielen Rückgabewerten (GetRegions/GetChildren) als Liste
local function GetList(obj, method)
    local fn = ns.GetField(obj, method)
    if type(fn) ~= "function" then return nil end
    local res = { pcall(fn, obj) }
    if not res[1] then return nil end
    table.remove(res, 1)
    return res
end

local function Has(obj, field)
    return Val(ns.GetField(obj, field) ~= nil)
end

---------------------------------------------------------------------------
-- Beschreibung eines Frames
---------------------------------------------------------------------------
local function DescribeRegion(r)
    if ns.IsForbidden(r) then return { forbidden = "true" } end
    local layer, sublevel = Get(r, "GetDrawLayer")
    return {
        type     = Val((Get(r, "GetObjectType"))),
        name     = Val((Get(r, "GetName"))),
        layer    = Val(layer),
        sublevel = Val(sublevel),
        texture  = Val((Get(r, "GetTexture"))),
        atlas    = Val((Get(r, "GetAtlas"))),
        shown    = Val((Get(r, "IsShown"))),
    }
end

local function Describe(obj, depth)
    if ns.IsForbidden(obj) then return { forbidden = "true" } end
    local info = {
        type      = Val((Get(obj, "GetObjectType"))),
        name      = Val((Get(obj, "GetName"))),
        protected = Val((Get(obj, "IsProtected"))),
        shown     = Val((Get(obj, "IsShown"))),
        width     = Val((Get(obj, "GetWidth"))),
        height    = Val((Get(obj, "GetHeight"))),
        strata    = Val((Get(obj, "GetFrameStrata"))),
        level     = Val((Get(obj, "GetFrameLevel"))),
        nineSlice = Has(obj, "NineSlice"),
        bg        = Has(obj, "Bg"),
        inset     = Has(obj, "Inset"),
    }

    local regions = GetList(obj, "GetRegions")
    if regions then
        info.numRegions = Val(#regions)
        info.regions = {}
        for i = 1, math.min(#regions, MAX_REGIONS) do
            info.regions[i] = DescribeRegion(regions[i])
        end
    end

    local children = GetList(obj, "GetChildren")
    if children then
        info.numChildren = Val(#children)
        info.children = {}
        for i = 1, math.min(#children, MAX_CHILDREN) do
            local child = children[i]
            if depth < MAX_DEPTH then
                info.children[i] = Describe(child, depth + 1)
            elseif ns.IsForbidden(child) then
                info.children[i] = { forbidden = "true" }
            else
                info.children[i] = {
                    type = Val((Get(child, "GetObjectType"))),
                    name = Val((Get(child, "GetName"))),
                }
            end
        end
    end
    return info
end

---------------------------------------------------------------------------
-- Analyse eines Moduls
---------------------------------------------------------------------------
local function Header()
    local h = {
        time         = type(date) == "function" and Val(date("%Y-%m-%d %H:%M:%S")) or nil,
        locale       = type(GetLocale) == "function" and Val(GetLocale()) or nil,
        libMinor     = Val(ns.GetLibMinor()),
        styleAPI     = Val(ns.HasStyleAPI()),
        addonVersion = Val(ns.AddonVersion()),
    }
    if type(GetBuildInfo) == "function" then
        local ok, version, build, buildDate, toc = pcall(GetBuildInfo)
        if ok then
            h.build = { version = Val(version), build = Val(build), date = Val(buildDate), toc = Val(toc) }
        end
    end
    return h
end

local function Analyse(key)
    local section = { header = Header(), frames = {}, functions = {} }
    local found, total = 0, #CANDIDATES[key]
    for i, path in ipairs(CANDIDATES[key]) do
        local obj = ns.Resolve(path)
        local entry
        if obj == nil then
            entry = { path = path, found = "false" }
        elseif ns.IsForbidden(obj) then
            entry = { path = path, found = "true", forbidden = "true" }
            found = found + 1
        elseif ns.IsUIObject(obj) then
            entry = Describe(obj, 0)
            entry.path, entry.found = path, "true"
            found = found + 1
        else
            entry = { path = path, found = "false", value = Val(obj) }
        end
        section.frames[i] = entry
    end
    for _, path in ipairs(FUNCTIONS[key]) do
        section.functions[path] = type(ns.Resolve(path))
    end
    return section, found, total
end

---------------------------------------------------------------------------
-- /pui frames [modul]
---------------------------------------------------------------------------
function ns.RunFrameAnalysis(arg)
    if type(ns.db) ~= "table" then
        ns.Print(L.FRAMES_NODB)
        return
    end
    local keys
    if arg == nil or arg == "" then
        keys = ORDER
    elseif CANDIDATES[arg] then
        keys = { arg }
    else
        ns.Print(L.FRAMES_UNKNOWN:format(arg, table.concat(ORDER, ", ")))
        return
    end
    if type(ns.db.debug) ~= "table" then ns.db.debug = {} end
    for _, key in ipairs(keys) do
        local ok, section, found, total = pcall(Analyse, key)
        if ok then
            ns.db.debug[key] = section
            ns.Print(L.FRAMES_SUMMARY:format(key, found, total))
        else
            ns.ReportError(section)
        end
    end
end
