-- Pardona's UI – Modul "Minimap (square)"
-- Eckige Minimap im Pardona-Stil (LibPardona-1.0 Stil-API, MINOR 4).
-- Nur optisch: keine Position, Größe, Skalierung, Parent oder Skripte von Blizzard-Frames
-- ändern. Geändert werden nur die Maske der Minimap (Entscheidung Lars) und über die Lib
-- eigene Rahmen/Hintergründe sowie Alpha bzw. Schrift einzelner Regionen. Unbekannte Kinder
-- der Minimap (z. B. Buttons anderer Addons) werden nie angefasst; die Zoom-Buttons bleiben.

local _, ns = ...
local L = ns.L

local MODULE = "minimap"
local MASK_SQUARE = "Interface\\Buttons\\WHITE8X8"
local MASK_ROUND = "Interface\\Masks\\CircleMaskScalable"
local TRACKING_BG_ATLAS = "ui-hud-minimap-button"

-- Kleine Buttons am Rand (Pfade aus der Frame-Analyse, Forever 1.60.1)
local SMALL_BUTTONS = {
    "MinimapCluster.Tracking",
    "MinimapCluster.IndicatorFrame.MailFrame",
    "GameTimeFrame",
    "AddonCompartmentFrame",
}

local active = false

---------------------------------------------------------------------------
-- GetMinimapShape
---------------------------------------------------------------------------
-- Nur definieren, wenn beim Laden noch keine vorhanden ist; eine fremde wird nie
-- überschrieben. Bleibt nach Disable bestehen und liefert dann "ROUND".
local ownShape
if type(GetMinimapShape) ~= "function" then
    ownShape = function()
        return active and "SQUARE" or "ROUND"
    end
    GetMinimapShape = ownShape
end

-- Herkunft der aktuellen GetMinimapShape: "own", "foreign" oder "none"
function ns.MinimapShapeOrigin()
    local fn = GetMinimapShape
    if type(fn) ~= "function" then return "none" end
    if ownShape ~= nil and fn == ownShape then return "own" end
    return "foreign"
end

---------------------------------------------------------------------------
-- Hilfsfunktionen
---------------------------------------------------------------------------
-- LibPardona-Methode geschützt aufrufen; Rückgabe wie die Lib (true / "queued" / false)
local function Call(method, ...)
    local LP = ns.LP
    local fn = LP and ns.GetField(LP, method)
    if type(fn) ~= "function" then return false end
    local ok, result = pcall(fn, LP, ...)
    if not ok then
        ns.ReportError(result)
        return false
    end
    return result
end

-- Gestalten und Ergebnis für die Frame-Analyse vermerken ("queued"/false, nie im Chat)
local function Apply(label, method, obj, ...)
    if not ns.IsUIObject(obj) then return end
    ns.NoteStyleResult(MODULE, label, Call(method, obj, ...))
end

local function Remove(obj)
    if ns.IsUIObject(obj) then Call("RemoveStyle", obj) end
end

local function Regions(obj)
    local fn = ns.GetField(obj, "GetRegions")
    if type(fn) ~= "function" then return {} end
    local res = { pcall(fn, obj) }
    if not res[1] then return {} end
    table.remove(res, 1)
    return res
end

local function Method(obj, method)
    local fn = ns.GetField(obj, method)
    if type(fn) ~= "function" then return nil end
    local ok, v = pcall(fn, obj)
    if not ok or ns.IsSecret(v) then return nil end
    return v
end

-- Blizzard-Texturen eines Frames einmal (vor der ersten Gestaltung) erfassen; so landen
-- die eigenen Teile der Lib nie in der hide-Liste.
local zoneTextures, trackingTextures

