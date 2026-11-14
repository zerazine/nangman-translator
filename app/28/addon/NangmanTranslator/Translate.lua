-- 낭만타우렌 번역기 · 번역 연결
-- 게임 대화를 화면 왼쪽 맨 아래 아주 얇은 어두운 색 점 줄로 내보내면, 바깥 번역 프로그램이
-- 그 색을 읽어 번역창(우리 대화창 모양)에 띄운다. 애드온은 인터넷을 못 써서 이 방법으로 밖에 알린다.
-- /번역 · /nttr = 번역 켜기/끄기 (켜면 게임 대화창은 숨고 번역창이 그 자리에 뜸)
-- /번역 테스트 = 가짜 외국인 대화가 15초마다 들어오는 테스트 모드
local NT = NangmanTr
if not NT or NT.inert then return end

local T = {}
NT.T = T
local db = NT.tr
local secret = NT.secret

-- ===== 바이트 → 6비트 숫자 (3바이트 = 4칸) =====
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

-- ===== 색 점 줄 =====
-- 칸 0~3: 밝기 기준(검정·어둠·밝음·흰색) · 4~5: 번호 · 6~7: 칸 수 · 8~9: 검산 · 10~: 내용
local CELLPX = 3
local PAYLOAD = 130
local BYTES = 96
local HEAD = 10
local HOLD = 0.1
local LV = { 0, 40 / 255, 80 / 255, 120 / 255 }
local strip, cells
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
-- 기록 하나 = 칸들을 탭으로 이은 한 줄
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
-- 다시 보내기(낮은 순서): 새 대화가 없을 때만 한 줄씩 보냄 → 새 대화는 늘 먼저
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
    -- 한글(3바이트) 중간에서 자르지 않기: 다음 바이트가 이어지는 바이트(10xxxxxx)면 앞으로 당김
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

-- ===== 대화 모으기 =====
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
-- 플레이어 대화 줄인지: 줄 안의 이름 링크에 대화 번호가 들어 있음 (그 번호를 이미 자세히 보냈으면 건너뜀)
local function playerLineID(t)
  return t:match("|Hplayer:[^:|]*:(%d+):") or t:match("|HBNplayer:[^:|]*:[^:|]*:(%d+):")
