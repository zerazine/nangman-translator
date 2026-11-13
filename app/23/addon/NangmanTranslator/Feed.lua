-- 낭만타우렌 번역기 · 화면 가운데 파티글 (제작자 원본 파티 대화 줄을 그대로 옮김)
-- 파티·공격대·인던·귓말 등 고른 종류의 대화가 한 줄씩 떴다가 15초 뒤 부드럽게 사라짐 · 새 줄은 아래에 붙고 위 줄은 밀려 올라감
-- 번역이 켜져 있으면 번역 프로그램이 이 자리에 번역된 줄을 대신 그림 → 여기선 알림음만 (위치 옮기는 중엔 게임 줄을 그대로 보여 줌)
-- 귓말 줄의 이름 = 누르는 단추 (번역 켜짐 = 번역 입력칸이 그 사람 귓말로 · 꺼짐 = 게임 귓말 입력줄) · 나머지는 클릭이 뒤로 통과
-- 잠금 풀기 = 대화창 설정 '파티글 옮기기' · /ntchat partymove · /파티글(테스트) · 끌기 = 이동 · 오른쪽 아래 = 크기 · Ctrl+오른쪽 클릭 = 잠금/풀기
local NT = NangmanTr
if not NT or NT.inert then return end

local MEDIA = NT.MEDIA
local secret = NT.secret
local LIFE, FADE_IN, FADE_OUT, MAXL, GAP, FS = 15, 0.2, 0.6, 7, 10, 13
local function cdb()
  local D = NT.db()
  local d = D.partyFeed
  if type(d) ~= "table" then d = { lock = true } D.partyFeed = d end
  return d
end
local feed = CreateFrame("Frame", "NangmanTrPartyFeed") -- 부모 없음: UI를 숨겨도 보임
feed:SetSize(360, 200) feed:SetFrameStrata("MEDIUM") feed:SetMovable(true) feed:SetClampedToScreen(true)
-- 게임이 자체로 기억하는 창 위치는 끄고 우리 저장 위치만 씀
if feed.SetDontSavePosition then pcall(feed.SetDontSavePosition, feed, true) end
local function noUserPlaced() if feed.SetUserPlaced then pcall(feed.SetUserPlaced, feed, false) end end
-- 평소 배경 투명 · 잠금 풀었을 때만 영역 표시 + 오른쪽 아래 크기 조절
feed:SetResizable(true)
if feed.SetResizeBounds then feed:SetResizeBounds(200, 80, 900, 600) elseif feed.SetMinResize then feed:SetMinResize(200, 80) feed:SetMaxResize(900, 600) end
feed.bg = feed:CreateTexture(nil, "BACKGROUND") feed.bg:SetAllPoints() feed.bg:SetColorTexture(0.067, 0.067, 0.071, 0.72) feed.bg:Hide()
local grip = CreateFrame("Button", nil, feed) grip:SetSize(16, 16) grip:SetPoint("BOTTOMRIGHT", 0, 0) grip:Hide()
grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
feed.grip = grip
feed.tag = feed:CreateFontString(nil, "OVERLAY") feed.tag:SetFont(STANDARD_TEXT_FONT, 11, "OUTLINE") feed.tag:SetPoint("BOTTOM", feed, "TOP", 0, 2) feed.tag:SetTextColor(0.89, 0.76, 0.60) feed.tag:Hide()
local function place()
  feed:SetScale(UIParent:GetEffectiveScale())
  local d = cdb() if d.w and d.h then feed:SetSize(d.w, d.h) end
  feed:ClearAllPoints()
  local p = cdb().pos
  if p then feed:SetPoint("BOTTOMLEFT", WorldFrame, "BOTTOMLEFT", p[1] / feed:GetEffectiveScale(), p[2] / feed:GetEffectiveScale())
  else feed:SetPoint("BOTTOM", WorldFrame, "CENTER", 0, 70 / feed:GetEffectiveScale()) end   -- (2026-11-13 대표) 처음 자리 = 화면 가운데 캐릭터 머리 위