local function CollectZoneTextures(button)
    if zoneTextures then return zoneTextures end
    local list = {}
    for _, region in ipairs(Regions(button)) do
        if ns.IsUIObject(region) and Method(region, "GetObjectType") == "Texture" then
            list[#list + 1] = region
        end
    end
    zoneTextures = list
    return list
end

local function CollectTrackingTextures(frame)
    if trackingTextures then return trackingTextures end
    local list = {}
    for _, region in ipairs(Regions(frame)) do
        if ns.IsUIObject(region) and Method(region, "GetObjectType") == "Texture"
            and Method(region, "GetDrawLayer") == "BACKGROUND" then
            local atlas = Method(region, "GetAtlas")
            if type(atlas) == "string" and atlas:lower() == TRACKING_BG_ATLAS then
                list[#list + 1] = region
            end
        end
    end
    trackingTextures = list
    return list
end

local function SetMask(path)
    local minimap = ns.Resolve("Minimap")
    local fn = ns.GetField(minimap, "SetMaskTexture")
    if ns.IsUIObject(minimap) and type(fn) == "function" then
        local ok, err = pcall(fn, minimap, path)
        if not ok then ns.ReportError(err) end
    end
end

-- Pardona-Minimap-Button und LibDBIcon-Buttons an den (neuen) Rand setzen
local function RefreshButtons()
    local LP = ns.LP
    local refresh = LP and ns.GetField(LP, "RefreshMinimapButton")
    if type(refresh) == "function" then pcall(refresh, LP) end
    if type(LibStub) ~= "table" or type(LibStub.GetLibrary) ~= "function" then return end
    local okLib, icon = pcall(LibStub.GetLibrary, LibStub, "LibDBIcon-1.0", true)
    if not okLib or type(icon) ~= "table" then return end
    if type(icon.GetButtonList) ~= "function" or type(icon.Refresh) ~= "function" then return end
    local okList, names = pcall(icon.GetButtonList, icon)
    if not okList or type(names) ~= "table" then return end
    for _, name in ipairs(names) do pcall(icon.Refresh, icon, name) end
end

---------------------------------------------------------------------------
-- Anwenden / Entfernen
---------------------------------------------------------------------------
-- Idempotent: die Lib aktualisiert vorhandene Stile, statt etwas doppelt anzulegen.
local function ApplyAll()
    SetMask(MASK_SQUARE)

    local minimap = ns.Resolve("Minimap")
    local hide = {}
    local compass = ns.Resolve("MinimapCompassTexture")
    if ns.IsUIObject(compass) then hide[#hide + 1] = compass end
    Apply("Minimap", "ApplyStyle", minimap, {
        variant = "panel", rounded = false, offsets = { -4, -4, -4, -4 }, hide = hide,
    })

    local zone = ns.Resolve("MinimapCluster.ZoneTextButton")
    if ns.IsUIObject(zone) then
        Apply("ZoneTextButton", "ApplyStyle", zone, {
            variant = "thin", rounded = false, hide = CollectZoneTextures(zone),
        })
        Apply("MinimapZoneText", "StyleFontString", ns.Resolve("MinimapZoneText"), "title", zone)
    end

    for _, path in ipairs(SMALL_BUTTONS) do
        local btn = ns.Resolve(path)
        if ns.IsUIObject(btn) then
            local opts = { variant = "button", rounded = false }
            if path == "MinimapCluster.Tracking" then opts.hide = CollectTrackingTextures(btn) end
            Apply(path, "ApplyStyle", btn, opts)
        end
    end

    local clock = ns.Resolve("TimeManagerClockButton")
    if ns.IsUIObject(clock) then
        Apply("TimeManagerClockTicker", "StyleFontString", ns.Resolve("TimeManagerClockTicker"), "text", clock)
    end

    RefreshButtons()
end

local function RemoveAll()
    Remove(ns.Resolve("Minimap"))
    Remove(ns.Resolve("MinimapCluster.ZoneTextButton"))      -- inkl. MinimapZoneText (owner)
    for _, path in ipairs(SMALL_BUTTONS) do Remove(ns.Resolve(path)) end
    Remove(ns.Resolve("TimeManagerClockButton"))             -- Uhr-Schrift (owner)
    -- Font-Strings ohne gestalteten owner zur Sicherheit direkt
    Remove(ns.Resolve("MinimapZoneText"))
    Remove(ns.Resolve("TimeManagerClockTicker"))
    SetMask(MASK_ROUND)
    ns.ClearStyleResults(MODULE)
end

---------------------------------------------------------------------------
-- Modul
---------------------------------------------------------------------------
local M = {
    title       = L.MOD_MINIMAP,
    description = L.MOD_MINIMAP_DESC,
    tested      = false,
}

function M.IsAvailable()
    return ns.HasFrame("Minimap")
end

function M.Enable()
    active = true
    local ok, err = pcall(ApplyAll)
    if not ok then
        -- halb angewendeten Zustand zurücknehmen; Core meldet den Fehler
        active = false
        pcall(RemoveAll)
        RefreshButtons()
        error(err, 0)
    end
end

function M.Disable()
    active = false
    RemoveAll()
    RefreshButtons()
end

-- Nach Ladebildschirmen erneut anwenden (idempotent), solange das Modul aktiv ist
local ev = CreateFrame("Frame")
ns.SafeRegisterEvent(ev, "PLAYER_ENTERING_WORLD")
ev:SetScript("OnEvent", function()
    if not active or not ns.IsModuleEnabled(MODULE) then return end
    local ok, err = pcall(ApplyAll)
    if not ok then ns.ReportError(err) end
end)

ns:RegisterModule(MODULE, M)
