-- Pardona's UI – Texte (Englisch als Grundlage, deDE überschreibt)

local _, ns = ...

local L = {
    TITLE            = "Pardona's UI",

    -- Versionshinweis beim Login (Beta/Alpha/Entwicklerversion)
    VERSION_LOADED   = "Version %s loaded",
    DEV_BUILD        = "Developer version loaded",

    -- Kurzstatus (Pardona-Übersicht, Minimap-Tooltip, Broker)
    STATUS_COUNT     = "%d/%d modules active",
    WAIT_LIB         = "waiting for LibPardona 1.1.0",

    -- Modulstatus auf der Optionsseite
    ST_ACTIVE        = "active",
    ST_OFF           = "off",
    ST_NOFRAME       = "frame not found",
    ST_PENDING       = "after combat",
    EXPERIMENTAL     = "experimental",

    -- Optionsseite
    OPT_DESC         = "Purple-gold look for parts of the default interface. Visual changes only – positions stay with Edit Mode.",
    OPT_LIB          = "LibPardona-1.0 (MINOR %s) – style API: %s",
    OPT_LIB_MISSING  = "LibPardona-1.0 not loaded",
    OPT_STYLE_YES    = "available",
    OPT_HINT         = "Changes apply immediately; during combat they apply when combat ends.",
    COMBAT_DEFERRED  = "Change will be applied after combat.",
    MODULE_ERROR     = "Module \"%s\": %s",

    -- Module
    MOD_MINIMAP      = "Minimap (square)",
    MOD_MINIMAP_DESC = "Square minimap with a purple-gold frame.",
    MOD_AURAS        = "Buffs & debuffs",
    MOD_AURAS_DESC   = "Purple-gold borders for buff and debuff icons.",
    MOD_LOOT         = "Loot window",
    MOD_LOOT_DESC    = "Purple-gold look for the loot window.",
    MOD_GROUPLOOT    = "Group loot rolls",
    MOD_GROUPLOOT_DESC = "Purple-gold look for need/greed roll frames.",
    MOD_TRADE        = "Trade window",
    MOD_TRADE_DESC   = "Purple-gold look for the trade window.",

    -- Frame-Analyse (/pui frames)
    FRAMES_SUMMARY   = "%s: %d/%d found – file is written on /reload",
    FRAMES_UNKNOWN   = "Unknown module \"%s\". Possible: %s",
    FRAMES_NODB      = "Saved variables are not loaded yet.",

    -- Secret-Größen (/pui secret)
    SECRET_LINE      = "%s: %d objects, %d times",

    -- Hilfe
    HELP = {
        "/pui – open settings",
        "/pui frames [minimap|auras|loot|grouploot|trade] – frame analysis (saved on /reload)",
        "/pui secret – frames skipped because of a secret size (details: /pui frames)",
        "/pui help – this help",
    },
}

local deDE = {
    VERSION_LOADED   = "Version %s geladen",
    DEV_BUILD        = "Entwicklerversion geladen",

    STATUS_COUNT     = "%d/%d Module aktiv",
    WAIT_LIB         = "wartet auf LibPardona 1.1.0",

    ST_ACTIVE        = "aktiv",
    ST_OFF           = "aus",
    ST_NOFRAME       = "Frame nicht gefunden",
    ST_PENDING       = "nach Kampfende",
    EXPERIMENTAL     = "experimentell",

    OPT_DESC         = "Lila-goldene Optik für Teile der Standardoberfläche. Nur optisch – Positionen bleiben beim Bearbeitungsmodus.",
    OPT_LIB          = "LibPardona-1.0 (MINOR %s) – Stil-API: %s",
    OPT_LIB_MISSING  = "LibPardona-1.0 nicht geladen",
    OPT_STYLE_YES    = "vorhanden",
    OPT_HINT         = "Änderungen wirken sofort, im Kampf erst nach Kampfende.",
    COMBAT_DEFERRED  = "Änderung wird nach dem Kampf übernommen.",
    MODULE_ERROR     = "Modul \"%s\": %s",

    MOD_MINIMAP      = "Minimap (eckig)",
    MOD_MINIMAP_DESC = "Eckige Minimap mit lila-goldenem Rahmen.",
    MOD_AURAS        = "Buffs & Debuffs",
    MOD_AURAS_DESC   = "Lila-goldene Rahmen für Buff- und Debuff-Symbole.",
    MOD_LOOT         = "Beutefenster",
    MOD_LOOT_DESC    = "Lila-goldene Optik für das Beutefenster.",
    MOD_GROUPLOOT    = "Würfelfenster (Gruppenbeute)",
    MOD_GROUPLOOT_DESC = "Lila-goldene Optik für die Bedarf-/Gier-Fenster.",
    MOD_TRADE        = "Handelsfenster",
    MOD_TRADE_DESC   = "Lila-goldene Optik für das Handelsfenster.",

    FRAMES_SUMMARY   = "%s: %d/%d gefunden – Datei wird bei /reload geschrieben",
    FRAMES_UNKNOWN   = "Unbekanntes Modul \"%s\". Möglich: %s",
    FRAMES_NODB      = "Gespeicherte Variablen sind noch nicht geladen.",

    SECRET_LINE      = "%s: %d Objekte, %d-mal",

    HELP = {
        "/pui – Einstellungen öffnen",
        "/pui frames [minimap|auras|loot|grouploot|trade] – Frame-Analyse (wird bei /reload gespeichert)",
        "/pui secret – wegen Secret-Größe übersprungene Frames (Details: /pui frames)",
        "/pui help – diese Hilfe",
    },
}

local locale = type(GetLocale) == "function" and GetLocale() or "enUS"
if locale == "deDE" then
    for k, v in pairs(deDE) do L[k] = v end
end

ns.L = L
