-- MultiBotQuestMatrixFrame.lua
--
-- Party-wide quest overview ("Quest-Matrix") for MultiBot.
--
-- Rows    = every quest that anybody in the party has open or has finished, restricted to quests of the
--           last <span> levels (quest level >= your level - span).
-- Columns = you + the bots grouped with you.
-- Cell    = Add (click: the quest is put straight into that bot's log, no NPC visit), Active, Turn in,
--           Failed, Done, or "-" (that character cannot take the quest).
--
-- Server side: mod-multibot-bridge  GET QUEST_MATRIX / RUN QUEST_GIVE  (capability QUEST_MATRIX_V1).
-- Packets are routed here from Core\MultiBotComm.lua (HandleAddonMessage) via MultiBot.QuestMatrix.OnPacket.

if not MultiBot then return end

local QM = MultiBot.QuestMatrix or {}
MultiBot.QuestMatrix = QM

local DE = (GetLocale() == "deDE")
local function tr(en, de)
  if DE then return de end
  return en
end

local FRAME_NAME = "MultiBotQuestMatrixFrame"
local SCROLL_NAME = "MultiBotQuestMatrixScroll"

local ROW_HEIGHT = 18
local VISIBLE_ROWS = 20
local LEFT = 16
local HEADER_TOP = 44
local ROWS_TOP = 78
local FOOTER = 46
local LEVEL_WIDTH = 28
local NAME_WIDTH = 250
local CELL_WIDTH = 66
local ALL_WIDTH = 44
local MAX_MEMBERS = 10
local REQUEST_TIMEOUT = 8
local SPANS = { 5, 10, 15, 20, 40 }

local CLASS_TOKENS = {
  [1] = "WARRIOR", [2] = "PALADIN", [3] = "HUNTER", [4] = "ROGUE", [5] = "PRIEST",
  [6] = "DEATHKNIGHT", [7] = "SHAMAN", [8] = "MAGE", [9] = "WARLOCK", [11] = "DRUID",
}

local STATUS = {
  A = { text = "Active",  color = { 1.00, 0.82, 0.00 } },
  R = { text = "Turn in", color = { 0.25, 1.00, 0.25 } },
  F = { text = "Failed",  color = { 1.00, 0.25, 0.25 } },
  D = { text = "Done",    color = { 0.55, 0.55, 0.55 } },
  N = { text = "Add",     color = { 1.00, 0.55, 0.10 } },
  X = { text = "-",       color = { 0.45, 0.20, 0.20 } },
}

local STATUS_TIP = {
  A = tr("Active", "Aktiv"),
  R = tr("Objectives done, turn it in", "Ziele erfuellt, abgabebereit"),
  F = tr("Failed", "Fehlgeschlagen"),
  D = tr("Done", "Abgeschlossen"),
  N = tr("Not taken yet", "Noch nicht angenommen"),
  X = tr("Cannot take this quest (level / class / prerequisite ...)", "Kann die Quest nicht annehmen (Level / Klasse / Voraussetzung ...)"),
}

local GIVE_ERRORS = {
  LEVEL = tr("level too low", "Level zu niedrig"),
  CLASS = tr("wrong class", "falsche Klasse"),
  RACE = tr("wrong race", "falsche Rasse"),
  SKILL = tr("skill too low", "Fertigkeit zu niedrig"),
  REPUTATION = tr("reputation too low", "Ruf zu niedrig"),
  PREREQ = tr("prerequisite quest missing", "Vorquest fehlt"),
  EXCLUSIVE = tr("an exclusive quest is already taken/done", "eine exklusive Quest ist schon aktiv/erledigt"),
  CHAIN = tr("a later quest of the chain is already taken", "eine spaetere Quest der Kette ist schon aktiv"),
  CANNOT_TAKE = tr("cannot take this quest", "kann die Quest nicht annehmen"),
  CANNOT_ADD = tr("start item does not fit in the bags", "Startgegenstand passt nicht ins Inventar"),
  ALREADY_DONE = tr("already done", "schon abgeschlossen"),
  ALREADY_HAS = tr("already has the quest", "hat die Quest schon"),
  NO_BOT = tr("bot not found", "Bot nicht gefunden"),
  NO_QUEST = tr("unknown quest", "unbekannte Quest"),
  FORBIDDEN = tr("not allowed", "keine Berechtigung"),
  RATE_LIMIT = tr("too fast, wait a moment", "zu schnell, kurz warten"),
  FAILED = tr("the server did not accept it", "der Server hat sie nicht angenommen"),
  BAD_REQUEST = tr("bad request", "ungueltige Anfrage"),
}

QM.span = QM.span or 10
QM.hideDone = QM.hideDone or false
QM.seq = QM.seq or 0
QM.giveActive = QM.giveActive or {}
QM.data = QM.data or { members = {}, rows = {}, refLevel = 0, span = 10, truncated = false }

local frame, scroll
local rowFrames = {}
local memberHeaders = {}

local function say(text)
  DEFAULT_CHAT_FRAME:AddMessage("|cffff9933[MultiBot]|r " .. text)
end

-- ---------------------------------------------------------------- tiny timer helper
local timerFrame = CreateFrame("Frame")
local timers = {}
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

-- ---------------------------------------------------------------- helpers
local function decode(value)
  return (string.gsub(value or "", "%%(%x%x)", function(hex) return string.char(tonumber(hex, 16)) end))
end

local function isActionable(row, members)
  for j, st in ipairs(row.st) do
    if st == "A" or st == "R" or st == "F" then return true end
    if st == "N" and members[j] and not members[j].isSelf then return true end
  end
  return false
end

local function visibleRows()
  local data = QM.data
  if not QM.hideDone then return data.rows end
  local list = {}
  for _, row in ipairs(data.rows) do
    if isActionable(row, data.members) then table.insert(list, row) end
  end
  return list
end

local function questLink(row)
  return "|cffffff00|Hquest:" .. row.id .. ":" .. row.level .. "|h[" .. row.title .. "]|h|r"
end

-- ---------------------------------------------------------------- bridge access
local function bridgeReady()
  local bridge = MultiBot.bridge
  local comm = MultiBot.Comm
  if not (bridge and comm and comm.Send) then return false, "no comm" end
  if not (bridge.connected or bridge.bootstrapPending) then
    return false, tr("MultiBot bridge is not connected (are the bots online?)", "MultiBot-Bridge nicht verbunden (sind die Bots online?)")
  end
  if bridge.capabilitiesResolved and not bridge.questMatrixCapable then
    return false, tr("The server does not support the quest matrix yet (needs the new build + restart).", "Der Server kennt die Quest-Matrix noch nicht (neuer Build + Neustart noetig).")
  end
  return true
end

local function newToken(kind)
  QM.seq = QM.seq + 1
  return "qm" .. kind .. math.floor(GetTime() * 1000) .. "-" .. QM.seq
end

-- ---------------------------------------------------------------- rendering
local function setStatusLine(text)
  if frame and frame.status then frame.status:SetText(text or "") end
end

local function memberCount()
  return math.min(#QM.data.members, MAX_MEMBERS)
end

local function layout()
  if not frame then return end
  local n = math.max(memberCount(), 1)
  local rowWidth = LEVEL_WIDTH + NAME_WIDTH + n * CELL_WIDTH + ALL_WIDTH
  frame:SetWidth(rowWidth + LEFT + 40)

  for i = 1, VISIBLE_ROWS do
    local rf = rowFrames[i]
    rf:SetWidth(rowWidth)
    for j = 1, MAX_MEMBERS do
      local cell = rf.cells[j]
      cell:ClearAllPoints()
      cell:SetPoint("LEFT", rf, "LEFT", LEVEL_WIDTH + NAME_WIDTH + (j - 1) * CELL_WIDTH, 0)
    end
    rf.all:ClearAllPoints()
    rf.all:SetPoint("LEFT", rf, "LEFT", LEVEL_WIDTH + NAME_WIDTH + n * CELL_WIDTH + 2, 0)
  end

  for j = 1, MAX_MEMBERS do
    local header = memberHeaders[j]
    header:ClearAllPoints()
    header:SetPoint("TOPLEFT", frame, "TOPLEFT", LEFT + LEVEL_WIDTH + NAME_WIDTH + (j - 1) * CELL_WIDTH, -HEADER_TOP)
    local m = QM.data.members[j]
    if m and j <= n then
      local token = CLASS_TOKENS[m.class]
      local color = token and RAID_CLASS_COLORS and RAID_CLASS_COLORS[token]
      if color then
        header:SetTextColor(color.r, color.g, color.b)
      else
        header:SetTextColor(1, 1, 1)
      end
      header:SetText(m.name .. "\n|cffaaaaaaLv " .. m.level .. "|r")
      header:Show()
    else
      header:Hide()
    end
  end
end

local function fillCell(cell, row, j, member)
  local st = row.st[j]
  if not member or not st then
    cell:Hide()
    return
  end

  local info = STATUS[st] or STATUS.X
  local text = info.text
  local r, g, b = info.color[1], info.color[2], info.color[3]

  if st == "N" and member.isSelf then
    text, r, g, b = "-", 0.4, 0.4, 0.4
  end
  if row.pending and row.pending[j] then
    text, r, g, b = "...", 0.8, 0.8, 0.8
  end

  cell.text:SetText(text)
  cell.text:SetTextColor(r, g, b)

  -- Add (bot does not have it) and Turn in (objectives done) are both clickable for bots, never for your own column
  local action = nil
  if not member.isSelf and not (row.pending and row.pending[j]) then
    if st == "N" then action = "give" elseif st == "R" then action = "turnin" end
  end
  local clickable = action ~= nil
  cell.clickable = clickable
  cell.action = action
  if clickable then
    cell:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    if action == "turnin" then
      cell:SetBackdropColor(0.04, 0.24, 0.05, 0.9)
      cell:SetBackdropBorderColor(0.25, 1, 0.25, 1)
    else
      cell:SetBackdropColor(0.30, 0.16, 0.03, 0.9)
      cell:SetBackdropBorderColor(1, 0.55, 0.1, 1)
    end
  else
    cell:SetBackdrop(nil)
  end

  cell.row = row
  cell.index = j
  cell:Show()
end

local function updateRows()
  if not frame then return end

  local rows = visibleRows()
  FauxScrollFrame_Update(scroll, #rows, VISIBLE_ROWS, ROW_HEIGHT)
  -- the offset is nil until the scroll bar was moved for the first time
  local offset = FauxScrollFrame_GetOffset(scroll) or 0
  local members = QM.data.members
  local n = memberCount()

  for i = 1, VISIBLE_ROWS do
    local rf = rowFrames[i]
    local row = rows[offset + i]
    if row then
      rf.row = row
      rf.level:SetText(row.level)
      rf.name.text:SetText(row.title)
      local color = isActionable(row, members) and 1 or 0.6
      rf.name.text:SetTextColor(color, color, color)

      local addable = 0
      for j = 1, MAX_MEMBERS do
        if j <= n then
          fillCell(rf.cells[j], row, j, members[j])
          if row.st[j] == "N" and members[j] and not members[j].isSelf and not (row.pending and row.pending[j]) then
            addable = addable + 1
          end
        else
          rf.cells[j]:Hide()
        end
      end

      if addable > 1 then rf.all:Show() else rf.all:Hide() end
      rf:Show()
    else
      rf.row = nil
      rf:Hide()
    end
  end

  local data = QM.data
  local info = tr("Quests of the last %d levels (level %d and up) - %d shown", "Quests der letzten %d Level (ab Level %d) - %d angezeigt")
  local line = string.format(info, data.span or QM.span, (data.refLevel or 0) - (data.span or QM.span), #rows)
  if data.truncated then
    line = line .. tr(" (list was cut at the server limit)", " (Liste am Server-Limit abgeschnitten)")
  end
  frame.info:SetText(line)
end

QM.UpdateRows = updateRows

-- ---------------------------------------------------------------- tooltips
local function showRowTooltip(owner, row)
  if not row then return end
  GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
  GameTooltip:AddLine(row.title, 1, 0.82, 0)
  GameTooltip:AddLine(string.format("Quest %d  -  Level %d", row.id, row.level), 0.7, 0.7, 0.7)
  GameTooltip:AddLine(" ")
  for j, m in ipairs(QM.data.members) do
    local st = row.st[j]
    if st then
      local info = STATUS[st] or STATUS.X
      GameTooltip:AddDoubleLine(m.name, STATUS_TIP[st] or st, 1, 1, 1, info.color[1], info.color[2], info.color[3])
    end
  end
  GameTooltip:AddLine(" ")
  GameTooltip:AddLine(tr("Click: quest text, where to go, party progress", "Klick: Quest-Text, Wo, Fortschritt der Party"), 0.5, 0.8, 1)
  GameTooltip:AddLine(tr("Shift-click: link the quest in chat", "Shift-Klick: Quest in den Chat verlinken"), 0.5, 0.5, 0.5)
  GameTooltip:Show()
end

-- ---------------------------------------------------------------- giving quests
function QM.Give(row, index)
  local member = QM.data.members[index]
  if not row or not member or member.isSelf then return end

  local ok, why = bridgeReady()
  if not ok then
    say(why or "?")
    return
  end

  local token = newToken("g")
  QM.giveActive[token] = { row = row, index = index, name = member.name }
  row.pending = row.pending or {}
  row.pending[index] = true

  if not MultiBot.Comm.Send("RUN", "QUEST_GIVE~" .. member.name .. "~" .. token .. "~" .. row.id) then
    QM.giveActive[token] = nil
    row.pending[index] = nil
    return
  end

  -- no answer at all (server without the feature): release the cell again
  after(REQUEST_TIMEOUT, function()
    if QM.giveActive[token] then
      QM.giveActive[token] = nil
      row.pending[index] = nil
      updateRows()
    end
  end)

  updateRows()
end

function QM.GiveToAll(row)
  if not row then return end
  local delay = 0
  for j, member in ipairs(QM.data.members) do
    if row.st[j] == "N" and not member.isSelf and not (row.pending and row.pending[j]) then
      local index = j
      after(delay, function() QM.Give(row, index) end)
      delay = delay + 0.25
    end
  end
end

local TURNIN_TIMEOUT = 75  -- the trip can take: teleport there, look for the NPC, hand in, teleport back

local TURNIN_ERRORS = {
  NOT_READY = tr("objectives are not done yet", "Ziele noch nicht erfuellt"),
  ALREADY_DONE = tr("already handed in", "schon abgegeben"),
  DEAD = tr("the bot is dead", "der Bot ist tot"),
  IN_COMBAT = tr("the bot is in combat", "der Bot kaempft gerade"),
  BUSY = tr("the bot is busy (already on a trip or teleporting)", "der Bot ist beschaeftigt (schon unterwegs oder im Teleport)"),
  IN_INSTANCE = tr("the bot is in an instance/battleground", "der Bot ist in einer Instanz/einem Schlachtfeld"),
  NO_ENDER = tr("no quest giver with a known position on the open world", "kein Questgeber mit bekannter Position in der offenen Welt"),
  TELEPORT_FAILED = tr("the teleport did not work", "der Teleport hat nicht funktioniert"),
  NO_NPC = tr("the quest giver was not there", "der Questgeber war nicht da"),
  REWARD_FAILED = tr("the reward could not be taken (bags full?)", "die Belohnung konnte nicht abgeholt werden (Taschen voll?)"),
  RETURN_FAILED = tr("the way back failed - the bot may still be at the quest giver", "der Rueckweg hat nicht geklappt - der Bot steht evtl. noch beim Questgeber"),
  BOT_GONE = tr("the bot logged out", "der Bot hat sich ausgeloggt"),
  RATE_LIMIT = tr("too fast, wait a moment", "zu schnell, kurz warten"),
  FORBIDDEN = tr("not allowed", "keine Berechtigung"),
  NO_BOT = tr("bot not found", "Bot nicht gefunden"),
  NO_QUEST = tr("unknown quest", "unbekannte Quest"),
  BAD_REQUEST = tr("bad request", "ungueltige Anfrage"),
}

function QM.TurnIn(row, index)
  local member = QM.data.members[index]
  if not row or not member or member.isSelf then return end

  local ok, why = bridgeReady()
  if not ok then
    say(why or "?")
    return
  end

  local token = newToken("t")
  QM.giveActive[token] = { row = row, index = index, name = member.name, turnin = true }
  row.pending = row.pending or {}
  row.pending[index] = true

  if not MultiBot.Comm.Send("RUN", "QUEST_TURNIN~" .. member.name .. "~" .. token .. "~" .. row.id) then
    QM.giveActive[token] = nil
    row.pending[index] = nil
    return
  end

  say(string.format(tr("%s is going to the quest giver of '%s' ...", "%s geht zum Questgeber von '%s' ..."), member.name, row.title))

  after(TURNIN_TIMEOUT, function()
    if QM.giveActive[token] then
      QM.giveActive[token] = nil
      row.pending[index] = nil
      updateRows()
    end
  end)

  updateRows()
end

local function onTurnInResult(payload)
  local name, token, questId, result, reason = strsplit("~", payload or "", 5)
  local job = QM.giveActive[token or ""]
  if not job then return end
  QM.giveActive[token] = nil

  local row = job.row
  row.pending[job.index] = nil
  name = decode(name)
  reason = decode(reason)

  if result == "OK" then
    row.st[job.index] = "D"
    say(string.format(tr("%s handed in: %s", "%s hat abgegeben: %s"), name, row.title))
    after(1.0, function() if frame and frame:IsShown() then QM.Request() end end)
  else
    say(string.format(tr("%s could not hand in '%s': %s", "%s konnte '%s' nicht abgeben: %s"), name, row.title, TURNIN_ERRORS[reason] or reason))
    -- open the quest popup: it shows where the quest is handed in, in case you have to walk there yourself
    if MultiBot.QuestInfo and MultiBot.QuestInfo.Show then
      MultiBot.QuestInfo.Show(row.id, row.level)
    end
  end

  updateRows()
end

local function onGiveResult(payload)
  local name, token, questId, result, reason = strsplit("~", payload or "", 5)
  local job = QM.giveActive[token or ""]
  if not job then return end
  QM.giveActive[token] = nil

  local row = job.row
  row.pending[job.index] = nil
  name = decode(name)
  reason = decode(reason)

  if result == "OK" then
    row.st[job.index] = "A"
    say(string.format(tr("%s received: %s", "%s hat bekommen: %s"), name, row.title))
    -- the quest may complete on the spot (items already in the bags): re-read the truth shortly
    after(1.0, function() if frame and frame:IsShown() then QM.Request() end end)
  else
    say(string.format(tr("%s did not get '%s': %s", "%s hat '%s' nicht bekommen: %s"), name, row.title, GIVE_ERRORS[reason] or reason))
  end

  updateRows()
end

-- ---------------------------------------------------------------- packets from the server
function QM.OnPacket(opcode, payload)
  if opcode == "QUEST_GIVE_RESULT" then
    onGiveResult(payload)
    return
  end

  if opcode == "QUEST_TURNIN_RESULT" then
    onTurnInResult(payload)
    return
  end

  local incoming = QM.incoming

  if opcode == "QM_BEGIN" then
    local token, memberTotal, rowTotal, refLevel, span, truncated = strsplit("~", payload or "", 6)
    if token ~= QM.token then return end
    QM.incoming = {
      members = {}, rows = {},
      refLevel = tonumber(refLevel) or 0,
      span = tonumber(span) or QM.span,
      truncated = truncated == "1",
      expectRows = tonumber(rowTotal) or 0,
    }
    return
  end

  if not incoming then return end

  if opcode == "QM_MEMBER" then
    local token, index, name, isSelf, level, class = strsplit("~", payload or "", 6)
    if token ~= QM.token then return end
    local i = (tonumber(index) or 0) + 1
    if i >= 1 and i <= MAX_MEMBERS then
      incoming.members[i] = {
        name = decode(name), isSelf = isSelf == "1",
        level = tonumber(level) or 0, class = tonumber(class) or 0,
      }
    end
    return
  end

  if opcode == "QM_ROW" then
    local token, questId, level, statuses, title = strsplit("~", payload or "", 5)
    if token ~= QM.token then return end
    local st = {}
    for j = 1, string.len(statuses or "") do
      st[j] = string.sub(statuses, j, j)
    end
    table.insert(incoming.rows, {
      id = tonumber(questId) or 0, level = tonumber(level) or 0,
      st = st, title = decode(title), pending = {},
    })
    return
  end

  if opcode == "QM_END" then
    local token = strsplit("~", payload or "", 2)
    if token ~= QM.token then return end
    QM.data = incoming
    QM.incoming = nil
    QM.loading = false
    QM.token = nil

    if frame then
      layout()
      FauxScrollFrame_SetOffset(scroll, 0)
      _G[SCROLL_NAME .. "ScrollBar"]:SetValue(0)
      setStatusLine("")
      updateRows()
    end
  end
end

-- the server answered with an ERR packet for one of our requests
function QM.OnError(requestType, token, reason)
  if requestType == "QUEST_MATRIX" and token == QM.token then
    QM.loading = false
    QM.token = nil

    -- the server allows one matrix request per 1.5 s (e.g. a refresh right after giving a quest): retry once
    if reason == "RATE_LIMIT" and not QM.retrying then
      QM.retrying = true
      setStatusLine(tr("Loading ...", "Lade ..."))
      after(1.6, function()
        QM.retrying = false
        if frame and frame:IsShown() then QM.Request() end
      end)
      return
    end

    setStatusLine("|cffff5555" .. (reason or "error") .. "|r")
  elseif requestType == "QUEST_GIVE" or requestType == "QUEST_TURNIN" then
    local job = QM.giveActive[token or ""]
    if job then
      QM.giveActive[token] = nil
      job.row.pending[job.index] = nil
      say(string.format(tr("%s did not get '%s': %s", "%s hat '%s' nicht bekommen: %s"), job.name, job.row.title, GIVE_ERRORS[reason or ""] or reason or "?"))
      updateRows()
    end
  end
end

-- ---------------------------------------------------------------- request
function QM.Request()
  local ok, why = bridgeReady()
  if not ok then
    setStatusLine("|cffff5555" .. (why or "?") .. "|r")
    return false
  end

  local token = newToken("m")
  QM.token = token
  QM.incoming = nil
  QM.loading = true
  setStatusLine(tr("Loading ...", "Lade ..."))

  if not MultiBot.Comm.Send("GET", "QUEST_MATRIX~" .. token .. "~" .. QM.span) then
    QM.loading = false
    QM.token = nil
    return false
  end

  after(REQUEST_TIMEOUT, function()
    if QM.loading and QM.token == token then
      QM.loading = false
      QM.token = nil
      setStatusLine("|cffff5555" .. tr("No answer from the server.", "Keine Antwort vom Server.") .. "|r")
    end
  end)

  return true
end

-- ---------------------------------------------------------------- frame construction
local function createRow(i)
  local rf = CreateFrame("Frame", nil, frame)
  rf:SetHeight(ROW_HEIGHT)
  rf:SetPoint("TOPLEFT", frame, "TOPLEFT", LEFT, -(ROWS_TOP + (i - 1) * ROW_HEIGHT))

  if i % 2 == 0 then
    local bg = rf:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture(1, 1, 1, 0.05)
  end

  rf.level = rf:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  rf.level:SetPoint("LEFT", rf, "LEFT", 0, 0)
  rf.level:SetWidth(LEVEL_WIDTH - 4)
  rf.level:SetJustifyH("RIGHT")

  local name = CreateFrame("Button", nil, rf)
  name:SetHeight(ROW_HEIGHT)
  name:SetWidth(NAME_WIDTH - 6)
  name:SetPoint("LEFT", rf, "LEFT", LEVEL_WIDTH + 4, 0)
  name.text = name:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  name.text:SetAllPoints()
  name.text:SetJustifyH("LEFT")
  name:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
  name:RegisterForClicks("LeftButtonUp")
  name:SetScript("OnEnter", function(self) showRowTooltip(self, rf.row) end)
  name:SetScript("OnLeave", function() GameTooltip:Hide() end)
  name:SetScript("OnClick", function()
    if not rf.row then return end
    if IsShiftKeyDown() and ChatEdit_InsertLink then
      ChatEdit_InsertLink(questLink(rf.row))
    elseif MultiBot.QuestInfo and MultiBot.QuestInfo.Show then
      MultiBot.QuestInfo.Show(rf.row.id, rf.row.level)
    end
  end)
  rf.name = name

  rf.cells = {}
  for j = 1, MAX_MEMBERS do
    local cell = CreateFrame("Button", nil, rf)
    cell:SetHeight(ROW_HEIGHT - 2)
    cell:SetWidth(CELL_WIDTH - 6)
    cell.text = cell:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    cell.text:SetAllPoints()
    cell.text:SetJustifyH("CENTER")
    cell:RegisterForClicks("LeftButtonUp")
    cell:SetScript("OnClick", function(self)
      if not (self.clickable and self.row) then return end
      if self.action == "turnin" then
        QM.TurnIn(self.row, self.index)
      else
        QM.Give(self.row, self.index)
      end
    end)
    cell:SetScript("OnEnter", function(self)
      if not self.row then return end
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      local m = QM.data.members[self.index]
      local st = self.row.st[self.index]
      GameTooltip:AddLine(m and m.name or "?", 1, 0.82, 0)
      GameTooltip:AddLine(self.row.title, 1, 1, 1)
      local text = STATUS_TIP[st] or st or ""
      if self.action == "give" then
        text = tr("Click: give this quest to the bot", "Klick: Quest direkt an den Bot geben")
      elseif self.action == "turnin" then
        text = tr("Click: the bot teleports to the quest giver, hands the quest in and comes back to you",
                  "Klick: der Bot teleportiert zum Questgeber, gibt die Quest ab und kommt zu dir zurueck")
      end
      GameTooltip:AddLine(text, 0.8, 0.8, 0.8)
      GameTooltip:Show()
    end)
    cell:SetScript("OnLeave", function() GameTooltip:Hide() end)
    cell:Hide()
    rf.cells[j] = cell
  end

  local all = CreateFrame("Button", nil, rf)
  all:SetHeight(ROW_HEIGHT - 2)
  all:SetWidth(ALL_WIDTH - 6)
  all.text = all:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  all.text:SetAllPoints()
  all.text:SetText(tr("All", "Alle"))
  all:SetHighlightTexture("Interface\\Buttons\\UI-Listbox-Highlight2", "ADD")
  all:RegisterForClicks("LeftButtonUp")
  all:SetScript("OnClick", function() QM.GiveToAll(rf.row) end)
  all:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(tr("Give this quest to every bot that can take it", "Quest an alle Bots geben, die sie annehmen koennen"), 1, 1, 1)
    GameTooltip:Show()
  end)
  all:SetScript("OnLeave", function() GameTooltip:Hide() end)
  all:Hide()
  rf.all = all

  rf:Hide()
  return rf
end

local function createFrame()
  frame = CreateFrame("Frame", FRAME_NAME, UIParent)
  frame:SetFrameStrata("DIALOG")
  frame:SetWidth(700)
  frame:SetHeight(ROWS_TOP + VISIBLE_ROWS * ROW_HEIGHT + FOOTER)
  frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:EnableMouseWheel(true)
  frame:SetClampedToScreen(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
  frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
  frame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 },
  })

  frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  frame.title:SetPoint("TOP", frame, "TOP", 0, -14)
  frame.title:SetText(tr("Quest matrix", "Quest-Matrix"))

  local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -4)

  frame.info = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  frame.info:SetPoint("TOPLEFT", frame, "TOPLEFT", LEFT, -30)
  frame.info:SetJustifyH("LEFT")

  -- column headers
  local levelHeader = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  levelHeader:SetPoint("TOPLEFT", frame, "TOPLEFT", LEFT, -(ROWS_TOP - 14))
  levelHeader:SetWidth(LEVEL_WIDTH - 4)
  levelHeader:SetJustifyH("RIGHT")
  levelHeader:SetText("Lv")

  local questHeader = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  questHeader:SetPoint("TOPLEFT", frame, "TOPLEFT", LEFT + LEVEL_WIDTH + 4, -(ROWS_TOP - 14))
  questHeader:SetText("Quest")

  for j = 1, MAX_MEMBERS do
    local header = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    header:SetWidth(CELL_WIDTH - 6)
    header:SetHeight(28)
    header:SetJustifyH("CENTER")
    header:SetJustifyV("TOP")
    header:Hide()
    memberHeaders[j] = header
  end

  scroll = CreateFrame("ScrollFrame", SCROLL_NAME, frame, "FauxScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", LEFT, -ROWS_TOP)
  scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -34, FOOTER)
  scroll:SetScript("OnVerticalScroll", function(self, offset)
    FauxScrollFrame_OnVerticalScroll(self, offset, ROW_HEIGHT, updateRows)
  end)

  frame:SetScript("OnMouseWheel", function(self, delta)
    local bar = _G[SCROLL_NAME .. "ScrollBar"]
    bar:SetValue(bar:GetValue() - delta * ROW_HEIGHT * 3)
  end)

  for i = 1, VISIBLE_ROWS do
    rowFrames[i] = createRow(i)
  end

  frame.status = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  frame.status:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", LEFT, 16)
  frame.status:SetJustifyH("LEFT")

  -- footer buttons
  local refresh = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  refresh:SetWidth(110)
  refresh:SetHeight(22)
  refresh:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -18, 14)
  refresh:SetText(tr("Refresh", "Aktualisieren"))
  refresh:SetScript("OnClick", function() QM.Request() end)

  local hide = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  hide:SetWidth(150)
  hide:SetHeight(22)
  hide:SetPoint("RIGHT", refresh, "LEFT", -6, 0)
  local function hideText()
    hide:SetText(QM.hideDone and tr("Only open: on", "Nur offene: an") or tr("Only open: off", "Nur offene: aus"))
  end
  hideText()
  hide:SetScript("OnClick", function()
    QM.hideDone = not QM.hideDone
    hideText()
    FauxScrollFrame_SetOffset(scroll, 0)
    _G[SCROLL_NAME .. "ScrollBar"]:SetValue(0)
    updateRows()
  end)
  hide:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine(tr("Hide quests where nobody has anything to do (everyone done, or nobody can take it).", "Quests ausblenden, bei denen niemand etwas tun kann (alle fertig oder nicht annehmbar)."), 1, 1, 1, true)
    GameTooltip:Show()
  end)
  hide:SetScript("OnLeave", function() GameTooltip:Hide() end)

  local spanButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  spanButton:SetWidth(120)
  spanButton:SetHeight(22)
  spanButton:SetPoint("RIGHT", hide, "LEFT", -6, 0)
  local function spanText()
    spanButton:SetText(string.format(tr("Last %d levels", "Letzte %d Level"), QM.span))
  end
  spanText()
  spanButton:SetScript("OnClick", function()
    local nextIndex = 1
    for i, value in ipairs(SPANS) do
      if value == QM.span then nextIndex = (i % #SPANS) + 1 end
    end
    QM.span = SPANS[nextIndex]
    spanText()
    QM.Request()
  end)
  spanButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine(tr("Only quests whose level is at most this many levels below yours. Click to change.", "Nur Quests, deren Level hoechstens so viele Level unter deinem liegt. Klick zum Aendern."), 1, 1, 1, true)
    GameTooltip:Show()
  end)
  spanButton:SetScript("OnLeave", function() GameTooltip:Hide() end)

  frame:SetScript("OnShow", function() QM.Request() end)
  table.insert(UISpecialFrames, FRAME_NAME)

  layout()
  frame:Hide()
end

function QM.Toggle()
  if not frame then createFrame() end
  if frame:IsShown() then frame:Hide() else frame:Show() end
end

function QM.Show()
  if not frame then createFrame() end
  frame:Show()
end

SLASH_MBQUESTMATRIX1 = "/mbq"
SLASH_MBQUESTMATRIX2 = "/questmatrix"
SlashCmdList["MBQUESTMATRIX"] = function() QM.Toggle() end
