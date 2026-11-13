-- 낭만타우렌 번역기 · 대화창
-- 블리자드 채팅창 대신: 테 없는 반투명 어두운 판 · 위 탭 띠(전체·파티·길드·귓말 · 구리색 밑줄 · 새 글 = 주황 점) · 아래 입력줄 띠 · 톱니 = 설정
-- 메시지는 블리자드 기본 채팅창(ChatFrame1)에 들어오는 줄을 그대로 받아서 보여 줌 (링크·직업 색 그대로)
-- 끌기 = 이동 · Ctrl+끌기 / 오른쪽 아래 모서리 = 크기 · Ctrl+오른쪽 클릭 = 위치 잠금/풀기 · 휠 = 위아래 · Shift+휠 = 맨 위/맨 아래
local NT = NangmanTr
if not NT or NT.inert then return end

local FACE = STANDARD_TEXT_FONT or "Fonts\\2002.TTF"
local GOLD = { 0.96, 0.82, 0.48 }
local MEDIA = NT.MEDIA
local secret = NT.secret

-- ===== 인터넷 주소: 대화에 나온 주소를 파란 글씨로 · 누르면 복사 창 =====
do
  local urlBox
  local function showURL(url)
    if not urlBox then
      local f = CreateFrame("Frame", "NangmanTrURLCopy", UIParent)
      f:SetSize(420, 76) f:SetPoint("CENTER") f:SetFrameStrata("DIALOG") f:SetClampedToScreen(true)
      f:EnableMouse(true) f:SetMovable(true) f:RegisterForDrag("LeftButton")
      f:SetScript("OnDragStart", f.StartMoving) f:SetScript("OnDragStop", f.StopMovingOrSizing)
      local bg = f:CreateTexture(nil, "BACKGROUND") bg:SetAllPoints() bg:SetColorTexture(0.067, 0.072, 0.082, 0.95)
      for _, p in ipairs({ "TOP", "BOTTOM" }) do
        local l = f:CreateTexture(nil, "BORDER") l:SetHeight(1) l:SetPoint(p .. "LEFT") l:SetPoint(p .. "RIGHT") l:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.85)
      end
      local t = f:CreateFontString(nil, "OVERLAY") t:SetFont(FACE, 13, "") t:SetPoint("TOPLEFT", 12, -10) t:SetTextColor(GOLD[1], GOLD[2], GOLD[3]) t:SetText("주소 복사  (Ctrl+C 누른 뒤 Esc)")
      local x = CreateFrame("Button", nil, f, "UIPanelCloseButton") x:SetPoint("TOPRIGHT", 2, 2)
      tinsert(UISpecialFrames, "NangmanTrURLCopy")
      f:Hide()
      urlBox = f
      local e = CreateFrame("EditBox", nil, urlBox, "InputBoxTemplate")
      e:SetSize(390, 22) e:SetPoint("BOTTOM", 0, 14) e:SetAutoFocus(true)
      e:SetScript("OnEscapePressed", function() urlBox:Hide() end)
      e:SetScript("OnTextChanged", function(self, user) if user then self:SetText(urlBox.url) self:HighlightText() end end)
      urlBox.edit = e
    end
    urlBox.url = url
    urlBox:Show()
    urlBox.edit:SetText(url) urlBox.edit:SetFocus() urlBox.edit:HighlightText()
  end
  if LinkUtil and LinkUtil.RegisterLinkHandler then
    pcall(LinkUtil.RegisterLinkHandler, "nturl", function(link)
      local url = link:match("^nturl:(.+)$")
      if url then showURL(url) end
      return LinkProcessorResponse and LinkProcessorResponse.Handled
    end)
  end
  -- 띄어쓰기로 나눈 낱말 중 주소로 시작하는 것만 (이미 링크·색 코드가 든 낱말은 건드리지 않음)
  local function linkify(msg)
    return (msg:gsub("%S+", function(w)
      if w:find("|", 1, true) then return w end
      local u = w:match("^(https?://[^%s]+)") or w:match("^(www%.[%w%-]+%.[^%s]+)")
      if not u then return w end
      local tail = ""
      while u:find("[%.,!%?%)]$") do tail = u:sub(-1) .. tail u = u:sub(1, -2) end
      return "|cff66bbff|Hnturl:" .. u .. "|h[" .. u .. "]|h|r" .. tail
    end))
  end
  local EVENTS = { "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER", "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER",
    "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER", "CHAT_MSG_RAID_WARNING", "CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_INSTANCE_CHAT_LEADER",
    "CHAT_MSG_WHISPER", "CHAT_MSG_WHISPER_INFORM", "CHAT_MSG_BN_WHISPER", "CHAT_MSG_BN_WHISPER_INFORM", "CHAT_MSG_CHANNEL", "CHAT_MSG_SYSTEM" }
  local addFilter = (ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter) or ChatFrame_AddMessageEventFilter
  local function urlFilter(_, _, msg, ...)
    if type(msg) ~= "string" or secret(msg) then return false end
    if not (msg:find("://", 1, true) or msg:find("www.", 1, true)) then return false end
    local ok, out = pcall(linkify, msg)
    if ok and out ~= msg then return false, out, ... end
    return false
  end
  if addFilter and LinkUtil and LinkUtil.RegisterLinkHandler then for _, e in ipairs(EVENTS) do pcall(addFilter, e, urlFilter) end end
end