end
local test = false
local function editLook()
  local unlocked = not cdb().lock
  local on = test or unlocked
  feed.bg:SetShown(unlocked) feed.tag:SetShown(on) feed.grip:SetShown(unlocked)
  feed.tag:SetText((test and "파티 대화 (테스트) · " or "파티 대화 · ") .. (unlocked and "끌어서 옮기기 · Ctrl+오른쪽 클릭 = 잠금" or "잠김 · 클릭이 창을 통과해요 · 풀기 = 대화창 설정 또는 /파티글"))
  -- 잠기면 마우스를 아예 안 받음 → 창 위를 눌러도 뒤의 몹·땅이 클릭됨 (잠글 땐 스크립트도 떼어 냄)
  if unlocked then
    feed:SetScript("OnDragStart", feed.ntDragStart) feed:SetScript("OnDragStop", feed.ntDragStop) feed:SetScript("OnMouseUp", feed.ntMouseUp)
    feed:RegisterForDrag("LeftButton")
  else
    feed:SetScript("OnDragStart", nil) feed:SetScript("OnDragStop", nil) feed:SetScript("OnMouseUp", nil)
    feed:RegisterForDrag()
  end
  feed:EnableMouse(unlocked)
  if feed.SetMouseClickEnabled then pcall(feed.SetMouseClickEnabled, feed, unlocked) end
  if feed.SetMouseMotionEnabled then pcall(feed.SetMouseMotionEnabled, feed, unlocked) end
  if NT.feedNow then NT.feedNow() end -- 번역 프로그램에 바로 다시 알림 (옮기는 중 표시)
  if NT.feedBtnText then pcall(NT.feedBtnText) end
end
feed:RegisterForDrag("LeftButton")
feed:SetScript("OnDragStart", function(self) if not cdb().lock then self:StartMoving() end end)
feed:SetScript("OnDragStop", function(self)
  self:StopMovingOrSizing() noUserPlaced()
  local x, y = self:GetLeft(), self:GetBottom()
  if x then local es = self:GetEffectiveScale() cdb().pos = { x * es, y * es } end
  place()
end)
feed:SetScript("OnMouseUp", function(_, btn)
  if btn == "RightButton" and IsControlKeyDown() then
    cdb().lock = not cdb().lock
    if UIErrorsFrame then UIErrorsFrame:AddMessage(cdb().lock and "파티 대화 위치 잠금" or "파티 대화 위치 풀림 — 끌어서 옮기기", 1, 0.84, 0.42) end
    editLook()
  end
end)
feed.ntDragStart, feed.ntDragStop, feed.ntMouseUp = feed:GetScript("OnDragStart"), feed:GetScript("OnDragStop"), feed:GetScript("OnMouseUp")
grip:SetScript("OnMouseDown", function() feed:StartSizing("BOTTOMRIGHT") end)
grip:SetScript("OnMouseUp", function()
  feed:StopMovingOrSizing() noUserPlaced()
  local d = cdb() d.w, d.h = feed:GetWidth(), feed:GetHeight()
  local x, y = feed:GetLeft(), feed:GetBottom()
  if x then local es = feed:GetEffectiveScale() d.pos = { x * es, y * es } end
  place()
end)
local lines, pool = {}, {}
-- 글자 크기 = 대화창 설정 '파티글 글자' (기본 13)
local function fs() local v = NT.centerFont and NT.centerFont() return (type(v) == "number" and v > 0) and v or FS end
function NT.feedRefresh()
  for _, l in ipairs(lines) do pcall(l.SetFont, l, STANDARD_TEXT_FONT, fs(), "") end
  if NT.feedNow then NT.feedNow() end
end
local function newLine()
  local l = table.remove(pool)
  if not l then
    l = feed:CreateFontString(nil, "OVERLAY")
    -- 검은 그림자 없이 · 글자 테두리는 은은하게
    l:SetShadowOffset(1, -1) l:SetShadowColor(0.2, 0.094, 0.016, 0.9)
    l:SetJustifyH("CENTER") l:SetWordWrap(true)
  end
  l:SetFont(STANDARD_TEXT_FONT, fs(), "")
  l:SetWidth(feed:GetWidth()) l:SetAlpha(0) l:Show()
  return l
