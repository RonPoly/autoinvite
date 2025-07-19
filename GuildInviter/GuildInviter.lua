-- GuildInviter v2.5 - Manual Override Fix & Class Filter
local GI = LibStub("AceAddon-3.0"):NewAddon("GuildInviter", "AceConsole-3.0", "AceEvent-3.0", "AceTimer-3.0")
local ADB  = LibStub("AceDB-3.0")
local ACD  = LibStub("AceConfig-3.0")
local ACDD = LibStub("AceConfigDialog-3.0")
local LBC = LibStub("LibBabble-Class-3.0"):GetLookupTable()

-- Default profile
local defaults = {
  profile = {
    levelMin         = 1,
    levelMax         = 80,
    scanInterval     = 5,
    queue            = {},
    blacklist        = {},
    autoInvite       = true,
    inviteDelay      = 30,
    framePos         = { point = "CENTER", x = 0, y = 0 },
    whisperMode      = "AFTER_INVITE",
    whisperMessage   = "Welcome to the guild! We're happy to have you join us.",
    sessionAccepted  = 0,
    queueThreshold   = 10,
    classes          = {
      WARRIOR = true,
      PALADIN = true,
      HUNTER = true,
      ROGUE = true,
      PRIEST = true,
      DEATHKNIGHT = true,
      SHAMAN = true,
      MAGE = true,
      WARLOCK = true,
      DRUID = true
    }
  },
}

-- Options panel
local options = {
  name = "GuildInviter",
  type = "group",
  args = {
    general = {
      type = "group",
      name = "General Settings",
      order = 1,
      args = {
        header1 = { type = "header", name = "Control", order = 1 },
        start = { type = "execute", name = "Start Scan", order = 2, width = "half", func = function() GI:Start() end },
        stop  = { type = "execute", name = "Stop Scan",  order = 3, width = "half", func = function() GI:Stop()  end },
        header2 = { type = "header", name = "Level Range", order = 4 },
        levelMin = { type = "range", name = "Min Level", min = 1, max = 80, step = 1, order = 5,
          get = function() return GI.db.profile.levelMin end,
          set = function(_,v) GI.db.profile.levelMin = v end },
        levelMax = { type = "range", name = "Max Level", min = 1, max = 80, step = 1, order = 6,
          get = function() return GI.db.profile.levelMax end,
          set = function(_,v) GI.db.profile.levelMax = v end },
        header3 = { type = "header", name = "Timing & Invites", order = 7 },
        scanInterval = { type = "range", name = "Scan Interval (sec)", desc = "Time between each /who query.", order = 8, min = 3, max = 15, step = 1,
          get = function() return GI.db.profile.scanInterval end,
          set = function(_,v) GI.db.profile.scanInterval = v end },
        inviteDelay = { type = "range", name = "Invite Delay (sec)", desc = "Delay between automatic invites.", min = 10, max = 120, step = 5, order = 9,
          get = function() return GI.db.profile.inviteDelay end,
          set = function(_,v) GI.db.profile.inviteDelay = v end },
        autoInvite = { type = "toggle", name = "Auto-Invite Players", desc = "Automatically invite players from queue.", width = "full", order = 10,
          get = function() return GI.db.profile.autoInvite end,
          set = function(_,v) GI.db.profile.autoInvite = v end },
        queueThreshold = { type = "range", name = "Queue Threshold", desc = "The scan will pause when the invite queue reaches this number.", order = 11, min = 1, max = 50, step = 1,
          get = function() return GI.db.profile.queueThreshold end,
          set = function(_,v) GI.db.profile.queueThreshold = v end },
      },
    },
    classes = {
      type = "group",
      name = "Classes",
      order = 2,
      args = {
        class_filter = {
          type = "multiselect",
          name = "Recruiting Classes",
          order = 1,
          values = {
            WARRIOR = LBC["Warrior"],
            PALADIN = LBC["Paladin"],
            HUNTER = LBC["Hunter"],
            ROGUE = LBC["Rogue"],
            PRIEST = LBC["Priest"],
            DEATHKNIGHT = LBC["Death Knight"],
            SHAMAN = LBC["Shaman"],
            MAGE = LBC["Mage"],
            WARLOCK = LBC["Warlock"],
            DRUID = LBC["Druid"]
          },
          get = function(info, key) return GI.db.profile.classes[key] end,
          set = function(info, key, value) GI.db.profile.classes[key] = value end,
        },
      },
    },
    whisper = { type = "group", name = "Whisper Settings", order = 3, args = {
        whisperMode = { type = "select", name = "Whisper Mode", order = 1, values = { AFTER_INVITE = "After Invite", INVITE_ONLY = "Invite Only", WHISPER_ONLY = "Whisper Only" },
          get = function() return GI.db.profile.whisperMode end,
          set = function(_,v) GI.db.profile.whisperMode = v end },
        whisperMessage = { type = "input", name = "Invite Message", desc = "Message to send when inviting players.", multiline = true, width = "full", order = 2,
          get = function() return GI.db.profile.whisperMessage end,
          set = function(_,v) GI.db.profile.whisperMessage = v end },
      },
    },
    maintenance = { type = "group", name = "Maintenance", order = 4, args = {
        clearQueue = { type = "execute", name = "Clear Queue", order = 3, confirm = true,
          func = function() GI.db.profile.queue = {}; GI:UpdateFrameLabel(); print("|cff00ff00Queue cleared.|r") end },
        resetBlacklist = { type = "execute", name = "Reset Blacklist", order = 4, confirm = true,
          func = function() GI.db.profile.blacklist = {}; print("|cff00ff00Blacklist cleared.|r") end },
        resetSessionStats = { type = "execute", name = "Reset Session Stats", order = 5,
          func = function() GI.db.profile.sessionAccepted = 0; print("|cff00ff00Session stats reset.|r") end },
      },
    },
  },
}

