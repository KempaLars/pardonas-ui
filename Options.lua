-- Pardona's UI – Optionsseite
-- Unterseite "UI" unter "Pardona's Addons" (LP:RegisterSettingsCanvas). Ohne Settings-API
-- öffnet /pui dieselbe Seite als eigenes, verschiebbares Fenster (Esc schließt).
-- Nur Blizzard-Vorlagen und -Schriftobjekte, keine eigenen Farbwerte.

local _, ns = ...
local L = ns.L

local Opt = {}          -- canvas, category, window, libText, rows

local ROW_HEIGHT = 46
local TOP_ROWS = 100    -- Abstand vom oberen Rand bis zur ersten Modulzeile
local STATUS_WIDTH = 190
local WINDOW_WIDTH = 600
local WINDOW_NAME = "PardonasUIOptionsWindow"

local STATUS_TEXT = {
    active  = "ST_ACTIVE",
    off     = "ST_OFF",
    noframe = "ST_NOFRAME",
    waitlib = "WAIT_LIB",
    pending = "ST_PENDING",
}

local STATUS_FONT = {
    active  = "GameFontHighlightSmall",
    off     = "GameFontDisableSmall",
    noframe = "GameFontDisableSmall",
    waitlib = "GameFontNormalSmall",
    pending = "GameFontNormalSmall",
}

local function ContentHeight()
    return TOP_ROWS + #ns.moduleOrder * ROW_HEIGHT + 40
end

local function SetFont(fs, name)
    local font = _G[name]
    if type(font) == "table" then fs:SetFontObject(font) end
end

---------------------------------------------------------------------------
-- Inhalt
---------------------------------------------------------------------------
local function BuildRow(parent, index, key)
    local def = ns.modules[key]
    local row = CreateFrame("Frame", nil, parent)
    local y = -(TOP_ROWS + (index - 1) * ROW_HEIGHT)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, y)
    row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -12, y)
    row:SetHeight(ROW_HEIGHT)

    local check = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
    check:SetSize(26, 26)
    check:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -2)
    check:SetScript("OnClick", function(self)
        ns.SetModuleEnabled(key, self:GetChecked() == true)
    end)

    local title = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    title:SetPoint("TOPLEFT", row, "TOPLEFT", 32, -6)
    title:SetJustifyH("LEFT")
    title:SetText(def.title or key)

    local status = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    status:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, -7)
    status:SetWidth(STATUS_WIDTH)
    status:SetJustifyH("RIGHT")

    local exp = row:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    exp:SetPoint("TOPRIGHT", status, "BOTTOMRIGHT", 0, -3)
    exp:SetWidth(STATUS_WIDTH)
    exp:SetJustifyH("RIGHT")
    exp:SetText(def.tested == true and "" or L.EXPERIMENTAL)

    local desc = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -3)
    desc:SetPoint("RIGHT", row, "RIGHT", -(STATUS_WIDTH + 12), 0)
    desc:SetJustifyH("LEFT")
    desc:SetText(def.description or "")

    return { key = key, check = check, status = status }
end