end
local function nameColor(guid)
  local ok, _, cls = pcall(GetPlayerInfoByGUID, guid)
  local c = ok and cls and RAID_CLASS_COLORS and RAID_CLASS_COLORS[cls]
  if c then return string.format("ff%02x%02x%02x", math.floor(c.r * 255), math.floor(c.g * 255), math.floor(c.b * 255)) end
  return "ffffd27a"
end
-- 줄이 다 사라진 뒤 첫 글이면 알림음 한 번 (이어지는 대화는 조용히 · 내가 쓴 글은 소리 없음)
-- 이 알림음만 작게: '주변 소리' 통로 볼륨을 잠깐 0.3으로 두고 그 통로로 재생 → 2초 뒤 원래대로
local restoreAt
local function playHalf(id)
  local en = GetCVar and GetCVar("Sound_EnableAmbience")
  if not (SetCVar and GetCVar) or en == "0" then PlaySound(id, "Master") return end
  local was = GetCVar("Sound_AmbienceVolume")
  if not restoreAt then feed.ntAmbWas = was end
  SetCVar("Sound_AmbienceVolume", "0.3")
  PlaySound(id, "Ambience")
  restoreAt = GetTime() + 2
  C_Timer.After(2.1, function()
    if restoreAt and GetTime() >= restoreAt then SetCVar("Sound_AmbienceVolume", feed.ntAmbWas or "0.6") restoreAt = nil end
  end)
end
-- 알림음 고르기: /파티글소리 1~6 (들어 보고 정하기 · 기본 3번)
local SOUNDS = { { 3081, "귓말 (작음)" }, { 3175, "지도 핑" }, { 18019, "배틀넷 알림 띵 (중간)" }, { 880, "파티 초대 종" }, { 8960, "전투 준비 종" }, { 12867, "자명종 띵 (큼)" } }
local function sndId() local D = NangmanTranslatorDB local i = D and D.partyFeedSound return (SOUNDS[i or 3] or SOUNDS[3])[1] end
SLASH_NTPARTYFEEDSND1 = "/파티글소리"
SlashCmdList.NTPARTYFEEDSND = function(m)
  local i = tonumber((m or ""):match("%d+"))
  local D = NT.db()
  if i and SOUNDS[i] then
    D.partyFeedSound = i
    playHalf(SOUNDS[i][1])
    print("|cffffd100[파티 대화]|r 알림음 " .. i .. "번 · " .. SOUNDS[i][2] .. " 로 정했어요")
  else
    local cur = D.partyFeedSound or 3
    print("|cffffd100[파티 대화]|r 알림음 고르기 — /파티글소리 번호 (치면 바로 들리고 그걸로 정해져요) · 지금 " .. cur .. "번")
    for k, v in ipairs(SOUNDS) do print("  " .. k .. ". " .. v[2] .. (k == cur and "  |cff7fd47f← 지금|r" or "")) end
  end
end
local function ding(isMe)
  if #lines == 0 and not isMe then playHalf(sndId()) end
end
-- 번역이 켜져 있으면 바깥 번역 프로그램이 이 자리에 번역된 줄을 대신 그림 → 여기선 소리만 (위치 옮기는 중엔 게임 줄을 그대로 보여 줌)
local function trActive()
  if not (NT.trOn() and NT.push) then return false end
  return cdb().lock or test
end
local trLast = 0
local function trDing(isMe)
  local now = GetTime()
  if not isMe and now - trLast > LIFE + FADE_OUT then playHalf(sndId()) end
  trLast = now
