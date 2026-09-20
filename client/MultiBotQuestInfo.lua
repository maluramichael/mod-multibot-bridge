-- MultiBotQuestInfo.lua
--
-- Quest popup + party quest progress in tooltips, for MultiBot. Companion of MultiBotQuestMatrixFrame.lua.
--
--   * Quest popup: the full quest text (description, objectives, reward text), where the quest starts and is
--     handed in (NPC, zone, map percent coordinates), and every party member's status and objective progress.
--     Opens when you click a quest name in the quest matrix, or a quest link in the chat.
--   * Tooltips: hover an enemy and the tooltip lists which party members still need it for a quest ("Kloppi: ...  3/8").
--
-- Why the server has to help: a 3.3.5 client only knows its own quest log, and quest texts of quests you do not have
-- are not available to addons at all. Server side: mod-multibot-bridge  GET QUEST_INFO / GET QUEST_PROGRESS
-- (capability QUEST_INFO_V1).

if not MultiBot then return end

local QI = MultiBot.QuestInfo or {}
MultiBot.QuestInfo = QI

local DE = (GetLocale() == "deDE")
local function tr(en, de)
  if DE then return de end
  return en
end

local FRAME_NAME = "MultiBotQuestInfoFrame"
local SCROLL_NAME = "MultiBotQuestInfoScroll"
local REQUEST_TIMEOUT = 8
local PROGRESS_MAX_AGE = 6
local TEXT_WIDTH = 410

local CLASS_TOKENS = {
  [1] = "WARRIOR", [2] = "PALADIN", [3] = "HUNTER", [4] = "ROGUE", [5] = "PRIEST",
  [6] = "DEATHKNIGHT", [7] = "SHAMAN", [8] = "MAGE", [9] = "WARLOCK", [11] = "DRUID",
}

local STATUS_TEXT = {
  A = { tr("Active", "Aktiv"), "|cffffd200" },
  R = { tr("Ready to turn in", "Abgabebereit"), "|cff40ff40" },
  F = { tr("Failed", "Fehlgeschlagen"), "|cffff4040" },
  D = { tr("Done", "Abgeschlossen"), "|cff909090" },
  N = { tr("Does not have it", "Hat die Quest nicht"), "|cffff8c1a" },
  X = { tr("Cannot take it", "Kann sie nicht annehmen"), "|cff995555" },
}

QI.seq = QI.seq or 0
QI.progress = QI.progress or { byCreature = {}, updatedAt = 0 }

local frame, scroll, content, child
local timers = {}

-- ---------------------------------------------------------------- helpers
local timerFrame = CreateFrame("Frame")
timerFrame:SetScript("OnUpdate", function()
  if #timers == 0 then return end
  local now = GetTime()
  for i = #timers, 1, -1 do
    local t = timers[i]
    if t and now >= t.at then
      table.remove(timers, i)
      t.fn()
    end
  end
end)

local function after(delay, fn)
  table.insert(timers, { at = GetTime() + delay, fn = fn })
end

local function decode(value)
  return (string.gsub(value or "", "%%(%x%x)", function(hex) return string.char(tonumber(hex, 16)) end))
end

local function classColor(classId)
  local token = CLASS_TOKENS[tonumber(classId) or 0]
  local color = token and RAID_CLASS_COLORS and RAID_CLASS_COLORS[token]
  if color then
    return string.format("|cff%02x%02x%02x", math.floor(color.r * 255), math.floor(color.g * 255), math.floor(color.b * 255))
  end
  return "|cffffffff"
end

local function bridgeReady()
  local bridge = MultiBot.bridge
  local comm = MultiBot.Comm
  if not (bridge and comm and comm.Send) then return false end
  if not (bridge.connected or bridge.bootstrapPending) then return false end
  if bridge.capabilitiesResolved and not bridge.questInfoCapable then return false end
  return true
end

local function newToken(kind)
  QI.seq = QI.seq + 1
  return "qi" .. kind .. math.floor(GetTime() * 1000) .. "-" .. QI.seq
end

-- ---------------------------------------------------------------- popup rendering
local function coordText(location)
  if location.px >= 0 and location.py >= 0 then
    return string.format("%.1f, %.1f", location.px, location.py)
  end
  return nil
end

local function locationLine(prefix, location)
  local where = {}
  if location.zone ~= "" then table.insert(where, location.zone) end
  local coords = coordText(location)
  local line = prefix .. " |cffffffff" .. location.name .. "|r"
  if #where > 0 then line = line .. " - " .. where[1] end
  if coords then line = line .. " |cff00ccff(" .. coords .. ")|r" end
  if location.map ~= "" and (location.zone == "" or not location.sameMap) then
    line = line .. " |cff909090[" .. location.map .. "]|r"
  end
  return line
end

