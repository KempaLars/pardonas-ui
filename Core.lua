-- Pardona's UI – WoW Forever (Interface 16001, Mainline-API)
-- Core: Namespace, Datenbank, Build-Erkennung, Modulverwaltung, LibPardona, Events, Slash-Befehle.
--
-- Pardona's UI greift nur optisch ein: keine Position, Größe, Skalierung, Parent oder Skripte
-- von Blizzard-Frames werden geändert. Die Gestaltung selbst kommt ausschließlich aus
-- LibPardona-1.0 (Stil-API ab Lib 1.1.0); ohne Stil-API bleiben alle Module inaktiv.

local ADDON_NAME, ns = ...
local L = ns.L

ns.ADDON_NAME = ADDON_NAME
ns.PARDONA_ID = "UI"
ns.ICON = "Interface\\AddOns\\PardonasUI\\Libs\\lib-pardona\\LibPardona-1.0\\Textures\\Pardona"
ns.LIB_MAJOR = "LibPardona-1.0"

ns.modules = {}       -- key -> def
ns.moduleOrder = {}   -- keys in Registrierungsreihenfolge
ns.ready = false      -- true ab PLAYER_LOGIN (vorher werden keine Module aktiviert)

local enabled = {}    -- key -> true: Enable() wurde ausgeführt
local pending = {}    -- key -> true: Änderung im Kampf vorgemerkt

---------------------------------------------------------------------------
-- Hilfsfunktionen
---------------------------------------------------------------------------
-- Chat-Ausgabe; das Präfix bleibt ohne eigene Farbe (Gestaltung nur aus LibPardona)
function ns.Print(msg)
    print(L.TITLE .. ": " .. tostring(msg))
end

function ns.IsSecret(v)
    return type(issecretvalue) == "function" and issecretvalue(v) == true
end

function ns.InCombat()
    return type(InCombatLockdown) == "function" and InCombatLockdown() == true
end

-- Fehler über den Fehler-Handler des Spiels melden (sichtbar mit /console scriptErrors 1)
function ns.ReportError(err)
    local handler = type(geterrorhandler) == "function" and geterrorhandler()
    if type(handler) == "function" then
        pcall(handler, err)
    else
        ns.Print(tostring(err))
    end
end

local function Index(t, k) return t[k] end

-- Sicheres Lesen eines Feldes (auch bei verbotenen Frames ohne Fehler)
function ns.GetField(t, k)
    if type(t) ~= "table" then return nil end
    local ok, v = pcall(Index, t, k)
    if ok then return v end
    return nil
end

-- Punkt-Pfad auflösen, z. B. "MinimapCluster.BorderTop" oder "BuffFrame.auraFrames.1"
-- (reine Ziffern werden als Zahlenindex gelesen). nil, wenn ein Teil fehlt.
function ns.Resolve(path)
    if type(path) ~= "string" or path == "" then return nil end
    local obj, first = nil, true
    for part in path:gmatch("[^%.]+") do
        local key = tonumber(part) or part
        if first then
            obj = _G[key]
            first = false
        else
            obj = ns.GetField(obj, key)
        end
        if obj == nil then return nil end
    end
    return obj
end

-- Verbotener Frame? (nur über IsForbidden, ohne weitere Zugriffe)
function ns.IsForbidden(obj)
    local fn = ns.GetField(obj, "IsForbidden")
    if type(fn) ~= "function" then return false end
    local ok, r = pcall(fn, obj)
    return ok and r == true
end

-- UI-Objekt (Frame, Textur …)? Verbotene Frames zählen nicht.
function ns.IsUIObject(obj)
    if type(obj) ~= "table" or ns.IsForbidden(obj) then return false end
    local fn = ns.GetField(obj, "GetObjectType")
    if type(fn) ~= "function" then return false end
    local ok, objType = pcall(fn, obj)
    return ok and type(objType) == "string"
end

-- true, wenn mindestens einer der Pfade auf ein UI-Objekt zeigt
function ns.HasFrame(...)
    for i = 1, select("#", ...) do
        if ns.IsUIObject(ns.Resolve((select(i, ...)))) then return true end
    end
    return false
end

-- Events nur registrieren, wenn der Client sie kennt (C_EventUtils.IsEventValid), und immer
-- per pcall. unit gesetzt: RegisterUnitEvent. Rückgabe: true = registriert.
function ns.SafeRegisterEvent(frame, event, unit)
    if C_EventUtils and C_EventUtils.IsEventValid then
        local okValid, valid = pcall(C_EventUtils.IsEventValid, event)
        if not okValid or not valid then return false end
    end
    if unit then return (pcall(frame.RegisterUnitEvent, frame, event, unit)) end
    return (pcall(frame.RegisterEvent, frame, event))
