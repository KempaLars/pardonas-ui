-- Pardona's UI – Frame-Analyse (/pui frames [modul])
-- Schreibt je Modul einen Abschnitt nach PardonasUIDB.debug[modul] (nur dieser Abschnitt wird
-- überschrieben). Grundlage für die Skins: welche Frames, Regionen und Funktionen der
-- Forever-Client tatsächlich hat. Nur lesend, alles in pcall; Werte werden nur per
-- type()/tostring() aufgenommen, nie verrechnet oder verglichen.

local _, ns = ...
local L = ns.L

local MAX_REGIONS = 40
local MAX_CHILDREN = 40
local MAX_DEPTH = 3     -- 0 = Kandidat, 1 = Kinder, 2 = Enkel, 3 = Urenkel (deren Kinder nur Typ/Name)
local MAX_ELEMENTS = 3  -- Listenelemente des Beutefensters

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
    auras     = { "BuffFrame.Update", "DebuffFrame.Update", "AuraButton_Update" },
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
    local objType = Get(r, "GetObjectType")
    local info = {
        type      = Val(objType),
        name      = Val((Get(r, "GetName"))),
        parentKey = Val((Get(r, "GetParentKey"))),
        layer     = Val(layer),
        sublevel  = Val(sublevel),
        texture   = Val((Get(r, "GetTexture"))),
        atlas     = Val((Get(r, "GetAtlas"))),
        shown     = Val((Get(r, "IsShown"))),
    }
    if not ns.IsSecret(objType) and objType == "FontString" then
        info.text = Val((Get(r, "GetText")))
    end
    return info
end

local function Describe(obj, depth)
    if ns.IsForbidden(obj) then return { forbidden = "true" } end
    local info = {
        type      = Val((Get(obj, "GetObjectType"))),
        name      = Val((Get(obj, "GetName"))),
        parentKey = Val((Get(obj, "GetParentKey"))),
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
                    type      = Val((Get(child, "GetObjectType"))),
                    name      = Val((Get(child, "GetName"))),
                    parentKey = Val((Get(child, "GetParentKey"))),
                }
            end
        end
    end
    return info
end

-- Element einer Liste (ab Tiefe 0) mit Feld "element"
local function DescribeElement(obj, index)
    local entry
    if ns.IsForbidden(obj) then
        entry = { forbidden = "true" }
    elseif ns.IsUIObject(obj) then
        entry = Describe(obj, 0)
    else
        entry = { value = Val(obj) }
    end
    entry.element = Val(index)
    return entry
end

---------------------------------------------------------------------------
-- Sonderfälle je Modul
---------------------------------------------------------------------------
-- Beutefenster: bis zu MAX_ELEMENTS Elemente der ScrollBox (GetFrames bzw. ForEachFrame)
local function LootExtra()
    local extra = { source = "none", elements = {} }
    local box = ns.Resolve("LootFrame.ScrollBox")
    if not ns.IsUIObject(box) then return extra end
    local frames = {}
    local list = Get(box, "GetFrames")
    if not ns.IsSecret(list) and type(list) == "table" then
        extra.source = "GetFrames"
        for i = 1, math.min(#list, MAX_ELEMENTS) do frames[i] = list[i] end
    else
        local each = ns.GetField(box, "ForEachFrame")
        if type(each) == "function" then
            extra.source = "ForEachFrame"
            pcall(each, box, function(frame)
                if #frames < MAX_ELEMENTS then frames[#frames + 1] = frame end
            end)
        end
    end
    for i, frame in ipairs(frames) do extra.elements[i] = DescribeElement(frame, i) end
    return extra
end

-- Gruppenbeute: alle Kinder von GroupLootContainer sowie GroupLootFrame1–4
local function GroupLootExtra()
    local extra = { containerChildren = {}, lootFrames = {} }
    local container = ns.Resolve("GroupLootContainer")
    if ns.IsUIObject(container) then
        local children = GetList(container, "GetChildren") or {}
        for i = 1, math.min(#children, MAX_CHILDREN) do
            extra.containerChildren[i] = DescribeElement(children[i], i)
        end
    end
    for i = 1, 4 do
        local path = "GroupLootFrame" .. i
        local obj = ns.Resolve(path)
        local entry
        if ns.IsUIObject(obj) then
            entry = Describe(obj, 0)
            entry.found = "true"
        else
            entry = { found = "false" }
        end
        entry.path = path
        extra.lootFrames[i] = entry
    end
    return extra
end

local EXTRA = {
    loot      = LootExtra,
    grouploot = GroupLootExtra,
}

---------------------------------------------------------------------------
-- Analyse eines Moduls
---------------------------------------------------------------------------
local function Header(key)
    local h = {
        time         = type(date) == "function" and Val(date("%Y-%m-%d %H:%M:%S")) or nil,
        locale       = type(GetLocale) == "function" and Val(GetLocale()) or nil,
        libMinor     = Val(ns.GetLibMinor()),
        styleAPI     = Val(ns.HasStyleAPI()),
        addonVersion = Val(ns.AddonVersion()),
        -- Herkunft von GetMinimapShape: "own" (eigen), "foreign" (fremd), "none" (keine)
        minimapShape = type(ns.MinimapShapeOrigin) == "function" and ns.MinimapShapeOrigin() or "none",
        modules      = {},
        styleResults = {},
    }
    for _, mod in ipairs(ns.moduleOrder) do
        h.modules[mod] = ns.GetModuleStatus(mod)
    end
    -- Stil-Aufrufe mit Ergebnis "queued" / false
    for module, list in pairs(ns.styleResults) do
        local copy = {}
        for label, result in pairs(list) do copy[label] = result end
        h.styleResults[module] = copy
    end
    -- Secret-Größen dieses Moduls: { [label] = { count, last, combat } }
    h.secretSize = {}
    for label, entry in pairs(ns.secretSize[key] or {}) do
        h.secretSize[label] = { count = entry.count, last = entry.last, combat = entry.combat }
    end
    if type(GetBuildInfo) == "function" then
        local ok, version, build, buildDate, toc = pcall(GetBuildInfo)
        if ok then
            h.build = { version = Val(version), build = Val(build), date = Val(buildDate), toc = Val(toc) }
        end
    end
    return h
end

-- Gestaltete Objekte des Moduls (M.DebugObjects): Label, IsStyled, Secret-Größe von Objekt/Icon
local function StyledObjects(key)
    local def = ns.modules[key]
    local fn = def and def.DebugObjects
    if type(fn) ~= "function" then return nil end
    local ok, list = pcall(fn)
    if not ok or type(list) ~= "table" then return nil end
    local LP = ns.LP
    local isStyled = LP and ns.GetField(LP, "IsStyled")
    local out = {}
    for i, t in ipairs(list) do
        local entry = { label = Val(t.label) }
        if type(isStyled) == "function" then
            local okStyled, variant, queued = pcall(isStyled, LP, t.obj)
            if okStyled then
                entry.isStyled = Val(variant) or "nil"
                entry.queued = Val(queued)
            end
        end
        entry.secretSize = Val(ns.HasSecretSize(t.obj))
        if t.icon ~= nil then entry.iconSecretSize = Val(ns.HasSecretSize(t.icon)) end
        out[i] = entry
    end
    return out
end

local function Analyse(key)
    local section = { header = Header(key), frames = {}, functions = {} }
    section.styledObjects = StyledObjects(key)
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
    if EXTRA[key] then section.extra = EXTRA[key]() end
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