-- Main Addon Functions
function GI:OnInitialize()
  self.db = ADB:New("GuildInviterDB", defaults, true)
  ACD:RegisterOptionsTable("GuildInviter", options)
  self.optionsFrame = ACDD:AddToBlizOptions("GuildInviter", "Guild Inviter")
  self:RegisterChatCommand("ginv", "ChatCommand")
  print("|cff00ff00GuildInviter v2.5 loaded.|r")
end

function GI:OnEnable()
  if not self.frame then self:CreateMainFrame() end
  self:RegisterEvent("WHO_LIST_UPDATE")
  self:RegisterEvent("CHAT_MSG_SYSTEM")
  self.db.profile.sessionAccepted = 0
  self:UpdateStatusText("STOPPED")
  print("|cff00ff00GuildInviter Enabled.|r")
end

function GI:OnDisable()
    self:Stop()
end

-- Scanning and Queue Logic
function GI:Start()
    if self.scanTimer then print("Scan already in progress."); return end
    self.currentScanLevel = self.db.profile.levelMin
    self.isPaused = false
    self.scanTimer = self:ScheduleRepeatingTimer("DoSearch", self.db.profile.scanInterval)
    if self.db.profile.autoInvite and not self.inviteTimer then
        self.inviteTimer = self:ScheduleRepeatingTimer("ProcessInviteQueue", self.db.profile.inviteDelay)
    end
end

function GI:Stop()
    if self.scanTimer then
        self:CancelTimer(self.scanTimer)
        self.scanTimer = nil
        self:UpdateStatusText("STOPPED")
    end
    if self.inviteTimer then
        self:CancelTimer(self.inviteTimer)
        self.inviteTimer = nil
    end
end

function GI:DoSearch(isManualOverride)
    if not isManualOverride and #self.db.profile.queue >= self.db.profile.queueThreshold then
        if not self.isPaused then
            self:UpdateStatusText("PAUSED")
            self.isPaused = true
        end
        return
    end

    if self.isPaused then
        self.isPaused = false
    end

    if self.currentScanLevel > self.db.profile.levelMax then
        self:UpdateStatusText("RESTARTING")
        self.currentScanLevel = self.db.profile.levelMin
        return
    end

    self:UpdateStatusText("SCANNING", self.currentScanLevel)
    
    local classQuery = ""
    local classes = {}
    for class, enabled in pairs(self.db.profile.classes) do
        if enabled then
            table.insert(classes, 'c-"' .. LBC[class] .. '"')
        end
    end
    if #classes > 0 then
        classQuery = table.concat(classes, " ")
    end

    SetWhoToUI(false)
    SendWho(string.format('g-"" %s %d', classQuery, self.currentScanLevel))
    self.currentScanLevel = self.currentScanLevel + 1
end

function GI:ForceScan()
    if not self.scanTimer then
        print("Scan is not running. Use Start first.")
        return
    end
    print("|cff00ff00Manual scan override!|r")
    self.isPaused = false
    self:DoSearch(true)
end

function GI:WHO_LIST_UPDATE()
    local numResults = GetNumWhoResults()
    for i = 1, numResults do
        local name, guild = GetWhoInfo(i)

        if guild == "" and not self.db.profile.blacklist[name] then
            local alreadyInQueue = false
            for _, queuedName in ipairs(self.db.profile.queue) do
                if queuedName == name then
                    alreadyInQueue = true
                    break
                end
            end
            if not alreadyInQueue then
                table.insert(self.db.profile.queue, name)
                self:UpdateFrameLabel()
            end
        end
    end
end

function GI:CHAT_MSG_SYSTEM(event, msg)
  if not msg then return end

  if (msg:find("muted") or msg:find("restricted") or msg:find("too many messages")) then
    print("|cffff0000GuildInviter: Chat restriction detected!|r")
    print("|cffff0000The addon has been automatically stopped for safety.|r")
    self:Stop()
  end

  if msg:find("has joined the guild") then
    self.db.profile.sessionAccepted = self.db.profile.sessionAccepted + 1
  end
end

function GI:ProcessInviteQueue()
    if #self.db.profile.queue == 0 then return end

    local name = table.remove(self.db.profile.queue, 1)
    if name then
        self:InvitePerson(name)
        self:UpdateFrameLabel()
    end