local function buildText(data)
  local parts = {}
  local function section(title, body)
    if body and body ~= "" then
      table.insert(parts, "|cffffd200" .. title .. "|r\n" .. body .. "\n")
    end
  end

  section(tr("Description", "Beschreibung"), data.text.D)
  section(tr("Objectives", "Ziele"), data.text.O)

  -- where to go
  local where = {}
  for _, location in ipairs(data.locations) do
    if location.role == "S" then
      table.insert(where, locationLine(tr("Start:", "Start:"), location))
    end
  end
  for _, location in ipairs(data.locations) do
    if location.role == "E" then
      table.insert(where, locationLine(tr("Turn in:", "Abgabe:"), location))
    end
  end
  if #where == 0 then
    table.insert(where, "|cff909090" .. tr("No position known for the quest giver.", "Keine Position des Questgebers bekannt.") .. "|r")
  end
  section(tr("Where", "Wo"), table.concat(where, "\n"))

  -- party progress
  local party = {}
  for _, member in ipairs(data.members) do
    local status = STATUS_TEXT[member.status] or STATUS_TEXT.X
    table.insert(party, classColor(member.class) .. member.name .. "|r  " .. status[2] .. status[1] .. "|r")
    for _, objective in ipairs(member.objectives) do
      local color = (objective.have >= objective.need) and "|cff40ff40" or "|cffffffff"
      table.insert(party, string.format("    %s%s  %d/%d|r", color, objective.name, objective.have, objective.need))
    end
  end
  section(tr("Party", "Party"), table.concat(party, "\n"))

  section(tr("Progress text", "Fortschrittstext"), data.text.P)
  section(tr("Reward text", "Belohnungstext"), data.text.R)

  return table.concat(parts, "\n")
end

QI.BuildText = buildText -- exposed for the offline tests

local function render()
  if not frame or not QI.data then return end
  local data = QI.data

  frame.title:SetText(data.title ~= "" and data.title or ("Quest " .. data.questId))
  local sub = string.format(tr("Quest %d  -  Level %d (from level %d)", "Quest %d  -  Level %d (ab Level %d)"), data.questId, data.level, data.minLevel)
  frame.sub:SetText(sub)

  content:SetText(buildText(data))
  child:SetHeight(content:GetStringHeight() + 12)
  scroll:UpdateScrollChildRect()
end

local function setLoading(text)
  if not frame then return end
  content:SetText("|cff909090" .. text .. "|r")
  child:SetHeight(content:GetStringHeight() + 12)
  scroll:UpdateScrollChildRect()
end

-- ---------------------------------------------------------------- request
function QI.Request(questId)
  questId = tonumber(questId)
  if not questId then return false end

  if not bridgeReady() then
    setLoading(tr("The server does not know the quest info yet (needs the new build + restart), or the MultiBot bridge is not connected.",
                  "Der Server kennt die Quest-Info noch nicht (neuer Build + Neustart noetig) oder die MultiBot-Bridge ist nicht verbunden."))
    return false
  end

  local token = newToken("q")
  QI.token = token
  QI.incoming = nil
  QI.loading = true
  setLoading(tr("Loading ...", "Lade ..."))

  if not MultiBot.Comm.Send("GET", "QUEST_INFO~" .. token .. "~" .. questId) then
    QI.loading = false
    QI.token = nil
    return false
  end

  after(REQUEST_TIMEOUT, function()
    if QI.loading and QI.token == token then
      QI.loading = false
      QI.token = nil
      setLoading(tr("No answer from the server.", "Keine Antwort vom Server."))
    end
  end)

  return true
end

