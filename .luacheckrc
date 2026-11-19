-- luacheck configuration for Pardona's UI (WoW Forever, Lua 5.1)
std = "lua51"
max_line_length = false
-- WoW callbacks receive parameters (self, event, button, ...) that are often unused
unused_args = false
exclude_files = { ".release", "Libs" }

-- Globals the addon writes
globals = {
    "GetMinimapShape",
    "PardonasUIDB",
    "SLASH_PARDONASUI1",
    "SlashCmdList",
}

-- WoW API functions and objects the addon reads
read_globals = {
    -- namespaces
    "C_AddOns",
    "C_EventUtils",
    -- frames and UI objects
    "CreateFrame",
    "LibStub",
    "UIParent",
    "UISpecialFrames",
    -- functions
    "date",
    "GetAddOnMetadata",
    "GetBuildInfo",
    "geterrorhandler",
    "GetLocale",
    "hooksecurefunc",
    "InCombatLockdown",
    "issecretvalue",
}