end
-- 번역 프로그램에 줄 자리 알려 주기 (F 신호 · 1초마다): 왼쪽 · 아래 끝(화면 위에서부터) · 폭 · 배율 · 옮기는 중 · 높이 · 띄울 종류 · 글자 크기 · 잠금 풀림
-- (2026-11-13 대표) 가운데 파티글은 선택 기능: 처음엔 꺼짐 · 번역 프로그램 설정의 '가운데 파티글' 스위치와 같이 (/ntchat feed 1|0)
function NT.feedEnabled() local D = NT.db() return D.partyFeedOn == true end
function NT.feedGeo()
  local l, b, w = feed:GetLeft(), feed:GetBottom(), feed:GetWidth()
  if not (l and b and w) then return nil end
  local _, ph = GetPhysicalScreenSize()
  local k = (ph or 1080) / 768
  local es = feed:GetEffectiveScale()
  local h1 = (UIParent:GetTop() or 768) * UIParent:GetEffectiveScale()
  local mask = NT.centerMask and NT.centerMask() or ""
  return string.format("%d\t%d\t%d\t%.4f\t%d\t%d\t%s\t%d\t%d", math.floor(l * es * k + 0.5), math.floor((h1 - b * es) * k + 0.5), math.floor(w * es * k + 0.5), es * k, (cdb().lock or test) and 0 or 1, math.floor((feed:GetHeight() or 200) * es * k + 0.5), mask ~= "" and mask or "-", fs(), cdb().lock and 0 or 1)
end
-- 번역 프로그램이 정한 자리 (/ntchat feedpos · F 신호와 같은 단위: 화면 픽셀 · x = 왼쪽 · y = 아래 끝까지 위에서부터 거리 · w · h)
function NT.feedSetPx(x, y, w, h)
  if not (x and y and w and h) or w <= 0 or h <= 0 then return end
  local _, ph = GetPhysicalScreenSize()
  local k = (ph or 1080) / 768
  local es = feed:GetEffectiveScale()
  local h1 = (UIParent:GetTop() or 768) * UIParent:GetEffectiveScale()
  if not es or es <= 0 then return end
  local d = cdb()
  d.pos = { x / k, h1 - y / k }
  d.w, d.h = math.max(100, math.min(1600, w / (es * k))), math.max(40, math.min(900, h / (es * k)))
  noUserPlaced() place()
  if NT.feedNow then NT.feedNow() end
end
function NT.feedReset()
  local d = cdb() d.pos, d.w, d.h = nil, nil, nil
  feed:SetSize(360, 200)
  noUserPlaced() place()
  if NT.feedNow then NT.feedNow() end
end
-- 귓말 줄의 이름 = 누르는 단추 (나머지는 그대로 클릭이 뒤로 통과)
local measure = feed:CreateFontString(nil, "OVERLAY") measure:SetFont(STANDARD_TEXT_FONT, FS, "") measure:Hide()
local function nameButton(l, full, nameText, pre)
  local nb = l.nb
  if not nb then
    nb = CreateFrame("Button", nil, feed)
    nb:RegisterForClicks("LeftButtonUp")
    nb.hl = nb:CreateTexture(nil, "HIGHLIGHT") nb.hl:SetTexture(MEDIA .. "glow") nb.hl:SetBlendMode("ADD") nb.hl:SetPoint("TOPLEFT", -8, 4) nb.hl:SetPoint("BOTTOMRIGHT", 8, -4) nb.hl:SetVertexColor(1, 0.5, 1, 0.55)
    nb:SetScript("OnClick", function(self) if self.who and NT.reply then NT.reply(self.who) end end)
    nb:SetScript("OnEnter", function(self) GameTooltip:SetOwner(self, "ANCHOR_TOP") GameTooltip:SetText("클릭 = " .. (self.short or "") .. " 님에게 답장", 1, 0.6, 1) GameTooltip:Show() end)
    nb:SetScript("OnLeave", function() GameTooltip:Hide() end)
    l.nb = nb
  end
  nb.who, nb.short = full, nameText
  measure:SetFont(STANDARD_TEXT_FONT, fs(), "")
  measure:SetText(pre .. nameText) local nw = measure:GetStringWidth() or 40
  measure:SetText(pre) local pw = (pre ~= "" and measure:GetStringWidth()) or 0
  local tw = math.min(l:GetStringWidth() or nw, l:GetWidth())
  nb:ClearAllPoints() nb:SetSize(math.max(16, nw - pw), fs() + 4)
  nb:SetPoint("TOPLEFT", l, "TOP", -tw / 2 + pw, 2)
  nb:SetAlpha(0) nb:Show()