end
local lineNo = 0
-- 이번 접속 번호(리로드마다 새로) + 줄 번호 = 대화마다 고유 번호 → PC가 같은 줄을 두 번 안 띄움
local SID = tostring(math.random(100000, 999999))
local recent = {} -- 최근 대화 (다시 보내기용)
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
evf:SetScript("OnEvent", function(_, ev, msg, sender, lang, chanStr, target, flags, zoneId, chanIdx, chanBase, _, lineID, guid, bnID)
  if secret(msg) or secret(sender) then return end
  -- 같은 대화가 게임 채팅창(ChatFrame1)에 찍힌 줄은 따로 보내지 않음 (플레이어 대화는 여기서 자세히 보냄)
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
    -- 두 단어 이름 캐릭터도 내가 보낸 말로 잡히게 캐릭터 고유번호(GUID)로도 확인
    (type(guid) == "string" and not secret(guid) and guid == UnitGUID("player")) or
    (sender and mine and (sender == mine or sender:match("^([^%-]+)") == mine))) then me = 1 end
  local cnum, cname = "", ""
  if t == "CHANNEL" then cnum = tostring(chanIdx or "") cname = tostring(chanBase or chanStr or "") end
  -- 배틀넷 귓말: 배틀넷 번호를 같이 보냄 (PC 번역 입력칸에서 /r · 이름 클릭으로 답장할 수 있게)
  --  게임 밖에서는 못 읽는 이름 표시(|K…|k)면 배틀태그 앞부분으로 바꿔 보냄
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
end)
-- 시스템·전리품 같은 다른 줄: 게임 채팅창에 찍히는 그대로
local function hookCF()
  if not ChatFrame1 or T.hooked then return end
  T.hooked = true
  hooksecurefunc(ChatFrame1, "AddMessage", function(_, text, r, g, b)
    if type(text) ~= "string" or secret(text) then return end
    pendLines[#pendLines + 1] = { text, hexOf(r, g, b) }
  end)
end

-- ===== 테스트 모드: 가짜 외국인 =====
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

-- ===== 게임 대화창 숨기기 (번역 켜짐일 때) =====
-- 글자 창만 투명하게 · 와우에서 직접 Enter로 입력하는 동안엔 입력줄이 보이게 · 번역창에도 알려서 그 동안 번역창 입력줄을 비켜 줌
local function chatPanel() return _G.NangmanTrChat end
local lastEdit, lastVis
local function applyHide()
  local p = chatPanel()
  if not p then return end
  local on = db().on
  local eb = ChatFrame1EditBox
  local typing = (eb and eb:HasFocus()) and true or false
  local w = on and 0 or 1
  for _, k in ipairs({ p:GetChildren() }) do
    if k.AddMessage and k.ScrollToBottom and k:GetAlpha() ~= w then k:SetAlpha(w) end
  end
  if p.chrome then
    if on then
      local cw = typing and 1 or 0
      if p.chrome:GetAlpha() ~= cw then p.chrome:SetAlpha(cw) end
      T.chromeForced = true
    elseif T.chromeForced then
      T.chromeForced = nil
      p.chrome:SetAlpha(1)
    end
  end
  if on then
    if typing ~= lastEdit then lastEdit = typing push("E", typing and 1 or 0) end
    -- 게임 안 아무 입력칸(경매장 검색·우편·매크로 등)에 글 쓰는 중인지 → 번역 쪽이 그동안 Enter를 안 가로챔
    local kb = (GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus() ~= nil) and true or false
    if kb ~= T.lastKb then T.lastKb = kb push("K", kb and 1 or 0) end
    -- 번역창이 보여야 하는지 (번역 켜짐이면 늘 보임 · 여행처럼 UI를 숨긴 때는 안 보임)
    local vis = p:IsVisible() and true or false
    if vis ~= lastVis then lastVis = vis push("V", vis and 1 or 0) end
  end
end

-- ===== 내 정보 · 채팅창 자리 (번역창이 같은 자리에 같은 크기로) =====
local function info()
  local name, realm = UnitFullName and UnitFullName("player")
  if not name then name = UnitName("player") end
  if not realm or realm == "" then realm = GetRealmName and GetRealmName() or "" end
  local _, cls = UnitClass("player")
  local c = cls and RAID_CLASS_COLORS and RAID_CLASS_COLORS[cls]
  -- 번역창을 대화창으로 쓰는 중이면 P(켜짐) · 게임 대화창을 쓰는 중이면 X(꺼짐) — 12초마다 다시 알림
  if db().on then push("P", name or "", realm or "", c and hexOf(c.r, c.g, c.b) or "", db().test and 1 or 0, GetLocale and GetLocale() or "", NT.chatFontSize and NT.chatFontSize() or "") -- 6번째 = 대화창 글자 크기 (PC 번역창이 따라감)
  else
    -- 게임 대화창 모드: 글 쓰는 중 · 전투 중 · 직접 끈 것(대화창 버튼 · /번역 · 프로그램이 끔)인지
    local eb = ChatFrame1EditBox
    local ty = ((eb and eb:HasFocus()) or (GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus() ~= nil)) and 1 or 0
    push("X", ty, (InCombatLockdown and InCombatLockdown()) and 1 or 0, T.userOff and 1 or 0)
  end
end
-- 들어가 있는 채널 · 서버 채널 이름 → PC 번역창 메뉴에서 채널 들어가기·나가기
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
do local cf = CreateFrame("Frame") cf:RegisterEvent("CHANNEL_UI_UPDATE") cf:RegisterEvent("PLAYER_ENTERING_WORLD") cf:SetScript("OnEvent", function() C_Timer.After(1, function() pcall(chans) end) end) end
local lastGeo = ""
local function geo()
  local p = chatPanel()
  if not p or not p:GetLeft() then return end
  local _, ph = GetPhysicalScreenSize()
  local s = p:GetEffectiveScale() * ph / 768
  local sh = (UIParent:GetTop() or 768) * UIParent:GetEffectiveScale() * ph / 768
  local L, Tp = p:GetLeft() * s, sh - p:GetTop() * s
  local g = string.format("%d\t%d\t%d\t%d\t%.4f", math.floor(L + 0.5), math.floor(Tp + 0.5), math.floor(p:GetWidth() * s + 0.5), math.floor(p:GetHeight() * s + 0.5), s)
  if g ~= lastGeo then lastGeo = g push("G", g) end
end

-- ===== 매 프레임 =====
local tick, infoAt = 0, 0
NT.infoNow = function() infoAt = 0 end
NT.feedNow = function() T.lastFeed = nil end
local drv = CreateFrame("Frame")
drv:SetScript("OnUpdate", function(_, el)
  local now = GetTime()
  if #pendLines > 0 then
    for _, l in ipairs(pendLines) do
      local id = playerLineID(l[1])
      if not (id and seenIDs[id]) then push("S", l[2], l[1]) end
    end
    pendLines = {}
    for id, at in pairs(seenIDs) do if now - at > 5 then seenIDs[id] = nil end end
  end
  tick = tick + el
  if tick > 1 then
    tick = 0
    geo()
    if now > infoAt then infoAt = now + 12 lastGeo = "" lastEdit = nil lastVis = nil T.lastFeed = nil T.lastKb = nil info() if (T.chanN or 0) <= 0 then T.chanN = 5 lastChan = "" end T.chanN = T.chanN - 1 pcall(chans) end -- 채널 목록은 1분에 한 번 다시
    -- 화면 가운데 파티 대화 줄 자리 (번역 켜면 번역 프로그램이 그 자리에 번역된 줄을 그림)
    local fg = NT.feedGeo and NT.feedGeo()
    local fon = (NT.feedEnabled and NT.feedEnabled()) and "1" or "0" -- (2026-11-13) 파티글 켜짐/꺼짐도 같이 알림
    if fg and (fg .. fon) ~= T.lastFeed then
      T.lastFeed = fg .. fon
      local a, b, c, d, e, h, m, z, mv = strsplit("\t", fg)
      push("F", a, b, c, d, e, h, m, z or "13", mv or "0", fon) -- x · y(아래 끝) · 폭 · 배율 · 옮기는 중 · 높이 · 띄울 종류 · 글자 크기 · 옮기는 중
    end
  end
  fake(now)
  if now > (T.replayAt or 0) then T.replayAt = now + 30 replay(now) end -- 30초마다 최근 10분 대화 다시 보내기
  if strip then pump(now) end
  applyHide()
end)

local function look() if NT.btnLook then pcall(NT.btnLook) end end
local function setOn(on)
  local d = db()
  d.on = on and true or false
  if d.on then
    makeStrip() layout() hookCF()
    infoAt = 0 lastGeo = ""
    NT.say("번역창을 대화창으로 써요 (번역 프로그램이 켜져 있어야 해요)")
    C_Timer.After(1.5, function() if NT.tabsPush then pcall(NT.tabsPush) end end) -- 번역창과 탭 설정 맞추기
  else
    -- 번역창에 '꺼짐'을 알린 뒤 끔 (남은 신호는 다 보내고 줄이 저절로 사라짐)
    push("X")
    d.test = false
    infoAt = 0
    NT.say("게임 대화창으로 돌아왔어요")
  end
  T.lastFeed = nil
  if NT.feedRefresh then pcall(NT.feedRefresh) end
  look()
end
-- 미니맵 버튼·단축키가 부름: on = 번역 켜기(번역창 = 대화창) · off = 번역 끄기(게임 대화창) · 직접 고른 것으로 기억
function NT.setTranslate(on)
  local d = db()
  T.userOff = (not on) and true or nil -- 이번 접속 동안만 기억 (다음 접속 땐 번역기가 다시 켤 수 있게)
  d.userOff = nil
  if (d.on and true or false) ~= (on and true or false) then setOn(on) else infoAt = 0 look() end
end
SLASH_NTTRANSLATE1 = "/nttr"
SLASH_NTTRANSLATE2 = "/번역"
SlashCmdList.NTTRANSLATE = function(arg)
  arg = (arg or ""):gsub("^%s+", ""):gsub("%s+$", "")
  if arg == "테스트" or arg == "test" then
    local d = db()
    if not d.on then NT.setTranslate(true) end
    d.test = not d.test
    fakeAt = GetTime() + 2
    infoAt = 0
    NT.say(d.test and "테스트 모드 켜짐 - 가짜 외국인 대화가 15초마다 와요 · 답장은 내 캐릭에게 귓말로 가요" or "테스트 모드 꺼짐")
    return
  end
  -- 켜기 = 번역창을 대화창으로 · 끄기 = 게임 대화창으로 (번역 프로그램의 '번역' 알약도 이것을 보냄)
  if arg == "켜기" or arg == "on" then NT.setTranslate(true) return end
  if arg == "끄기" or arg == "off" then NT.setTranslate(false) return end
  NT.setTranslate(not db().on)
end

local ld = CreateFrame("Frame")
ld:RegisterEvent("PLAYER_LOGIN")
ld:RegisterEvent("DISPLAY_SIZE_CHANGED")
ld:RegisterEvent("UI_SCALE_CHANGED")
ld:SetScript("OnEvent", function(_, ev)
  myName = UnitName("player")
  if ev == "PLAYER_LOGIN" then
    -- 대화 신호는 접속하자마자 늘 보냄 · 번역창/게임 대화창 중 고른 것은 그대로 기억
    makeStrip() layout() hookCF()
    do local d = db() d.test = false end
    infoAt = 0
  elseif strip then
    layout()
    lastGeo = ""
    T.lastFeed = nil
  end
end)

-- ===== 파티(공대)에 들어가면 입력창 기본 대상 = 파티 (번역 입력칸은 'J' 신호로 · 게임 기본 입력줄도 같이) =====
do
  local jf = CreateFrame("Frame")
  jf:RegisterEvent("GROUP_JOINED")
  jf:SetScript("OnEvent", function()
    C_Timer.After(0.5, function()
      if not (IsInGroup and IsInGroup()) then return end
      local t = (IsInGroup(LE_PARTY_CATEGORY_INSTANCE or 2) and "INSTANCE_CHAT") or (IsInRaid and IsInRaid() and "RAID") or "PARTY"
      push("J", t)
      local eb = ChatFrame1EditBox
      if eb and not InCombatLockdown() then pcall(eb.SetAttribute, eb, "chatType", t) pcall(eb.SetAttribute, eb, "stickyType", t) end
    end)
  end)
end

-- ===== 접속 신호: 처음 접속(캐릭터 선택 → 게임)일 때만 'W' (/reload·순간이동 로딩 때는 안 보냄) =====
do
  local wf = CreateFrame("Frame")
  wf:RegisterEvent("PLAYER_ENTERING_WORLD")
  wf:SetScript("OnEvent", function(_, _, isLogin, isReload)
    if isLogin and not isReload then push("W", UnitName("player") or "") end
  end)
end

-- ===== Shift+Enter · 귓말 답장 =====
-- Shift+Enter: 번역이 꺼져 있으면 → 켜고 바로 입력칸 · 켜져 있으면 바깥 번역 프로그램이 이 키를 먼저 받아 입력칸을 염
--   (프로그램이 안 돌고 있어 키가 게임으로 오면 → 그냥 게임 입력줄)
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
  -- 귓말 답장 (가운데 파티 대화 줄에서 부름) · 번역 켜짐 = 번역 입력칸이 그 사람 귓말로 · 꺼짐 = 게임 귓말 입력줄
  function NT.reply(name)
    if type(name) ~= "string" or name == "" or secret(name) then return end
    if db().on then push("R", name)
    elseif ChatFrame_SendTell then ChatFrame_SendTell(name) end
  end
  local w = CreateFrame("Frame")
  w:RegisterEvent("PLAYER_LOGIN") w:RegisterEvent("PLAYER_REGEN_ENABLED")
  local bound = false
  w:SetScript("OnEvent", function()
    if not bound then bound = bindKey() end
  end)
end

-- 번역창에서 아이템·주문·퀘스트 링크 [이름]을 누르면 번역 프로그램이 '/ntlink item:12345:…'를 대신 입력
--  → 게임 대화창에서 링크를 누른 것과 똑같이 정보 창을 엶 (SetItemRef) · 링크 모양이 아니면 아무것도 안 함
-- 배틀넷 귓말 보내기: /ntbn 배틀넷번호 내용 (PC 번역 입력칸에서 배틀넷 친구에게 답장할 때 씀)
SLASH_NTBNTELL1 = "/ntbn"
SlashCmdList.NTBNTELL = function(arg)
  local id, msg = (arg or ""):match("^%s*(%d+)%s+(.+)$")
  id = tonumber(id)
  if id and msg and BNSendWhisper then pcall(BNSendWhisper, id, msg) end
end
SLASH_NTLINK1 = "/ntlink"
SlashCmdList.NTLINK = function(arg)
  arg = (arg or ""):gsub("^%s+", ""):gsub("%s+$", "")
  if not arg:match("^%a+:[%d:%-]+$") then return end
  local text = "[" .. arg .. "]"
  if arg:match("^item:") and GetItemInfo then
    local ok, _, full = pcall(GetItemInfo, arg)
    if ok and type(full) == "string" then text = full end
  end
  if SetItemRef then pcall(SetItemRef, arg, text, "LeftButton") end
end

-- 번역창에 쓰는 중에 게임에서 아이템·주문·퀘스트 링크를 시프트 클릭하면 → 번역창 입력줄로 보냄
--  게임 입력줄이 열려 있으면 원래대로 게임 입력줄,
--  번역창에 쓰던 중이면(번역 프로그램이 Ctrl+F11 신호를 줌 · Ctrl+F12 = 끝) 번역창으로 보내고 '아이템 나누기' 창은 닫음
--  번역 프로그램은 링크 자리를 '{fkl번호}'로 붙여 넣고, 게임 입력줄에 들어오는 순간 여기서 진짜 링크로 바꿈
do
  local links, nid, busy = {}, 0, false
  local typingAt, swallowAt = nil, 0
  local lastLink, lastAt = nil, 0          -- 같은 클릭이 두 번 잡히는 것 방지
  local pendLink, pendAt = nil, 0          -- 신호보다 클릭이 먼저 들어온 경우 잠깐 보관
  local function trTyping() return typingAt and GetTime() - typingAt < 30 end
  local function gameTyping()
    local f = ChatEdit_GetActiveWindow or (ChatFrameUtil and ChatFrameUtil.GetActiveWindow)
    if not f then return false end
    local ok, eb = pcall(f)
    return ok and eb and eb.IsVisible and eb:IsVisible() and true or false
  end
  local function hideSplit() if StackSplitFrame and StackSplitFrame:IsShown() then StackSplitFrame:Hide() end end
  local function send(text)
    nid = nid % 99 + 1
    links[nid] = text
    push("H", nid, text)
    swallowAt = GetTime()
    hideSplit()
  end
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
  -- 게임 기본 퀘스트 창(클래식): 게임 입력줄이 닫혀 있으면 Shift+클릭이 '추적 켜기/끄기'라서 링크가 안 갔음
  --  → 번역창에 쓰는 중일 때만 링크를 번역창으로 보내고, 같이 바뀐 추적 상태는 되돌림
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
        if b and b.HookScript and not b.__ntLink then b.__ntLink = true b:HookScript("PreClick", pre) b:HookScript("PostClick", post) end
      end
    end
    local qe = CreateFrame("Frame")
    qe:RegisterEvent("PLAYER_LOGIN")
    qe:SetScript("OnEvent", function() pcall(hookQL) end)
    if QuestLogFrame and QuestLogFrame.HookScript then QuestLogFrame:HookScript("OnShow", function() pcall(hookQL) end) end
  end
  if HandleModifiedItemClick then hooksecurefunc("HandleModifiedItemClick", function(link) if not IsModifiedClick or IsModifiedClick("CHATLINK") then onLink(link) end end) end
  if ChatEdit_InsertLink then hooksecurefunc("ChatEdit_InsertLink", onLink) end
  if ChatFrameUtil and ChatFrameUtil.InsertLink then hooksecurefunc(ChatFrameUtil, "InsertLink", onLink) end
  if StackSplitFrame then StackSplitFrame:HookScript("OnShow", function(self) if GetTime() - swallowAt < 0.3 then self:Hide() end end) end
  local on = CreateFrame("Button", "NangmanTrTypingOn")
  on:SetScript("OnClick", function()
    typingAt = GetTime()
    if pendLink and GetTime() - pendAt < 0.6 then local t = pendLink pendLink = nil send(t) end
  end)
  local off = CreateFrame("Button", "NangmanTrTypingOff")
  off:SetScript("OnClick", function() typingAt = nil pendLink = nil end)
  -- 붙여 넣은 직후 0.6초 동안은 그 글 뒤에 끼어든 글자(보내고 바로 앞으로 가려고 누른 W 등)도 버림
  --  게임이 '/s ' 같은 앞머리를 떼어 내며 글이 한 번 더 바뀌므로, 바뀔 때마다 마지막 모양을 기억해 두고 그 뒤에 덧붙은 글자만 버림
  local pasted, pastedEb, pastedAt = nil, nil, 0
  local function swap(eb)
    if busy then return end
    local t = eb:GetText()
    if type(t) ~= "string" or secret(t) then return end
    if t == "" then pasted = nil end -- 보내져서 입력줄이 비면 끝
    if pasted and pastedEb == eb and GetTime() - pastedAt < 0.6 and not t:find("{fks}", 1, true) then
      if #t > #pasted and t:sub(1, #pasted) == pasted then
        busy = true pcall(eb.SetText, eb, pasted) busy = false
      else
        pasted = t -- 게임이 앞머리를 떼어 냈거나 다른 변화 → 이 모양을 새 기준으로
      end
      return
    end
    -- (2026-11-13 대표) 번역 프로그램이 넣는 명령어(/ntchat 등) 앞에 끼어든 글자(이동하며 누르던 W·D 등)는 버림
    --  예전엔 'wd/ntchat nudge …'처럼 명령어가 아닌 보통 말로 채널에 그대로 나갔음
    if not t:find("{fks}", 1, true) then
      local pre, cmd = t:match("^([^/%s]+)(/nt%a+.*)$")
      if pre and cmd and #pre <= 8 then busy = true pcall(eb.SetText, eb, cmd) busy = false return end
    end
    -- 번역 프로그램이 붙여 넣는 글 앞에는 '{fks}' 표시가 있음 → 그 앞에 끼어든 글자(이동하며 누르던 W 등)는 버림
    local nt = t
    local mark = nt:find("{fks}", 1, true)
    if mark then nt = nt:match("{fks}(.*)$") or "" end
    if not nt:find("{fkl", 1, true) and nt == t then return end
    nt = nt:gsub("{fkl(%d+)}", function(i) return links[tonumber(i)] or "" end)
    if nt ~= t then busy = true pcall(eb.SetText, eb, nt) busy = false end
    if mark then -- 게임이 '/s ' 같은 앞머리를 떼어 낸 뒤의 실제 모양을 기준으로
      local now = eb:GetText()
      pasted, pastedEb, pastedAt = (type(now) == "string" and not secret(now)) and now or nt, eb, GetTime()
    end
  end
  local bound, hooked = false, false
  local w = CreateFrame("Frame")
  w:RegisterEvent("PLAYER_LOGIN") w:RegisterEvent("PLAYER_REGEN_ENABLED")
  w:SetScript("OnEvent", function()
    if not hooked then
      hooked = true
      for i = 1, (NUM_CHAT_WINDOWS or 10) do
        local eb = _G["ChatFrame" .. i .. "EditBox"]
        if eb and eb.HookScript then eb:HookScript("OnTextChanged", swap) end
      end
    end
    if not bound and not InCombatLockdown() and SetOverrideBindingClick then
      bound = true
      for _, k in ipairs({ "CTRL-F11", "CTRL-SHIFT-F11" }) do SetOverrideBindingClick(on, true, k, "NangmanTrTypingOn") end
      for _, k in ipairs({ "CTRL-F12", "CTRL-SHIFT-F12" }) do SetOverrideBindingClick(off, true, k, "NangmanTrTypingOff") end
      -- 번역이 켜져 있으면 Ctrl+V(와우 기본: 모든 이름표 켜기/끄기)를 막음 · 번역 프로그램의 붙여넣기가 이름표를 꺼 버리지 않게
      --  번역이 꺼져 있으면 원래대로 이름표 켜기/끄기
      local nop = CreateFrame("Button", "NangmanTrCtrlV")
      nop:SetScript("OnClick", function()
        if db().on or InCombatLockdown() or not GetCVar then return end
        pcall(SetCVar, "nameplateShowAll", GetCVar("nameplateShowAll") == "1" and "0" or "1")
      end)
      SetOverrideBindingClick(nop, true, "CTRL-V", "NangmanTrCtrlV")
    end
  end)
end

-- 전투 시작·끝을 PC 번역기에 알림 → 전투 중엔 화면 가운데 파티 대화가 휠·클릭을 가로채지 않음
do
  local qf = CreateFrame("Frame")
  qf:RegisterEvent("PLAYER_REGEN_DISABLED") qf:RegisterEvent("PLAYER_REGEN_ENABLED") qf:RegisterEvent("PLAYER_ENTERING_WORLD")
  qf:SetScript("OnEvent", function(_, e)
    local on = (e == "PLAYER_REGEN_DISABLED") or (e == "PLAYER_ENTERING_WORLD" and InCombatLockdown and InCombatLockdown())
    push("Q", on and 1 or 0)
  end)
end

-- 확인 창(경매 즉시 구매·파티 초대 등 StaticPopup)이 떠 있으면 PC 번역기에 알림 → 가운데 파티 대화가 그 위 클릭을 가로채지 않게
do
  local pf, last, acc = CreateFrame("Frame"), nil, 0
  pf:SetScript("OnUpdate", function(_, el)
    acc = acc + el if acc < 0.1 then return end acc = 0
    local on = false
    for i = 1, 4 do local p = _G["StaticPopup" .. i] if p and p:IsShown() then on = true break end end
    if on ~= last then last = on push("U", on and 1 or 0) end
  end)
end