end

-- Ergebnisse der Stil-Aufrufe, die nicht true waren ("queued" / false), je Modul.
-- Nur für die Frame-Analyse (/pui frames), nie im Chat.
ns.styleResults = {}

function ns.NoteStyleResult(module, label, result)
    if type(module) ~= "string" or label == nil then return end
    local list = ns.styleResults[module]
    if result == true then
        if list then list[tostring(label)] = nil end
        return
    end
    if not list then
        list = {}
        ns.styleResults[module] = list
    end
    list[tostring(label)] = tostring(result)
end

function ns.ClearStyleResults(module)
    ns.styleResults[module] = nil
end

-- Secret-Größe: GetWidth/GetHeight per pcall lesen. true, wenn einer der Werte ein Secret
-- Value oder nicht lesbar ist. Es wird nichts verrechnet oder verglichen (nur type/issecretvalue).
-- Hintergrund: Der Rahmen der Lib (BackdropTemplate) rechnet bei Größenänderung mit der Größe
-- seines Ankers; ein Anker mit Secret-Größe führt zu einem Fehler in Backdrop.lua.
local SIZE_METHODS = { "GetWidth", "GetHeight" }

function ns.HasSecretSize(obj)
    if ns.IsSecret(obj) or type(obj) ~= "table" then return true end
    for _, method in ipairs(SIZE_METHODS) do
        local fn = ns.GetField(obj, method)
        if type(fn) ~= "function" then return true end
        local ok, v = pcall(fn, obj)
        if not ok or ns.IsSecret(v) or type(v) ~= "number" then return true end
    end
    return false
end

-- Funde von Secret-Größen je Modul und Label: { count, last, combat }.
-- Nur für die Frame-Analyse (/pui frames) und die Zusammenfassung (/pui secret), nie im Chat
-- als Einzelmeldung. Bleibt bis /reload erhalten (auch nach Modul aus/an).
ns.secretSize = {}

function ns.NoteSecretSize(module, label)
    if type(module) ~= "string" or label == nil then return end
    local list = ns.secretSize[module]
    if not list then
        list = {}
        ns.secretSize[module] = list
    end
    local key = tostring(label)
    local entry = list[key]
    if not entry then
        entry = { count = 0 }
        list[key] = entry
    end
    entry.count = entry.count + 1
    entry.last = type(date) == "function" and date("%Y-%m-%d %H:%M:%S") or nil
    entry.combat = ns.InCombat()
end

-- Zusammenfassung je Modul: Anzahl der Labels und Summe der Funde
function ns.SecretSizeSummary(module)
    local objects, times = 0, 0
    for _, entry in pairs(ns.secretSize[module] or {}) do
        objects = objects + 1
        times = times + entry.count
    end
    return objects, times
end

---------------------------------------------------------------------------
-- LibPardona
---------------------------------------------------------------------------
-- Die Lib-Tabelle bleibt bei einem Upgrade durch ein anderes Addon dieselbe; MINOR wird
-- deshalb bei Bedarf neu gelesen.
local function GetLib()
    if type(LibStub) ~= "table" then return nil end
    local ok, lib, minor = pcall(LibStub.GetLibrary, LibStub, ns.LIB_MAJOR, true)
    if ok and type(lib) == "table" then return lib, minor end
    return nil
end

ns.LP = GetLib()

function ns.GetLibMinor()
    local _, minor = GetLib()
    return minor
end

-- Stil-API vorhanden? (ab LibPardona 1.1.0: LP.STYLE_VERSION, ersatzweise ApplyStyle/RemoveStyle)
function ns.HasStyleAPI()
    local LP = ns.LP
    if type(LP) ~= "table" then return false end
    if LP.STYLE_VERSION ~= nil then return true end
    return type(LP.ApplyStyle) == "function" and type(LP.RemoveStyle) == "function"
end

---------------------------------------------------------------------------
-- Version / Build-Art
---------------------------------------------------------------------------
-- Addon-Version aus der TOC ("" = nicht lesbar)
function ns.AddonVersion()
    local fn = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
    if type(fn) ~= "function" then return "" end
    local ok, v = pcall(fn, ADDON_NAME, "Version")
    if not ok or type(v) ~= "string" or ns.IsSecret(v) then return "" end
    return v