end
local function trim()
  while #lines > MAXL do local o = table.remove(lines, 1) o:Hide() if o.nb then o.nb:Hide() o.nb.who = nil end pool[#pool + 1] = o end
end
function NT.feedClear() while #lines > 0 do local o = table.remove(lines, 1) o:Hide() if o.nb then o.nb:Hide() o.nb.who = nil end pool[#pool + 1] = o end end
local function push(sender, msg, guid, kind, mine, bn)
  local me = UnitName("player")
  local isMe = mine or (type(sender) == "string" and not secret(sender) and sender:gsub("%-.*", "") == me)
  if trActive() then trDing(isMe) return end
  ding(isMe)
  local l = newLine()
  local who = (type(sender) == "string" and not secret(sender)) and sender:gsub("%-.*", "") or sender
  local col = isMe and "ffffe9b8" or nameColor(guid) -- 내가 쓴 글은 직업 상관없이 이름을 금빛으로
  local mc = (kind == "raid" and "|cffff9a5a") or (kind == "warn" and "|cffff5a5a") or (kind == "whisper" and "|cffff80ff")
    or (kind == "say" and "|cffffffff") or (kind == "yell" and "|cffff4040") or (kind == "guild" and "|cff40ff40") or (kind == "channel" and "|cffffc0c0") or "|cffaad4ff"
  -- 귓말: 와우 귓말 색(분홍) · 내가 보낸 귓말은 '→ 받는 사람' 으로 구분
  local pre = (kind == "whisper" and mine) and "|cffff80ff→|r " or ""
  if not pcall(l.SetFormattedText, l, pre .. "|c%s%s|r  " .. mc .. "%s|r", col, who or "?", msg or "") then l:SetText("") end
  if l.nb then l.nb:Hide() l.nb.who = nil end
  if kind == "whisper" and not bn and type(sender) == "string" and not secret(sender) and type(who) == "string" then
    pcall(nameButton, l, sender, who, (mine and "→ " or ""))
  end
  l.t, l.y = 0, nil
  lines[#lines + 1] = l
  trim()
  feed:Show()
end
feed:SetScript("OnUpdate", function(_, el)
  -- 아래에서 위로 쌓기 (새 줄 = 맨 아래) · 위치는 부드럽게 따라감
  local y = 0
  for i = #lines, 1, -1 do
    local l = lines[i]
    l.t = l.t + el
    local a = 1
    if l.t < FADE_IN then a = l.t / FADE_IN elseif l.t > LIFE then a = 1 - (l.t - LIFE) / FADE_OUT end
    l.want = y
    l.y = l.y and (l.y + (l.want - l.y) * math.min(1, el * 12)) or l.want
    l:ClearAllPoints() l:SetPoint("BOTTOMLEFT", feed, "BOTTOMLEFT", 0, l.y)
    -- 정한 높이를 넘는 위쪽(오래된) 줄은 바로 사라지게
    if y + (l:GetStringHeight() or fs()) > (feed:GetHeight() or 200) + 2 and i < #lines then a = 0 l.t = math.max(l.t, LIFE + FADE_OUT) end
    l:SetAlpha(math.max(0, a))
    if l.nb and l.nb.who then l.nb:SetAlpha(math.max(0, a)) local m = a > 0.3 if l.nb.__m ~= m then l.nb.__m = m l.nb:EnableMouse(m) end end
    y = y + (l:GetStringHeight() or fs()) + GAP
  end
  for i = #lines, 1, -1 do
    local l = lines[i]
    if l.t > LIFE + FADE_OUT then table.remove(lines, i) l:Hide() if l.nb then l.nb:Hide() l.nb.who = nil end pool[#pool + 1] = l end
  end
end)
local KIND = { CHAT_MSG_PARTY = "party", CHAT_MSG_PARTY_LEADER = "party", CHAT_MSG_RAID = "raid", CHAT_MSG_RAID_LEADER = "raid",
  CHAT_MSG_RAID_WARNING = "warn", CHAT_MSG_INSTANCE_CHAT = "party", CHAT_MSG_INSTANCE_CHAT_LEADER = "party",
  CHAT_MSG_WHISPER = "whisper", CHAT_MSG_WHISPER_INFORM = "whisper", CHAT_MSG_BN_WHISPER = "whisper", CHAT_MSG_BN_WHISPER_INFORM = "whisper",
  CHAT_MSG_SAY = "say", CHAT_MSG_YELL = "yell", CHAT_MSG_GUILD = "guild", CHAT_MSG_OFFICER = "guild", CHAT_MSG_CHANNEL = "channel" }
-- 대화창 설정 '가운데' 칸 종류 (파티·공대·인던·길드·귓말·일반·채널)
local CKEY = { CHAT_MSG_PARTY = "party", CHAT_MSG_PARTY_LEADER = "party", CHAT_MSG_RAID = "raid", CHAT_MSG_RAID_LEADER = "raid", CHAT_MSG_RAID_WARNING = "raid",
  CHAT_MSG_INSTANCE_CHAT = "inst", CHAT_MSG_INSTANCE_CHAT_LEADER = "inst", CHAT_MSG_WHISPER = "whisper", CHAT_MSG_WHISPER_INFORM = "whisper",
  CHAT_MSG_BN_WHISPER = "whisper", CHAT_MSG_BN_WHISPER_INFORM = "whisper", CHAT_MSG_SAY = "say", CHAT_MSG_YELL = "say",
  CHAT_MSG_GUILD = "guild", CHAT_MSG_OFFICER = "guild", CHAT_MSG_CHANNEL = "channel" }
local ev = CreateFrame("Frame")
for e in pairs(KIND) do pcall(ev.RegisterEvent, ev, e) end
ev:RegisterEvent("PLAYER_ENTERING_WORLD") ev:RegisterEvent("UI_SCALE_CHANGED")
ev:SetScript("OnEvent", function(_, e, msg, sender, ...)
  if e == "PLAYER_ENTERING_WORLD" or e == "UI_SCALE_CHANGED" then
    noUserPlaced() place() editLook()
    C_Timer.After(2, function() noUserPlaced() place() end) -- 게임이 예전 기억 위치로 옮겨 놓아도 2초 뒤 우리 저장 위치로
    return
  end
  if secret(msg) or secret(sender) then return end
  if not NT.feedEnabled() and not test then return end -- (2026-11-13) 파티글 꺼짐
  if NT.centerOn then if not NT.centerOn(CKEY[e]) then return end
  elseif not (CKEY[e] == "party" or CKEY[e] == "raid" or CKEY[e] == "inst" or CKEY[e] == "whisper") then return end
  if CKEY[e] == "channel" and NT.centerChOn and not NT.centerChOn(select(2, ...)) then return end -- (2026-11-09 대표) 채널은 하나씩 따로 (대화창 톱니에서 끈 채널은 안 띄움)
  local guid = select(10, ...)
  if (KIND[e] == "whisper" or KIND[e] == "say" or KIND[e] == "yell" or KIND[e] == "guild" or KIND[e] == "channel") and type(guid) ~= "string" then guid = nil end
  if secret(guid) then guid = nil end
  pcall(push, sender, msg, guid, KIND[e], e == "CHAT_MSG_WHISPER_INFORM" or e == "CHAT_MSG_BN_WHISPER_INFORM", e == "CHAT_MSG_BN_WHISPER" or e == "CHAT_MSG_BN_WHISPER_INFORM")
end)
-- 테스트: 가짜 파티 대화가 1~2초마다 (다시 /파티글 = 끔 · 리로드하면 꺼짐)
local FAKE = {
  { "Thrall", "SHAMAN", "토템 깔았어요" }, { "Jaina", "MAGE", "물 필요하신 분?" },
  { "Uther", "PALADIN", "다들 준비됐나요? 풀링 갑니다" }, { "Gul'dan", "WARLOCK", "잠깐만요 영석 하나 만들게요" },
  { "Malfurion", "DRUID", "가시 걸어드릴게요" }, { "Uther", "PALADIN", "오른쪽 몹부터 잡을게요" },
  { "Jaina", "MAGE", "양 걸었어요 건드리지 마세요 ㅎㅎ" }, { "Gul'dan", "WARLOCK", "ㄱㄱ" },
  { "Jaina", "MAGE", "귓) 물 몇 개 드릴까요?", true },
}
local tk, n, burst, burstMax = nil, 0, 0, nil
SLASH_NTPARTYFEED1 = "/파티글"
SlashCmdList.NTPARTYFEED = function()
  test = not test
  if tk then tk:Cancel() tk = nil end
  cdb().lock = not test -- 테스트 켜면 잠금 풀림(옮기기) · 끄면 잠김
  if test then
    place()
    local FAKE_EN = { "ready? pulling next pack", "brb 1 min, need to drink", "can someone mark skull pls", "nice run guys, ty!", "oom, wait for mana pls" }
    local function one()
      if not test then return end
      n = n % #FAKE + 1
      local f = FAKE[n]
      if trActive() then -- 번역 켜짐: 영어 가짜 대화를 번역 프로그램 쪽 줄로 (번역돼서 보이는지 확인)
        local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[f[2]]
        local hex = c and string.format("%02x%02x%02x", math.floor(c.r * 255), math.floor(c.g * 255), math.floor(c.b * 255)) or ""
        trDing(false)
        pcall(NT.push, "C", f[4] and "WHISPER" or "PARTY", "", "", f[1], hex, "aad4ff", f[4] and "how many waters do you need?" or FAKE_EN[(n - 1) % #FAKE_EN + 1], 0, 1, 0)
        burst = (burst or 0) + 1 burstMax = burstMax or math.random(2, 4)
        local wait = 0.8 + math.random() * 1.4
        if burst >= burstMax then burst, burstMax, wait = 0, nil, LIFE + FADE_OUT + 2.5 end
        tk = C_Timer.NewTimer(wait, one)
        return
      end
      ding(false)
      local l = newLine()
      local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[f[2]]
      l:SetText(string.format("|cff%02x%02x%02x%s|r  " .. (f[4] and "|cffff80ff" or "|cffaad4ff") .. "%s|r", math.floor(c and c.r * 255 or 255), math.floor(c and c.g * 255 or 210), math.floor(c and c.b * 255 or 120), f[1], (f[3]:gsub("^귓%) ", ""))))
      l.t, l.y = 0, nil
      lines[#lines + 1] = l
      if l.nb then l.nb:Hide() l.nb.who = nil end
      if f[4] then pcall(nameButton, l, f[1], f[1], "") end -- 테스트 귓말도 이름 누르기 확인
      trim()
      -- 2~4줄씩 대화가 오고 쉼 → 줄이 다 사라졌다가 다시 올라오며 알림음도 확인
      burst = (burst or 0) + 1
      burstMax = burstMax or math.random(2, 4)
      local wait = 0.8 + math.random() * 1.4
      if burst >= burstMax then burst, burstMax, wait = 0, nil, LIFE + FADE_OUT + 2.5 end
      tk = C_Timer.NewTimer(wait, one)
    end
    one()
  end
  editLook()
  print("|cffffd100[파티 대화]|r 테스트 " .. (test and "켬 — 가짜 대화가 계속 떠요 · 끌어서 위치 잡기 · 다시 /파티글 = 끔" or "끔"))
end
-- 대화창 설정 '파티글 옮기기' · /ntchat partymove: 누르면 잠금 풀림/잠김 (돌려주는 값 = 지금 풀림)
function NT.feedMove()
  cdb().lock = not cdb().lock
  place() editLook()
  return not cdb().lock
end
function NT.feedMoving() return not cdb().lock end
-- 저장값은 접속 때 읽힘 (PLAYER_ENTERING_WORLD) · 그 전엔 기본 자리
feed:SetScale(UIParent:GetEffectiveScale())
feed:SetPoint("BOTTOM", WorldFrame, "CENTER", 0, 70 / feed:GetEffectiveScale())
feed:EnableMouse(false)