-- ===== 대화창 =====
do
  local function cfg()
    local d = NT.db()
    local c = d.chatUI
    if type(c) ~= "table" then c = {} d.chatUI = c end
    if c.font == nil then c.font = 12 end
    if c.bg == nil then c.bg = 0.2 end
    if c.fade == nil then c.fade = 60 end
    if c.cfont == nil then c.cfont = 13 end -- 화면 가운데 파티글 글자 크기
    -- 화면 가운데 파티글에도 띄울 글 종류 (탭과 상관없이 하나) · 처음 = 전부 켜짐
    if type(c.center) ~= "table" then c.center = { say = true, party = true, raid = true, inst = true, guild = true, whisper = true, channel = true } end
    return c
  end
  NT.chatCfg = cfg
  -- 가운데 파티글·번역 프로그램이 묻는 곳
  local CENTER_KEYS = { say = "s", party = "p", raid = "r", inst = "i", guild = "g", whisper = "w", channel = "c" }
  function NT.centerFont() return cfg().cfont or 13 end
  function NT.centerOn(k) local c = cfg().center return k and c[k] and true or false end
  function NT.centerMask()
    local c, t = cfg().center, {}
    for _, k in ipairs({ "say", "party", "raid", "inst", "guild", "whisper", "channel" }) do if c[k] then t[#t + 1] = CENTER_KEYS[k] end end
    return table.concat(t)
  end
  local function feedChanged() if NT.feedRefresh then pcall(NT.feedRefresh) end if NT.feedNow then NT.feedNow() end end
  local P -- 패널
  local frames, active = {}, "all"
  local medals = {}
  local TABS = {
    { key = "all", name = "전체" },
    { key = "party", name = "파티 · 공대 · 인던" },
    { key = "guild", name = "길드" },
    { key = "whisper", name = "귓말" },
  }
  -- 글 종류 묶음 (탭마다 체크로 고름) · 색으로 종류를 알아냄
  local GROUPS = {
    { k = "say", n = "일반 대화 · 외침 · 감정", t = { "SAY", "YELL", "EMOTE", "TEXT_EMOTE" } },
    { k = "party", n = "파티", t = { "PARTY", "PARTY_LEADER" } },
    { k = "raid", n = "공격대", t = { "RAID", "RAID_LEADER", "RAID_WARNING" } },
    { k = "inst", n = "인던 대화", t = { "INSTANCE_CHAT", "INSTANCE_CHAT_LEADER" } },
    { k = "guild", n = "길드 · 관리자", t = { "GUILD", "OFFICER", "GUILD_ACHIEVEMENT" } },
    { k = "whisper", n = "귓말", t = { "WHISPER", "WHISPER_INFORM", "BN_WHISPER", "BN_WHISPER_INFORM" } },
    { k = "channel", n = "채널 (공개 · 거래 등)", t = { "CHANNEL", "CHANNEL1", "CHANNEL2", "CHANNEL3", "CHANNEL4", "CHANNEL5", "CHANNEL6", "CHANNEL7", "CHANNEL8", "CHANNEL9", "CHANNEL10" } },
    { k = "loot", n = "전리품 · 돈", t = { "LOOT", "MONEY", "CURRENCY" } },
    { k = "xp", n = "경험치 · 평판 · 숙련도", t = { "COMBAT_XP_GAIN", "COMBAT_FACTION_CHANGE", "COMBAT_HONOR_GAIN", "SKILL" } },
    { k = "npc", n = "몬스터 · NPC 대사", t = { "MONSTER_SAY", "MONSTER_YELL", "MONSTER_EMOTE", "MONSTER_WHISPER", "RAID_BOSS_EMOTE", "RAID_BOSS_WHISPER" } },
    { k = "system", n = "시스템 알림", t = { "SYSTEM" } },
    { k = "other", n = "그 밖 (애드온 알림 등)", t = {} },
  }
  -- (2026-11-09 대표) 번역 대화창(PC 번역기)과 탭·보일 대화 설정을 하나로: 같은 탭(만든 탭 포함) · 같은 칸 이름 · 같은 규칙
  --  어느 쪽에서 바꾸든 마지막에 바꾼 쪽이 이김 (게임 → PC = 신호 줄 'T' · PC → 게임 = '/fkchat tabs') · 계정 공통 저장
  local TK = { "party", "raid", "inst", "whisper", "guild", "say", "lfg", "general", "trade", "otherch", "sys", "loot", "xp", "npc" }
  local TDEF = {
    all = { party = true, raid = true, inst = true, whisper = true, guild = true, say = true, lfg = true, general = true, trade = true, otherch = true, sys = true, loot = true, xp = true, npc = true },
    party = { party = true, raid = true, inst = true },
    guild = { guild = true },
    whisper = { whisper = true },
  }
  local CHFIX = {
    { k = "ch:general", n = "공개", m = { "^general", "^공개" } },
    { k = "ch:trade", n = "거래", m = { "^trade", "^거래" } },
    { k = "ch:localdefense", n = "수비", m = { "^localdefense", "^수비", "^지역 ?방어" } },
    { k = "ch:lookingforgroup", n = "파티찾기", m = { "^lookingforgroup", "^lfg", "^파티 ?찾기" } },
    { k = "ch:worlddefense", n = "세계수비", m = { "^worlddefense", "^세계 ?방어", "^세계 ?수비" } },
  }
  local CHOLD = { ["ch:general"] = "general", ["ch:trade"] = "trade", ["ch:localdefense"] = "general", ["ch:lookingforgroup"] = "lfg", ["ch:worlddefense"] = "general" }
  local function TS()
    local d = NT.db()
    local t = d.chatTabs
    if type(t) ~= "table" then t = { ver = 0, ctabs = {}, tabf = {} } d.chatTabs = t end
    if type(t.ctabs) ~= "table" then t.ctabs = {} end
    if type(t.tabf) ~= "table" then t.tabf = {} end
    t.ver = tonumber(t.ver) or 0
    return t
  end
  local function filt(tab)
    local t = TS()
    if type(t.tabf[tab]) ~= "table" then
      local d = TDEF[tab] or (tostring(tab):match("^c%d+$") and {} or TDEF.all)
      local h = {} for _, k in ipairs(TK) do h[k] = d[k] and true or false end
      t.tabf[tab] = h
    end
    return t.tabf[tab]
  end
  -- 이 탭에서 이 칸을 볼지 (따로 안 고른 채널 = 예전 묶음 칸을 따름 · 처음 보는 개인 채널 = '그 밖 채널')
  local function tabOn(f, key, tab)
    if f[key] ~= nil then return f[key] and true or false end
    if key:sub(1, 3) == "ch:" then local o = CHOLD[key] or "otherch" return f[o] and true or false end
    local d = TDEF[tab] or (tostring(tab):match("^c%d+$") and {} or TDEF.all)
    return d[key] and true or false
  end
  local SYS_WORDS = { "게임에 접속했습니다", "게임을 종료했습니다", "길드를 탈퇴했습니다", "길드에 가입했습니다", "길드에서 추방", "has come online", "has gone offline", "has joined the guild", "has left the guild" }
  local function groupOf(r, g, b)
    if not ChatTypeInfo then return "other" end
    for _, gr in ipairs(GROUPS) do
      for _, k in ipairs(gr.t) do
        local i = ChatTypeInfo[k]
        if i and math.abs((i.r or -1) - (r or -2)) < 0.004 and math.abs((i.g or -1) - (g or -2)) < 0.004 and math.abs((i.b or -1) - (b or -2)) < 0.004 then return gr.k end
      end
    end
    return "other"
  end
  local hist = {} -- 최근 글 (탭 설정을 바꾸면 다시 채우기용)
  -- (2026-11-09) 채널 글은 글 앞의 [번호. 채널이름] 링크로 알아냄 · 칸 이름은 PC 번역기와 같은 규칙 (ch:general · ch:trade · … · ch:개인채널)
  local chanSeen = {} -- [칸 이름] = { n = 번호, name = 보일 이름 }
  local function chBase(nm)
    if type(nm) ~= "string" then return end
    nm = nm:gsub("^%s*%d+%.%s*", "")
    nm = nm:match("^(.-) %- ") or nm
    nm = nm:gsub("^%s+", ""):gsub("%s+$", ""):gsub("%s+%d+$", "")
    if nm == "" then return end
    return nm
  end
  -- (2026-11-09 대표) 가운데 파티글: 채널을 하나씩 따로 끄고 켬 · 끈 채널 목록 = cfg().cenChOff ('공개,거래' · PC 번역창 톱니의 채널 칩과 같은 설정)
  local function chOffList() local t = {} for b in tostring(cfg().cenChOff or ""):gmatch("[^,]+") do t[#t + 1] = b end return t end
  local function centerChOn(nm)
    local b = chBase(nm) if not b then return true end
    for _, x in ipairs(chOffList()) do if x == b then return false end end
    return true
  end
  NT.centerChOn = centerChOn
  local function pushChOff() if NT.push then pcall(NT.push, "O", cfg().cenChOff or "") end end
  local function joinedBases()
    local t = {}
    if GetChannelList then
      local l = { GetChannelList() }
      for i = 1, #l, 3 do local b = chBase(l[i + 1]) if b then t[#t + 1] = { n = l[i], b = b } end end
    end
    return t
  end
  local function toggleChOff(base)
    local c = cfg()
    if not c.center.channel then
      -- '채널'이 꺼져 있으면: 이 채널만 켠 채로 채널 켜기
      local offs = {}
      for _, j in ipairs(joinedBases()) do if j.b ~= base then offs[#offs + 1] = j.b end end
      c.cenChOff = table.concat(offs, ",") c.center.channel = true
    else
      local t, found = {}, false
      for _, x in ipairs(chOffList()) do if x == base then found = true else t[#t + 1] = x end end
      if not found then t[#t + 1] = base end
      c.cenChOff = table.concat(t, ",")
    end
    pushChOff()
  end
  local function chKey(base)
    local b = base:lower()
    for _, c in ipairs(CHFIX) do for _, p in ipairs(c.m) do if b:find(p) then return c.k end end end
    return "ch:" .. b
  end
  local function noteChan(id, nm, prefer)
    local b = chBase(nm) if not b then return end
    local k = chKey(b)
    local cur = chanSeen[k]
    if not cur or prefer then chanSeen[k] = { n = tonumber(id) or (cur and cur.n), name = b } end
    return k
  end
  local function chanOf(text)
    if type(text) ~= "string" or secret(text) then return end
    local id, nm = text:match("|Hchannel:[^|]*|h%[(%d+)%.%s*([^%]]-)%]|h")
    if not nm then return end
    return noteChan(id, nm)
  end
  local G2K = { say = "say", party = "party", raid = "raid", inst = "inst", guild = "guild", whisper = "whisper", system = "sys", other = "sys", loot = "loot", xp = "xp", npc = "npc", channel = "otherch" }
  -- 탭 동기화 글자 (PC 번역기와 같은 약속)
  local CODE = { party = "p", raid = "r", inst = "i", whisper = "w", guild = "g", say = "s", lfg = "l", general = "n", trade = "t", otherch = "o", sys = "y", loot = "b", xp = "x", npc = "m",
    ["ch:general"] = "G", ["ch:trade"] = "T", ["ch:localdefense"] = "D", ["ch:lookingforgroup"] = "L", ["ch:worlddefense"] = "W" }
  local UNCODE = {} for k, v in pairs(CODE) do UNCODE[v] = k end
  local function tclean(s) return (tostring(s or ""):gsub("%s", "_"):gsub("[/~,=#;%+%-|]", "")) end
  local function packTabs()
    local t = TS()
    local cs = {}
    for _, c in ipairs(t.ctabs) do cs[#cs + 1] = c.key .. "~" .. tclean(c.label) .. "~" .. (c.auto and "1" or "0") end
    local segs = { "C=" .. table.concat(cs, ",") }
    local keys = {} for k in pairs(t.tabf) do keys[#keys + 1] = k end table.sort(keys)
    for _, tk in ipairs(keys) do
      local f, e = t.tabf[tk], {}
      local fk = {} for k in pairs(f) do fk[#fk + 1] = k end table.sort(fk)
      for _, k in ipairs(fk) do
        local sg = f[k] and "+" or "-"
        if CODE[k] then e[#e + 1] = sg .. CODE[k]
        elseif k:sub(1, 3) == "ch:" then e[#e + 1] = sg .. "#" .. tclean(k:sub(4)) .. ";" end
      end
      segs[#segs + 1] = tclean(tk) .. "=" .. table.concat(e)
    end
    return table.concat(segs, "/")
  end
  local function unpackTabs(s)
    local ct, tf = {}, {}
    for seg in (s .. "/"):gmatch("([^/]*)/") do
      local k, v = seg:match("^([^=]+)=(.*)$")
      if k == "C" then
        for item in v:gmatch("[^,]+") do
          local key, lab, au = item:match("^(c%d+)~([^~]*)~([01])$")
          if key then ct[#ct + 1] = { key = key, label = (lab:gsub("_", " ")), auto = (au == "1") } end
        end
      elseif k then
        local f, i = {}, 1
        while i <= #v do
          local on = v:sub(i, i) == "+"
          i = i + 1
          local c = v:sub(i, i)
          if c == "" then break end
          if c == "#" then
            local j = v:find(";", i, true) or (#v + 1)
            f["ch:" .. (v:sub(i + 1, j - 1):gsub("_", " "))] = on
            i = j + 1
          else
            if UNCODE[c] then f[UNCODE[c]] = on end
            i = i + 1
          end
        end
        tf[k] = f
      end
    end
    return ct, tf
  end
  local function pushTabs()
    if NT.push then pcall(NT.push, "T", TS().ver, packTabs()) end
    pushChOff() -- (2026-11-09) 가운데 파티글 채널별 끄기도 같이 알림
  end
  local afterTabsChanged, allTabs -- 아래 (탭 다시 그리기 · 탭 목록)
  local function bumpTabs()
    local t = TS()
    local now = time and time() or 0
    if (t.ver or 0) > now + 60 then t.ver = now end -- (2026-11-09) 번호가 미래로 너무 앞서 있으면 바로잡음 (내 쪽 변경이 계속 지던 것)
    t.ver = math.max((t.ver or 0) + 1, now)
    pushTabs()
  end
  local tabsBuf = {}
  local function tabsIn(v, i, n, chunk)
    if not v or not i or not n or n < 1 or n > 40 then return end
    local b = tabsBuf[v] if not b then b = { n = n, got = 0, p = {} } tabsBuf[v] = b end
    if not b.p[i] then b.got = b.got + 1 end
    b.p[i] = chunk
    if b.got < b.n then return end
    tabsBuf[v] = nil
    local s = table.concat(b.p, "", 1, b.n)
    local t = TS()
    if v > t.ver then
      local ct, tf = unpackTabs(s)
      t.ctabs, t.tabf, t.ver = ct, tf, v
      if afterTabsChanged then pcall(afterTabsChanged) end
    elseif v < t.ver then
      pushTabs()
    end
  end
  NT.tabsPush = function() pushTabs() end -- 번역 켤 때 · 접속할 때 PC에 지금 설정을 알림
  do local ef = CreateFrame("Frame") ef:RegisterEvent("PLAYER_ENTERING_WORLD") ef:SetScript("OnEvent", function() C_Timer.After(6, pushTabs) end) end
  local function shows(f, key, tab) return tabOn(f, key, tab) end

  local COPPER = { 0.725, 0.557, 0.373 } -- #b98e5f (켜진 탭 밑줄 · 체크 · 작은 버튼)
  local HITXT = { 0.89, 0.765, 0.604 } -- #e3c39a (강조 값 글씨)
  local MUTED = 0.541 -- #8a8a8a (흐린 글씨)
  local OFFTXT = 0.639 -- #a3a3a3 (꺼진 탭 글씨)
  local HEADTXT = 0.902 -- #e6e6e6 (머리줄 글씨)
  local DOT = { 0.914, 0.635, 0.231 } -- #e9a23b (새 글 알림 점)
  local R_ALL, R_TOP, R_BOT = { tl = true, tr = true, bl = true, br = true }, { tl = true, tr = true }, { bl = true, br = true }
  local DISC = MEDIA .. "hb_disc" -- 흰 원판 (모서리 둥글게 · 점)
  -- 납작한 판 9칸 (모서리만 둥근 원판 그림 1/4 · 나머지는 색 판) · 칸끼리 서로 붙여 놓아 겹침·틈 없음
  local function plate(f, layer, r, round, a)
    a, round = a or f, round or {}
    local t = {}
    local function piece(tc)
      local x = f:CreateTexture(nil, layer)
      if tc then x:SetTexture(DISC, "CLAMP", "CLAMP", "TRILINEAR") x:SetTexCoord(unpack(tc)) else x:SetColorTexture(1, 1, 1, 1) end
      t[#t + 1] = x
      return x
    end
    local tl, tr = piece(round.tl and { 0, 0.5, 0, 0.5 }), piece(round.tr and { 0.5, 1, 0, 0.5 })
    local bl, br = piece(round.bl and { 0, 0.5, 0.5, 1 }), piece(round.br and { 0.5, 1, 0.5, 1 })
    for _, x in ipairs({ tl, tr, bl, br }) do x:SetSize(r, r) end
    tl:SetPoint("TOPLEFT", a, "TOPLEFT") tr:SetPoint("TOPRIGHT", a, "TOPRIGHT") bl:SetPoint("BOTTOMLEFT", a, "BOTTOMLEFT") br:SetPoint("BOTTOMRIGHT", a, "BOTTOMRIGHT")
    local tp, bt, lf, rt, md = piece(), piece(), piece(), piece(), piece()
    tp:SetPoint("TOPLEFT", tl, "TOPRIGHT") tp:SetPoint("BOTTOMRIGHT", tr, "BOTTOMLEFT")
    bt:SetPoint("TOPLEFT", bl, "TOPRIGHT") bt:SetPoint("BOTTOMRIGHT", br, "BOTTOMLEFT")
    lf:SetPoint("TOPLEFT", tl, "BOTTOMLEFT") lf:SetPoint("BOTTOMRIGHT", bl, "TOPRIGHT")
    rt:SetPoint("TOPLEFT", tr, "BOTTOMLEFT") rt:SetPoint("BOTTOMRIGHT", br, "TOPRIGHT")
    md:SetPoint("TOPLEFT", tl, "BOTTOMRIGHT") md:SetPoint("BOTTOMRIGHT", br, "TOPLEFT")
    return t
  end
  NT.plate = plate
  -- 위쪽 밝은 띠 · 입력줄 띠 · 설정 머리줄 (흰색 아주 옅게)
  local function strip(parent, h, where, alpha, round)
    local s = CreateFrame("Frame", nil, parent)
    if where == "TOP" then s:SetPoint("TOPLEFT") s:SetPoint("TOPRIGHT") else s:SetPoint("BOTTOMLEFT") s:SetPoint("BOTTOMRIGHT") end
    s:SetHeight(h)
    for _, t in ipairs(plate(s, "BACKGROUND", 4, round)) do t:SetVertexColor(1, 1, 1, alpha) end
    return s
  end
  -- 글자 탭 · 켜짐 = 흰 글씨 + 옅은 흰 바탕 + 아래 구리색 2px 줄 · 새 글 = 이름 옆 주황 점
  local function flatTab(parent, label)
    local b = CreateFrame("Button", nil, parent)
    b.t = b:CreateFontString(nil, "OVERLAY") b.t:SetFont(STANDARD_TEXT_FONT, 12.5, "") b.t:SetPoint("LEFT", 12, 0)
    b.t:SetShadowColor(0, 0, 0, 0.8) b.t:SetShadowOffset(1, -1)
    b.t:SetText(label or "") b.t:SetTextColor(OFFTXT, OFFTXT, OFFTXT)
    b:SetSize(math.floor((b.t:GetStringWidth() or 24) + 26.5), 24)
    b.disc = b:CreateTexture(nil, "BACKGROUND") b.disc:SetAllPoints() b.disc:SetColorTexture(1, 1, 1, 0.09) b.disc:Hide()
    b.hl = b:CreateTexture(nil, "HIGHLIGHT") b.hl:SetAllPoints() b.hl:SetColorTexture(1, 1, 1, 0.04)
    b.under = b:CreateTexture(nil, "ARTWORK") b.under:SetColorTexture(COPPER[1], COPPER[2], COPPER[3], 1) b.under:SetHeight(2)
    b.under:SetPoint("BOTTOMLEFT") b.under:SetPoint("BOTTOMRIGHT") b.under:Hide()
    b.glow = b:CreateTexture(nil, "OVERLAY") b.glow:SetTexture(DISC, "CLAMP", "CLAMP", "TRILINEAR") b.glow:SetSize(6, 6)
    b.glow:SetPoint("LEFT", b.t, "RIGHT", 5, 0) b.glow:SetVertexColor(DOT[1], DOT[2], DOT[3], 1) b.glow:Hide()
    return b
  end
  -- 체크 칸 · 켜짐 = 구리색 찬 네모 + 어두운 체크 · 꺼짐 = 어두운 네모 + 옅은 흰 테
  local function flatBox(owner)
    local o = {}
    o.fill = owner:CreateTexture(nil, "ARTWORK") o.fill:SetSize(14, 14) o.fill:SetColorTexture(1, 1, 1, 1)
    o.edges = {}
    for _, e in ipairs({ { "TOPLEFT", "TOPRIGHT", 0, 1 }, { "BOTTOMLEFT", "BOTTOMRIGHT", 0, 1 }, { "TOPLEFT", "BOTTOMLEFT", 1, 0 }, { "TOPRIGHT", "BOTTOMRIGHT", 1, 0 } }) do
      local l = owner:CreateTexture(nil, "OVERLAY") l:SetColorTexture(1, 1, 1, 1) l:SetPoint(e[1], o.fill, e[1]) l:SetPoint(e[2], o.fill, e[2])
      if e[3] == 1 then l:SetWidth(1) else l:SetHeight(1) end
      o.edges[#o.edges + 1] = l
    end
    o.chk = owner:CreateTexture(nil, "OVERLAY", nil, 2) o.chk:SetTexture("Interface\\Buttons\\UI-CheckBox-Check") o.chk:SetSize(18, 18) o.chk:SetPoint("CENTER", o.fill, "CENTER", 1, 1)
    o.chk:SetVertexColor(0.08, 0.07, 0.06, 1)
    o.set = function(on)
      if on then
        o.fill:SetVertexColor(COPPER[1], COPPER[2], COPPER[3], 1)
        for _, l in ipairs(o.edges) do l:SetVertexColor(COPPER[1], COPPER[2], COPPER[3], 1) end
      else
        o.fill:SetVertexColor(0.04, 0.04, 0.045, 0.9)
        for _, l in ipairs(o.edges) do l:SetVertexColor(1, 1, 1, 0.18) end
      end
      o.chk:SetShown(on and true or false)
    end
    o.set(false)
    return o
  end
  -- 작은 둥근 −/+ 버튼
  local function roundBtn(parent, D, plus)
    local b = CreateFrame("Button", nil, parent) b:SetSize(D, D)
    b.disc = b:CreateTexture(nil, "ARTWORK") b.disc:SetTexture(DISC, "CLAMP", "CLAMP", "TRILINEAR") b.disc:SetAllPoints() b.disc:SetVertexColor(COPPER[1], COPPER[2], COPPER[3], 0.3)
    local hl = b:CreateTexture(nil, "HIGHLIGHT") hl:SetTexture(DISC, "CLAMP", "CLAMP", "TRILINEAR") hl:SetAllPoints() hl:SetVertexColor(COPPER[1], COPPER[2], COPPER[3], 0.3)
    local function bar(w, h)
      local t = b:CreateTexture(nil, "OVERLAY", nil, 3)
      t:SetColorTexture(HITXT[1], HITXT[2], HITXT[3], 1) t:SetSize(w, h) t:SetPoint("CENTER", b, "CENTER", 0, 0)
      if t.SetSnapToPixelGrid then t:SetSnapToPixelGrid(true) end
      return t
    end
    bar(8, 2)
    if plus then bar(2, 8) end
    return b
  end
  -- 납작한 글자 버튼
  local function flatBtn(parent, w, h, label)
    local b = CreateFrame("Button", nil, parent) b:SetSize(w, h)
    for _, t in ipairs(plate(b, "BACKGROUND", 3, R_ALL)) do t:SetVertexColor(1, 1, 1, 0.06) end
    local hl = b:CreateTexture(nil, "HIGHLIGHT") hl:SetPoint("TOPLEFT", 3, 0) hl:SetPoint("BOTTOMRIGHT", -3, 0) hl:SetColorTexture(1, 1, 1, 0.05)
    b.t = b:CreateFontString(nil, "OVERLAY") b.t:SetFont(STANDARD_TEXT_FONT, 12, "") b.t:SetPoint("CENTER") b.t:SetTextColor(HEADTXT, HEADTXT, HEADTXT) b.t:SetText(label or "")
    return b
  end
  -- 설정 창 판 + 머리줄 · 제목 글씨를 돌려줌
  local function flatPopup(f, titleSize)
    for _, t in ipairs(plate(f, "BACKGROUND", 4, R_ALL)) do t:SetVertexColor(0.086, 0.086, 0.09, 0.93) end
    local head = strip(f, 28, "TOP", 0.05, R_TOP)
    local title = head:CreateFontString(nil, "OVERLAY") title:SetFont(STANDARD_TEXT_FONT, titleSize or 12, "") title:SetPoint("LEFT", 12, 0)
    title:SetTextColor(HEADTXT, HEADTXT, HEADTXT)
    return title, head
  end

  local function fontFile() local f = ChatFontNormal and ChatFontNormal:GetFont() return f or STANDARD_TEXT_FONT end
  function NT.chatFontSize() return cfg().font end
  local function applyFont()
    local c = cfg()
    for _, m in pairs(frames) do
      m:SetFont(fontFile(), c.font, "") m:SetShadowColor(0, 0, 0, 0) m:SetShadowOffset(0, 0)
      if m.SetSpacing then m:SetSpacing(9) end
    end
    local eb = ChatFrame1EditBox
    if eb then pcall(eb.SetFont, eb, fontFile(), math.max(13, c.font), "") end
  end
  local function applyFade()
    local c = cfg()
    for _, m in pairs(frames) do
      if c.fade and c.fade > 0 then m:SetFading(true) m:SetTimeVisible(c.fade) m:SetFadeDuration(2) else m:SetFading(false) end
    end
  end
  local fillTex
  local function applyBg() if fillTex then for _, t in ipairs(fillTex) do t:SetVertexColor(0.067, 0.067, 0.071, cfg().bg) end end end

  local function selTab(key)
    active = key
    for k, m in pairs(frames) do m:SetShown(k == key) end
    for _, md in ipairs(medals) do
      local on = md.key == key
      md.disc:SetShown(on) md.under:SetShown(on)
      if on then md.t:SetTextColor(1, 1, 1) else md.t:SetTextColor(OFFTXT, OFFTXT, OFFTXT) end
      if on then md.unread = nil md.glow:Hide() if md.spin then md.spin:Hide() end end
      md.glow:SetShown(not on and md.unread and true or false)
    end
    frames[key]:ResetAllFadeTimes()
  end
  local function route(text, r, g, b, quiet)
    if not P then return end
    local gk = groupOf(r, g, b)
    local ck = chanOf(text)
    local key = ck or G2K[gk] or "sys"
    -- 접속·접속 종료·길드 가입/탈퇴 알림은 글 색이 달라도 '시스템 알림'으로
    if not ck and key ~= "sys" and type(text) == "string" and not secret(text) then
      for _, w in ipairs(SYS_WORDS) do if text:find(w, 1, true) then key = "sys" break end end
    end
    if not quiet then
      hist[#hist + 1] = { text, r, g, b, key }
      if #hist > 400 then table.remove(hist, 1) end
    end
    for _, tb in ipairs(allTabs and allTabs() or TABS) do
      if shows(filt(tb.key), key, tb.key) and frames[tb.key] then
        pcall(frames[tb.key].AddMessage, frames[tb.key], text, r, g, b)
        if not quiet and tb.key ~= "all" and active ~= tb.key then for _, md in ipairs(medals) do if md.key == tb.key then md.unread = true md.glow:Show() end end end
      end
    end
  end
  -- (2026-11-09 공유판 제보: 업데이트 뒤에도 따로 들어간 채널 글이 기본 대화창에 안 나옴)
  --  채널 대화는 블리자드 1번 대화창을 거치지 않고 게임 신호(CHAT_MSG_CHANNEL)에서 직접 받아 탭에 나눔
  --  1번 대화창에도 들어오면 같은 글 번호(lineID)로 한 번만 보이게 (먼저 온 쪽이 보여 주고 나머지는 건너뜀)
  local chDone = {}
  local function chHook(text)
    if type(text) ~= "string" or secret(text) then return false end
    local id = tonumber(text:match("|Hplayer:[^|]-:(%d+):CHANNEL"))
    if not id then return false end
    if chDone[id] then return true end
    chDone[id] = true
    return false
  end
  local function pk(...) return select("#", ...), { ... } end
  do
    local CE = CreateFrame("Frame") CE:RegisterEvent("CHAT_MSG_CHANNEL")
    CE:SetScript("OnEvent", function(_, e, ...)
      local n, args = pk(...)
      local msg, sender, _, chName, _, _, _, idx, base, _, lineID, guid = ...
      if not P or secret(msg) or secret(sender) or type(sender) ~= "string" then return end
      lineID = tonumber(lineID)
      if lineID and chDone[lineID] then return end
      -- 블리자드 대화창과 똑같이 다른 애드온의 거르기(필터)도 거침
      local getF = ChatFrame_GetMessageEventFilters or (ChatFrameUtil and ChatFrameUtil.GetMessageEventFilters)
      local ok0, fl = pcall(function() return getF and getF(e) end)
      if ok0 and type(fl) == "table" then
        for _, fn in ipairs(fl) do
          local cnt, r = pk(pcall(fn, ChatFrame1, e, unpack(args, 1, n)))
          if r[1] then
            if r[2] then if lineID then chDone[lineID] = true end return end
            if r[3] ~= nil then n = cnt - 2 args = { select(3, unpack(r, 1, cnt)) } end
          end
        end
        msg = args[1]
      end
      if lineID then chDone[lineID] = true end
      idx = tonumber(idx) or tonumber(tostring(chName or ""):match("^(%d+)"))
      local bn = (type(base) == "string" and base ~= "" and base) or chBase(chName) or "?"
      local info = ChatTypeInfo and idx and ChatTypeInfo["CHANNEL" .. idx]
      local r, g, b = 1, 0.75, 0.75
      if info then r, g, b = info.r, info.g, info.b end
      local short = sender:gsub("%-.*", "")
      local nm = short
      if guid and GetPlayerInfoByGUID then
        local ok, _, cls = pcall(GetPlayerInfoByGUID, guid)
        local cc = ok and cls and (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS or {})[cls]
        if cc then nm = "|c" .. (cc.colorStr or "ffffffff") .. short .. "|r" end
      end
      local text = "|Hchannel:channel:" .. (idx or 0) .. "|h[" .. (idx and (idx .. ". ") or "") .. bn .. "]|h |Hplayer:" .. sender .. ":" .. (lineID or 0) .. ":CHANNEL:" .. (idx or 0) .. "|h[" .. nm .. "]|h: " .. tostring(msg or "")
      route(text, r, g, b)
    end)
  end
  -- 탭 하나를 지금 설정대로 다시 채우기
  local function refill(key)
    local m = frames[key] if not m then return end
    m:Clear()
    local f = filt(key)
    for _, h in ipairs(hist) do if shows(f, h[5], key) then pcall(m.AddMessage, m, h[1], h[2], h[3], h[4]) end end
  end
  -- 오른쪽 클릭: 이 탭에 보일 대화 (2026-11-09 대표: PC 번역 대화창과 똑같은 모양·같은 칸 · 바꾸면 양쪽 다 바뀜)
  local rebuildTabs -- 아래 (탭 줄 다시 만들기)
  local fpop
  local CATS1 = { { "party", "파티" }, { "raid", "공격대" }, { "inst", "인던" }, { "whisper", "귓말" }, { "guild", "길드" }, { "say", "일반 · 외침" } }
  local CATS3 = { { "sys", "시스템" }, { "loot", "전리품 · 돈" }, { "xp", "경험치 · 숙련도" }, { "npc", "NPC 대사" } }
  local KCOL = { party = { 0.67, 0.67, 1 }, raid = { 1, 0.5, 0 }, inst = { 0.67, 0.83, 1 }, whisper = { 1, 0.5, 1 }, guild = { 0.25, 1, 0.25 }, say = { 1, 1, 1 },
    sys = { 1, 1, 0 }, loot = { 0, 0.67, 0 }, xp = { 0.43, 0.43, 1 }, npc = { 1, 1, 0.62 } }
  local CHCOL = { 1, 0.75, 0.75 }
  local function tabLabel(k)
    local base = { all = "전체", party = "파티", guild = "길드", whisper = "귓말" }
    if base[k] then return base[k] end
    for _, c in ipairs(TS().ctabs) do if c.key == k then return c.label end end
    return "전체"
  end
  local function isCustom(k) return tostring(k):match("^c%d+$") ~= nil end
  local function popFill() end
  local function setLabel(k, label, auto)
    label = tostring(label or ""):gsub("^%s+", ""):gsub("%s+$", "")
    -- 4글자까지 (한글 3바이트)
    local out, n = "", 0
    for ch in label:gmatch("[%z\1-\127\194-\244][\128-\191]*") do if n >= 4 then break end out = out .. ch n = n + 1 end
    label = out
    if label == "" then label, auto = "새 탭", true end
    for _, c in ipairs(TS().ctabs) do
      if c.key == k and (c.label ~= label or (c.auto and true or false) ~= (auto and true or false)) then c.label, c.auto = label, auto and true or false bumpTabs() if rebuildTabs then rebuildTabs() end end
    end
  end
  local function openFilter(md)
    if not fpop then
      fpop = CreateFrame("Frame", "NangmanTrChatFilter", P)
      fpop:SetSize(450, 300)
      fpop:SetFrameStrata("FULLSCREEN_DIALOG") fpop:SetToplevel(true) fpop:EnableMouse(true) fpop:SetClampedToScreen(true)
      fpop.title = flatPopup(fpop, 13)
      fpop.title:SetText("이 탭에 보일 대화")
      -- 기본 탭 = '전체 탭만' 딱지 · 만든 탭 = 이름 칸 (4글자 · Enter 또는 칸을 벗어나면 저장)
      fpop.chip = fpop:CreateFontString(nil, "OVERLAY") fpop.chip:SetFont(STANDARD_TEXT_FONT, 11, "") fpop.chip:SetTextColor(0.89, 0.76, 0.6)
      fpop.chip:SetPoint("LEFT", fpop.title, "RIGHT", 10, 0)
      fpop.chipBg = fpop:CreateTexture(nil, "ARTWORK") fpop.chipBg:SetColorTexture(COPPER[1], COPPER[2], COPPER[3], 0.18)
      fpop.chipBg:SetPoint("TOPLEFT", fpop.chip, "TOPLEFT", -7, 3) fpop.chipBg:SetPoint("BOTTOMRIGHT", fpop.chip, "BOTTOMRIGHT", 7, -3)
      local nb = CreateFrame("EditBox", nil, fpop) nb:SetSize(70, 20) nb:SetPoint("LEFT", fpop.title, "RIGHT", 12, 0)
      nb:SetFont(STANDARD_TEXT_FONT, 12, "") nb:SetTextColor(1, 0.91, 0.69) nb:SetAutoFocus(false) nb:SetMaxLetters(4) nb:SetTextInsets(6, 6, 0, 0)
      local nbb = nb:CreateTexture(nil, "BACKGROUND") nbb:SetAllPoints() nbb:SetColorTexture(0.05, 0.05, 0.05, 1)
      for _, e in ipairs({ { "TOPLEFT", "TOPRIGHT", 0, 1 }, { "BOTTOMLEFT", "BOTTOMRIGHT", 0, 1 }, { "TOPLEFT", "BOTTOMLEFT", 1, 0 }, { "TOPRIGHT", "BOTTOMRIGHT", 1, 0 } }) do
        local l = nb:CreateTexture(nil, "BORDER") l:SetColorTexture(COPPER[1], COPPER[2], COPPER[3], 1) l:SetPoint(e[1]) l:SetPoint(e[2]) if e[3] == 1 then l:SetWidth(1) else l:SetHeight(1) end
      end
      local pen = fpop:CreateFontString(nil, "OVERLAY") pen:SetFont(STANDARD_TEXT_FONT, 10, "") pen:SetTextColor(MUTED, MUTED, MUTED) pen:SetPoint("LEFT", nb, "RIGHT", 5, 0) pen:SetText("이름")
      nb.pen = pen
      -- (2026-11-09) 이름 칸에 '/'로 시작하는 글(번역 프로그램이 대신 친 명령어)이 들어오면 저장하지 않고 원래 이름으로
      local function nameOK(self) local tx = self:GetText() or "" if tx:sub(1, 1) == "/" then self:SetText(tabLabel(self.k)) return false end return true end
      local function nameDone(self) if self.k and nameOK(self) then setLabel(self.k, self:GetText(), false) end self:ClearFocus() end
      nb:SetScript("OnEnterPressed", nameDone) nb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
      nb:SetScript("OnEditFocusLost", function(self) if self.k and nameOK(self) then setLabel(self.k, self:GetText(), false) end end)
      fpop.nb = nb
      fpop.rows, fpop.heads = {}, {}
      -- 아래: 이 탭 지우기 (만든 탭만) · 처음대로
      local del = CreateFrame("Button", nil, fpop) del:SetSize(80, 18)
      del.t = del:CreateFontString(nil, "OVERLAY") del.t:SetFont(STANDARD_TEXT_FONT, 11, "") del.t:SetPoint("LEFT") del.t:SetTextColor(0.88, 0.54, 0.48) del.t:SetText("이 탭 지우기")
      del:SetScript("OnClick", function()
        local k = fpop.key
        local t, n = TS(), {}
        for _, c in ipairs(t.ctabs) do if c.key ~= k then n[#n + 1] = c end end
        t.ctabs = n t.tabf[k] = nil
        fpop:Hide()
        bumpTabs()
        if rebuildTabs then rebuildTabs() end
      end)
      fpop.del = del
      local rs = CreateFrame("Button", nil, fpop) rs:SetSize(60, 18)
      rs.t = rs:CreateFontString(nil, "OVERLAY") rs.t:SetFont(STANDARD_TEXT_FONT, 11, "") rs.t:SetPoint("RIGHT") rs.t:SetTextColor(MUTED, MUTED, MUTED) rs.t:SetText("처음대로")
      rs:SetScript("OnClick", function() TS().tabf[fpop.key] = nil bumpTabs() refill(fpop.key) popFill() end)
      fpop.rs = rs
      local x = CreateFrame("Button", nil, fpop) x:SetSize(20, 20) x:SetPoint("TOPRIGHT", -4, -4)
      x.t = x:CreateFontString(nil, "OVERLAY") x.t:SetFont(STANDARD_TEXT_FONT, 16, "") x.t:SetPoint("CENTER") x.t:SetText("×") x.t:SetTextColor(OFFTXT, OFFTXT, OFFTXT)
      x:SetScript("OnClick", function() fpop:Hide() end)
      fpop:SetScript("OnMouseUp", function(_, btn) if btn == "RightButton" then fpop:Hide() end end)
    end
    if fpop:IsShown() and fpop.key == md.key then fpop:Hide() return end
    fpop.key = md.key
    popFill()
    fpop:ClearAllPoints() fpop:SetPoint("BOTTOMLEFT", P, "BOTTOMRIGHT", 8, 0) -- 대화창 오른쪽
    fpop:SetFrameStrata("TOOLTIP") fpop:SetFrameLevel(50)
    fpop:Show() fpop:Raise()
  end
  popFill = function()
    if not fpop then return end
    local k = fpop.key
    local f = filt(k)
    local custom = isCustom(k)
    if custom then
      fpop.chip:Hide() fpop.chipBg:Hide()
      fpop.nb.k = nil fpop.nb:SetText(tabLabel(k)) fpop.nb.k = k fpop.nb:Show() fpop.nb.pen:Show()
    else
      fpop.nb.k = nil fpop.nb:Hide() fpop.nb.pen:Hide()
      fpop.chip:SetText(tabLabel(k) .. " 탭만") fpop.chip:Show() fpop.chipBg:Show()
    end
    -- 지금 들어가 있는 채널 (게임 목록) + 대화창에 들어온 채널
    if GetChannelList then
      local l = { GetChannelList() }
      for i = 1, #l, 3 do if type(l[i + 1]) == "string" then noteChan(l[i], l[i + 1], true) end end
    end
    local groups = { { "나와 하는 대화", {} }, { "채널 — 하나씩 따로", {} }, { "그 밖", {} } }
    for _, c in ipairs(CATS1) do table.insert(groups[1][2], { c[1], c[2], KCOL[c[1]] }) end
    local seen = {}
    for _, c in ipairs(CHFIX) do seen[c.k] = true table.insert(groups[2][2], { c.k, c.n, CHCOL }) end
    local extra = {}
    for key, v in pairs(chanSeen) do if not seen[key] then extra[#extra + 1] = { key, v } end end
    table.sort(extra, function(a, b) return (a[2].n or 99) < (b[2].n or 99) end)
    for _, e in ipairs(extra) do
      local ci = e[2].n and ChatTypeInfo and ChatTypeInfo["CHANNEL" .. e[2].n]
      table.insert(groups[2][2], { e[1], (e[2].n and (e[2].n .. ". ") or "") .. e[2].name, ci and { ci.r, ci.g, ci.b } or { 0.44, 0.83, 1 } })
    end
    for _, c in ipairs(CATS3) do table.insert(groups[3][2], { c[1], c[2], KCOL[c[1]] }) end
    local y, ri, hi = -38, 0, 0
    local order = {}
    for _, g in ipairs(groups) do
      hi = hi + 1
      local h = fpop.heads[hi]
      if not h then h = fpop:CreateFontString(nil, "OVERLAY") h:SetFont(STANDARD_TEXT_FONT, 10.5, "") h:SetTextColor(MUTED, MUTED, MUTED) fpop.heads[hi] = h end
      h:ClearAllPoints() h:SetPoint("TOPLEFT", 14, y) h:SetText(g[1]) h:Show()
      y = y - 18
      for n, it in ipairs(g[2]) do
        ri = ri + 1
        local b = fpop.rows[ri]
        if not b then
          b = CreateFrame("Button", nil, fpop) b:SetSize(132, 24)
          b.box = flatBox(b) b.box.fill:SetPoint("LEFT", 1, 0)
          b.t = b:CreateFontString(nil, "OVERLAY") b.t:SetFont(STANDARD_TEXT_FONT, 12, "") b.t:SetPoint("LEFT", b.box.fill, "RIGHT", 8, 0) b.t:SetPoint("RIGHT", -14, 0)
          b.t:SetJustifyH("LEFT") b.t:SetWordWrap(false)
          b.dot = b:CreateTexture(nil, "OVERLAY") b.dot:SetTexture(MEDIA .. "hb_disc", "CLAMP", "CLAMP", "TRILINEAR") b.dot:SetSize(8, 8) b.dot:SetPoint("RIGHT", -2, 0)
          b:SetScript("OnClick", function(self)
            local tk = fpop.key
            local ff = filt(tk)
            ff[self.k] = not tabOn(ff, self.k, tk)
            -- 이름을 직접 안 정한 탭 = 첫 번째로 고른 대화 이름
            for _, c in ipairs(TS().ctabs) do
              if c.key == tk and c.auto then
                local nm = ""
                for _, q in ipairs(fpop.order) do if tabOn(ff, q[1], tk) then nm = q[2] break end end
                setLabel(tk, nm, true)
              end
            end
            bumpTabs()
            refill(tk)
            popFill()
          end)
          fpop.rows[ri] = b
        end
        local col = (n - 1) % 3
        b.k = it[1]
        local on = tabOn(f, it[1], k)
        b.box.set(on)
        b.t:SetText(it[2])
        if on then b.t:SetTextColor(0.95, 0.9, 0.78) else b.t:SetTextColor(MUTED, MUTED, MUTED) end
        b.dot:SetVertexColor(it[3][1], it[3][2], it[3][3], 1)
        b:ClearAllPoints() b:SetPoint("TOPLEFT", 14 + col * 142, y) b:Show()
        if col == 2 or n == #g[2] then y = y - 26 end
        order[#order + 1] = { it[1], it[2] }
      end
      y = y - 4
    end
    fpop.order = order
    for i = ri + 1, #fpop.rows do fpop.rows[i]:Hide() end
    for i = hi + 1, #fpop.heads do fpop.heads[i]:Hide() end
    fpop.del:ClearAllPoints() fpop.del:SetPoint("TOPLEFT", 14, y - 6) fpop.del:SetShown(custom)
    fpop.rs:ClearAllPoints() fpop.rs:SetPoint("TOPRIGHT", -14, y - 6)
    fpop:SetHeight(-y + 34)
  end

  -- 블리자드 채팅창 겉모습 숨기기 (메시지는 계속 받음)
  local KILL = { "GeneralDockManager", "ChatFrameMenuButton", "ChatFrameChannelButton", "ChatFrameToggleVoiceDeafenButton", "ChatFrameToggleVoiceMuteButton", "QuickJoinToastButton", "ChatAlertFrame" }
  local grave = CreateFrame("Frame") grave:Hide() -- 블리자드 탭·버튼은 여기로 (보이지 않는 곳)
  local function bury(x)
    if x and x.GetParent and x:GetParent() ~= grave and not (x.IsProtected and x:IsProtected()) then pcall(x.SetParent, x, grave) end
  end
  local function hideBlizz()
    if not InCombatLockdown() then
      for i = 1, (NUM_CHAT_WINDOWS or 10) do bury(_G["ChatFrame" .. i .. "Tab"]) bury(_G["ChatFrame" .. i .. "ButtonFrame"]) end
      bury(_G.GeneralDockManager) bury(_G.ChatFrameMenuButton) bury(_G.ChatFrameChannelButton) bury(_G.QuickJoinToastButton)
    end
    for i = 1, (NUM_CHAT_WINDOWS or 10) do
      local cf = _G["ChatFrame" .. i]
      if cf then
        if cf:GetAlpha() > 0 then cf:SetAlpha(0) end
        if cf:IsMouseEnabled() then cf:EnableMouse(false) end
        if cf.EnableMouseWheel then cf:EnableMouseWheel(false) end
      end
      for _, suf in ipairs({ "Tab", "ButtonFrame" }) do
        local x = _G["ChatFrame" .. i .. suf]
        if x then if x:GetAlpha() > 0 then x:SetAlpha(0) end if x.EnableMouse and x:IsMouseEnabled() then x:EnableMouse(false) end end
      end
    end
    for _, n in ipairs(KILL) do
      local x = _G[n]
      if x and x.SetAlpha then if x:GetAlpha() > 0 then x:SetAlpha(0) end if x.EnableMouse and x:IsMouseEnabled() then pcall(x.EnableMouse, x, false) end end
    end
  end

  local function savePos()
    local l, b = P:GetLeft(), P:GetBottom()
    if l and b then cfg().pos = { l, b } end
    cfg().w, cfg().h = P:GetWidth(), P:GetHeight()
  end
  local function place()
    local c = cfg()
    P:ClearAllPoints()
    if c.pos then P:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", c.pos[1], c.pos[2]) else P:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0.5, 27.5) end
    P:SetSize(c.w or 440, c.h or 230)
  end

  local sizing
  local function dragStart()
    if cfg().locked or InCombatLockdown() then return end
    if IsControlKeyDown() then
      local x, y = GetCursorPosition()
      sizing = { x = x, y = y, w = P:GetWidth(), h = P:GetHeight() }
      return
    end
    P:StartMoving()
  end
  local function dragStop()
    if sizing then sizing = nil savePos() return end
    P:StopMovingOrSizing()
    savePos() place()
  end
  local function lockClick(_, btn)
    if btn ~= "RightButton" or not IsControlKeyDown() then return end
    cfg().locked = not cfg().locked
    if UIErrorsFrame then UIErrorsFrame:AddMessage(cfg().locked and "대화창 고정" or "대화창 고정 풀림", 1, 0.84, 0.42) end
  end

  -- 번역 프로그램 메뉴에서 바꾸는 대화창 설정 (번역창을 대화창으로 쓸 때도 게임 대화창을 안 켜고 다 되게)
  --  /ntchat cfont 14 · center p 1 · nudge dx dy dw dh · reset · partymove · join 이름 · leave 번호
  --  · feedpos x y w h (가운데 파티글 자리, 화면 픽셀) · feedreset
  SLASH_NTCHATSET1 = "/ntchat"
  SlashCmdList.NTCHATSET = function(arg)
    arg = ((arg or ""):gsub("^%s+", ""):gsub("%s+$", ""))
    local cmd, rest = arg:match("^(%S+)%s*(.*)$")
    if not cmd then return end
    local c = cfg()
    if cmd == "feed" then -- (2026-11-13) 가운데 파티글 켜기/끄기 (번역 프로그램 설정과 같이)
      NT.db().partyFeedOn = (rest == "1")
      if rest ~= "1" and NT.feedClear then pcall(NT.feedClear) end
    elseif cmd == "cfont" then
      local n = tonumber(rest) if n then c.cfont = math.max(9, math.min(24, math.floor(n + 0.5))) feedChanged() end
    elseif cmd == "choff" then -- (2026-11-09) PC 번역창에서 바꾼 '가운데 파티글 채널별 끄기' 목록
      cfg().cenChOff = rest feedChanged()
      local st = _G["NangmanTrChatSettings"] if st and st:IsShown() and st.fillCh then pcall(st.fillCh) end
    elseif cmd == "center" then
      local k, v = rest:match("^(%S+)%s+(%S+)$")
      -- 긴 이름(say·party…)과 한 글자(s·p…) 둘 다 받음
      if k and not CENTER_KEYS[k] then for long, short in pairs(CENTER_KEYS) do if short == k then k = long break end end end
      if k and c.center and CENTER_KEYS[k] then c.center[k] = (v == "1") feedChanged() end
    elseif cmd == "font" then
      local n = tonumber(rest) if n then c.font = math.max(10, math.min(20, math.floor(n + 0.5))) applyFont() if NT.infoNow then NT.infoNow() end end
    elseif cmd == "nudge" and P then
      local dx, dy, dw, dh = rest:match("^(%S+)%s+(%S+)%s+(%S+)%s+(%S+)$")
      dx, dy, dw, dh = tonumber(dx) or 0, tonumber(dy) or 0, tonumber(dw) or 0, tonumber(dh) or 0
      local l, b = P:GetLeft(), P:GetBottom()
      if l and b then
        local sw, sh = UIParent:GetWidth(), UIParent:GetHeight()
        local w = math.max(240, math.min(sw, P:GetWidth() + dw))
        local h = math.max(120, math.min(sh, P:GetHeight() + dh))
        c.pos = { math.max(0, math.min(sw - w, l + dx)), math.max(0, math.min(sh - h, b + dy)) }
        c.w, c.h = w, h
        place()
      end
    elseif cmd == "reset" and P then
      c.pos, c.w, c.h = nil, nil, nil place()
    elseif cmd == "partymove" then
      local on = NT.feedMove and NT.feedMove()
      if UIErrorsFrame then UIErrorsFrame:AddMessage(on and "파티글 옮기기 — 끌어서 이동 · 오른쪽 아래 끌기 = 크기 · 다 옮기면 다시 누르기" or "파티글 위치 잠금", 1, 0.84, 0.42) end
    elseif cmd == "feedpos" then
      local x, y, w, h = rest:match("^(%S+)%s+(%S+)%s+(%S+)%s+(%S+)$")
      if x and NT.feedSetPx then NT.feedSetPx(tonumber(x), tonumber(y), tonumber(w), tonumber(h)) end
    elseif cmd == "feedreset" then
      if NT.feedReset then NT.feedReset() end
    elseif cmd == "join" and rest ~= "" then
      if JoinPermanentChannel then pcall(JoinPermanentChannel, rest, nil, (DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME:GetID()) or 1) end
      if ChatFrame_AddChannel and DEFAULT_CHAT_FRAME then pcall(ChatFrame_AddChannel, DEFAULT_CHAT_FRAME, rest) end
    elseif cmd == "tabs" then -- PC 번역기 대화창의 탭 설정 (번호 순서/개수 내용)
      local v, i, n, chunk = rest:match("^(%d+)%s+(%d+)/(%d+)%s*(.*)$")
      tabsIn(tonumber(v), tonumber(i), tonumber(n), chunk or "")
      return
    elseif cmd == "leave" and rest ~= "" then
      -- (2026-11-09 공유판 제보: 채널 칩을 눌러도 안 나가짐) 번역창은 채널 '번호'를 보내는데 나가기는 '이름'만 받음
      --  → 번호면 이름을 찾아서 나감 ('거래 - 오그리마'처럼 지역이 붙으면 앞 이름으로 먼저, 안 나가지면 전체 이름으로)
      local id = tonumber(rest)
      local full = rest
      if id and GetChannelName then local _, n2 = GetChannelName(id) if type(n2) == "string" and n2 ~= "" then full = n2 end end
      local base = (full:gsub("^%s*%d+%.%s*", ""):match("^(.-) %- ") or full:gsub("^%s*%d+%.%s*", ""))
      if LeaveChannelByName then
        pcall(LeaveChannelByName, base)
        if full ~= base then
          C_Timer.After(0.6, function()
            local still = GetChannelName and select(2, GetChannelName(id or full))
            if type(still) == "string" and still ~= "" then pcall(LeaveChannelByName, full) end
          end)
        end
      end
    end
    if NT.chans then C_Timer.After(1, function() pcall(NT.chans) end) end
  end

  local settings
  local function makeSettings()
    local s = CreateFrame("Frame", "NangmanTrChatSettings", P)
    s:SetSize(230, 336) s:SetFrameStrata("FULLSCREEN_DIALOG") s:SetToplevel(true) s:EnableMouse(true) s:SetClampedToScreen(true)
    local title = flatPopup(s, 12) title:SetText("대화창 설정")
    local rows = {}
    local function row(i, label, val, minus, plus)
      local y = -38 - (i - 1) * 28
      local l = s:CreateFontString(nil, "OVERLAY") l:SetFont(STANDARD_TEXT_FONT, 12, "") l:SetPoint("TOPLEFT", 16, y - 4) l:SetTextColor(HEADTXT, HEADTXT, HEADTXT) l:SetText(label)
      local v = s:CreateFontString(nil, "OVERLAY") v:SetFont(STANDARD_TEXT_FONT, 12, "") v:SetPoint("TOPRIGHT", -48, y - 4) v:SetTextColor(HITXT[1], HITXT[2], HITXT[3])
      local mb = roundBtn(s, 16, false) mb:SetPoint("TOPRIGHT", -112, y - 2)
      local pb = roundBtn(s, 16, true) pb:SetPoint("TOPRIGHT", -18, y - 2)
      mb:SetScript("OnClick", function() minus() v:SetText(val()) end)
      pb:SetScript("OnClick", function() plus() v:SetText(val()) end)
      rows[#rows + 1] = function() v:SetText(val()) end
    end
    local FADES = { 15, 30, 60, 120, 0 }
    local function fadeIdx() for i, x in ipairs(FADES) do if x == cfg().fade then return i end end return 3 end
    local function infoNow() if NT.infoNow then NT.infoNow() end end -- PC 번역창 글자 크기도 같이
    row(1, "글자 크기", function() return tostring(cfg().font) end,
      function() cfg().font = math.max(10, cfg().font - 1) applyFont() infoNow() end, function() cfg().font = math.min(20, cfg().font + 1) applyFont() infoNow() end)
    row(2, "배경 진하기", function() return string.format("%d%%", math.floor(cfg().bg * 100 + 0.5)) end,
      function() cfg().bg = math.max(0, cfg().bg - 0.1) applyBg() end, function() cfg().bg = math.min(1, cfg().bg + 0.1) applyBg() end)
    row(3, "글 사라짐", function() local f2 = cfg().fade return f2 > 0 and (f2 .. "초") or "안 사라짐" end,
      function() cfg().fade = FADES[math.max(1, fadeIdx() - 1)] applyFade() end, function() cfg().fade = FADES[math.min(#FADES, fadeIdx() + 1)] applyFade() end)
    -- 화면 가운데 파티글 글자 크기 (번역 켜져 있으면 번역 프로그램의 가운데 줄도 같이)
    row(4, "파티글 글자", function() return tostring(cfg().cfont) end,
      function() cfg().cfont = math.max(9, cfg().cfont - 1) feedChanged() end, function() cfg().cfont = math.min(24, cfg().cfont + 1) feedChanged() end)
    -- 가운데 파티글에 띄울 대화 (PC 번역창 설정과 같음)
    do
      local hdr = s:CreateFontString(nil, "OVERLAY") hdr:SetFont(STANDARD_TEXT_FONT, 10.5, "") hdr:SetTextColor(MUTED, MUTED, MUTED)
      hdr:SetPoint("TOPLEFT", 16, -38 - 4 * 28 - 4) hdr:SetText("가운데 파티글에 띄울 대화")
      -- (2026-11-13 대표) 가운데 파티글 켜기/끄기 (처음엔 꺼짐 · 번역 프로그램 설정의 '가운데 파티글'과 같이 움직임)
      local fb = CreateFrame("Button", nil, s) fb:SetSize(70, 18) fb:SetPoint("TOPRIGHT", -14, -38 - 4 * 28 - 2)
      fb.box = flatBox(fb) fb.box.fill:SetPoint("LEFT", 1, 0)
      fb.t = fb:CreateFontString(nil, "OVERLAY") fb.t:SetFont(STANDARD_TEXT_FONT, 11, "") fb.t:SetPoint("LEFT", fb.box.fill, "RIGHT", 6, 0)
      local function fpaint() local on = NT.feedEnabled and NT.feedEnabled() or false fb.box.set(on) fb.t:SetText(on and "켜짐" or "꺼짐") if on then fb.t:SetTextColor(0.95, 0.9, 0.78) else fb.t:SetTextColor(MUTED, MUTED, MUTED) end end
      fb:SetScript("OnClick", function() local D = NT.db() D.partyFeedOn = not (D.partyFeedOn == true) if not D.partyFeedOn and NT.feedClear then pcall(NT.feedClear) end fpaint() feedChanged() end)
      rows[#rows + 1] = fpaint
      local CK = { { "say", "일반 · 외침" }, { "party", "파티" }, { "raid", "공격대" }, { "inst", "인던" }, { "guild", "길드" }, { "whisper", "귓말" }, { "channel", "채널" } }
      for i, it in ipairs(CK) do
        local b = CreateFrame("Button", nil, s) b:SetSize(100, 20)
        b.box = flatBox(b) b.box.fill:SetPoint("LEFT", 1, 0)
        b.t = b:CreateFontString(nil, "OVERLAY") b.t:SetFont(STANDARD_TEXT_FONT, 11.5, "") b.t:SetPoint("LEFT", b.box.fill, "RIGHT", 7, 0) b.t:SetText(it[2])
        local col = (i - 1) % 2
        b:SetPoint("TOPLEFT", 16 + col * 104, -38 - 4 * 28 - 22 - math.floor((i - 1) / 2) * 22)
        local function paint() local on = cfg().center[it[1]] and true or false b.box.set(on) if on then b.t:SetTextColor(0.95, 0.9, 0.78) else b.t:SetTextColor(MUTED, MUTED, MUTED) end end
        b:SetScript("OnClick", function() local c = cfg().center c[it[1]] = not c[it[1]] paint() feedChanged() if s.fillCh then s.fillCh() end end)
        rows[#rows + 1] = paint
      end
      -- (2026-11-09 대표) '채널' 아래에 들어가 있는 채널을 하나씩 (끄면 그 채널 글은 가운데 파티글에 안 뜸)
      s.chRows = {}
      s.fillCh = function()
        local list = joinedBases()
        local y0 = -38 - 4 * 28 - 22 - 4 * 22
        local chOn = cfg().center.channel and true or false
        for i, it in ipairs(list) do
          local b = s.chRows[i]
          if not b then
            b = CreateFrame("Button", nil, s) b:SetSize(96, 20)
            b.box = flatBox(b) b.box.fill:SetPoint("LEFT", 1, 0)
            b.t = b:CreateFontString(nil, "OVERLAY") b.t:SetFont(STANDARD_TEXT_FONT, 11, "") b.t:SetPoint("LEFT", b.box.fill, "RIGHT", 7, 0) b.t:SetPoint("RIGHT", 0, 0)
            b.t:SetJustifyH("LEFT") b.t:SetWordWrap(false)
            b:SetScript("OnClick", function(self) toggleChOff(self.base) feedChanged() for _, f2 in ipairs(rows) do f2() end s.fillCh() end)
            s.chRows[i] = b
          end
          b.base = it.b
          local col = (i - 1) % 2
          b:ClearAllPoints() b:SetPoint("TOPLEFT", 28 + col * 98, y0 - math.floor((i - 1) / 2) * 22)
          b.t:SetText(it.n .. ". " .. it.b)
          local on = chOn and centerChOn(it.b)
          b.box.set(on and true or false)
          if on then b.t:SetTextColor(0.95, 0.9, 0.78) else b.t:SetTextColor(MUTED, MUTED, MUTED) end
          b:Show()
        end
        for i = #list + 1, #s.chRows do s.chRows[i]:Hide() end
        s:SetHeight(336 + math.ceil(#list / 2) * 22)
      end
    end
    local rb = flatBtn(s, 180, 24, "위치 · 크기 처음대로")
    rb:SetPoint("BOTTOM", 0, 14)
    rb:SetScript("OnClick", function() local c = cfg() c.pos, c.w, c.h = nil, nil, nil place() end)
    -- 가운데 파티글: 파티가 없어도 연습 글을 띄워서 옮기기 (끌기 = 이동 · 오른쪽 아래 끌기 = 크기)
    local pb2 = flatBtn(s, 180, 24, "파티글 옮기기")
    pb2:SetPoint("BOTTOM", rb, "TOP", 0, 8)
    local function pbText()
      local on = NT.feedMoving and NT.feedMoving()
      pb2.t:SetText(on and "옮기기 끝 (위치 잠그기)" or "파티글 옮기기")
      if on then pb2.t:SetTextColor(HITXT[1], HITXT[2], HITXT[3]) else pb2.t:SetTextColor(HEADTXT, HEADTXT, HEADTXT) end
    end
    NT.feedBtnText = function() if pb2:IsVisible() then pbText() end end
    pb2:SetScript("OnClick", function()
      local on = NT.feedMove and NT.feedMove()
      pbText()
      if UIErrorsFrame then UIErrorsFrame:AddMessage(on and "파티글 옮기기 — 끌어서 이동 · 오른쪽 아래 끌기 = 크기 · 다 옮기면 버튼 다시 누르기" or "파티글 위치 잠금", 1, 0.84, 0.42) end
    end)
    pb2:SetScript("OnShow", pbText)
    s:SetScript("OnShow", function(self)
      if self.fillCh then pcall(self.fillCh) end
      self:SetFrameStrata("TOOLTIP") self:SetFrameLevel(50) self:Raise()
      for _, f2 in ipairs(rows) do f2() end
    end)
    s:Hide()
    return s
  end

  -- (2026-11-09 대표) 탭 줄: 기본 4개 + 만든 탭 (PC 번역 대화창과 같은 탭) · 마지막 탭 옆 [+] = 탭 추가
  local tabBtns, plusBtn = {}, nil
  allTabs = function()
    local l = {}
    local BASEL = { all = "전체", party = "파티", guild = "길드", whisper = "귓말" }
    for _, tb in ipairs(TABS) do l[#l + 1] = { key = tb.key, label = BASEL[tb.key] or tb.label or tb.name, name = tb.name } end
    for _, c in ipairs(TS().ctabs) do l[#l + 1] = { key = c.key, label = c.label, name = c.label, custom = true } end
    return l
  end
  local function makeFrame(key)
    if frames[key] then return frames[key] end
    local m = CreateFrame("ScrollingMessageFrame", nil, P)
    m:SetPoint("TOPLEFT", P, "TOPLEFT", 12, -34) m:SetPoint("BOTTOMRIGHT", P, "BOTTOMRIGHT", -12, 40) -- (2026-11-04) A안: 위 탭 띠·아래 입력줄 띠 사이
    m:SetJustifyH("LEFT") m:SetMaxLines(500) m:SetFrameLevel(P:GetFrameLevel() + 3)
    m:SetHyperlinksEnabled(true)
    m:SetScript("OnHyperlinkClick", function(self, link, text, button)
      -- (2026-11-07 대표) 이름 오른쪽 클릭 = 메뉴 (파티 초대 · 귓속말 · 정보 보기 · 친구 추가) · Shift 없이
      local who = button == "RightButton" and link and link:match("^player:([^:]+)")
      if who and who ~= "" and NT.nameMenu then pcall(NT.nameMenu, who) return end
      pcall(SetItemRef, link, text, button, ChatFrame1)
    end)
    m:EnableMouseWheel(true)
    m:SetScript("OnMouseWheel", function(self, d)
      if IsShiftKeyDown() then if d > 0 then self:ScrollToTop() else self:ScrollToBottom() end
      elseif d > 0 then self:ScrollUp() self:ScrollUp() else self:ScrollDown() self:ScrollDown() end
    end)
    m:RegisterForDrag("LeftButton")
    m:SetScript("OnDragStart", dragStart) m:SetScript("OnDragStop", dragStop)
    m:SetScript("OnMouseUp", lockClick)
    m:Hide()
    frames[key] = m
    return m
  end
  local function addTab()
    local t = TS()
    if #t.ctabs >= 4 then return end
    local i = 1
    local used = {} for _, c in ipairs(t.ctabs) do used[c.key] = true end
    while used["c" .. i] do i = i + 1 end
    local k = "c" .. i
    t.ctabs[#t.ctabs + 1] = { key = k, label = "새 탭", auto = true }
    t.tabf[k] = nil
    bumpTabs()
    rebuildTabs()
    selTab(k)
    if tabBtns[k] then openFilter(tabBtns[k]) end
  end
  local function makeTabBtn(tb)
    local md = flatTab(P.chrome, tb.label)
    md:SetFrameLevel(P:GetFrameLevel() + 6)
    md.key = tb.key
    md:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    md:SetScript("OnClick", function(self, btn)
      if btn == "RightButton" then
        if IsControlKeyDown() then lockClick(self, btn) else openFilter(self) end
        return
      end
      selTab(self.key)
    end)
    md:SetScript("OnEnter", function(self) GameTooltip:SetOwner(self, "ANCHOR_TOP") GameTooltip:AddLine(self.tip or "", 1, 0.84, 0.42) GameTooltip:AddLine("오른쪽 클릭: 보일 대화 고르기", 0.8, 0.8, 0.8) GameTooltip:Show() end)
    md:SetScript("OnLeave", function() GameTooltip:Hide() end)
    md:RegisterForDrag("LeftButton") md:SetScript("OnDragStart", dragStart) md:SetScript("OnDragStop", dragStop)
    tabBtns[tb.key] = md
    return md
  end
  rebuildTabs = function()
    if not P then return end
    wipe(medals)
    local list = allTabs()
    local keep, prev = {}, nil
    for _, tb in ipairs(list) do
      keep[tb.key] = true
      if not frames[tb.key] then makeFrame(tb.key) applyFont() applyFade() refill(tb.key) end
      local md = tabBtns[tb.key] or makeTabBtn(tb)
      md.t:SetText(tb.label)
      md:SetSize(math.floor((md.t:GetStringWidth() or 24) + 26.5), 24)
      md.tip = tb.name or tb.label
      md:ClearAllPoints()
      if prev then md:SetPoint("BOTTOMLEFT", prev, "BOTTOMRIGHT", 2, 0) else md:SetPoint("BOTTOMLEFT", P.tabBar, "BOTTOMLEFT", 6, 0) end
      md:Show()
      medals[#medals + 1] = md
      prev = md
    end
    for k, md in pairs(tabBtns) do if not keep[k] then md:Hide() if frames[k] then frames[k]:Hide() end end end
    if not plusBtn then
      plusBtn = flatTab(P.chrome, "+")
      plusBtn.t:SetTextColor(COPPER[1], COPPER[2], COPPER[3])
      plusBtn:SetSize(24, 24)
      plusBtn:SetFrameLevel(P:GetFrameLevel() + 6)
      plusBtn:SetScript("OnClick", addTab)
      plusBtn:SetScript("OnEnter", function(self) GameTooltip:SetOwner(self, "ANCHOR_TOP") GameTooltip:AddLine("탭 추가", 1, 0.84, 0.42) GameTooltip:Show() end)
      plusBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    plusBtn:ClearAllPoints() plusBtn:SetPoint("BOTTOMLEFT", prev, "BOTTOMRIGHT", 2, 0)
    -- 자리가 있을 때만 [+] (오른쪽 톱니 앞까지) · 만든 탭은 4개까지
    local room = (#TS().ctabs < 4)
    local pr, gr = prev and prev:GetRight(), P.gear and P.gear:GetLeft()
    if room and pr and gr and pr + 28 > gr then room = false end
    plusBtn:SetShown(room)
    if not keep[active] then active = "all" end
    selTab(active)
  end
  afterTabsChanged = function()
    rebuildTabs()
    for _, tb in ipairs(allTabs()) do refill(tb.key) end
    if fpop and fpop:IsShown() then
      local ok = false
      for _, tb in ipairs(allTabs()) do if tb.key == fpop.key then ok = true end end
      if ok then popFill() else fpop:Hide() end
    end
  end

  local function build()
    if P then return end
    P = CreateFrame("Frame", "NangmanTrChat", UIParent)
    P:SetFrameStrata("LOW") P:SetMovable(true) P:SetResizable(true) P:SetClampedToScreen(true)
    P:EnableMouse(true) P:RegisterForDrag("LeftButton")
    P:SetScript("OnDragStart", dragStart) P:SetScript("OnDragStop", dragStop)
    P:SetScript("OnMouseUp", lockClick)
    place()
    -- 겉모습(판·탭·입력줄)은 한 묶음 → 가만히 두면 흐려지고 글자만 남음
    local chrome = CreateFrame("Frame", nil, P) chrome:SetAllPoints() chrome:SetFrameLevel(P:GetFrameLevel())
    P.chrome = chrome
    fillTex = plate(chrome, "BACKGROUND", 4, R_ALL)
    applyBg()
    local tabBar = strip(chrome, 28, "TOP", 0.05, R_TOP)
    P.tabBar = tabBar
    -- 메시지 창: 기본 4개 (만든 탭 창은 탭 줄을 만들 때)
    for _, tb in ipairs(TABS) do makeFrame(tb.key) end
    applyFont() applyFade()
    -- 입력줄 · 아래쪽 옅은 띠 34px
    local cap = CreateFrame("Button", "NangmanTrChatInput", chrome)
    cap:SetHeight(34) cap:SetPoint("BOTTOMLEFT", P, "BOTTOMLEFT", 0, 0) cap:SetPoint("BOTTOMRIGHT", P, "BOTTOMRIGHT", 0, 0)
    cap:SetFrameLevel(P:GetFrameLevel() + 4)
    for _, t in ipairs(plate(cap, "BACKGROUND", 4, R_BOT)) do t:SetVertexColor(1, 1, 1, 0.04) end
    cap.ph = cap:CreateFontString(nil, "OVERLAY") cap.ph:SetFont(STANDARD_TEXT_FONT, 13, "") cap.ph:SetPoint("LEFT", 48, 0) cap.ph:SetTextColor(MUTED, MUTED, MUTED) cap.ph:SetText("메시지를 입력하세요…  (Enter)")
    cap:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    cap:SetScript("OnClick", function(self, btn)
      if btn == "RightButton" then lockClick(self, btn) return end
      local open = (ChatFrameUtil and ChatFrameUtil.OpenChat) or ChatFrame_OpenChat
      if open then pcall(open, "", ChatFrame1) end
    end)
    cap:RegisterForDrag("LeftButton") cap:SetScript("OnDragStart", dragStart) cap:SetScript("OnDragStop", dragStop)
    -- 입력 채널 표시 = 채널 색이 옅게 깔린 작은 네모 딱지 (글자는 채널 색 밝게)
    local ch = CreateFrame("Frame", nil, cap) ch:SetSize(34, 22) ch:SetPoint("LEFT", cap, "LEFT", 6, 0)
    ch.disc = ch:CreateTexture(nil, "ARTWORK") ch.disc:SetAllPoints() ch.disc:SetColorTexture(1, 1, 1, 1) ch.disc:SetVertexColor(0.47, 0.43, 0.37, 0.3)
    ch.t = ch:CreateFontString(nil, "OVERLAY") ch.t:SetFont(STANDARD_TEXT_FONT, 12, "") ch.t:SetPoint("CENTER", 0, 0)
    ch.t:SetTextColor(0.55 + 0.47 * 0.45, 0.55 + 0.43 * 0.45, 0.55 + 0.37 * 0.45) ch.t:SetText("일")
    P.chMedal = ch
    -- 톱니 = 설정 (위쪽 탭 띠 오른쪽 끝 · 회색 · 올리면 밝게)
    local gear = CreateFrame("Button", nil, chrome) gear:SetSize(24, 28) gear:SetPoint("RIGHT", tabBar, "RIGHT", -4, 0)
    gear:SetFrameLevel(P:GetFrameLevel() + 6)
    gear.icon = gear:CreateTexture(nil, "ARTWORK") gear.icon:SetSize(14, 14) gear.icon:SetPoint("CENTER", 0, 0)
    gear.icon:SetTexture(MEDIA .. "gear", "CLAMP", "CLAMP", "TRILINEAR")
    gear.icon:SetVertexColor(OFFTXT, OFFTXT, OFFTXT)
    gear:SetScript("OnEnter", function(self) self.icon:SetVertexColor(0.9, 0.9, 0.9) GameTooltip:SetOwner(self, "ANCHOR_TOP") GameTooltip:AddLine("대화창 설정", 1, 0.84, 0.42) GameTooltip:Show() end)
    gear:SetScript("OnLeave", function(self) self.icon:SetVertexColor(OFFTXT, OFFTXT, OFFTXT) GameTooltip:Hide() end)
    gear:SetScript("OnClick", function()
      settings = settings or makeSettings()
      if settings:IsShown() then settings:Hide() else settings:ClearAllPoints() settings:SetPoint("BOTTOMRIGHT", P, "TOPRIGHT", 0, 8) settings:Show() end
    end)
    -- (2026-11-13 대표) 게임 대화창 입력줄 오른쪽에도 번역 프로그램 입력줄처럼 [번역 OFF] · [가운데 파티글] 단추 (설정과 같이 움직임)
    do
      -- (2026-11-13 대표 A안) 게임 대화창의 '일' 채널 딱지처럼 옅은 바탕 · 테두리 없음 · 켜지면 구리빛
      local function ring(b, w, h)
        b:SetSize(w, h)
        b.ring = plate(b, "BACKGROUND", 10, R_ALL)
        return b
      end
      local function ringColor(b, on) for _, t in ipairs(b.ring) do if on then t:SetVertexColor(COPPER[1], COPPER[2], COPPER[3], 0.28) else t:SetVertexColor(1, 1, 1, 0.07) end end end
      local cen = CreateFrame("Button", nil, cap) cen:SetPoint("RIGHT", cap, "RIGHT", -10, 0) cen:SetFrameLevel(cap:GetFrameLevel() + 4)
      local ci = ring(cen, 30, 20)
      local function bar(w, h, x, y) local t = ci:CreateTexture(nil, "ARTWORK") t:SetColorTexture(1, 1, 1, 1) t:SetSize(w, h) t:SetPoint("CENTER", x, y) return t end
      cen.g = { bar(11, 1, 0, 4), bar(11, 1, 0, -4), bar(1, 9, -5, 0), bar(1, 9, 5, 0), bar(5, 1, 0, 0) } -- 네모 안에 가로줄 = 가운데 파티글
      local tr = CreateFrame("Button", nil, cap) tr:SetPoint("RIGHT", cen, "LEFT", -6, 0) tr:SetFrameLevel(cap:GetFrameLevel() + 4)
      local ti = ring(tr, 70, 20)
      tr.t = ti:CreateFontString(nil, "OVERLAY") tr.t:SetFont(STANDARD_TEXT_FONT, 11.5, "") tr.t:SetPoint("CENTER", 0, 0)
      local function paint()
        local fon = NT.feedEnabled and NT.feedEnabled() or false
        local c = fon and { 0.95, 0.85, 0.62, 1 } or { MUTED, MUTED, MUTED, 1 }
        for _, t in ipairs(cen.g) do t:SetVertexColor(c[1], c[2], c[3], c[4]) end ringColor(cen, fon)
        local on = NT.trOn and NT.trOn() or false
        ringColor(tr, on)
        tr.t:SetText(on and "번역 ON" or "번역 OFF") tr.t:SetTextColor(on and 0.95 or MUTED, on and 0.85 or MUTED, on and 0.62 or MUTED)
      end
      cen:SetScript("OnClick", function() local D = NT.db() D.partyFeedOn = not (D.partyFeedOn == true) if not D.partyFeedOn and NT.feedClear then pcall(NT.feedClear) end paint() feedChanged() local st = _G["NangmanTrChatSettings"] if st and st:IsShown() and st.refresh then pcall(st.refresh) end end)
      cen:SetScript("OnEnter", function(self) GameTooltip:SetOwner(self, "ANCHOR_TOP") GameTooltip:AddLine("가운데 파티글", 1, 0.84, 0.42) GameTooltip:AddLine((NT.feedEnabled and NT.feedEnabled()) and "켜짐 (클릭 = 끄기)" or "꺼짐 (클릭 = 켜기)", 0.9, 0.9, 0.9) GameTooltip:Show() end)
      cen:SetScript("OnLeave", function() GameTooltip:Hide() end)
      tr:SetScript("OnClick", function() if NT.setTranslate then NT.setTranslate(not (NT.trOn and NT.trOn())) end paint() end)
      tr:SetScript("OnEnter", function(self) GameTooltip:SetOwner(self, "ANCHOR_TOP") GameTooltip:AddLine("번역", 1, 0.84, 0.42) GameTooltip:AddLine("클릭 = 번역창으로 (번역 프로그램이 켜져 있어야 해요)", 0.9, 0.9, 0.9) GameTooltip:Show() end)
      tr:SetScript("OnLeave", function() GameTooltip:Hide() end)
      cap.paintBtns = paint
      local pt = CreateFrame("Frame", nil, cap) local acc = 0
      pt:SetScript("OnUpdate", function(_, e) acc = acc + e if acc > 0.5 then acc = 0 paint() end end) -- 설정·번역 프로그램에서 바꾼 것도 따라감
      paint()
    end
    P.cap = cap
    P.gear = gear
    -- (2026-11-13 대표) 팝업(대화창 설정 · 이 탭에 보일 대화)이 열려 있을 때 바깥을 클릭하면 닫기 — 기본
    if not P.__ntOutside then
      P.__ntOutside = true
      local function over(f) return f and f.IsShown and f:IsShown() and f.IsMouseOver and f:IsMouseOver() end
      local function outside()
        if (DropDownList1 and over(DropDownList1)) or (DropDownList2 and over(DropDownList2)) then return end
        if settings and settings:IsShown() and not over(settings) and not over(P.gear) then settings:Hide() end
        if fpop and fpop:IsShown() and not over(fpop) then
          local onTab = over(plusBtn)
          for _, b in pairs(tabBtns) do if over(b) then onTab = true end end
          if not onTab then if fpop.nb and fpop.nb:HasFocus() then fpop.nb:ClearFocus() end fpop:Hide() end
        end
      end
      local of = CreateFrame("Frame")
      if pcall(of.RegisterEvent, of, "GLOBAL_MOUSE_DOWN") then of:SetScript("OnEvent", outside)
      elseif WorldFrame then WorldFrame:HookScript("OnMouseDown", outside) end
    end
    rebuildTabs() -- 탭 줄 (기본 4개 + 만든 탭 + [+])
    -- 오른쪽 아래 모서리 끌기 = 크기 조절 (잠겨 있지 않을 때만 보임)
    if P.SetResizeBounds then P:SetResizeBounds(260, 120, 1000, 700) elseif P.SetMinResize then P:SetMinResize(260, 120) P:SetMaxResize(1000, 700) end
    local grip = CreateFrame("Button", nil, chrome)
    grip:SetSize(16, 16) grip:SetPoint("BOTTOMRIGHT", P, "BOTTOMRIGHT", -2, 36) grip:SetFrameLevel(P:GetFrameLevel() + 8)
    grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    for _, t in ipairs({ grip:GetNormalTexture(), grip:GetPushedTexture() }) do if t then t:SetVertexColor(COPPER[1], COPPER[2], COPPER[3]) end end
    grip:SetScript("OnMouseDown", function() if cfg().locked or InCombatLockdown() then return end P.gripping = true P:StartSizing("BOTTOMRIGHT") end)
    grip:SetScript("OnMouseUp", function() if not P.gripping then return end P.gripping = nil P:StopMovingOrSizing() savePos() place() end)
    P.grip = grip
    -- 블리자드 입력창을 입력줄 안으로
    local eb = ChatFrame1EditBox
    if eb then
      local guard
      -- 번역을 끈 상태(게임 대화창)에서 Enter = 입력줄이 가운데 파티글 바로 아래 (번역 입력칸과 같은 자리 · 같은 너비)
      --  다 쓰면(초점 잃으면) 대화창 입력줄로 돌아감
      local CIN = CreateFrame("Frame", "NangmanTrCenterInput")
      CIN:SetFrameStrata("DIALOG") CIN:SetHeight(32) CIN:Hide()
      for _, tx in ipairs(plate(CIN, "BACKGROUND", 6, R_ALL)) do tx:SetVertexColor(0.067, 0.067, 0.071, 0.88) end
      local function centerOK() return not NT.trOn() and NT.feedEnabled and NT.feedEnabled() and _G.NangmanTrPartyFeed and _G.NangmanTrPartyFeed:GetLeft() and eb:HasFocus() end
      local function placeEB()
        if guard then return end
        guard = true
        eb:ClearAllPoints()
        if centerOK() then
          local fd = _G.NangmanTrPartyFeed
          CIN:SetScale(UIParent:GetEffectiveScale())
          CIN:SetWidth(P:GetWidth() * P:GetEffectiveScale() / UIParent:GetEffectiveScale())
          CIN:ClearAllPoints() CIN:SetPoint("TOP", fd, "BOTTOM", 0, -14)
          CIN:Show()
          if eb:GetParent() ~= CIN then pcall(eb.SetParent, eb, CIN) end
          eb:SetFrameLevel(CIN:GetFrameLevel() + 3)
          eb:SetPoint("TOPLEFT", CIN, "TOPLEFT", 10, -2) eb:SetPoint("BOTTOMRIGHT", CIN, "BOTTOMRIGHT", -10, 2)
        else
          CIN:Hide()
          if eb:GetParent() ~= P then pcall(eb.SetParent, eb, P) eb:SetFrameLevel(cap:GetFrameLevel() + 3) end
          eb:SetPoint("TOPLEFT", cap, "TOPLEFT", 44, -4) eb:SetPoint("BOTTOMRIGHT", cap, "BOTTOMRIGHT", -112, 4)
        end
        guard = false
      end
      eb:HookScript("OnEditFocusGained", function() C_Timer.After(0, placeEB) end)
      eb:HookScript("OnEditFocusLost", function() C_Timer.After(0, placeEB) end)
      pcall(eb.SetParent, eb, P)
      eb:SetFrameLevel(cap:GetFrameLevel() + 3)
      for _, r in ipairs({ eb:GetRegions() }) do if r.GetObjectType and r:GetObjectType() == "Texture" then r:SetAlpha(0) end end
      local lang = _G["ChatFrame1EditBoxLanguage"] if lang then lang:SetAlpha(0) lang:EnableMouse(false) end
      placeEB()
      hooksecurefunc(eb, "SetPoint", function() if not guard then C_Timer.After(0, placeEB) end end)
    end
    -- 첫 화면: 지금까지의 채팅 기록 옮겨 오기
    local n = ChatFrame1.GetNumMessages and ChatFrame1:GetNumMessages() or 0
    for i = math.max(1, n - 200), n do
      local ok, t, r, g, b = pcall(ChatFrame1.GetMessageInfo, ChatFrame1, i)
      if ok and t then route(t, r, g, b) end
    end
    for _, md in ipairs(medals) do md.unread = nil end
    -- 새 귓말이 오면 귓말 탭 이름 옆 작은 주황 점 (귓말 탭을 누르면 꺼짐)
    for _, md in ipairs(medals) do
      if md.key == "whisper" then
        local sp = md:CreateTexture(nil, "OVERLAY", nil, 3)
        sp:SetTexture(DISC, "CLAMP", "CLAMP", "TRILINEAR") sp:SetVertexColor(DOT[1], DOT[2], DOT[3], 1)
        sp:SetSize(6, 6) sp:SetPoint("LEFT", md.t, "RIGHT", 5, 0) sp:Hide()
        md.spin = sp
        local wev = CreateFrame("Frame")
        for _, e in ipairs({ "CHAT_MSG_WHISPER", "CHAT_MSG_BN_WHISPER" }) do pcall(wev.RegisterEvent, wev, e) end
        wev:SetScript("OnEvent", function() if active ~= "whisper" then sp:Show() end end)
      end
    end
    selTab("all")
    -- 흐려짐 · 입력 채널 딱지 · 크기 조절
    local CHT = { SAY = { "일", { 0.47, 0.43, 0.37 } }, YELL = { "외", { 0.7, 0.2, 0.2 } }, PARTY = { "파", { 0.24, 0.39, 0.78 } }, PARTY_LEADER = { "파", { 0.24, 0.39, 0.78 } },
      RAID = { "공", { 0.75, 0.42, 0.12 } }, RAID_WARNING = { "경", { 0.8, 0.3, 0.1 } }, INSTANCE_CHAT = { "인", { 0.75, 0.42, 0.12 } }, GUILD = { "길", { 0.16, 0.55, 0.24 } },
      OFFICER = { "관", { 0.15, 0.45, 0.2 } }, WHISPER = { "귓", { 0.67, 0.24, 0.59 } }, BN_WHISPER = { "귓", { 0.2, 0.55, 0.75 } }, EMOTE = { "감", { 0.75, 0.45, 0.2 } }, CHANNEL = { "채", { 0.6, 0.5, 0.35 } } }
    local a, acc, idle = 1, 0, 0
    P:SetScript("OnUpdate", function(self, el)
      if sizing then
        if not IsMouseButtonDown("LeftButton") then sizing = nil savePos()
        else
          local x, y = GetCursorPosition()
          local es = self:GetEffectiveScale()
          self:SetSize(math.max(260, math.min(1000, sizing.w + (x - sizing.x) / es)), math.max(120, math.min(700, sizing.h + (y - sizing.y) / es)))
        end
      end
      local typing = eb and eb:HasFocus()
      local want = (typing or self:IsMouseOver(6, -4, -4, 4) or (settings and settings:IsShown()) or (fpop and fpop:IsShown()) or sizing or self.gripping) and 1 or nil
      if want then idle = 0 else idle = idle + el end
      local target = want or (idle > 4 and 0 or 1)
      if a ~= target then
        a = target > a and math.min(target, a + el * 6) or math.max(target, a - el * 1.5)
        if not NT.trOn() then chrome:SetAlpha(a) end -- 번역 켜짐일 땐 번역 연결 쪽이 겉모습을 맡음
      end
      if P.grip then P.grip:SetShown(not cfg().locked) end
      cap.ph:SetShown(not (eb and eb:IsShown() and (typing or (eb:GetText() or "") ~= "")))
      acc = acc + el
      if acc > 0.2 then
        acc = 0
        if eb then
          local t = eb:GetAttribute("chatType") or "SAY"
          local info = CHT[t] or CHT.SAY
          if ch.cur ~= t then
            ch.cur = t ch.t:SetText(info[1])
            local cc = info[2]
            ch.disc:SetVertexColor(cc[1], cc[2], cc[3], 0.3) ch.t:SetTextColor(0.55 + cc[1] * 0.45, 0.55 + cc[2] * 0.45, 0.55 + cc[3] * 0.45)
          end
        end
      end
    end)
    hooksecurefunc(ChatFrame1, "AddMessage", function(_, text, r, g, b) if chHook(text) then return end route(text, r, g, b) end)
    hideBlizz()
    C_Timer.NewTicker(2, function() pcall(hideBlizz) end)
  end

  local ce = CreateFrame("Frame")
  ce:RegisterEvent("PLAYER_LOGIN")
  ce:SetScript("OnEvent", function() C_Timer.After(1, function() local ok, err = pcall(build) if not ok then print("|cffff6060[번역기 대화창]|r " .. tostring(err)) end end) end)
end

-- ===== 입력줄 밖을 클릭하면 입력줄에서 빠져나오기 (커서가 계속 깜빡이며 남지 않게) =====
do
  local function boxes()
    local t = {}
    for i = 1, (NUM_CHAT_WINDOWS or 10) do local eb = _G["ChatFrame" .. i .. "EditBox"] if eb then t[#t + 1] = eb end end
    return t
  end
  local function hookOpen(eb)
    if not eb.__ntHook and eb.HookScript then eb.__ntHook = true eb:HookScript("OnEditFocusGained", function(self) self.__ntOpenAt = GetTime() end) end
  end
  local function leave()
    -- Shift·Ctrl+클릭(아이템·이름 링크 넣기)이나 대화창 자체를 누른 건 그대로 둠
    if IsShiftKeyDown() or IsControlKeyDown() or IsAltKeyDown() then return end
    local cp = _G.NangmanTrChat
    if cp and cp.IsMouseOver and cp:IsShown() and cp:IsMouseOver() then return end
    for _, eb in ipairs(boxes()) do
      -- 방금(1초 안) 열린 입력줄은 그대로 둠: 번역 프로그램이 대신 글을 넣는 순간 입력줄이 닫혀 글이 사라지지 않게
      hookOpen(eb)
      if eb:HasFocus() and not (eb.__ntOpenAt and GetTime() - eb.__ntOpenAt < 1.0) and not (eb.IsMouseOver and eb:IsMouseOver()) then
        if ChatEdit_DeactivateChat then pcall(ChatEdit_DeactivateChat, eb) else eb:ClearFocus() end
      end
    end
  end
  C_Timer.After(2, function() for _, eb in ipairs(boxes()) do hookOpen(eb) end end)
  local f = CreateFrame("Frame")
  if not pcall(f.RegisterEvent, f, "GLOBAL_MOUSE_DOWN") then
    if WorldFrame then WorldFrame:HookScript("OnMouseDown", leave) end
  end
  f:SetScript("OnEvent", function() C_Timer.After(0, leave) end)
end

-- 영어 클라이언트에서도 한글로 채팅 종류 바꾸기: 한글 자판 그대로 친 /ㅎ(=/g 길드) · /ㅔ(=/p 파티) 등 + /길드 · /파티 같은 한글 말
do
  local KO = {
    ["/ㅎ"] = "/g", ["/ㅔ"] = "/p", ["/ㄴ"] = "/s", ["/ㅛ"] = "/y", ["/ㅐ"] = "/o", ["/ㅑ"] = "/i", ["/ㅈ"] = "/w", ["/ㄱ"] = "/r", ["/ㄷ"] = "/e",
    ["/ㄱㅁ"] = "/ra", ["/ㄱㅈ"] = "/rw",
    ["/길드"] = "/g", ["/길"] = "/g", ["/파티"] = "/p", ["/파"] = "/p", ["/공대"] = "/ra", ["/공격대"] = "/ra", ["/공대경보"] = "/rw",
    ["/일반"] = "/s", ["/말"] = "/s", ["/외침"] = "/y", ["/관리자"] = "/o", ["/인던"] = "/i", ["/귓"] = "/w", ["/귓속말"] = "/w", ["/답장"] = "/r", ["/감정"] = "/e",
  }
  local TYPE = { ["/g"] = "GUILD", ["/p"] = "PARTY", ["/s"] = "SAY", ["/y"] = "YELL", ["/o"] = "OFFICER", ["/i"] = "INSTANCE_CHAT", ["/ra"] = "RAID", ["/rw"] = "RAID_WARNING", ["/e"] = "EMOTE" }
  local function addHash()
    if type(hash_ChatTypeInfoList) ~= "table" then return end
    for k, v in pairs(KO) do local t = TYPE[v] if t and hash_ChatTypeInfoList[strupper(k)] == nil then hash_ChatTypeInfoList[strupper(k)] = t end end
  end
  pcall(addHash)
  local busy = false
  local function onText(self)
    if busy or not self or not self.GetText then return end
    local t = self:GetText()
    if type(t) ~= "string" or NT.secret(t) or t:sub(1, 1) ~= "/" then return end
    local cmd, rest = t:match("^(/[^%s]+)%s(.*)$")
    local en = cmd and KO[cmd]
    if not en then return end
    busy = true
    self:SetText(en .. " " .. (rest or ""))
    if ChatEdit_ParseText then pcall(ChatEdit_ParseText, self, 0) end
    busy = false
  end
  if hooksecurefunc and ChatEdit_OnTextChanged then pcall(hooksecurefunc, "ChatEdit_OnTextChanged", onText) end
  local kf = CreateFrame("Frame") kf:RegisterEvent("PLAYER_LOGIN") kf:SetScript("OnEvent", function() pcall(addHash) end)
end

-- 대화창에서 아이디(이름) 클릭
--  · Shift + 왼쪽 클릭 = 그 사람 정보 (/누구 결과가 채팅창에 한 줄)
--  · Shift + 오른쪽 클릭 = 작은 메뉴 (파티 초대 · 귓속말 · 정보 보기 · 친구 추가) · 우리 대화창은 Shift 없이 오른쪽 클릭
--  블리자드 기본 클릭 처리(SetItemRef) 뒤에 덧붙이는 방식 → 기본 기능은 그대로
do
  local last = 0
  local function closeMenus()
    if Menu and Menu.GetManager then pcall(function() Menu.GetManager():CloseMenus() end) end
    if CloseDropDownMenus then pcall(CloseDropDownMenus) end
  end
  function NT.nameMenu(who)
    if type(who) ~= "string" or who == "" or NT.secret(who) then return end
    closeMenus()
    C_Timer.After(0, function()
      closeMenus()
      local short = who:match("^([^%-]+)") or who
      local function invite() local inv = (C_PartyInfo and C_PartyInfo.InviteUnit) or InviteUnit if inv then pcall(inv, who) end end
      local function whisper() if ChatFrame_SendTell then ChatFrame_SendTell(who) end end
      local function info()
        if C_FriendList and C_FriendList.SendWho then pcall(C_FriendList.SendWho, 'n-"' .. short .. '"')
        elseif SendWho then pcall(SendWho, 'n-"' .. short .. '"') end
      end
      local function friend() if C_FriendList and C_FriendList.AddFriend then pcall(C_FriendList.AddFriend, who) end end
      if MenuUtil and MenuUtil.CreateContextMenu then
        MenuUtil.CreateContextMenu(UIParent, function(_, root)
          root:CreateTitle(short)
          root:CreateButton("파티 초대", invite)
          root:CreateButton("귓속말", whisper)
          root:CreateButton("정보 보기", info)
          root:CreateButton("친구 추가", friend)
        end)
      elseif EasyMenu then
        local menu = { { text = short, isTitle = true, notCheckable = true },
          { text = "파티 초대", func = invite, notCheckable = true },
          { text = "귓속말", func = whisper, notCheckable = true },
          { text = "정보 보기", func = info, notCheckable = true },
          { text = "친구 추가", func = friend, notCheckable = true } }
        NangmanTrNameMenu = NangmanTrNameMenu or CreateFrame("Frame", "NangmanTrNameMenu", UIParent, "UIDropDownMenuTemplate")
        EasyMenu(menu, NangmanTrNameMenu, "cursor", 0, 0, "MENU")
      else
        invite()
      end
    end)
  end
  hooksecurefunc("SetItemRef", function(link, text, button)
    if not IsShiftKeyDown() or type(link) ~= "string" or NT.secret(link) then return end
    local who = link:match("^player:([^:]+)")
    if not who or who == "" then return end
    local now = GetTime()
    if now - last < 0.3 then return end -- 같은 클릭이 두 번 들어오는 것 막기
    last = now
    if button == "RightButton" then
      NT.nameMenu(who)
    else
      if ChatEdit_GetActiveWindow and ChatEdit_GetActiveWindow() then return end -- 글 쓰는 중이면 이름 넣기(기본 기능)만
      local short = who:match("^([^%-]+)") or who
      if C_FriendList and C_FriendList.SendWho then pcall(C_FriendList.SendWho, 'n-"' .. short .. '"')
      elseif SendWho then pcall(SendWho, 'n-"' .. short .. '"') end
    end
  end)
end


-- (2026-11-09 공유판 제보: 번역 끈 기본 대화창에 따로 들어간 채널(knus) 글이 안 보임)
--  우리 대화창은 블리자드 1번 대화창에 들어온 글을 받아 탭마다 나눔 → 1번 대화창이 그 채널을 안 받고 있으면 글이 아예 안 들어옴
--  → 내가 들어가 있는 '따로 만든 채널'은 1번 대화창도 받게 해 둠 (공개·거래 같은 기본 채널은 건드리지 않음 · 보일지는 탭 설정이 정함)
do
  local WORLD = { "공개", "거래", "수비", "파티찾기", "세계", "서비스", "초보", "general", "trade", "localdefense", "lookingforgroup", "worlddefense", "services", "newcomer" }
  local function isWorld(nm)
    local l = nm:lower()
    for _, w in ipairs(WORLD) do if l:find(w, 1, true) then return true end end
    return false
  end
  local function sub()
    if not (ChatFrame1 and GetChannelList) then return end
    local add = ChatFrame_AddChannel or (ChatFrameUtil and ChatFrameUtil.AddChannel)
    if not add then return end
    local have = {}
    if type(ChatFrame1.channelList) == "table" then
      for _, n in pairs(ChatFrame1.channelList) do if type(n) == "string" then have[n:lower()] = true end end
    end
    local l = { GetChannelList() }
    for i = 1, #l, 3 do
      local nm = l[i + 1]
      if type(nm) == "string" and nm ~= "" and not have[nm:lower()] and not isWorld(nm) then pcall(add, ChatFrame1, nm) end
    end
  end
  local f = CreateFrame("Frame")
  f:RegisterEvent("PLAYER_ENTERING_WORLD") f:RegisterEvent("CHANNEL_UI_UPDATE")
  local pend
  f:SetScript("OnEvent", function()
    if pend then return end
    pend = true
    C_Timer.After(4, function() pend = nil pcall(sub) end)
  end)
end
