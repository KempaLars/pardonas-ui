-- Pardona's UI – Modul "Group loot rolls"
-- Gerüst: noch ohne Gestaltung. Der Skin folgt, sobald LibPardona 1.1.0 (LP.Style,
-- LP:ApplyStyle/LP:RemoveStyle) getaggt ist und die Frame-Analyse (/pui frames grouploot)
-- ausgewertet wurde. Nur optisch: keine Position, Größe, Skalierung, Parent oder Skripte
-- von Blizzard-Frames ändern; Gestaltung nachträglich per hooksecurefunc bzw. OnShow.

local _, ns = ...
local L = ns.L

local M = {
    title       = L.MOD_GROUPLOOT,
    description = L.MOD_GROUPLOOT_DESC,
    tested      = false,
}

function M.IsAvailable()
    return ns.HasFrame("GroupLootContainer", "GroupLootFrame1")
end

function M.Enable()
    -- Skin folgt nach LibPardona 1.1.0 und der Frame-Analyse.
end

function M.Disable()
    -- Skin entfernen (LP:RemoveStyle) folgt zusammen mit Enable().
end

ns:RegisterModule("grouploot", M)