-- ---------------------------------------------------------------- packets
local function onInfoPacket(opcode, payload)
  if opcode == "QI_HEAD" then
    local token, questId, level, minLevel, title = strsplit("~", payload or "", 5)
    if token ~= QI.token then return end
    QI.incoming = {
      questId = tonumber(questId) or 0, level = tonumber(level) or 0, minLevel = tonumber(minLevel) or 0,
      title = decode(title), text = { D = "", O = "", P = "", R = "" }, chunks = {}, locations = {}, members = {},
    }
    return
  end

  local incoming = QI.incoming
  if not incoming then return end

  if opcode == "QI_TEXT" then
    local token, kind, index, count, chunk = strsplit("~", payload or "", 5)
    if token ~= QI.token then return end
    incoming.chunks[kind] = incoming.chunks[kind] or {}
    incoming.chunks[kind][(tonumber(index) or 0) + 1] = decode(chunk)
    incoming.text[kind] = table.concat(incoming.chunks[kind])
    return
  end

  if opcode == "QI_LOC" then
    local token, role, kind, entry, px, py, same, mapName, zoneName, name = strsplit("~", payload or "", 10)
    if token ~= QI.token then return end
    px, py = tonumber(px) or -1, tonumber(py) or -1
    table.insert(incoming.locations, {
      role = role, kind = kind, entry = tonumber(entry) or 0,
      px = px >= 0 and px / 10 or -1, py = py >= 0 and py / 10 or -1,
      sameMap = same == "1", map = decode(mapName), zone = decode(zoneName), name = decode(name),
    })
    return
  end

  if opcode == "QI_MEMBER" then
    local token, index, name, isSelf, status, class = strsplit("~", payload or "", 6)
    if token ~= QI.token then return end
    local i = (tonumber(index) or 0) + 1
    incoming.members[i] = { name = decode(name), isSelf = isSelf == "1", status = status, class = tonumber(class) or 0, objectives = {} }
    return
  end

  if opcode == "QI_OBJ" then
    local token, index, kind, entry, have, need, name = strsplit("~", payload or "", 7)
    if token ~= QI.token then return end
    local member = incoming.members[(tonumber(index) or 0) + 1]
    if member then
      table.insert(member.objectives, {
        kind = kind, entry = tonumber(entry) or 0, have = tonumber(have) or 0, need = tonumber(need) or 0, name = decode(name),
      })
    end
    return
  end

  if opcode == "QI_END" then
    local token = strsplit("~", payload or "", 2)
    if token ~= QI.token then return end
    QI.data = incoming
    QI.incoming = nil
    QI.loading = false
    QI.token = nil
    render()
  end
end

local function onProgressPacket(opcode, payload)
  if opcode == "QP_BEGIN" then
    local token = strsplit("~", payload or "", 2)
    if token ~= QI.progressToken then return end
    QI.progressIncoming = { byCreature = {}, members = {} }
    return
  end

  local incoming = QI.progressIncoming
  if not incoming then return end

  if opcode == "QP_MEMBER" then
    local token, index, name, isSelf, class = strsplit("~", payload or "", 5)
    if token ~= QI.progressToken then return end
    incoming.members[(tonumber(index) or 0) + 1] = { name = decode(name), isSelf = isSelf == "1", class = tonumber(class) or 0 }
    return
  end

  if opcode == "QP_Q" then
    local token, index, questId, complete, objectives, title = strsplit("~", payload or "", 6)
    if token ~= QI.progressToken then return end
    local member = incoming.members[(tonumber(index) or 0) + 1]
    if not member or member.isSelf then return end

    for entry, have, need in string.gmatch(objectives or "", "(%d+):(%d+):(%d+)") do
      local id = tonumber(entry)
      incoming.byCreature[id] = incoming.byCreature[id] or {}
      table.insert(incoming.byCreature[id], {
        member = member, questId = tonumber(questId) or 0, title = decode(title),
        have = tonumber(have) or 0, need = tonumber(need) or 0,
      })
    end
    return
  end

  if opcode == "QP_END" then
    local token = strsplit("~", payload or "", 2)
    if token ~= QI.progressToken then return end
    QI.progress = { byCreature = incoming.byCreature, updatedAt = GetTime() }
    QI.progressIncoming = nil
    QI.progressLoading = false

    -- redraw the tooltip that is showing right now with the fresh numbers
    if GameTooltip:IsShown() and UnitExists("mouseover") then
      GameTooltip:SetUnit("mouseover")
    end
  end
end

function QI.OnPacket(opcode, payload)
  if string.sub(opcode, 1, 3) == "QP_" then
    onProgressPacket(opcode, payload)
  else
    onInfoPacket(opcode, payload)
  end
end

function QI.OnError(requestType, token, reason)
  if requestType == "QUEST_INFO" and token == QI.token then
    QI.loading = false
    QI.token = nil
    setLoading("|cffff5555" .. (reason or "error") .. "|r")
  elseif requestType == "QUEST_PROGRESS" and token == QI.progressToken then
    QI.progressLoading = false
  end
end

-- ---------------------------------------------------------------- quest progress for tooltips
local function inGroup()
  return (GetNumPartyMembers and GetNumPartyMembers() > 0) or (GetNumRaidMembers and GetNumRaidMembers() > 0)
end

function QI.RequestProgress()
  if QI.progressLoading or not bridgeReady() or not inGroup() then return false end

  local token = newToken("p")
  QI.progressToken = token
  QI.progressLoading = true

  if not MultiBot.Comm.Send("GET", "QUEST_PROGRESS~" .. token) then
    QI.progressLoading = false
    return false
  end

  after(REQUEST_TIMEOUT, function()
    if QI.progressToken == token then QI.progressLoading = false end
  end)

  return true
end

local function creatureEntryFromGuid(guid)
  if type(guid) ~= "string" or string.len(guid) < 12 then return nil end
  local high = tonumber(string.sub(guid, 3, 6), 16)
  -- 0xF130 creature, 0xF150 vehicle
  if high ~= 0xF130 and high ~= 0xF150 then return nil end
  return tonumber(string.sub(guid, 7, 12), 16)