end

-- Build-Art: "dev" (Platzhalter nicht ersetzt / nicht lesbar), "test" (Beta/Alpha), "release"
function ns.BuildKind()
    local v = ns.AddonVersion()
    if v == "" or v:find("@project-version@", 1, true) then return "dev", v end
    local lv = v:lower()
    if lv:find("beta", 1, true) or lv:find("alpha", 1, true) then return "test", v end
    return "release", v
end

-- Beta/Alpha oder Entwicklerversion?
function ns.IsTestBuild()
    return ns.BuildKind() ~= "release"
end

-- Versionshinweis beim Login: nur Beta/Alpha und Entwicklerversion
local function PrintVersionNotice()
    local kind, v = ns.BuildKind()
    if kind == "dev" then
        ns.Print(L.DEV_BUILD)
    elseif kind == "test" then
        ns.Print(L.VERSION_LOADED:format(v))
    end
end

---------------------------------------------------------------------------
-- Datenbank
---------------------------------------------------------------------------
-- PardonasUIDB.modules[key]: nur die ausdrückliche Wahl des Nutzers (true/false);
--   nil = Standard (Testbuild oder tested → an), damit der Standard zwischen Beta und
--   Release richtig wechselt.
-- PardonasUIDB.pardona: Daten von LibPardona (Minimap-Button usw.).
-- PardonasUIDB.debug: Frame-Analyse (/pui frames), je Modul ein Abschnitt.
local function InitDB()
    if type(PardonasUIDB) ~= "table" then PardonasUIDB = {} end
    local db = PardonasUIDB
    if type(db.modules) ~= "table" then db.modules = {} end
    if type(db.pardona) ~= "table" then db.pardona = {} end
    ns.db = db
end

---------------------------------------------------------------------------
-- Modulverwaltung
---------------------------------------------------------------------------
-- def = { title, description, tested = false, IsAvailable(), Enable(), Disable() }
function ns:RegisterModule(key, def)
    if type(key) ~= "string" or key == "" then error("RegisterModule: key must be a non-empty string", 2) end
    if type(def) ~= "table" then error("RegisterModule: def must be a table", 2) end
    def.key = key
    if not self.modules[key] then table.insert(self.moduleOrder, key) end
    self.modules[key] = def
end

-- Funktion geschützt aufrufen; Fehler werden gemeldet. Rückgabe: true = ohne Fehler.
local function CallSafe(def, fn)
    if type(fn) ~= "function" then return true end
    local ok, err = pcall(fn, def)
    if not ok then
        ns.ReportError(L.MODULE_ERROR:format(tostring(def.key), tostring(err)))
        return false
    end
    return true
end

function ns.IsModuleDefaultOn(key)
    local def = ns.modules[key]
    return def ~= nil and (ns.IsTestBuild() or def.tested == true)
end

-- Gewünschter Zustand: ausdrückliche Wahl des Nutzers, sonst Standard
function ns.IsModuleWanted(key)
    if not ns.modules[key] then return false end
    local choice = ns.db and ns.db.modules[key]
    if choice == nil then return ns.IsModuleDefaultOn(key) end
    return choice == true
end

function ns.IsModuleAvailable(key)
    local def = ns.modules[key]
    if not def then return false end
    if type(def.IsAvailable) ~= "function" then return true end
    local ok, r = pcall(def.IsAvailable, def)
    return ok and r == true
end

function ns.IsModuleEnabled(key)
    return enabled[key] == true
end

-- Status für die Optionsseite: "active", "pending", "off", "waitlib", "noframe"
function ns.GetModuleStatus(key)
    if pending[key] then return "pending" end
    if enabled[key] then return "active" end
    if not ns.IsModuleWanted(key) then return "off" end
    if not ns.HasStyleAPI() then return "waitlib" end
    if not ns.IsModuleAvailable(key) then return "noframe" end
    return "off"
end

function ns.CountActiveModules()
    local n = 0
    for _, key in ipairs(ns.moduleOrder) do
        if enabled[key] then n = n + 1 end
    end
    return n, #ns.moduleOrder
end