end

function GI:InvitePerson(name)
    if not name or self.db.profile.blacklist[name] then return end

    GuildInvite(name)
    self.db.profile.blacklist[name] = true

    if self.db.profile.whisperMode == "AFTER_INVITE" then
        self:ScheduleTimer(function()
            SendChatMessage(self.db.profile.whisperMessage, "WHISPER", nil, name)
        end, 2)
    elseif self.db.profile.whisperMode == "WHISPER_ONLY" then
        SendChatMessage(self.db.profile.whisperMessage, "WHISPER", nil, name)
    end
end

-- UI and Helper Functions
function GI:CreateMainFrame()
  self.frame = CreateFrame("Button", "GI_MainFrame", UIParent)
  local f = self.frame
  f:SetSize(150, 40); f:SetMovable(true); f:EnableMouse(true); f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); local p, _, _, x, y = self:GetPoint(); GI.db.profile.framePos = {point = p, x = x, y = y} end)
  f:SetPoint(self.db.profile.framePos.point, UIParent, self.db.profile.framePos.point, self.db.profile.framePos.x, self.db.profile.framePos.y)
  f:SetNormalTexture("Interface\\Buttons\\WHITE8X8");
  local tex = f:GetNormalTexture(); tex:SetVertexColor(0.1, 0.1, 0.1, 0.8)
  f:SetBackdrop({edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 14}); f:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)

  self.label = f:CreateFontString(nil, "OVERLAY", "GameFontNormal");
  self.label:SetPoint("TOP", f, "TOP", 0, -8);

  self.statusLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
  self.statusLabel:SetPoint("BOTTOM", f, "BOTTOM", 0, 8)

  self:UpdateFrameLabel()

  f:SetScript("OnClick", function(self, button)
    if IsShiftKeyDown() then
        GI:ForceScan()
    else
        InterfaceOptionsFrame_OpenToCategory(GI.optionsFrame)
        InterfaceOptionsFrame_OpenToCategory(GI.optionsFrame)
    end
  end)

  f:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText("Guild Inviter")
    GameTooltip:AddLine("Left-Click: Open settings", 0.8, 0.8, 0.8)
    GameTooltip:AddLine("Shift-Click: Force scan to continue", 0.8, 0.8, 0.8)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(string.format("Session Accepted: |cff00ff00%d|r", GI.db.profile.sessionAccepted))
    GameTooltip:Show()
  end)
  f:SetScript("OnLeave", GameTooltip_Hide)
end

function GI:UpdateFrameLabel()
  if self.label then
    self.label:SetText(string.format("Invite Queue: %d", #self.db.profile.queue))
  end
end

function GI:UpdateStatusText(statusKey, value)
    if not self.statusLabel then return end

    local text = ""
    if statusKey == "SCANNING" then
        text = string.format("|cffffff00Scanning Level %d...|r", value)
    elseif statusKey == "PAUSED" then
        text = "|cffff0000Scan Paused|r"
    elseif statusKey == "STOPPED" then
        text = "|cffff0000Scan Stopped|r"
    elseif statusKey == "RESTARTING" then
        text = "|cff00ff00Cycle Finished|r"
    end
    self.statusLabel:SetText(text)
end

function GI:ChatCommand(input)
  local cmd, rest = strsplit(" ", input or "", 2); cmd = (cmd or ""):lower()
  if cmd == "" or cmd == "help" then
    print("|cff00ff00GuildInviter commands:|r"); print("|cffffcc00/ginv start|r - Start"); print("|cffffcc00/ginv stop|r - Stop"); print("|cffffcc00/ginv auto|r - Toggle auto-invite"); print("|cffffcc00/ginv scan|r - Force a scan"); print("|cffffcc00/ginv status|r - Show status"); print("|cffffcc00/ginv config|r - Open settings")
  elseif cmd == "start" then self:Start()
  elseif cmd == "stop" then self:Stop()
  elseif cmd == "auto" then self:ToggleAutoInvite()
  elseif cmd == "scan" then self:ForceScan()
  elseif cmd == "status" then self:PrintStatus()
  elseif cmd == "config" or cmd == "options" then
    InterfaceOptionsFrame_OpenToCategory(self.optionsFrame)
    InterfaceOptionsFrame_OpenToCategory(self.optionsFrame)
  else print("|cffff0000Unknown command.|r Use /ginv help") end
end

function GI:PrintStatus()
    print("|cff00ff00GuildInviter Status:|r")
    if self.scanTimer then
        if self.isPaused then
            print("  Status: |cffff0000Scan Paused|r")
        else
            print("  Status: |cff00ff00Scanning|r")
        end
    else
        print("  Status: |cffff0000Scan Stopped|r")
    end
    print(string.format("  Auto-invite: %s", self.db.profile.autoInvite and "|cff00ff00Enabled|r" or "|cffff0000Disabled|r"))
    print(string.format("  Invite Queue: |cffffcc00%d|r", #self.db.profile.queue))
    print(string.format("  Session Accepted: |cffffcc00%d|r", self.db.profile.sessionAccepted))
end

