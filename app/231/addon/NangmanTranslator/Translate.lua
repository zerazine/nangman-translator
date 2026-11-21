local NT = NangmanTr
if not NT or NT.inert then return end

local T = {}
NT.T = T
local db = NT.tr
local secret = NT.secret
local function chatEB()
  local f = ChatEdit_GetActiveWindow or (ChatFrameUtil and ChatFrameUtil.GetActiveWindow)
  if f then local ok, eb = pcall(f) if ok and eb then return eb end end
  local kb = GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus()
  if kb and not (kb.IsForbidden and kb:IsForbidden()) and kb.GetName then local n = kb:GetName() if type(n) == "string" and n:find("^ChatFrame%d+EditBox$") then return kb end end
  return ChatFrame1EditBox
end

local function b64(s)
  local out, n = {}, #s
  for i = 1, n, 3 do
    local a, b, c = s:byte(i, i + 2)
    b, c = b or 0, c or 0
    local v = a * 65536 + b * 256 + c
    out[#out + 1] = math.floor(v / 262144) % 64
    out[#out + 1] = math.floor(v / 4096) % 64
    if i + 1 <= n then out[#out + 1] = math.floor(v / 64) % 64 end
    if i + 2 <= n then out[#out + 1] = v % 64 end
  end
  return out
end

local CELLPX = 3
local PAYLOAD = 130
local BYTES = 96
local HEAD = 10
local HOLD = 0.1
local LV = { 0, 40 / 255, 80 / 255, 120 / 255 }
local strip, cells
NT.stripY = function(f, x, y)
  local _, ph = GetPhysicalScreenSize()
  if not (ph and ph > 0 and x and y and f) then return y end
  local es = f:GetEffectiveScale()
  local u = 768 / ph
  if x * es >= u * (CELLPX * (HEAD + PAYLOAD) + 10) then return y end
  local need = u * 8 / es
  return y < need and need or y
end
local seq, lastShow, shownAny = 0, 0, false
local pendBytes = ""

local function layout()
  local _, ph = GetPhysicalScreenSize()
  if not ph or ph <= 0 then ph = 1080 end
  local sz = (768 / ph) * CELLPX
  strip:ClearAllPoints()
  strip:SetPoint("BOTTOMLEFT", nil, "BOTTOMLEFT", 0, 0)
  strip:SetSize(sz * (HEAD + PAYLOAD), sz)
  for i = 1, HEAD + PAYLOAD do
    local t = cells[i]
    if not t then
      t = strip:CreateTexture(nil, "OVERLAY")
      if t.SetSnapToPixelGrid then t:SetSnapToPixelGrid(false) t:SetTexelSnappingBias(0) end
      cells[i] = t
    end
    t:ClearAllPoints()
    t:SetPoint("BOTTOMLEFT", strip, "BOTTOMLEFT", (i - 1) * sz, 0)
    t:SetSize(sz, sz)
  end
end
local function makeStrip()
  if strip then return end
  strip = CreateFrame("Frame", "NangmanTrTranslateStrip", nil)
  strip:SetFrameStrata("TOOLTIP")
  strip:SetFrameLevel(9000)
  strip:SetScale(1)
  strip:EnableMouse(false)
  cells = {}
  layout()
  strip:Hide()
end
local function paint(i, v)
  local t = cells[i]
  t:SetColorTexture(LV[math.floor(v / 16) % 4 + 1], LV[math.floor(v / 4) % 4 + 1], LV[v % 4 + 1], 1)
  t:Show()
end
local function showPacket(vals)
  seq = (seq + 1) % 4096
  for k = 0, 3 do cells[k + 1]:SetColorTexture(LV[k + 1], LV[k + 1], LV[k + 1], 1) cells[k + 1]:Show() end
  local n, sum = #vals, 0
  for i = 1, n do sum = (sum + vals[i] * ((i % 7) + 1)) % 4096 end
  paint(5, math.floor(seq / 64)) paint(6, seq % 64)
  paint(7, math.floor(n / 64)) paint(8, n % 64)
  paint(9, math.floor(sum / 64)) paint(10, sum % 64)
  for i = 1, PAYLOAD do
    if i <= n then paint(HEAD + i, vals[i]) else cells[HEAD + i]:Hide() end
  end
  strip:Show()
end
local function clean(s)
  s = tostring(s or "")
  return (s:gsub("[\t\r\n]", " "))
end
local function recOf(...)
  local n = select("#", ...)
  local parts = {}
  for i = 1, n do parts[i] = clean((select(i, ...))) end
  return table.concat(parts, "\t") .. "\n"
end
local function push(...)
  local rec = recOf(...)
  if #pendBytes > 6000 then return end
  pendBytes = pendBytes .. rec
end
local function pushS(...)
  local rec = recOf(...)
  local nl = pendBytes:find("\n", 1, true)
  if nl then pendBytes = pendBytes:sub(1, nl) .. rec .. pendBytes:sub(nl + 1) else pendBytes = pendBytes .. rec end
end
function NT.trAck(sq) pushS("B", sq) end
do local hf = CreateFrame("Frame") hf:RegisterEvent("PLAYER_ENTERING_WORLD") NT.onEvent(hf, function() C_Timer.After(5, function() pushS("B", "hi") end) end) end
local pendLow = ""
T.push = push
NT.push = push
local function pump(now)
  if now - lastShow < HOLD then return end
  if #pendBytes == 0 and #pendLow > 0 then
    local nl = pendLow:find("\n", 1, true)
    if nl then pendBytes = pendLow:sub(1, nl) pendLow = pendLow:sub(nl + 1) else pendLow = "" end
  end
  if #pendBytes > 0 then
    local take = BYTES
    if #pendBytes < take then take = #pendBytes end
    local chunk
    while take > 1 and take < #pendBytes do
      local nb = pendBytes:byte(take + 1)
      if nb >= 128 and nb < 192 then take = take - 1 else break end
    end
    chunk = pendBytes:sub(1, take)
    pendBytes = pendBytes:sub(take + 1)
    showPacket(b64(chunk))
    lastShow = now
    shownAny = true
  elseif shownAny and now - lastShow > 0.6 then
    strip:Hide()
    shownAny = false
  end
end

local EV = {
  "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_EMOTE",
  "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER", "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER", "CHAT_MSG_RAID_WARNING",
  "CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_INSTANCE_CHAT_LEADER", "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER",
  "CHAT_MSG_WHISPER", "CHAT_MSG_WHISPER_INFORM", "CHAT_MSG_BN_WHISPER", "CHAT_MSG_BN_WHISPER_INFORM", "CHAT_MSG_CHANNEL",
}
local function hexOf(r, g, b) return string.format("%02x%02x%02x", math.floor((r or 1) * 255 + 0.5), math.floor((g or 1) * 255 + 0.5), math.floor((b or 1) * 255 + 0.5)) end
NT.hexOf = hexOf
local function classHex(guid)
  if not guid or guid == "" or secret(guid) or not GetPlayerInfoByGUID then return "" end
  local ok, _, cls = pcall(GetPlayerInfoByGUID, guid)
  if not ok or not cls then return "" end
  local c = (CUSTOM_CLASS_COLORS and CUSTOM_CLASS_COLORS[cls]) or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[cls])
  if not c then return "" end
  return hexOf(c.r, c.g, c.b)
end
NT.classHex = classHex
local myName = UnitName("player")
local pendLines = {}
local seenIDs = {}
local function playerLineID(t)
  return t:match("|Hplayer:[^:|]*:(%d+):") or t:match("|HBNplayer:[^:]*:[^:|]*:(%d+):")
end
local lineNo = 0
local SID = tostring(math.random(100000, 999999))
local recent = {}
local function remember(f)
  recent[#recent + 1] = { at = GetTime(), f = f }
  while #recent > 30 do table.remove(recent, 1) end
end
local function replay(now)
  if #pendLow > 0 then return end
  for _, r in ipairs(recent) do
    if now - r.at < 600 then
      local f = r.f
      pendLow = pendLow .. recOf(f[1], f[2], f[3], f[4], f[5], f[6], f[7], f[8], f[9], f[10], f[11], SID, "1")
    end
  end
end

local evf = CreateFrame("Frame")
for _, e in ipairs(EV) do pcall(evf.RegisterEvent, evf, e) end
local function onChatEv(_, ev, msg, sender, lang, chanStr, target, flags, zoneId, chanIdx, chanBase, _, lineID, guid, bnID)
  if secret(msg) or secret(sender) then return end
  if NangmanTranslator_LinkKO then msg = NangmanTranslator_LinkKO(msg, sender, ev, guid) end
  if lineID and not secret(lineID) then
    local key = ":" .. tostring(lineID) .. ":"
    for i = #pendLines, 1, -1 do if pendLines[i][1]:find(key, 1, true) then table.remove(pendLines, i) end end
    seenIDs[tostring(lineID)] = GetTime()
  end
  local t = ev:sub(10)
  local me = 0
  local mine = UnitName("player") or myName
  if t == "WHISPER_INFORM" or t == "BN_WHISPER_INFORM" then me = 1
  elseif t ~= "WHISPER" and t ~= "BN_WHISPER" and (
    (type(guid) == "string" and not secret(guid) and guid == UnitGUID("player")) or
    (sender and mine and (sender == mine or sender:match("^([^%-]+)") == mine))) then me = 1 end
  local cnum, cname = "", ""
  if t == "CHANNEL" then cnum = tostring(chanIdx or "") cname = tostring(chanBase or chanStr or "") end
  if (t == "BN_WHISPER" or t == "BN_WHISPER_INFORM") and type(bnID) == "number" and not secret(bnID) then
    cnum = tostring(bnID)
    if type(sender) ~= "string" or sender == "" or sender:find("|K", 1, true) then
      local nm
      if C_BattleNet and C_BattleNet.GetAccountInfoByID then
        local ok, info = pcall(C_BattleNet.GetAccountInfoByID, bnID)
        if ok and type(info) == "table" and type(info.battleTag) == "string" then nm = info.battleTag:match("^([^#]+)") end
      end
      if not nm and BNGetFriendInfoByID then
        local ok, _, _, tag = pcall(BNGetFriendInfoByID, bnID)
        if ok and type(tag) == "string" then nm = tag:match("^([^#]+)") end
      end
      if nm and nm ~= "" then sender = nm end
    end
  end
  local col = ChatTypeInfo and ChatTypeInfo[t == "CHANNEL" and ("CHANNEL" .. tostring(chanIdx or "")) or t]
  if not col and ChatTypeInfo then col = ChatTypeInfo[t] end
  lineNo = lineNo + 1
  local f = { "C", t, cnum, cname, sender or "", classHex(guid), col and hexOf(col.r, col.g, col.b) or "ffffff", msg or "", me, 0, lineNo }
  push(f[1], f[2], f[3], f[4], f[5], f[6], f[7], f[8], f[9], f[10], f[11], SID, "0")
  remember(f)
end
local function pkv(...) return select("#", ...), { ... } end
NT.onEvent(evf, function(self, ev, ...)
  local n, args = pkv(...)
  local getF = ChatFrame_GetMessageEventFilters or (ChatFrameUtil and ChatFrameUtil.GetMessageEventFilters)
  local okf, fl = pcall(function() return getF and getF(ev) end)
  if okf and type(fl) == "table" then
    for _, fn in ipairs(fl) do
      local _, r = pkv(pcall(fn, ChatFrame1, ev, unpack(args, 1, n)))
      if r[1] and r[2] then return end
    end
  end
  return onChatEv(self, ev, unpack(args, 1, n))
end)
local function hookCF()
  if not ChatFrame1 or T.hooked then return end
  T.hooked = true
  NT.hsf(ChatFrame1, "AddMessage", function(_, text, r, g, b)
    if type(text) ~= "string" or secret(text) or not text:find("%S") then return end
    pendLines[#pendLines + 1] = { text, hexOf(r, g, b) }
  end)
end
local catOf = {}
do
  local CAT = { CHAT_MSG_LOOT = "loot", CHAT_MSG_MONEY = "loot", CHAT_MSG_CURRENCY = "loot", CHAT_MSG_COMBAT_XP_GAIN = "xp", CHAT_MSG_COMBAT_FACTION_CHANGE = "xp", CHAT_MSG_COMBAT_HONOR_GAIN = "xp", CHAT_MSG_SKILL = "xp", CHAT_MSG_MONSTER_SAY = "npc", CHAT_MSG_MONSTER_YELL = "npc", CHAT_MSG_MONSTER_EMOTE = "npc", CHAT_MSG_MONSTER_WHISPER = "npc", CHAT_MSG_RAID_BOSS_EMOTE = "npc", CHAT_MSG_RAID_BOSS_WHISPER = "npc" }
  local cf = CreateFrame("Frame")
  for e in pairs(CAT) do pcall(cf.RegisterEvent, cf, e) end
  NT.onEvent(cf, function(_, e, msg)
    if type(msg) == "string" and msg ~= "" and not secret(msg) then catOf[#catOf + 1] = { msg, CAT[e], GetTime() } end
  end)
end
local function catFor(text, now)
  local c = ""
  for i = #catOf, 1, -1 do
    local x = catOf[i]
    if now - x[3] > 3 then table.remove(catOf, i)
    elseif c == "" and text:find(x[1], 1, true) then c = "/" .. x[2] end
  end
  return c
end

local FAKE = {
  { "Testwulf", "WHISPER", "d18f5a", "Hallo! Suchst du noch eine Gruppe für die Höhlen?" },
  { "Emmalyn", "PARTY", "f58cba", "tank can u pull next pack? i need to drink first" },
  { "Pierrot", "WHISPER", "69ccf0", "Salut ! Tu peux m'aider pour cette quête ?" },
  { "Ivanko", "PARTY", "c79c6e", "Привет всем, я танк. Идём в подземелье?" },
  { "Lucía", "WHISPER", "fff569", "¿Tienes hueco en el grupo? Soy sanadora." },
  { "Mirelle", "GUILD", "ff7d0a", "raid tonight 8pm server time, dont be late" },
  { "Kaelthorn", "CHANNEL", "40c7eb", "LF2M SFK need heal and dps, PST" },
  { "Haruka", "WHISPER", "abd473", "こんにちは！一緒にクエストしませんか？" },
}
local fakeAt, fakeI = 0, 0
local function fake(now)
  if not db().test or now < fakeAt then return end
  fakeAt = now + 15
  fakeI = fakeI % #FAKE + 1
  local f = FAKE[fakeI]
  local col = ChatTypeInfo and ChatTypeInfo[f[2] == "CHANNEL" and "CHANNEL4" or f[2]]
  lineNo = lineNo + 1
  push("C", f[2], f[2] == "CHANNEL" and "4" or "", f[2] == "CHANNEL" and "LookingForGroup" or "", f[1], f[3], col and hexOf(col.r, col.g, col.b) or "ffffff", f[4], 0, 1, lineNo, SID, "0")
end

local function chatPanel() return _G.NangmanTrChat end
local lastEdit, lastVis
local edT0
function NT.realTyping()
  local eb = chatEB()
  if not (eb and eb:HasFocus()) then edT0 = nil return false end
  local now = GetTime() edT0 = edT0 or now
  local tx = eb:GetText() or ""
  if tx:sub(1, 1) == "/" then return false end
  if tx == "" and now - edT0 < 0.8 then return false end
  return true
end
local function applyHide()
  local p = chatPanel()
  if not p then return end
  local on = db().on
  local eb = chatEB()
  local typing = (eb and eb:HasFocus()) and true or false
  local w = on and 0 or 1
  if on and T.onAt then local age = GetTime() - T.onAt if age < 0.4 then w = 1 elseif age < 0.7 then w = 1 - (age - 0.4) / 0.3 end end
  for _, k in ipairs({ p:GetChildren() }) do
    if k.AddMessage and k.ScrollToBottom and math.abs(k:GetAlpha() - w) > 0.01 then k:SetAlpha(w) end
  end
  if p.chrome then
    if on then
      local cw = NT.realTyping() and 1 or 0
      if T.onAt and GetTime() - T.onAt < 0.7 and not typing then local age = GetTime() - T.onAt cw = (age < 0.4) and 1 or (1 - (age - 0.4) / 0.3) end
      if p.chrome:GetAlpha() ~= cw then p.chrome:SetAlpha(cw) end
      T.chromeForced = true
    elseif T.chromeForced then
      T.chromeForced = nil
      p.chrome:SetAlpha(1)
    end
  end
  if GetTime() > (T.stAt or 0) then T.stAt = GetTime() + 2 lastEdit = nil T.lastKb = nil end
  if typing ~= lastEdit then lastEdit = typing pushS("E", typing and 1 or 0) end
  if on then
    local kb = (GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus() ~= nil) and true or false
    if kb ~= T.lastKb then T.lastKb = kb pushS("K", kb and 1 or 0) end
    local vis = p:IsVisible() and true or false
    if vis ~= lastVis then lastVis = vis pushS("V", vis and 1 or 0) end
  end
end

local function info()
  local name, realm = UnitFullName and UnitFullName("player")
  if not name then name = UnitName("player") end
  if not realm or realm == "" then realm = GetRealmName and GetRealmName() or "" end
  local _, cls = UnitClass("player")
  local c = cls and RAID_CLASS_COLORS and RAID_CLASS_COLORS[cls]
  if db().on then push("P", name or "", realm or "", c and hexOf(c.r, c.g, c.b) or "", db().test and 1 or 0, GetLocale and GetLocale() or "", NT.chatFontSize and NT.chatFontSize() or "")
  else
    local eb = chatEB()
    local ty = ((eb and eb:HasFocus()) or (GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus() ~= nil)) and 1 or 0
    push("X", ty, (InCombatLockdown and InCombatLockdown()) and 1 or 0, (T.userOff or db().bgOff) and 1 or 0, db().bgOff and 1 or 0)
  end
end
local lastChan = ""
local function chans()
  local t, sv = {}, {}
  local L = { GetChannelList() }
  local step = (type(L[3]) == "boolean" or (L[3] == nil and #L >= 3)) and 3 or 2
  for i = 1, #L, step do
    local id, nm = L[i], L[i + 1]
    if type(id) == "number" and type(nm) == "string" then t[#t + 1] = id .. "=" .. nm end
  end
  if EnumerateServerChannels then for _, n in ipairs({ EnumerateServerChannels() }) do if type(n) == "string" then sv[#sv + 1] = n end end end
  local g = table.concat(t, ";") .. "\t" .. table.concat(sv, ";")
  if g ~= lastChan then lastChan = g push("N", table.concat(t, ";"), table.concat(sv, ";")) end
end
NT.chans = function() lastChan = "" pcall(chans) end
do local cf = CreateFrame("Frame") cf:RegisterEvent("CHANNEL_UI_UPDATE") cf:RegisterEvent("PLAYER_ENTERING_WORLD") for _, e in ipairs({ "CHAT_MSG_CHANNEL_NOTICE", "CHANNEL_COUNT_UPDATE" }) do pcall(cf.RegisterEvent, cf, e) end NT.onEvent(cf, function() C_Timer.After(1, function() pcall(chans) end) end) C_Timer.NewTicker(5, function() pcall(chans) end) end
local lastGeo = ""
local function geo()
  local p = chatPanel()
  if not p or not p:GetLeft() then return end
  local _, ph = GetPhysicalScreenSize()
  local s = p:GetEffectiveScale() * ph / 768
  local sh = (UIParent:GetTop() or 768) * UIParent:GetEffectiveScale() * ph / 768
  local L, Tp = p:GetLeft() * s, sh - p:GetTop() * s
  local lk = (NT.chatCfg and NT.chatCfg().locked) and "1" or "0"
  local g = string.format("%d\t%d\t%d\t%d\t%.4f\t%s", math.floor(L + 0.5), math.floor(Tp + 0.5), math.floor(p:GetWidth() * s + 0.5), math.floor(p:GetHeight() * s + 0.5), s, lk)
  if g ~= lastGeo then lastGeo = g push("G", g) end
  local ug = NT.undockGeo and NT.undockGeo() or ""
  if ug ~= T.lastUG then T.lastUG = ug push("Z", ug) end
end
function NT.geoNow() lastGeo = "" pcall(geo) end
function NT.pushUG()
  if not db().on then return end
  local ug = NT.undockGeo and NT.undockGeo() or ""
  if ug ~= T.lastUG then T.lastUG = ug push("Z", ug) end
end

local tick, infoAt = 0, 0
do local pe = CreateFrame("Frame") pe:RegisterEvent("PLAYER_ENTERING_WORLD") pcall(pe.RegisterEvent, pe, "LOADING_SCREEN_DISABLED")
  NT.onEvent(pe, function() infoAt = 0 tick = 2 C_Timer.After(1, function() infoAt = 0 tick = 2 end) end) end
NT.infoNow = function() infoAt = 0 end
NT.feedNow = function() T.lastFeed = nil end
local drv = CreateFrame("Frame")
NT.onUpdate(drv, function(_, el)
  local now = GetTime()
  if #pendLines > 0 then
    for _, l in ipairs(pendLines) do
      local id = playerLineID(l[1])
      if not (id and seenIDs[id]) then push("S", l[2] .. catFor(l[1], now), l[1]) end
    end
    pendLines = {}
    for id, at in pairs(seenIDs) do if now - at > 5 then seenIDs[id] = nil end end
  end
  tick = tick + el
  if tick > 1 then
    tick = 0
    geo()
    if now > infoAt then infoAt = now + 12 lastGeo = "" T.lastUG = nil lastEdit = nil lastVis = nil T.lastFeed = nil T.lastKb = nil info() if (T.chanN or 0) <= 0 then T.chanN = 5 lastChan = "" end T.chanN = T.chanN - 1 pcall(chans) end
    local fg = NT.feedGeo and NT.feedGeo()
    local fon = (NT.feedEnabled and NT.feedEnabled()) and "1" or "0"
    if fg and (fg .. fon) ~= T.lastFeed then
      T.lastFeed = fg .. fon
      local a, b, c, d, e, h, m, z, mv = strsplit("\t", fg)
      push("F", a, b, c, d, e, h, m, z or "13", mv or "0", fon)
    end
  end
  fake(now)
  if now > (T.replayAt or 0) then T.replayAt = now + 30 replay(now) end
  if strip then pump(now) end
  applyHide()
end)

local function look() if NT.btnLook then pcall(NT.btnLook) end end
local function setOn(on, quiet)
  local d = db()
  d.on = on and true or false
  if d.on then
    if NT.feedClear then pcall(NT.feedClear) end
    makeStrip() layout() hookCF()
    infoAt = 0 lastGeo = ""
    T.onAt = GetTime()
    if not quiet then NT.say("번역창을 대화창으로 써요 (번역 프로그램이 켜져 있어야 해요)") end
    C_Timer.After(1.5, function() if NT.tabsPush then pcall(NT.tabsPush) end end)
  else
    push("X", 0, (InCombatLockdown and InCombatLockdown()) and 1 or 0, (T.userOff or d.bgOff) and 1 or 0, d.bgOff and 1 or 0)
    d.test = false
    infoAt = 0
    if not quiet then NT.say("게임 대화창으로 돌아왔어요") end
  end
  T.lastFeed = nil
  if NT.feedRefresh then pcall(NT.feedRefresh) end
  look()
end
function NT.setTranslate(on)
  local d = db()
  d.autoOff = nil
  T.userOff = (not on) and true or nil
  d.userOff = nil
  if (d.on and true or false) ~= (on and true or false) then setOn(on) else infoAt = 0 look() end
end
SLASH_NTTRANSLATE1 = "/nttr"
SLASH_NTTRANSLATE2 = "/번역"
SlashCmdList.NTTRANSLATE = function(arg)
  if NT.seen then NT.seen() end
  arg = (arg or ""):gsub("^%s+", ""):gsub("%s+$", "")
  if arg:find("^켜기") then arg = "켜기" elseif arg:find("^끄기") then arg = "끄기" end
  if arg == "테스트" or arg == "test" then
    local d = db()
    if not d.on then NT.setTranslate(true) end
    d.test = not d.test
    fakeAt = GetTime() + 2
    infoAt = 0
    NT.say(d.test and "테스트 모드 켜짐 - 가짜 외국인 대화가 15초마다 와요 · 답장은 내 캐릭에게 귓말로 가요" or "테스트 모드 꺼짐")
    return
  end
  if arg == "켜기" or arg == "on" then NT.setTranslate(true) return end
  if arg == "끄기" or arg == "off" then NT.setTranslate(false) return end
  NT.setTranslate(not db().on)
end

local ld = CreateFrame("Frame")
ld:RegisterEvent("PLAYER_LOGIN")
ld:RegisterEvent("DISPLAY_SIZE_CHANGED")
ld:RegisterEvent("UI_SCALE_CHANGED")
NT.onEvent(ld, function(_, ev)
  myName = UnitName("player")
  if ev == "PLAYER_LOGIN" then
    makeStrip() layout() hookCF()
    do local d = db() d.test = false end
    infoAt = 0
  elseif strip then
    layout()
    lastGeo = ""
    T.lastFeed = nil
  end
end)

do
  local jf = CreateFrame("Frame")
  jf:RegisterEvent("GROUP_JOINED") jf:RegisterEvent("GROUP_LEFT") jf:RegisterEvent("PLAYER_ENTERING_WORLD")
  NT.onEvent(jf, function(_, ev)
    C_Timer.After(0.5, function()
      if not (IsInGroup and IsInGroup()) then
        push("J", "SOLO")
        local eb = ChatFrame1EditBox
        local ct = eb and eb:GetAttribute("chatType")
        if ct and ct:find("^PARTY") or ct and ct:find("^RAID") or ct and ct:find("^INSTANCE") then
          if not InCombatLockdown() then pcall(eb.SetAttribute, eb, "chatType", "SAY") pcall(eb.SetAttribute, eb, "stickyType", "SAY") end
        end
        return
      end
      if ev ~= "GROUP_JOINED" then return end
      local t = (IsInGroup(LE_PARTY_CATEGORY_INSTANCE or 2) and "INSTANCE_CHAT") or (IsInRaid and IsInRaid() and "RAID") or "PARTY"
      push("J", t)
      local eb = ChatFrame1EditBox
      if eb and not InCombatLockdown() then pcall(eb.SetAttribute, eb, "chatType", t) pcall(eb.SetAttribute, eb, "stickyType", t) end
    end)
  end)
end

do
  local alive
  function NT.alive() return alive and true or false end
  local hf = CreateFrame("Frame")
  hf:RegisterEvent("PLAYER_ENTERING_WORLD")
  NT.onEvent(hf, function(_, _, isLogin, isReload) if isLogin or isReload then C_Timer.After(4, function() push("A", 1) end) end end)
  function NT.seen()
    local was = alive
    alive = true
    if not was and NT.chatSettingsRefresh then C_Timer.After(0, NT.chatSettingsRefresh) end
    local d = db()
    if d.autoOff then
      d.autoOff = nil
      if not T.userOff and not d.on then setOn(true) end
    end
  end
  local pf = CreateFrame("Frame")
  pf:RegisterEvent("PLAYER_ENTERING_WORLD")
  NT.onEvent(pf, function(_, _, isLogin, isReload)
    if not isLogin or isReload then return end
    C_Timer.After(45, function()
      if alive then return end
      local d = db()
      if d.on then setOn(false) d.autoOff = true end
      NT.say("번역기 프로그램이 꺼져 있어요 · 바탕화면 '낭만타우렌 와우 포에버 번역기' 아이콘을 눌러 켜 주세요")
      if RaidNotice_AddMessage and RaidWarningFrame then
        pcall(RaidNotice_AddMessage, RaidWarningFrame, "번역기 프로그램이 꺼져 있어요", { r = 1, g = 0.82, b = 0.4 })
      end
    end)
  end)
end

do
  local wf = CreateFrame("Frame")
  wf:RegisterEvent("PLAYER_ENTERING_WORLD")
  NT.onEvent(wf, function(_, _, isLogin, isReload)
    if isLogin and not isReload then push("W", UnitName("player") or "") end
  end)
end

do
  local key = CreateFrame("Button", "NangmanTrTranslateKey", UIParent)
  key:Hide()
  key:SetScript("OnClick", function()
    if not db().on then
      NT.setTranslate(true) push("I")
    elseif ChatFrame_OpenChat then
      ChatFrame_OpenChat("")
    end
  end)
  local function bindKey()
    if InCombatLockdown() or not SetOverrideBindingClick then return false end
    SetOverrideBindingClick(key, true, "SHIFT-ENTER", "NangmanTrTranslateKey")
    return true
  end
  function NT.reply(name)
    if type(name) ~= "string" or name == "" or secret(name) then return end
    if db().on then push("R", name)
    elseif ChatFrame_SendTell then ChatFrame_SendTell(name) end
  end
  local w = CreateFrame("Frame")
  w:RegisterEvent("PLAYER_LOGIN") w:RegisterEvent("PLAYER_REGEN_ENABLED")
  local bound = false
  NT.onEvent(w, function()
    if not bound then bound = bindKey() end
  end)
end

SLASH_NTBNTELL1 = "/ntbn"
SlashCmdList.NTBNTELL = function(arg)
  local id, msg = (arg or ""):match("^%s*(%d+)%s+(.+)$")
  id = tonumber(id)
  if id and msg and BNSendWhisper then pcall(BNSendWhisper, id, msg) end
end
SLASH_NTLINK1 = "/ntlink"
SlashCmdList.NTLINK = function(arg)
  arg = (arg or ""):gsub("^%s+", ""):gsub("%s+$", "")
  if not (arg:match("^%a+:[%d:%-]+$") or arg:match("^trade:[%w:%-]+$")) then return end
  local text = "[" .. arg .. "]"
  if arg:match("^item:") and GetItemInfo then
    local ok, _, full = pcall(GetItemInfo, arg)
    if ok and type(full) == "string" then text = full end
  end
  if SetItemRef then pcall(SetItemRef, arg, text, "LeftButton") end
end

do
  local links, nid, busy = {}, 0, false
  local typingAt, swallowAt = nil, 0
  local lastLink, lastAt = nil, 0
  local pendLink, pendAt = nil, 0
  local function trTyping() return typingAt and GetTime() - typingAt < 180 end
  local function gameTyping()
    local f = ChatEdit_GetActiveWindow or (ChatFrameUtil and ChatFrameUtil.GetActiveWindow)
    if not f then return false end
    local ok, eb = pcall(f)
    return ok and eb and eb.IsVisible and eb:IsVisible() and true or false
  end
  local function hideSplit() if StackSplitFrame and StackSplitFrame:IsShown() then StackSplitFrame:Hide() end end
  local function send(text)
    if NangmanTranslator_LinkEN then text = NangmanTranslator_LinkEN(text, true) end
    nid = nid % 99 + 1
    links[nid] = text
    push("H", nid, text)
    swallowAt = GetTime()
    hideSplit()
  end
  T.linkSend = send
  local function onLink(text)
    if type(text) ~= "string" or secret(text) or not text:find("|H", 1, true) then return end
    if gameTyping() then return end
    local now = GetTime()
    if text == lastLink and now - lastAt < 0.1 then return end
    lastLink, lastAt = text, now
    if trTyping() then send(text) else pendLink, pendAt = text, now end
  end
  local function questLink(qid, title, level, idx)
    qid = tonumber(qid)
    if not qid then return nil end
    if GetQuestLink then
      for _, a in ipairs({ qid, idx }) do
        if a then
          local ok, l = pcall(GetQuestLink, a)
          if ok and type(l) == "string" and l:find("|Hquest:" .. qid .. ":", 1, true) then return l end
        end
      end
    end
    if (not title or not level) and idx and GetQuestLogTitle then
      local ok, tt, lv = pcall(GetQuestLogTitle, idx)
      if ok then title = title or tt level = level or lv end
    end
    if not title or title == "" then return nil end
    return string.format("|cffffff00|Hquest:%d:%d|h[%s]|h|r", qid, tonumber(level) or 0, title)
  end
  do
    local function qlIdx(self)
      local off = (FauxScrollFrame_GetOffset and QuestLogListScrollFrame) and FauxScrollFrame_GetOffset(QuestLogListScrollFrame) or 0
      return (self.GetID and self:GetID() or 0) + off
    end
    local function pre(self, button)
      self.__ntW = nil
      if button ~= "LeftButton" or not IsShiftKeyDown() or gameTyping() or not trTyping() or not GetQuestLogTitle then return end
      local idx = qlIdx(self)
      local ok, title, level, _, isHeader, _, _, _, qid = pcall(GetQuestLogTitle, idx)
      if not ok or isHeader or not title or not qid then return end
      self.__ntW = { idx = idx, w = (IsQuestWatched and IsQuestWatched(idx)) and true or false }
      local l = questLink(qid, title, level, idx)
      if l then send(l) end
    end
    local function post(self)
      local w = self.__ntW self.__ntW = nil
      if not w or not IsQuestWatched then return end
      local now = IsQuestWatched(w.idx) and true or false
      if now ~= w.w then
        if w.w then pcall(AddQuestWatch, w.idx) else pcall(RemoveQuestWatch, w.idx) end
        if QuestWatch_Update then pcall(QuestWatch_Update) end
        if QuestLog_Update then pcall(QuestLog_Update) end
      end
    end
    local function hookQL()
      for i = 1, (QUESTS_DISPLAYED or 27) do
        local b = _G["QuestLogTitle" .. i]
        if b and b.HookScript and not b.__ntLink then b.__ntLink = true b:HookScript("PreClick", NT.safe(pre)) b:HookScript("PostClick", NT.safe(post)) end
      end
    end
    local qe = CreateFrame("Frame")
    qe:RegisterEvent("PLAYER_LOGIN")
    NT.onEvent(qe, function() pcall(hookQL) end)
    if QuestLogFrame and QuestLogFrame.HookScript then QuestLogFrame:HookScript("OnShow", function() pcall(hookQL) end) end
  end
  if HandleModifiedItemClick then NT.hsf("HandleModifiedItemClick", function(link) if not IsModifiedClick or IsModifiedClick("CHATLINK") then onLink(link) end end) end
  if ChatEdit_InsertLink then NT.hsf("ChatEdit_InsertLink", onLink) end
  if ChatFrameUtil and ChatFrameUtil.InsertLink then NT.hsf(ChatFrameUtil, "InsertLink", onLink) end
  if StackSplitFrame then StackSplitFrame:HookScript("OnShow", function(self) if GetTime() - swallowAt < 0.3 then self:Hide() end end) end
  local on = CreateFrame("Button", "NangmanTrTypingOn")
  on:SetScript("OnClick", function()
    typingAt = GetTime()
    if pendLink and GetTime() - pendAt < 0.6 then local t = pendLink pendLink = nil send(t) end
  end)
  local off = CreateFrame("Button", "NangmanTrTypingOff")
  off:SetScript("OnClick", function() typingAt = nil pendLink = nil end)
  local pasted, pastedEb, pastedAt = nil, nil, 0
  local function swap(eb)
    if busy then return end
    local t = eb:GetText()
    if type(t) ~= "string" or secret(t) then return end
    if t == "" then pasted = nil end
    if NangmanTranslator_LinkEN and not t:find("{fk", 1, true) then
      local c = NangmanTranslator_LinkEN(t)
      if c ~= t then busy = true pcall(eb.SetText, eb, c) busy = false t = c end
    end
    if pasted and pastedEb == eb and GetTime() - pastedAt < 0.6 and not t:find("{fks}", 1, true) then
      if #t > #pasted and t:sub(1, #pasted) == pasted then
        busy = true pcall(eb.SetText, eb, pasted) busy = false
      else
        pasted = t
      end
      return
    end
    if not t:find("{fks}", 1, true) then
      local fi = t:find("/ntchat ", 2, true)
      if fi then busy = true pcall(eb.SetText, eb, t:sub(fi)) busy = false return end
      local pre, cmd = t:match("^([%w ]+)(/nt%a+.*)$")
      if pre and cmd then busy = true pcall(eb.SetText, eb, cmd) busy = false return end
    end
    local nt = t
    local mark = nt:find("{fks}", 1, true)
    if mark then nt = nt:match("{fks}(.*)$") or "" end
    if not nt:find("{fkl", 1, true) and nt == t then return end
    nt = nt:gsub("{fkl(%d+)}", function(i) return links[tonumber(i)] or "" end)
    if NangmanTranslator_LinkEN then nt = NangmanTranslator_LinkEN(nt, true) end
    if nt ~= t then busy = true pcall(eb.SetText, eb, nt) busy = false end
    if mark then
      local now = eb:GetText()
      pasted, pastedEb, pastedAt = (type(now) == "string" and not secret(now)) and now or nt, eb, GetTime()
    end
  end
  local bound, hooked = false, false
  local w = CreateFrame("Frame")
  w:RegisterEvent("PLAYER_LOGIN") w:RegisterEvent("PLAYER_REGEN_ENABLED") w:RegisterEvent("UPDATE_BINDINGS")
  local function sigBind()
    if InCombatLockdown() or not SetOverrideBindingClick then return end
    for _, k in ipairs({ "CTRL-F11", "CTRL-SHIFT-F11" }) do SetOverrideBindingClick(on, true, k, "NangmanTrTypingOn") end
    for _, k in ipairs({ "CTRL-F12", "CTRL-SHIFT-F12" }) do SetOverrideBindingClick(off, true, k, "NangmanTrTypingOff") end
  end
  NT.onEvent(w, function(_, e)
    if e == "UPDATE_BINDINGS" then if bound then pcall(sigBind) end return end
    if not hooked then
      hooked = true
      for i = 1, (NUM_CHAT_WINDOWS or 10) do
        local eb = _G["ChatFrame" .. i .. "EditBox"]
        if eb and eb.HookScript then eb:HookScript("OnTextChanged", NT.safe(swap)) end
      end
    end
    if not bound and not InCombatLockdown() and SetOverrideBindingClick then
      bound = true
      for _, k in ipairs({ "CTRL-F11", "CTRL-SHIFT-F11" }) do SetOverrideBindingClick(on, true, k, "NangmanTrTypingOn") end
      for _, k in ipairs({ "CTRL-F12", "CTRL-SHIFT-F12" }) do SetOverrideBindingClick(off, true, k, "NangmanTrTypingOff") end
      local nop = CreateFrame("Button", "NangmanTrCtrlV")
      nop:SetScript("OnClick", function()
        if db().on or InCombatLockdown() or not GetCVar then return end
        pcall(SetCVar, "nameplateShowAll", GetCVar("nameplateShowAll") == "1" and "0" or "1")
      end)
      SetOverrideBindingClick(nop, true, "CTRL-V", "NangmanTrCtrlV")
    end
  end)
end

do
  local qf = CreateFrame("Frame")
  qf:RegisterEvent("PLAYER_REGEN_DISABLED") qf:RegisterEvent("PLAYER_REGEN_ENABLED") qf:RegisterEvent("PLAYER_ENTERING_WORLD")
  NT.onEvent(qf, function(_, e)
    local on = (e == "PLAYER_REGEN_DISABLED") or (e == "PLAYER_ENTERING_WORLD" and InCombatLockdown and InCombatLockdown())
    push("Q", on and 1 or 0)
  end)
end

do
  local pf, last, acc = CreateFrame("Frame"), nil, 0
  NT.onUpdate(pf, function(_, el)
    acc = acc + el if acc < 0.1 then return end acc = 0
    local on = false
    for i = 1, 4 do local p = _G["StaticPopup" .. i] if p and p:IsShown() then on = true break end end
    if on ~= last then last = on push("U", on and 1 or 0) end
  end)
end

do
  local lastN, lastT = nil, 0
  local function onTell(name)
    if type(name) ~= "string" or name == "" or secret(name) then return end
    if not db().on or not NT.alive() then return end
    local now = GetTime()
    if name == lastN and now - lastT < 0.5 then return end
    lastN, lastT = name, now
    local f = ChatEdit_GetActiveWindow or (ChatFrameUtil and ChatFrameUtil.GetActiveWindow)
    local ok, eb = pcall(f or function() end)
    if ok and eb then
      local off = ChatEdit_DeactivateChat or (ChatFrameUtil and ChatFrameUtil.DeactivateChat)
      if off then pcall(off, eb) elseif eb.Hide then pcall(eb.ClearFocus, eb) pcall(eb.Hide, eb) end
    end
    push("R", name)
  end
  local hg, hu = false, false
  local function hook()
    if not hg and type(ChatFrame_SendTell) == "function" then hg = true NT.hsf("ChatFrame_SendTell", onTell) end
    if not hu and ChatFrameUtil and type(ChatFrameUtil.SendTell) == "function" then hu = true NT.hsf(ChatFrameUtil, "SendTell", onTell) end
  end
  hook()
  local hf = CreateFrame("Frame")
  hf:RegisterEvent("ADDON_LOADED") hf:RegisterEvent("PLAYER_LOGIN")
  NT.onEvent(hf, function() hook() if hg and hu then hf:UnregisterAllEvents() end end)
end

do
  local lastAct = 0
  local function check(eb)
    if not (db().on and NT.alive()) then return end
    if not (eb and eb.IsShown and eb:IsShown() and eb:HasFocus()) then return end
    local t = eb:GetText() or ""
    if secret(t) or t:sub(1, 1) == "/" or t:find("{fk", 1, true) then return end
    local ct = eb:GetAttribute("chatType")
    local tell = eb:GetAttribute("tellTarget")
    local links = {}
    local plain = t:gsub("(|c[^|]*|H.-|h.-|h|r)", function(l) links[#links + 1] = l return "" end)
    plain = plain:gsub("(|H.-|h.-|h)", function(l) links[#links + 1] = l return "" end)
    plain = plain:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
    eb:SetText("")
    local off = ChatEdit_DeactivateChat or (ChatFrameUtil and ChatFrameUtil.DeactivateChat)
    if off then pcall(off, eb) else pcall(eb.ClearFocus, eb) end
    if (ct == "WHISPER" or ct == "BN_WHISPER") and type(tell) == "string" and tell ~= "" and not secret(tell) then push("R", tell) end
    push("M", plain)
    for _, l in ipairs(links) do if T.linkSend then pcall(T.linkSend, l) end end
  end
  local function onAct(eb)
    local now = GetTime()
    if now - lastAct < 0.2 then return end
    lastAct = now
    eb = eb or chatEB()
    C_Timer.After(1, function() pcall(check, eb) end)
  end
  if ChatEdit_ActivateChat then NT.hsf("ChatEdit_ActivateChat", onAct) end
  if ChatFrameUtil and type(ChatFrameUtil.ActivateChat) == "function" then NT.hsf(ChatFrameUtil, "ActivateChat", onAct) end
end

do
  local bf = CreateFrame("Frame")
  bf:RegisterEvent("PLAYER_ENTERING_WORLD") bf:RegisterEvent("ZONE_CHANGED_NEW_AREA")
  local function check()
    local _, typ = IsInInstance()
    local d = db()
    if typ == "pvp" or typ == "arena" then
      if d.on then
        d.bgOff = true setOn(false, true)
        C_Timer.After(2, function() if RaidNotice_AddMessage and RaidWarningFrame then pcall(RaidNotice_AddMessage, RaidWarningFrame, "전장에 계시는 동안에는 집중 대화창으로 번역을 보실 수 있어요", { r = 1, g = 0.82, b = 0.4 }, 5) end end)
      end
    elseif d.bgOff then
      d.bgOff = nil
      if not d.on and not T.userOff then setOn(true, true) end
    end
  end
  NT.onEvent(bf, function() C_Timer.After(1, function() pcall(check) end) end)
end

do
  local IN = {}
  for _, c in ipairs({ "ntchat", "ntbn", "ntlink", "nttr" }) do IN[c] = true end
  local function inner(t)
    if type(t) ~= "string" then return false end
    local c = t:match("^%s*/(%S+)")
    return c and IN[c:lower()] or false
  end
  local function run(t)
    local c, rest = t:match("^%s*/(%S+)%s*(.*)$")
    if not c then return end
    c = "/" .. c:lower()
    for k, h in pairs(SlashCmdList) do
      if _G["SLASH_" .. k .. "1"] == c then pcall(h, rest) return end
    end
  end
  local function wrap(fn) return function(msg, ...) if inner(msg) then run(msg) return end return fn(msg, ...) end end
  if C_ChatInfo and type(C_ChatInfo.SendChatMessage) == "function" then C_ChatInfo.SendChatMessage = wrap(C_ChatInfo.SendChatMessage) end
  if type(SendChatMessage) == "function" then SendChatMessage = wrap(SendChatMessage) end
  if type(BNSendWhisper) == "function" then local o = BNSendWhisper BNSendWhisper = function(id, msg, ...) if inner(msg) then run(msg) return end return o(id, msg, ...) end end
  local seen = {}
  local function quiet(eb)
    if not eb or seen[eb] or not eb.HookScript then return end
    seen[eb] = true
    eb:HookScript("OnTextChanged", function(self)
      local t = self:GetText() or ""
      local hide = inner(t)
      local c = t:match("^/(%S+)$")
      if not hide and c and #c >= 2 then c = c:lower() for k in pairs(IN) do if k:sub(1, #c) == c then hide = true break end end end
      if hide then if not self.__ntq then self.__ntq = self:GetAlpha() end self:SetAlpha(0)
      elseif self.__ntq then self:SetAlpha(self.__ntq) self.__ntq = nil end
    end)
    eb:HookScript("OnHide", function(self) if self.__ntq then self:SetAlpha(self.__ntq) self.__ntq = nil end end)
  end
  local qf = CreateFrame("Frame")
  qf:RegisterEvent("PLAYER_LOGIN")
  qf:SetScript("OnEvent", function()
    for i = 1, (NUM_CHAT_WINDOWS or 10) do quiet(_G["ChatFrame" .. i .. "EditBox"]) end
  end)
end