end

local function onTooltipUnit(tooltip)
  local _, unit = tooltip:GetUnit()
  if not unit or UnitIsPlayer(unit) then return end

  if not inGroup() then return end

  local entry = creatureEntryFromGuid(UnitGUID(unit))
  if not entry then return end

  -- refresh in the background when the numbers are getting old; the tooltip redraws itself when they arrive
  if GetTime() - (QI.progress.updatedAt or 0) > PROGRESS_MAX_AGE then
    QI.RequestProgress()
  end

  local list = QI.progress.byCreature[entry]
  if not list then return end

  tooltip:AddLine(" ")
  for _, item in ipairs(list) do
    local done = item.have >= item.need
    local color = done and "|cff40ff40" or "|cffffd200"
    tooltip:AddLine(classColor(item.member.class) .. item.member.name .. "|r: " .. item.title .. "  " .. color .. item.have .. "/" .. item.need .. "|r")
  end

  tooltip:Show()
end

if GameTooltip and GameTooltip.HookScript then
  GameTooltip:HookScript("OnTooltipSetUnit", onTooltipUnit)
end

-- ---------------------------------------------------------------- popup frame
local function createFrame()
  frame = CreateFrame("Frame", FRAME_NAME, UIParent)
  frame:SetFrameStrata("DIALOG")
  frame:SetWidth(470)
  frame:SetHeight(560)
  frame:SetPoint("CENTER", UIParent, "CENTER", 120, 0)
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:SetClampedToScreen(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
  frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
  frame:SetBackdrop({
    bgFile = "Interface/DialogFrame/UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = false, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 },
  })
  -- the parchment is dark on some clients: put a plain dark layer under it so the text is always readable
  local shade = frame:CreateTexture(nil, "BACKGROUND")
  shade:SetPoint("TOPLEFT", frame, "TOPLEFT", 11, -11)
  shade:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 11)
  shade:SetTexture(0.05, 0.05, 0.08, 0.92)

  frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  frame.title:SetPoint("TOPLEFT", frame, "TOPLEFT", 22, -20)
  frame.title:SetPoint("RIGHT", frame, "RIGHT", -40, 0)
  frame.title:SetJustifyH("LEFT")

  frame.sub = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  frame.sub:SetPoint("TOPLEFT", frame.title, "BOTTOMLEFT", 0, -4)
  frame.sub:SetJustifyH("LEFT")

  local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -4)

  scroll = CreateFrame("ScrollFrame", SCROLL_NAME, frame, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -66)
  scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -38, 46)

  child = CreateFrame("Frame", nil, scroll)
  child:SetWidth(TEXT_WIDTH)
  child:SetHeight(10)
  scroll:SetScrollChild(child)

  content = child:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  content:SetPoint("TOPLEFT", child, "TOPLEFT", 0, 0)
  content:SetWidth(TEXT_WIDTH)
  content:SetJustifyH("LEFT")
  content:SetJustifyV("TOP")

  local refresh = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  refresh:SetWidth(110)
  refresh:SetHeight(22)
  refresh:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -20, 16)
  refresh:SetText(tr("Refresh", "Aktualisieren"))
  refresh:SetScript("OnClick", function()
    if QI.questId then QI.Request(QI.questId) end
  end)

  table.insert(UISpecialFrames, FRAME_NAME)
  frame:Hide()
end

function QI.Show(questId, level)
  questId = tonumber(questId)
  if not questId then return end

  if not frame then createFrame() end

  QI.questId = questId
  QI.data = nil
  frame.title:SetText("Quest " .. questId)
  frame.sub:SetText(level and string.format(tr("Level %d", "Level %d"), tonumber(level) or 0) or "")
  frame:Show()
  QI.Request(questId)
end

-- ---------------------------------------------------------------- click on quest links
-- A plain click on a quest link opens the popup instead of doing nothing (or, with AzerothAdmin, a GM command).
-- Modified clicks (shift = link into the chat, ...) and unknown situations fall through to the original handler.
local originalSetItemRef = SetItemRef
if type(originalSetItemRef) == "function" then
  SetItemRef = function(link, text, button, ...)
    if type(link) == "string" and button ~= "RightButton"
        and not IsShiftKeyDown() and not IsControlKeyDown() and not IsAltKeyDown() then
      local id, level = string.match(link, "^quest:(%d+):?(%-?%d*)")
      if id and bridgeReady() then
        QI.Show(tonumber(id), tonumber(level))
        return
      end
    end
    return originalSetItemRef(link, text, button, ...)
  end
end

SLASH_MBQUESTINFO1 = "/mbqi"
SlashCmdList["MBQUESTINFO"] = function(msg)
  local id = tonumber(string.match(msg or "", "(%d+)"))
  if id then QI.Show(id) end
end