local function BuildContent(parent)
    local title = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -16)
    title:SetText(L.TITLE)

    local desc = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -44)
    desc:SetPoint("RIGHT", parent, "RIGHT", -16, 0)
    desc:SetJustifyH("LEFT")
    desc:SetText(L.OPT_DESC)

    local lib = parent:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    lib:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -74)
    lib:SetPoint("RIGHT", parent, "RIGHT", -16, 0)
    lib:SetJustifyH("LEFT")
    Opt.libText = lib

    Opt.rows = {}
    for i, key in ipairs(ns.moduleOrder) do
        Opt.rows[i] = BuildRow(parent, i, key)
    end

    local hint = parent:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    hint:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -(TOP_ROWS + #ns.moduleOrder * ROW_HEIGHT + 8))
    hint:SetPoint("RIGHT", parent, "RIGHT", -16, 0)
    hint:SetJustifyH("LEFT")
    hint:SetText(L.OPT_HINT)
end

function ns.RefreshOptions()
    if not Opt.rows then return end
    if ns.LP then
        local style = ns.HasStyleAPI() and L.OPT_STYLE_YES or L.WAIT_LIB
        Opt.libText:SetText(L.OPT_LIB:format(tostring(ns.GetLibMinor()), style))
    else
        Opt.libText:SetText(L.OPT_LIB_MISSING)
    end
    for _, row in ipairs(Opt.rows) do
        row.check:SetChecked(ns.IsModuleWanted(row.key))
        local st = ns.GetModuleStatus(row.key)
        row.status:SetText(L[STATUS_TEXT[st] or "ST_OFF"])
        SetFont(row.status, STATUS_FONT[st] or "GameFontHighlightSmall")
    end
end

---------------------------------------------------------------------------
-- Eigenes Fenster (nur ohne Settings-API)
---------------------------------------------------------------------------
local WINDOW_TEMPLATES = { "BasicFrameTemplateWithInset", "ButtonFrameTemplate", "DefaultPanelTemplate" }

local function EnsureWindow()
    if Opt.window then return Opt.window end
    local w
    for _, template in ipairs(WINDOW_TEMPLATES) do
        local ok, f = pcall(CreateFrame, "Frame", WINDOW_NAME, UIParent, template)
        if ok and f then w = f; break end
    end
    if not w then w = CreateFrame("Frame", WINDOW_NAME, UIParent) end

    w:SetSize(WINDOW_WIDTH, ContentHeight() + 30)
    w:SetPoint("CENTER", UIParent, "CENTER")
    w:SetFrameStrata("DIALOG")
    w:SetClampedToScreen(true)
    w:SetMovable(true)
    w:EnableMouse(true)
    w:RegisterForDrag("LeftButton")
    w:SetScript("OnDragStart", w.StartMoving)
    w:SetScript("OnDragStop", w.StopMovingOrSizing)

    if not ns.GetField(w, "CloseButton") then
        local ok, close = pcall(CreateFrame, "Button", nil, w, "UIPanelCloseButton")
        if ok and close then close:SetPoint("TOPRIGHT", w, "TOPRIGHT", 0, 0) end
    end

    local canvas = Opt.canvas
    canvas:SetParent(w)
    canvas:ClearAllPoints()
    canvas:SetPoint("TOPLEFT", w, "TOPLEFT", 4, -24)
    canvas:SetPoint("BOTTOMRIGHT", w, "BOTTOMRIGHT", -4, 4)
    canvas:Show()

    if type(UISpecialFrames) == "table" then table.insert(UISpecialFrames, WINDOW_NAME) end
    w:SetScript("OnShow", ns.RefreshOptions)
    w:Hide()
    Opt.window = w
    return w
end

---------------------------------------------------------------------------
-- Registrierung und Öffnen
---------------------------------------------------------------------------
-- Aufruf aus Core nach ADDON_LOADED (alle Module sind dann registriert)
function ns.RegisterOptions()
    if Opt.canvas then return end
    local canvas = CreateFrame("Frame")
    canvas:Hide()
    canvas:SetSize(WINDOW_WIDTH - 8, ContentHeight())
    Opt.canvas = canvas
    BuildContent(canvas)
    canvas:SetScript("OnShow", ns.RefreshOptions)

    local LP = ns.LP
    if LP and type(LP.RegisterSettingsCanvas) == "function" then
        local ok, category = pcall(LP.RegisterSettingsCanvas, LP, ns.PARDONA_ID, canvas, "UI")
        if ok and category then Opt.category = category end
    end
end

function ns.OpenOptions()
    if not Opt.canvas then return end
    if Opt.category then
        local LP = ns.LP
        if type(LP.OpenSettings) == "function" then pcall(LP.OpenSettings, LP, ns.PARDONA_ID) end
        return
    end
    local w = EnsureWindow()
    if w:IsShown() then w:Hide() else w:Show() end
end