-- Ist-Zustand an den Soll-Zustand angleichen; im Kampf nur vormerken
function ns.ApplyModule(key)
    local def = ns.modules[key]
    if not def or not ns.ready or not ns.db then return end
    local want = ns.IsModuleWanted(key) and ns.HasStyleAPI() and ns.IsModuleAvailable(key)
    if want == (enabled[key] == true) then
        pending[key] = nil
        return
    end
    if ns.InCombat() then
        pending[key] = true
        return
    end
    pending[key] = nil
    if want then
        if CallSafe(def, def.Enable) then enabled[key] = true end
    else
        CallSafe(def, def.Disable)
        enabled[key] = nil
    end
end

-- Optionsseite und Pardona-Status neu anzeigen
function ns.Changed()
    if type(ns.RefreshOptions) == "function" then ns.RefreshOptions() end
    local LP = ns.LP
    if ns.registered and LP and type(LP.RefreshStatus) == "function" then
        pcall(LP.RefreshStatus, LP)
    end
end

function ns.ApplyAllModules()
    for _, key in ipairs(ns.moduleOrder) do ns.ApplyModule(key) end
    ns.Changed()
end

-- Schalter auf der Optionsseite: speichert die ausdrückliche Wahl und wendet sie sofort an
function ns.SetModuleEnabled(key, value)
    if not ns.db or not ns.modules[key] then return end
    ns.db.modules[key] = value and true or false
    ns.ApplyModule(key)
    if pending[key] then ns.Print(L.COMBAT_DEFERRED) end
    ns.Changed()
end

---------------------------------------------------------------------------
-- Registrierung bei LibPardona
---------------------------------------------------------------------------
-- Kurzstatus für Übersicht, Minimap-Tooltip und Broker
local function PardonaStatus()
    if not ns.HasStyleAPI() then return L.WAIT_LIB end
    return L.STATUS_COUNT:format(ns.CountActiveModules())
end

local function OpenOptions()
    if type(ns.OpenOptions) == "function" then ns.OpenOptions() end
end

-- Erst nach ADDON_LOADED aufrufen (SavedVariables müssen geladen sein)
local function RegisterPardona()
    local LP = ns.LP
    if not LP or type(LP.RegisterAddon) ~= "function" then return end
    local ok, err = pcall(LP.RegisterAddon, LP, ns.PARDONA_ID, {
        name    = L.TITLE,
        addon   = ADDON_NAME,
        icon    = ns.ICON,
        db      = ns.db.pardona,
        onClick = OpenOptions,
        status  = PardonaStatus,
    })
    if ok then
        ns.registered = true
    else
        ns.ReportError(err)
    end
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local ev = CreateFrame("Frame")
ns.SafeRegisterEvent(ev, "ADDON_LOADED")
ns.SafeRegisterEvent(ev, "PLAYER_LOGIN")
ns.SafeRegisterEvent(ev, "PLAYER_REGEN_ENABLED")

ev:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 ~= ADDON_NAME then return end
        InitDB()
        RegisterPardona()
        if type(ns.RegisterOptions) == "function" then
            local ok, err = pcall(ns.RegisterOptions)
            if not ok then ns.ReportError(err) end
        end
        pcall(self.UnregisterEvent, self, "ADDON_LOADED")
    elseif event == "PLAYER_LOGIN" then
        if not ns.db then InitDB() end
        PrintVersionNotice()
        ns.ready = true
        ns.ApplyAllModules()
    elseif event == "PLAYER_REGEN_ENABLED" then
        if next(pending) ~= nil then ns.ApplyAllModules() end
    end
end)

---------------------------------------------------------------------------
-- Slash-Befehle
---------------------------------------------------------------------------
local function PrintHelp()
    for _, line in ipairs(L.HELP) do ns.Print(line) end
end

-- /pui secret: eine Zeile je Modul; Details nur über /pui frames
local function PrintSecretSummary()
    for _, key in ipairs(ns.moduleOrder) do
        ns.Print(L.SECRET_LINE:format(key, ns.SecretSizeSummary(key)))
    end
end

SLASH_PARDONASUI1 = "/pui"
if type(SlashCmdList) == "table" then
    SlashCmdList.PARDONASUI = function(msg)
        local cmd, rest = tostring(msg or ""):match("^%s*(%S*)%s*(.-)%s*$")
        cmd = (cmd or ""):lower()
        if cmd == "" or cmd == "options" or cmd == "config" then
            OpenOptions()
        elseif cmd == "frames" then
            if type(ns.RunFrameAnalysis) == "function" then ns.RunFrameAnalysis((rest or ""):lower()) end
        elseif cmd == "secret" then
            PrintSecretSummary()
        else
            PrintHelp()
        end
    end
end
