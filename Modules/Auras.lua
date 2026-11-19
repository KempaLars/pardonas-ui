-- Pardona's UI – Modul "Buffs & debuffs"
-- Feiner Rand um Buff- und Debuff-Symbole (LibPardona-1.0 Stil-API, MINOR 4).
-- Buffs: Goldrand. Debuffs: Typfarbe des Blizzard-Debuff-Rands bleibt erhalten.
-- Nur optisch: keine Position, Größe, Skripte; Abbrechen per Rechtsklick bleibt unberührt.
-- Die Hooks auf BuffFrame/DebuffFrame:Update lassen sich nicht entfernen; sie prüfen deshalb
-- immer zuerst, ob das Modul aktiv ist.

local _, ns = ...
local L = ns.L

local MODULE = "auras"

local active = false
local hooked = {}                                    -- "BuffFrame"/"DebuffFrame" -> true
local styled = setmetatable({}, { __mode = "k" })    -- Button -> zuletzt angewendete Optik

local function IsNumber(v)
    return not ns.IsSecret(v) and type(v) == "number"
end

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

local function Method(obj, method)
    local fn = ns.GetField(obj, method)
    if type(fn) ~= "function" then return false end
    return pcall(fn, obj)
end

-- Typfarbe des Debuff-Rands, nur wenn er sichtbar ist und alle vier Werte normale Zahlen
-- sind (keine Secret Values; es wird nichts verrechnet). Sonst nil.
local function DebuffColor(btn)
    local border = ns.GetField(btn, "DebuffBorder")
    if not ns.IsUIObject(border) then return nil end
    local okShown, shown = Method(border, "IsShown")
    if not okShown or ns.IsSecret(shown) or shown ~= true then return nil end
    local ok, r, g, b, a = Method(border, "GetVertexColor")
    if not ok or not IsNumber(r) or not IsNumber(g) or not IsNumber(b) or not IsNumber(a) then return nil end
    return { r, g, b, a }, border
end

local function StyleButton(btn, isDebuff, label)
    if not ns.IsUIObject(btn) then return end
    local icon = ns.GetField(btn, "Icon")
    if ns.IsUIObject(icon) then
        local opts, look
        if isDebuff then
            local color, border = DebuffColor(btn)
            if color then
                opts = { icon = icon, borderColor = color, hide = { border } }
                look = string.format("%s,%s,%s,%s", tostring(color[1]), tostring(color[2]),
                    tostring(color[3]), tostring(color[4]))
            end
        end
        if not opts then
            opts = { icon = icon }
            look = "gold"
        end
        -- Nur neu aufbauen, wenn sich die Optik geändert hat (Update kommt sehr oft)
        local variant = Call("IsStyled", btn)
        if styled[btn] ~= look or variant ~= "icon" then
            local result = Call("StyleIconBorder", btn, opts)
            if result == true or result == "queued" then
                styled[btn] = look
            else
                styled[btn] = styled[btn] or "none"
            end
            if result ~= true then ns.NoteStyleResult(MODULE, label, result) end
        end
    end
    local duration = ns.GetField(btn, "Duration")
    if ns.IsUIObject(duration) then
        if Call("StyleFontString", duration, "text", btn) == true then
            styled[btn] = styled[btn] or "font"
        end
    end
end

local function StyleList(name, isDebuff)
    local list = ns.GetField(ns.Resolve(name), "auraFrames")
    if ns.IsSecret(list) or type(list) ~= "table" then return end
    for i, btn in ipairs(list) do StyleButton(btn, isDebuff, name .. ".auraFrames." .. i) end
end

local function StyleAll()
    StyleList("BuffFrame", false)
    StyleList("DebuffFrame", true)
end

local function OnUpdate()
    if not active or not ns.IsModuleEnabled(MODULE) then return end
    local ok, err = pcall(StyleAll)
    if not ok then ns.ReportError(err) end
end

local function Hook(name)
    if hooked[name] or type(hooksecurefunc) ~= "function" then return end
    local frame = ns.Resolve(name)
    if not ns.IsUIObject(frame) or type(ns.GetField(frame, "Update")) ~= "function" then return end
    if pcall(hooksecurefunc, frame, "Update", OnUpdate) then hooked[name] = true end
end

---------------------------------------------------------------------------
-- Modul
---------------------------------------------------------------------------
local M = {
    title       = L.MOD_AURAS,
    description = L.MOD_AURAS_DESC,
    tested      = false,
}

function M.IsAvailable()
    return ns.HasFrame("BuffFrame", "DebuffFrame")
end

function M.Enable()
    active = true
    Hook("BuffFrame")
    Hook("DebuffFrame")
    StyleAll()
end

function M.Disable()
    active = false
    local list = {}
    for btn in pairs(styled) do list[#list + 1] = btn end
    for _, btn in ipairs(list) do
        styled[btn] = nil
        Call("RemoveStyle", btn)    -- entfernt auch die Dauer-Schrift (owner = btn)
    end
    ns.ClearStyleResults(MODULE)
end

ns:RegisterModule(MODULE, M)
