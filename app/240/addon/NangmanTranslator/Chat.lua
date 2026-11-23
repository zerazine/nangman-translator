local NT = NangmanTr
if not NT or NT.inert then return end
local function commText(t)
  if type(t) ~= "string" or (issecretvalue and issecretvalue(t)) or not t:find("|HplayerCommunity:", 1, true) then return t end
  return (t:gsub("|K[wx]%d+|k", "|cff8c8c8c(내용은 커뮤니티 창 J에서 보여요)|r"))
end

local FACE = STANDARD_TEXT_FONT or "Fonts\\2002.TTF"
local GOLD = { 0.96, 0.82, 0.48 }
local MEDIA = NT.MEDIA
local secret = NT.secret

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

do
  local function cfg()
    local d = NT.db()
    NangmanTranslatorCharDB = NangmanTranslatorCharDB or {}
    local c = NangmanTranslatorCharDB.chatUI
    if type(c) ~= "table" then
      local function cp(v) if type(v) ~= "table" then return v end local r = {} for k, x in pairs(v) do r[k] = cp(x) end return r end
      c = type(d.chatUI) == "table" and cp(d.chatUI) or {}
      c.undock, c.uiv = nil, nil
      if type(d.chatLook) == "table" then for k, v in pairs(d.chatLook) do c[k] = v end end
      NangmanTranslatorCharDB.chatUI = c
    end
    if c.font == nil then c.font = 12 end
    if c.bg == nil then c.bg = 0.6 end
    if c.fade == nil then c.fade = 0 end
    if c.cfont == nil then c.cfont = 13 end
    if type(c.center) ~= "table" then c.center = { say = true, party = true, raid = true, inst = true, guild = true, whisper = true, channel = true } end
    return c
  end
  NT.chatCfg = cfg
  local function lookSave()
    local c = cfg()
    NT.db().chatLook = { face = c.face, thin = c.thin, font = c.font, bg = c.bg, fade = c.fade, keep = c.keep, native = c.native, cfont = c.cfont }
  end
  local CENTER_KEYS = { say = "s", party = "p", raid = "r", inst = "i", guild = "g", whisper = "w", channel = "c" }
  function NT.centerFont() return cfg().cfont or 13 end
  function NT.centerOn(k) local c = cfg().center return k and c[k] and true or false end
  function NT.centerMask()
    local c, t = cfg().center, {}
    for _, k in ipairs({ "say", "party", "raid", "inst", "guild", "whisper", "channel" }) do if c[k] then t[#t + 1] = CENTER_KEYS[k] end end
    return table.concat(t)
  end
  local function feedChanged() if NT.feedRefresh then pcall(NT.feedRefresh) end if NT.feedNow then NT.feedNow() end end
  local P
  local frames, active = {}, "all"
  local medals, tabBtns = {}, {}
  local TABS = {
    { key = "all", name = "전체" },
    { key = "party", name = "파티 · 공대 · 인던" },
    { key = "guild", name = "길드" },
    { key = "whisper", name = "귓말" },
  }
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
    NangmanTranslatorCharDB = NangmanTranslatorCharDB or {}
    local t = NangmanTranslatorCharDB.chatTabs
    if type(t) ~= "table" then
      local function cp(v) if type(v) ~= "table" then return v end local r = {} for k, x in pairs(v) do r[k] = cp(x) end return r end
      t = type(d.chatTabs) == "table" and cp(d.chatTabs) or { ver = 0, ctabs = {}, tabf = {} }
      NangmanTranslatorCharDB.chatTabs = t
    end
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
  local hist = {}
  local chanSeen = {}
  local function chBase(nm)
    if type(nm) ~= "string" then return end
    nm = nm:gsub("^%s*%d+%.%s*", "")
    nm = nm:match("^(.-) %- ") or nm
    nm = nm:gsub("^%s+", ""):gsub("%s+$", ""):gsub("%s+%d+$", "")
    if nm == "" then return end
    return nm
  end
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
    pushChOff()
  end
  local afterTabsChanged, allTabs
  local function bumpTabs()
    local t = TS()
    local now = time and time() or 0
    if (t.ver or 0) > now + 60 then t.ver = now end
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
  NT.tabsPush = function() pushTabs() end
  do local ef = CreateFrame("Frame") ef:RegisterEvent("PLAYER_ENTERING_WORLD") NT.onEvent(ef, function() C_Timer.After(6, pushTabs) end) end
  local function shows(f, key, tab) return tabOn(f, key, tab) end

  local COPPER = { 0.725, 0.557, 0.373 }
  local HITXT = { 0.89, 0.765, 0.604 }
  local MUTED = 0.541
  local OFFTXT = 0.639
  local HEADTXT = 0.902
  local DOT = { 0.914, 0.635, 0.231 }
  local TABOFF, TABON, TABUL = { 0.741, 0.702, 0.604 }, { 0.953, 0.886, 0.702 }, { 0.878, 0.725, 0.353 }
  local UIFONT = MEDIA .. "GJ_UI.ttf"
  local R_ALL, R_TOP, R_BOT = { tl = true, tr = true, bl = true, br = true }, { tl = true, tr = true }, { bl = true, br = true }
  local DISC = MEDIA .. "hb_disc"
  local function plate(f, layer, r, round, a)
    a, round = a or f, round or {}
    local t = {}
    local function piece(tc)
      local x = f:CreateTexture(nil, layer)
      if tc then x:SetTexture(MEDIA .. "pill_cap", "CLAMP", "CLAMP", "TRILINEAR") x:SetTexCoord(unpack(tc)) else x:SetColorTexture(1, 1, 1, 1) end
      t[#t + 1] = x
      return x
    end
    local tl, tr = piece(round.tl and { 0, 1, 0, 0.5 }), piece(round.tr and { 1, 0, 0, 0.5 })
    local bl, br = piece(round.bl and { 0, 1, 0.5, 1 }), piece(round.br and { 1, 0, 0.5, 1 })
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
  local function pill(f, h)
    local o = {}
    local function tx(file, flip, layer)
      local x = f:CreateTexture(nil, layer)
      if file then x:SetTexture(MEDIA .. file, "CLAMP", "CLAMP", "TRILINEAR") if flip then x:SetTexCoord(1, 0, 0, 1) end else x:SetColorTexture(1, 1, 1, 1) end
      return x
    end
    o.fl, o.fr, o.fm = tx("pill_cap", false, "BACKGROUND"), tx("pill_cap", true, "BACKGROUND"), tx(nil, false, "BACKGROUND")
    o.rl, o.rr, o.rt, o.rb = tx("pill_rim", false, "BORDER"), tx("pill_rim", true, "BORDER"), tx(nil, false, "BORDER"), tx(nil, false, "BORDER")
    o.fl:SetPoint("TOPLEFT") o.fl:SetPoint("BOTTOMLEFT") o.fr:SetPoint("TOPRIGHT") o.fr:SetPoint("BOTTOMRIGHT")
    o.fm:SetPoint("TOPLEFT", o.fl, "TOPRIGHT") o.fm:SetPoint("BOTTOMRIGHT", o.fr, "BOTTOMLEFT")
    o.rl:SetPoint("TOPLEFT") o.rl:SetPoint("BOTTOMLEFT") o.rr:SetPoint("TOPRIGHT") o.rr:SetPoint("BOTTOMRIGHT")
    o.rt:SetPoint("TOPLEFT", o.rl, "TOPRIGHT") o.rt:SetPoint("TOPRIGHT", o.rr, "TOPLEFT") o.rt:SetHeight(1)
    o.rb:SetPoint("BOTTOMLEFT", o.rl, "BOTTOMRIGHT") o.rb:SetPoint("BOTTOMRIGHT", o.rr, "BOTTOMLEFT") o.rb:SetHeight(1)
    function o.size(w) f:SetSize(w, h) for _, x in ipairs({ o.fl, o.fr, o.rl, o.rr }) do x:SetWidth(h / 2) end end
    function o.set(bg, rim)
      for _, x in ipairs({ o.fl, o.fr, o.fm }) do x:SetVertexColor(bg[1], bg[2], bg[3], bg[4]) end
      for _, x in ipairs({ o.rl, o.rr, o.rt, o.rb }) do if rim then x:SetVertexColor(rim[1], rim[2], rim[3], rim[4]) x:Show() else x:Hide() end end
    end
    o.size(h)
    return o
  end
  local function edge(f, r, c)
    local t = {}
    local function q(tc, p) local x = f:CreateTexture(nil, "BORDER") x:SetTexture(MEDIA .. "ring6", "CLAMP", "CLAMP", "TRILINEAR") x:SetTexCoord(unpack(tc)) x:SetSize(r, r) x:SetPoint(p) t[#t + 1] = x return x end
    local tl, tr, bl, br = q({ 0, 0.5, 0, 0.5 }, "TOPLEFT"), q({ 0.5, 1, 0, 0.5 }, "TOPRIGHT"), q({ 0, 0.5, 0.5, 1 }, "BOTTOMLEFT"), q({ 0.5, 1, 0.5, 1 }, "BOTTOMRIGHT")
    local function ln(a1, o1, p1, a2, o2, p2, vert) local x = f:CreateTexture(nil, "BORDER") x:SetColorTexture(1, 1, 1, 1) x:SetPoint(a1, o1, p1) x:SetPoint(a2, o2, p2) if vert then x:SetWidth(1) else x:SetHeight(1) end t[#t + 1] = x end
    ln("TOPLEFT", tl, "TOPRIGHT", "TOPRIGHT", tr, "TOPLEFT") ln("BOTTOMLEFT", bl, "BOTTOMRIGHT", "BOTTOMRIGHT", br, "BOTTOMLEFT")
    ln("TOPLEFT", tl, "BOTTOMLEFT", "BOTTOMLEFT", bl, "TOPLEFT", true) ln("TOPRIGHT", tr, "BOTTOMRIGHT", "BOTTOMRIGHT", br, "TOPRIGHT", true)
    for _, x in ipairs(t) do x:SetVertexColor(c[1], c[2], c[3], c[4]) end
    return t
  end
  local function hsep(f, top, y)
    local x = f:CreateTexture(nil, "BORDER") x:SetColorTexture(1, 1, 1, 18 / 255) x:SetHeight(1)
    if top then x:SetPoint("TOPLEFT", 1, -y) x:SetPoint("TOPRIGHT", -1, -y) else x:SetPoint("BOTTOMLEFT", 1, y) x:SetPoint("BOTTOMRIGHT", -1, y) end
    return x
  end
  local EDGEC = { 0.910, 0.780, 0.416, 64 / 255 }
  local function strip(parent, h, where, alpha, round, rr)
    local s = CreateFrame("Frame", nil, parent)
    if where == "TOP" then s:SetPoint("TOPLEFT") s:SetPoint("TOPRIGHT") else s:SetPoint("BOTTOMLEFT") s:SetPoint("BOTTOMRIGHT") end
    s:SetHeight(h)
    s.tex, s.a = plate(s, "BACKGROUND", rr or 4, round), alpha
    for _, t in ipairs(s.tex) do t:SetVertexColor(1, 1, 1, alpha) end
    function s.hi(on) for _, t in ipairs(s.tex) do if on then t:SetVertexColor(0.878, 0.725, 0.353, 0.6) else t:SetVertexColor(1, 1, 1, s.a) end end end
    return s
  end
  local function flatTab(parent, label)
    local b = CreateFrame("Button", nil, parent)
    b.t = b:CreateFontString(nil, "OVERLAY") b.t:SetFont(UIFONT, 11.5, "") b.t:SetPoint("CENTER", 0, -0.5)
    b.t:SetShadowOffset(0, 0)
    b.t:SetText(label or "") b.t:SetTextColor(TABOFF[1], TABOFF[2], TABOFF[3])
    b:SetSize(50, 28)
    b.disc = b:CreateTexture(nil, "BACKGROUND") b.disc:SetAllPoints() b.disc:SetColorTexture(1, 1, 1, 0.09) b.disc:Hide()
    b.under = b:CreateTexture(nil, "ARTWORK") b.under:SetColorTexture(TABUL[1], TABUL[2], TABUL[3], 1) b.under:SetHeight(2)
    b.under:SetPoint("BOTTOMLEFT", 4, 0) b.under:SetPoint("BOTTOMRIGHT", -4, 0) b.under:Hide()
    b.glow = b:CreateTexture(nil, "OVERLAY") b.glow:SetTexture(MEDIA .. "hb_disc", "CLAMP", "CLAMP", "TRILINEAR") b.glow:SetSize(6, 6)
    b.glow:SetPoint("TOPRIGHT", -3, -4) b.glow:SetVertexColor(DOT[1], DOT[2], DOT[3], 1) b.glow:Hide()
    return b
  end
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
  local function flatBtn(parent, w, h, label)
    local b = CreateFrame("Button", nil, parent) b:SetSize(w, h)
    for _, t in ipairs(plate(b, "BACKGROUND", 3, R_ALL)) do t:SetVertexColor(1, 1, 1, 0.06) end
    local hl = b:CreateTexture(nil, "HIGHLIGHT") hl:SetPoint("TOPLEFT", 3, 0) hl:SetPoint("BOTTOMRIGHT", -3, 0) hl:SetColorTexture(1, 1, 1, 0.05)
    b.t = b:CreateFontString(nil, "OVERLAY") b.t:SetFont(STANDARD_TEXT_FONT, 12, "") b.t:SetPoint("CENTER") b.t:SetTextColor(HEADTXT, HEADTXT, HEADTXT) b.t:SetText(label or "")
    return b
  end
  local function flatPopup(f, titleSize)
    for _, t in ipairs(plate(f, "BACKGROUND", 4, R_ALL)) do t:SetVertexColor(0.086, 0.086, 0.09, 0.93) end
    local head = strip(f, 28, "TOP", 0.05, R_TOP)
    local title = head:CreateFontString(nil, "OVERLAY") title:SetFont(STANDARD_TEXT_FONT, titleSize or 12, "") title:SetPoint("LEFT", 12, 0)
    title:SetTextColor(HEADTXT, HEADTXT, HEADTXT)
    return title, head
  end

  local fontOK = {}
  local FACES = { maple = { "GJ_MapleBold", "GJ_MapleLight" }, wow = { "GJ_UI", "GJ_UILight" }, bing = { "GJ_Binggrae", "GJ_Binggrae" }, malgun = { "GJ_MalgunBold", "GJ_Malgun" } }
  local function fontFile()
    local c = cfg()
    local fc = FACES[c.face or ""]
    if fc then
      for _, nm in ipairs(c.thin and { fc[2], fc[1] } or { fc[1] }) do
        local path = MEDIA .. nm .. ".ttf"
        if fontOK[path] == nil then
          local fp = UIParent:CreateFontString(nil, "OVERLAY")
          local ok = fp:SetFont(path, 12, "")
          fontOK[path] = (ok ~= false) and (fp:GetFont() ~= nil)
          fp:Hide()
        end
        if fontOK[path] then return path end
      end
    end
    local f = ChatFontNormal and ChatFontNormal:GetFont() return f or STANDARD_TEXT_FONT
  end
  NT.chatFace = fontFile
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
  local UD = {}
  local fillTex
  local function bgAlpha() local v = cfg().bg if NT.tr().bgOff then v = math.max(v, 0.9) end return v * 0.94 end
  local function applyBg() local a = bgAlpha() if fillTex then for _, t in ipairs(fillTex) do t:SetVertexColor(0.067, 0.067, 0.071, a) end end if UD.win then for _, U in pairs(UD.win) do for _, t in ipairs(U.fill) do t:SetVertexColor(0.067, 0.067, 0.071, a) end end end end

  local function selTab(key)
    local uw = UD.of and UD.of(key)
    if uw then uw.act = key else active = key end
    for k, m in pairs(frames) do
      local w = UD.of and UD.of(k)
      if w then m:SetShown(w.act == k and UD.win[w.id] ~= nil) else m:SetShown(k == active) end
    end
    for _, md in ipairs(medals) do
      local on = (UD.isAct and UD.isAct(md.key)) or (not UD.isAct and md.key == key)
      md.under:SetShown(on)
      if on then md.t:SetTextColor(TABON[1], TABON[2], TABON[3]) else md.t:SetTextColor(TABOFF[1], TABOFF[2], TABOFF[3]) end
      if on then md.unread = nil md.glow:Hide() if md.spin then md.spin:Hide() end end
      md.glow:SetShown(not on and md.unread and true or false)
    end
    if frames[key] then frames[key]:ResetAllFadeTimes() end
  end
  local function route(text, r, g, b, quiet)
    if not P then return end
    local gk = groupOf(r, g, b)
    local ck = chanOf(text)
    local key = ck or G2K[gk] or "sys"
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
        if not quiet and tb.key ~= "all" and not (UD.isAct and UD.isAct(tb.key)) then for _, md in ipairs(medals) do if md.key == tb.key then md.unread = true md.glow:Show() end end end
      end
    end
  end
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
    NT.onEvent(CE, function(_, e, ...)
      local n, args = pk(...)
      local msg, sender, _, chName, _, _, _, idx, base, _, lineID, guid = ...
      if not P or secret(msg) or secret(sender) or type(sender) ~= "string" then return end
      lineID = tonumber(lineID)
      if lineID and chDone[lineID] then return end
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
  local function refill(key)
    local m = frames[key] if not m then return end
    m:Clear()
    local f = filt(key)
    for _, h in ipairs(hist) do if shows(f, h[5], key) then pcall(m.AddMessage, m, h[1], h[2], h[3], h[4]) end end
  end
  local rebuildTabs
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
      local function nameOK(self) local tx = self:GetText() or "" if tx:sub(1, 1) == "/" then self:SetText(tabLabel(self.k)) return false end return true end
      local function nameDone(self) if self.k and nameOK(self) then setLabel(self.k, self:GetText(), false) end self:ClearFocus() end
      nb:SetScript("OnEnterPressed", nameDone) nb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
      nb:SetScript("OnEditFocusLost", function(self) if self.k and nameOK(self) then setLabel(self.k, self:GetText(), false) end end)
      fpop.nb = nb
      fpop.rows, fpop.heads = {}, {}
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
      local dk = CreateFrame("Button", nil, fpop) dk:SetSize(100, 18)
      dk.t = dk:CreateFontString(nil, "OVERLAY") dk.t:SetFont(STANDARD_TEXT_FONT, 11, "") dk.t:SetPoint("LEFT") dk.t:SetTextColor(COPPER[1], COPPER[2], COPPER[3]) dk.t:SetText("원래 창에 붙이기")
      dk:SetScript("OnClick", function() local k = fpop.key fpop:Hide() UD.moveTab(k, "main") end)
      fpop.dock = dk
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
    local uw = UD.of(md.key)
    fpop:ClearAllPoints() fpop:SetPoint("BOTTOMLEFT", (uw and UD.win[uw.id]) or P, "BOTTOMRIGHT", 8, 0)
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
    fpop.dock:ClearAllPoints() fpop.dock:SetPoint("TOPLEFT", custom and 110 or 14, y - 6) fpop.dock:SetShown(UD.of(k) and true or false)
    fpop.rs:ClearAllPoints() fpop.rs:SetPoint("TOPRIGHT", -14, y - 6)
    fpop:SetHeight(-y + 34)
  end

  local KILL = { "GeneralDockManager", "ChatFrameMenuButton", "ChatFrameChannelButton", "ChatFrameToggleVoiceDeafenButton", "ChatFrameToggleVoiceMuteButton", "QuickJoinToastButton", "ChatAlertFrame" }
  local grave = CreateFrame("Frame") grave:Hide()
  local function bury(x)
    if x and x.GetParent and x:GetParent() ~= grave and not (x.IsProtected and x:IsProtected()) then
      if x.__ntPar == nil then x.__ntPar = x:GetParent() or false end
      pcall(x.SetParent, x, grave)
    end
  end
  local function unbury(x)
    if x and x.__ntPar and x.GetParent and x:GetParent() == grave then pcall(x.SetParent, x, x.__ntPar) end
  end
  local function bgOffG() local d = NangmanTranslatorDB return d and type(d.translate) == "table" and d.translate.bgOff and true or false end
  function NT.chatDual() return (cfg().dual and (NT.trOn() or bgOffG())) and true or false end
  function NT.chatNativeOff() return (cfg().native and not NT.trOn()) and true or false end
  function NT.chatNative() return (cfg().native and not NT.trOn()) or NT.chatDual() end
  local function showBlizz()
    for i = 1, (NUM_CHAT_WINDOWS or 10) do unbury(_G["ChatFrame" .. i .. "Tab"]) unbury(_G["ChatFrame" .. i .. "ButtonFrame"]) end
    unbury(_G.GeneralDockManager) unbury(_G.ChatFrameMenuButton) unbury(_G.ChatFrameChannelButton) unbury(_G.QuickJoinToastButton)
    for i = 1, (NUM_CHAT_WINDOWS or 10) do
      local cf = _G["ChatFrame" .. i]
      if cf then
        if cf:GetAlpha() < 1 then cf:SetAlpha(1) end
        if not cf:IsMouseEnabled() then cf:EnableMouse(true) end
        if cf.EnableMouseWheel then cf:EnableMouseWheel(true) end
      end
      for _, suf in ipairs({ "Tab", "ButtonFrame" }) do
        local x = _G["ChatFrame" .. i .. suf]
        if x then if x:GetAlpha() < 1 then x:SetAlpha(1) end if x.EnableMouse and not x:IsMouseEnabled() then x:EnableMouse(true) end end
      end
    end
    for _, n in ipairs(KILL) do
      local x = _G[n]
      if x and x.SetAlpha then if x:GetAlpha() < 1 then x:SetAlpha(1) end if n ~= "ChatAlertFrame" and x.EnableMouse and not x:IsMouseEnabled() then pcall(x.EnableMouse, x, true) end end
    end
  end
  local function hideBlizz()
    if NT.chatNative() then return end
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
    if c.pos and NT.stripY then c.pos[2] = NT.stripY(P, c.pos[1], c.pos[2]) end
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
    if NT.geoNow then NT.geoNow() end
  end
  local function lockClick(_, btn)
    if btn ~= "RightButton" or not IsControlKeyDown() then return end
    cfg().locked = not cfg().locked
    if UIErrorsFrame then UIErrorsFrame:AddMessage(cfg().locked and "대화창 고정" or "대화창 고정 풀림", 1, 0.84, 0.42) end
  end

  SLASH_NTCHATSET1 = "/ntchat"
  local function ntChatRun(arg)
    arg = ((arg or ""):gsub("^%s+", ""):gsub("%s+$", ""))
    local cmd, rest = arg:match("^(%S+)%s*(.*)$")
    if not cmd then return end
    if NT.seen then NT.seen() end
    if cmd == "hi" then if NT.trAck then NT.trAck("hi") end return end
    if cmd == "uplace" or cmd == "ulock" or cmd == "undock" or cmd == "lock" or cmd == "nudge" then rest = rest:gsub("(%d)[%a\128-\255]+$", "%1") end
    local c = cfg()
    if cmd == "tell" then
      if rest and rest ~= "" then
        local who = rest
        C_Timer.After(0.15, function()
          local fn = ChatFrame_SendTell or (ChatFrameUtil and ChatFrameUtil.SendTell)
          if fn then pcall(fn, who) end
        end)
      end
    elseif cmd == "friends" then
      if ToggleFriendsFrame then pcall(ToggleFriendsFrame, 1) elseif FriendsFrame then if FriendsFrame:IsShown() then HideUIPanel(FriendsFrame) else ShowUIPanel(FriendsFrame) end end
    elseif cmd == "feed" then
      NT.db().partyFeedOn = (rest == "1")
      if rest ~= "1" and NT.feedClear then pcall(NT.feedClear) end
    elseif cmd == "cfont" then
      local n = tonumber(rest) if n then c.cfont = math.max(9, math.min(24, math.floor(n + 0.5))) feedChanged() lookSave() end
    elseif cmd == "choff" then
      cfg().cenChOff = rest
      if NT.chatSettingsRefresh then NT.chatSettingsRefresh() end
    elseif cmd == "trst" then
      local st = {}
      for kk, vv in rest:gmatch("(%w+)=(%S*)") do
        if kk == "t" then st.tr = {} for k2 in vv:gmatch("[^.]+") do st.tr[k2] = true end
        elseif kk == "och" then st.och = {} for nm, on in vv:gmatch("([^.~]+)~(%d)") do st.och[#st.och + 1] = { n = nm:gsub("_", " "), on = on == "1" } end
        elseif kk == "vs" then st.vs = vv:gsub("_", " ")
        else st[kk] = (vv == "1") end
      end
      NT.db().trState = st
      if NT.chatSettingsRefresh then NT.chatSettingsRefresh() end
    elseif cmd == "ui" then
      local ver, k, bg, nat, face, th, fade, fz, du = rest:match("^(%d+)%s+(%S+)%s+(%S+)%s+(%S+)%s+(%S+)%s+(%S+)%s+(%S+)%s+(%S+)%s*(%S*)")
      ver = tonumber(ver)
      if ver then
        if (c.uiv or 0) > ver then
          if NT.push then
            for _, kv in ipairs({ { "keep", c.keep and "1" or "0" }, { "bg", string.format("%.2f", c.bg) }, { "native", c.native and "1" or "0" }, { "face", c.face or "maple" }, { "thin", c.thin and "1" or "0" }, { "fade", tostring(c.fade or 60) }, { "fz", tostring(c.font) }, { "dual", c.dual and "1" or "0" } }) do pcall(NT.push, "D", "ui", kv[1], kv[2]) end
          end
        else
          c.uiv = ver
          c.keep = (k == "1")
          local n = tonumber(bg) if n then c.bg = math.max(0, math.min(1, n)) pcall(applyBg) end
          c.face = face c.thin = (th == "1")
          local f2 = tonumber(fade) if f2 then c.fade = f2 pcall(applyFade) end
          local z = tonumber(fz) if z and z >= 9 and z <= 20 then c.font = z end
          pcall(applyFont)
          if du and du ~= "" then c.dual = (du == "1") end
          c.native = (nat == "1") if NT.syncNative then NT.syncNative() end
          lookSave()
        end
        if NT.chatSettingsRefresh then NT.chatSettingsRefresh() end
      end
    elseif cmd == "center" then
      local k, v = rest:match("^(%S+)%s+(%S+)$")
      if k and not CENTER_KEYS[k] then for long, short in pairs(CENTER_KEYS) do if short == k then k = long break end end end
      if k and c.center and CENTER_KEYS[k] then c.center[k] = (v == "1") feedChanged() end
    elseif cmd == "bg" then
      local n = tonumber(rest) if n then c.bg = math.max(0, math.min(1, n)) applyBg() end
    elseif cmd == "sync" then
      local k, bg, nat, face, th = rest:match("^(%S+)%s+(%S+)%s+(%S+)%s+(%S+)%s+(%S+)$")
      if k then
        c.keep = (k == "1")
        local n = tonumber(bg) if n then c.bg = math.max(0, math.min(1, n)) applyBg() end
        c.face = face c.thin = (th == "1") applyFont() if NT.feedRefresh then pcall(NT.feedRefresh) end
        c.native = (nat == "1") if NT.syncNative then NT.syncNative() end
      end
    elseif cmd == "face" then
      local k, th = rest:match("^(%S+)%s*(%S*)$")
      if k then c.face = k c.thin = (th == "1") applyFont() if NT.feedRefresh then pcall(NT.feedRefresh) end end
    elseif cmd == "native" then
      c.native = (rest == "1") if NT.syncNative then NT.syncNative() end
    elseif cmd == "keep" then
      c.keep = (rest == "1")
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
    elseif cmd == "place" and P then
      local x, y, w, h = rest:match("^(%S+)%s+(%S+)%s+(%S+)%s+(%S+)$")
      x, y, w, h = tonumber(x), tonumber(y), tonumber(w), tonumber(h)
      if x and y and w and h then
        local sw, sh = UIParent:GetWidth(), UIParent:GetHeight()
        w = math.max(240, math.min(sw, w)) h = math.max(120, math.min(sh, h))
        c.pos = { math.max(0, math.min(sw - w, x)), math.max(0, math.min(sh - h, sh - y - h)) }
        c.w, c.h = w, h
        place()
      end
    elseif cmd == "lock" then
      c.locked = (rest == "1")
    elseif cmd == "uplace" and P then
      local id, x, y, w, h = rest:match("^(%S+)%s+(%S+)%s+(%S+)%s+(%S+)%s+(%S+)$")
      local uw = id and UD.get(id)
      x, y, w, h = tonumber(x), tonumber(y), tonumber(w), tonumber(h)
      if uw and x and y and w and h then
        local sw, sh = UIParent:GetWidth(), UIParent:GetHeight()
        w = math.max(180, math.min(sw, w)) h = math.max(90, math.min(sh, h))
        uw.pos = { math.max(0, math.min(sw - w, x)), math.max(0, math.min(sh - h, sh - y - h)) }
        uw.w, uw.h = w, h
        UD.place(uw)
      end
    elseif cmd == "ulock" then
      local id, v = rest:match("^(%S+)%s+(%S+)$")
      local uw = id and UD.get(id)
      if uw and (v == "1") ~= (uw.locked and true or false) then UD.lock(id) end
    elseif cmd == "utab" and P then
      if tabBtns[rest] then selTab(rest) end
    elseif cmd == "undock" and P then
      local k, x, y = rest:match("^(%S+)%s+(%S+)%s+(%S+)$")
      x, y = tonumber(x), tonumber(y)
      if k and x and y then UD.moveTab(k, "new", { x, UIParent:GetHeight() - y }) end
    elseif cmd == "dock" and P then
      if UD.of(rest) then UD.moveTab(rest, "main") end
    elseif cmd == "dockw" and P then
      if UD.get(rest) then UD.dockAll(rest) end
    elseif cmd == "umove" and P then
      local k, id = rest:match("^(%S+)%s+(%S+)$")
      if k and id and UD.get(id) then UD.moveTab(k, id) end
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
    elseif cmd == "tabs" then
      local v, i, n, chunk = rest:match("^(%d+)%s+(%d+)/(%d+)%s*(.*)$")
      tabsIn(tonumber(v), tonumber(i), tonumber(n), chunk or "")
      return
    elseif cmd == "leave" and rest ~= "" then
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
  local doneSq, doneN = {}, 0
  SlashCmdList.NTCHATSET = function(arg)
    arg = arg or ""
    local body, sq = arg:match("^(.-)%s+#(%d+)[%a\128-\255]*%s*$")
    if sq then
      if not doneSq[sq] then
        doneSq[sq] = true doneN = doneN + 1
        if doneN > 300 then doneSq = { [sq] = true } doneN = 1 end
        ntChatRun(body)
      end
      if NT.trAck then NT.trAck(sq) end
      return
    end
    ntChatRun(arg)
  end

  local settings
  local SXW = 392
  local SX = { cream = { 0.941, 0.941, 0.941 }, gold = { 0.890, 0.765, 0.604 }, sub = { 0.816, 0.816, 0.816 }, mut = { 0.541, 0.541, 0.541 }, seg = { 0.722, 0.722, 0.722 }, dark = { 0.078, 0.078, 0.078 } }
  local TRC = { say = "ffffff", party = "aaaaff", raid = "ff7f00", inst = "aad4ff", whisper = "ff80ff", guild = "40ff40", lfg = "ffc0c0", general = "ffc0c0", trade = "ffc0c0", otherch = "ffc0c0" }
  local TRN = { say = "일반 · 외침", party = "파티", raid = "공격대", inst = "인던", whisper = "귓말", guild = "길드", lfg = "파티찾기", general = "공개 채널", trade = "거래", otherch = "그 밖 채널" }
  local TRK = { "say", "party", "raid", "inst", "guild", "whisper", "lfg", "general", "trade", "otherch" }
  local function hxc(s) return { tonumber(s:sub(1, 2), 16) / 255, tonumber(s:sub(3, 4), 16) / 255, tonumber(s:sub(5, 6), 16) / 255 } end
  local function trState() local D = NT.db() if type(D.trState) ~= "table" then D.trState = {} end return D.trState end
  local function trAlive() return (NT.alive and NT.alive()) and true or false end
  local function toPC(kind, k, v) if NT.push then pcall(NT.push, "D", kind, k or "", v or "") end end
  local function uiVer() cfg().uiv = time() end
  local function makeSettings()
    local s = CreateFrame("Frame", "NangmanTrChatSettings", P)
    s:SetWidth(SXW + 30) s:SetFrameStrata("FULLSCREEN_DIALOG") s:SetToplevel(true) s:EnableMouse(true) s:SetClampedToScreen(true)
    for _, t in ipairs(plate(s, "BACKGROUND", 8, R_ALL)) do t:SetVertexColor(0.086, 0.086, 0.090, 0.95) end
    edge(s, 8, { 1, 1, 1, 31 / 255 })
    local sf = CreateFrame("ScrollFrame", nil, s) sf:SetPoint("TOPLEFT", 0, -11) sf:SetPoint("BOTTOMRIGHT", 0, 11)
    local SC = CreateFrame("Frame", nil, sf) SC:SetSize(SXW + 30, 10) sf:SetScrollChild(SC)
    local C = CreateFrame("Frame", nil, SC) C:SetPoint("TOPLEFT", 15, 0) C:SetSize(SXW, 10)
    sf:EnableMouseWheel(true)
    sf:SetScript("OnMouseWheel", function(self, d) local m = math.max(0, SC:GetHeight() - self:GetHeight()) self:SetVerticalScroll(math.max(0, math.min(m, self:GetVerticalScroll() - d * 40))) end)
    local pools, used = {}, {}
    local function get(kind, make)
      pools[kind] = pools[kind] or {} used[kind] = (used[kind] or 0) + 1
      local o = pools[kind][used[kind]]
      if not o then o = make() pools[kind][used[kind]] = o end
      o:ClearAllPoints() o:Show()
      return o
    end
    local function fs(o, size, face) local t = o:CreateFontString(nil, "OVERLAY") t:SetFont(face or fontFile(), size, "") t:SetShadowOffset(0, 0) t:SetWordWrap(false) return t end
    local function col(t, c) t:SetTextColor(c[1], c[2], c[3]) end
    local function box(o, r, layer) local p = plate(o, layer or "BACKGROUND", r, R_ALL) o.bgp = p function o.bg(c, a) for _, x in ipairs(p) do x:SetVertexColor(c[1], c[2], c[3], a) end end return o end
    local rebuild
    local function act(o, f) o:SetScript("OnClick", function() f() rebuild() end) end
    local y, dim = 0, nil
    local function putAt(o, x, h, w) o:SetPoint("TOPLEFT", C, "TOPLEFT", x or 0, -y) if w then o:SetWidth(w) end if h then o:SetHeight(h) end if o.SetAlpha then o:SetAlpha(dim or 1) end if o.EnableMouse then o:EnableMouse(not dim) end end
    local function text(str, size, c, x, dy, face)
      local o = get("text", function() local f = CreateFrame("Frame", nil, C) f.t = fs(f, 12) f.t:SetPoint("TOPLEFT") return f end)
      o.t:SetFont(face or fontFile(), size, "") o.t:SetText(str) col(o.t, c) o.t:SetWordWrap(true) o.t:SetWidth(SXW - (x or 0)) o.t:SetJustifyH("LEFT")
      o:SetSize(SXW - (x or 0), o.t:GetStringHeight()) o:SetPoint("TOPLEFT", C, "TOPLEFT", x or 0, -(y + (dy or 0))) o:SetAlpha(dim or 1)
      return o
    end
    local function toggle(parent, on)
      local tg = parent.tg
      if not tg then
        tg = CreateFrame("Frame", nil, parent) tg.pl = pill(tg, 18) tg.pl.size(34)
        tg.kn = tg:CreateTexture(nil, "OVERLAY") tg.kn:SetTexture(MEDIA .. "hb_disc", "CLAMP", "CLAMP", "TRILINEAR") tg.kn:SetSize(14, 14)
        parent.tg = tg
      end
      tg.pl.set(on and { COPPER[1], COPPER[2], COPPER[3], 1 } or { 1, 1, 1, 38 / 255 }, nil)
      tg.kn:ClearAllPoints() tg.kn:SetPoint(on and "RIGHT" or "LEFT", on and -2 or 2, 0)
      return tg
    end
    local function head(str, badge, warm)
      local o = get("head", function()
        local f = CreateFrame("Frame", nil, C) f.b = f:CreateTexture(nil, "BACKGROUND") f.b:SetColorTexture(1, 1, 1, 18 / 255) f.b:SetPoint("TOPLEFT", -15, 0) f.b:SetPoint("BOTTOMRIGHT", 15, 0)
        f.t = fs(f, 12) f.t:SetPoint("LEFT", 0, 0)
        f.bd = CreateFrame("Frame", nil, f) f.bd.pl = pill(f.bd, 16) f.bd.t = fs(f.bd, 10.5) f.bd.t:SetPoint("CENTER", 0, 0)
        return f
      end)
      y = y + 12
      o:SetPoint("TOPLEFT", C, "TOPLEFT", 0, -y) o:SetSize(SXW, 24) o:SetAlpha(dim or 1)
      o.t:SetFont(fontFile(), 12, "") o.t:SetText(str) col(o.t, { 0.902, 0.902, 0.902 })
      if badge then
        o.bd.t:SetFont(fontFile(), 10.5, "") o.bd.t:SetText(badge) col(o.bd.t, warm and SX.gold or SX.sub)
        o.bd.pl.size(math.floor(o.bd.t:GetStringWidth() + 14.5)) o.bd.pl.set(warm and { COPPER[1], COPPER[2], COPPER[3], 46 / 255 } or { 1, 1, 1, 20 / 255 }, nil)
        o.bd:ClearAllPoints() o.bd:SetPoint("LEFT", o.t, "RIGHT", 8, 0) o.bd:Show()
      else o.bd:Hide() end
      y = y + 24 + 7
    end
    local function switch(x, w, label, sub, on, f)
      local o = get("sw", function() local b = box(CreateFrame("Button", nil, C), 6) b.l = fs(b, 12.5) b.s = fs(b, 9.5) return b end)
      putAt(o, x, 38, w) o.bg({ 1, 1, 1 }, 10 / 255)
      o.l:SetFont(fontFile(), 12.5, "") o.l:SetText(label) col(o.l, on and SX.cream or SX.sub)
      o.s:SetFont(fontFile(), 9.5, "") o.s:SetText(sub or "") col(o.s, SX.mut)
      o.l:ClearAllPoints() o.s:ClearAllPoints()
      if sub and sub ~= "" then o.l:SetPoint("BOTTOMLEFT", o, "LEFT", 12, 1) o.s:SetPoint("TOPLEFT", o, "LEFT", 12, -1) else o.l:SetPoint("LEFT", 12, 0) end
      o.s:SetWidth(w - 62) o.l:SetWidth(w - 62)
      local tg = toggle(o, on) tg:ClearAllPoints() tg:SetPoint("RIGHT", -10, 0)
      act(o, f)
      return o
    end
    local function chips(list)
      local x, rowH = 0, 26
      for _, it in ipairs(list) do
        local o = get("chip", function()
          local b = CreateFrame("Button", nil, C) b.pl = pill(b, 26)
          b.dot = b:CreateTexture(nil, "ARTWORK") b.dot:SetTexture(MEDIA .. "hb_disc", "CLAMP", "CLAMP", "TRILINEAR") b.dot:SetSize(8, 8) b.dot:SetPoint("LEFT", 10, 0)
          b.l = fs(b, 11.5) b.l:SetPoint("LEFT", b.dot, "RIGHT", 6, 0)
          return b
        end)
        o.l:SetFont(fontFile(), 11.5, "") o.l:SetText(it.label) col(o.l, it.on and SX.gold or SX.mut)
        local w = math.floor(10 + 8 + 6 + o.l:GetStringWidth() + 11 + 0.5)
        o.pl.size(w) o.pl.set(it.on and { COPPER[1], COPPER[2], COPPER[3], 56 / 255 } or { 1, 1, 1, 13 / 255 }, nil)
        local c = it.color or { 1, 1, 1 } o.dot:SetVertexColor(c[1], c[2], c[3], it.on and 1 or 0.5)
        if x > 0 and x + w > SXW then x = 0 y = y + rowH + 6 end
        o:SetPoint("TOPLEFT", C, "TOPLEFT", x, -y) o:SetAlpha(dim or 1) o:EnableMouse(not dim)
        act(o, it.f)
        x = x + w + 6
      end
      if #list > 0 then y = y + rowH + 6 end
    end
    local function seg(items, cur, f, cols)
      local n = cols or #items
      local cw = (SXW + 5) / n - 5
      for i, it in ipairs(items) do
        local o = get("seg", function() local b = box(CreateFrame("Button", nil, C), 6) b.l = fs(b, 11.5) b.l:SetPoint("CENTER", 0, 0) return b end)
        local on = (it[1] == cur)
        local ci = (i - 1) % n
        o:SetPoint("TOPLEFT", C, "TOPLEFT", ci * (cw + 5), -(y + math.floor((i - 1) / n) * 35)) o:SetSize(cw, 30) o:SetAlpha(dim or 1)
        if on then o.bg({ COPPER[1], COPPER[2], COPPER[3] }, 230 / 255) else o.bg({ 1, 1, 1 }, 13 / 255) end
        o.l:SetFont(it[3] or fontFile(), it[4] or 11.5, "") o.l:SetText(it[2]) col(o.l, on and SX.dark or SX.seg)
        act(o, function() f(it[1]) end)
        if it.new and not o.nb then o.nb = o:CreateTexture(nil, "OVERLAY", nil, 6) o.nt = o:CreateFontString(nil, "OVERLAY") o.nt:SetDrawLayer("OVERLAY", 7) end
        if o.nb then
          if it.new then
            o.nt:SetFont(STANDARD_TEXT_FONT, 7.5, "") o.nt:SetText("NEW") o.nt:SetTextColor(0.08, 0.08, 0.09, 1)
            o.nb:SetColorTexture(0.878, 0.725, 0.353, 1) o.nb:ClearAllPoints() o.nb:SetPoint("TOPRIGHT", o, "TOPRIGHT", 4, 6) o.nb:SetSize(math.floor(o.nt:GetStringWidth() + 9), 11)
            o.nt:ClearAllPoints() o.nt:SetPoint("CENTER", o.nb, "CENTER", 0, 0) o.nb:Show() o.nt:Show()
          else o.nb:Hide() o.nt:Hide() end
        end
      end
      y = y + math.ceil(#items / n) * 35 - 5
    end
    local function key(x, sym, f)
      local o = get("key", function()
        local b = box(CreateFrame("Button", nil, C), 4)
        b.h = b:CreateTexture(nil, "OVERLAY") b.h:SetColorTexture(1, 1, 1, 1) b.h:SetSize(8, 1.5) b.h:SetPoint("CENTER", 0, 0)
        b.v = b:CreateTexture(nil, "OVERLAY") b.v:SetColorTexture(1, 1, 1, 1) b.v:SetSize(1.5, 8) b.v:SetPoint("CENTER", 0, 0)
        return b
      end)
      o:SetSize(26, 24) o:SetPoint("TOPLEFT", C, "TOPLEFT", x, -(y + 7)) o.bg({ 1, 1, 1 }, 31 / 255) o:SetAlpha(dim or 1)
      o.h:SetVertexColor(SX.cream[1], SX.cream[2], SX.cream[3]) o.v:SetVertexColor(SX.cream[1], SX.cream[2], SX.cream[3]) o.v:SetShown(sym == "+")
      act(o, f)
      return o
    end
    local function rowBox(h, top)
      local o = get("rowbox", function() local b = box(CreateFrame("Frame", nil, C), 6) b.l = fs(b, 12.5) b.s = fs(b, 9.5) return b end)
      y = y + (top or 0)
      o:SetPoint("TOPLEFT", C, "TOPLEFT", 0, -y) o:SetSize(SXW, h) o.bg({ 1, 1, 1 }, 10 / 255) o:SetAlpha(dim or 1)
      o.l:ClearAllPoints() o.s:ClearAllPoints() o.s:SetText("")
      return o
    end
    local fontOpen = false
    local FNM = { maple = "메이플스토리", wow = "이사만루체", bing = "빙그레", malgun = "맑은 고딕" }
    local function faceFile(k) local fc = FACES[k] if fc then local path = MEDIA .. fc[1] .. ".ttf" if fontOK[path] == nil then local fp = UIParent:CreateFontString(nil, "OVERLAY") local ok = fp:SetFont(path, 12, "") fontOK[path] = (ok ~= false) and (fp:GetFont() ~= nil) fp:Hide() end if fontOK[path] then return path end end return STANDARD_TEXT_FONT end
    local function setUI(kind, v)
      local c = cfg()
      if kind == "fz" then c.font = v applyFont() if NT.infoNow then NT.infoNow() end
      elseif kind == "face" then c.face = v applyFont()
      elseif kind == "thin" then c.thin = v applyFont()
      elseif kind == "bg" then c.bg = v applyBg()
      elseif kind == "fade" then c.fade = v applyFade()
      elseif kind == "keep" then c.keep = v
      elseif kind == "native" then c.native = v if NT.syncNative then NT.syncNative() end
      elseif kind == "dual" then c.dual = v if NT.syncNative then NT.syncNative() end end
      uiVer() lookSave()
      local sv = v
      if type(v) == "boolean" then sv = v and "1" or "0" elseif type(v) == "number" then sv = string.format("%.2f", v) end
      toPC("ui", kind, sv)
    end
    rebuild = function()
      for k in pairs(used) do used[k] = 0 end
      for _, pl in pairs(pools) do for _, o in ipairs(pl) do o:Hide() end end
      y, dim = 0, nil
      local c = cfg()
      do
        local o = get("title", function()
          local f = CreateFrame("Frame", nil, C) f.t = fs(f, 13.5) f.t:SetPoint("LEFT", 0, 0)
          f.x = CreateFrame("Button", nil, f) f.x:SetSize(22, 24) f.x:SetPoint("RIGHT", 2, 0) f.x.t = fs(f.x, 18, UIFONT) f.x.t:SetPoint("CENTER", 0, 1) f.x.t:SetText("×") col(f.x.t, { 0.639, 0.639, 0.639 })
          f.x:SetScript("OnClick", function() s:Hide() end)
          return f
        end)
        o:SetPoint("TOPLEFT", C, "TOPLEFT", 0, 0) o:SetSize(SXW, 24) o.t:SetFont(fontFile(), 13.5, "") o.t:SetText("대화창 설정") col(o.t, { 1, 1, 1 })
        y = 24
      end
      local st, alive = trState(), trAlive()
      head("번역")
      local trOnNow = NT.trOn()
      if not (alive and trOnNow) then local n = text(alive and "번역이 꺼져 있어요 · 번역을 켜면 바꿀 수 있어요" or "PC 번역기를 켜면 바꿀 수 있어요", 10.5, { 0.851, 0.718, 0.478 }, 2, -2) y = y + n:GetHeight() + 4 dim = 0.38 end
      local cw = (SXW + 8) / 2 - 8
      local sws = {
        { "번역 표시", (st.o ~= false), function() st.o = not (st.o ~= false) toPC("origoff", "", (st.o ~= false) and "1" or "0") end, function(on) return on and "원문과 함께 보기" or "번역된 글만 보기" end },
      }
      if st.vok then sws[#sws + 1] = { "디스코드 음성 번역", st.v and true or false, function() st.v = not st.v toPC("voice", "", st.v and "1" or "0") end, function() return (st.vs or "") .. " · 켜면 일반·파티·공대·귓말만 번역" end } end
      sws[#sws + 1] = { "내 이름 부르면 강조", (st.c ~= false), function() st.c = not (st.c ~= false) toPC("calloff", "", (st.c ~= false) and "1" or "0") end, function(on) return on and "주황색 · 가운데에도 띄움" or "강조 안 함" end }
      for i, it in ipairs(sws) do
        local ci = (i - 1) % 2
        switch(ci * (cw + 8), cw, it[1], it[4](it[2]), it[2], it[3])
        if ci == 1 or i == #sws then y = y + 38 + 8 end
      end
      y = y - 8
      head("번역할 대화", "모든 탭 공통", false)
      local tl = {}
      local trv = type(st.tr) == "table" and st.tr or {}
      for _, k in ipairs(TRK) do
        if k == "otherch" and type(st.och) == "table" and #st.och > 0 then
          for _, oc in ipairs(st.och) do
            local num = GetChannelName and select(1, GetChannelName(oc.n)) or 0
            tl[#tl + 1] = { label = ((num and num > 0) and (num .. ". ") or "") .. oc.n, color = hxc(TRC.otherch), on = oc.on, f = function() oc.on = not oc.on toPC("trch", "och:" .. string.lower(oc.n), oc.on and "1" or "0") end }
          end
        else
          tl[#tl + 1] = { label = TRN[k], color = hxc(TRC[k]), on = trv[k] and true or false, f = function() trv[k] = not trv[k] st.tr = trv toPC("tr", k, trv[k] and "1" or "0") end }
        end
      end
      chips(tl)
      y = y - 6
      head("보내기 번역", "받기는 늘 자체 번역", false)
      do
        local o = rowBox(44)
        local gon = st.g and true or false
        local tg = toggle(o, gon) tg:ClearAllPoints() tg:SetPoint("RIGHT", -12, 0)
        o.l:SetFont(fontFile(), 12.5, "") o.l:SetText("제미나이 번역") col(o.l, gon and SX.cream or SX.sub) o.l:SetPoint("BOTTOMLEFT", o, "LEFT", 12, 1)
        o.s:SetFont(fontFile(), 9.5, "") o.s:SetText(st.k and "GEMINI API 사용 시 보내는 번역 품질이 향상될 수 있습니다 · 키는 PC 설정에서" or "키 입력은 PC 번역기 설정에서 해 주세요") col(o.s, SX.mut) o.s:SetPoint("TOPLEFT", o, "LEFT", 12, -1)
        local hit = get("gemhit", function() local b = CreateFrame("Button", nil, C) return b end)
        hit:SetPoint("TOPLEFT", o, "TOPLEFT") hit:SetPoint("BOTTOMRIGHT", o, "BOTTOMRIGHT") hit:EnableMouse(not dim)
        act(hit, function() st.g = not st.g toPC("sendeng", "", st.g and "2" or "1") end)
        y = y + 44
      end
      dim = nil
      head("대화창")
      do
        local o = rowBox(38, 10)
        o.l:SetFont(fontFile(), 12.5, "") o.l:SetText("글자") col(o.l, SX.cream) o.l:SetPoint("LEFT", 12, 0)
        local px = SXW - 8 - 26
        key(px, "+", function() setUI("fz", math.min(20, c.font + 1)) end)
        local v = text(tostring(c.font), 13, SX.gold, 0, 0, UIFONT) v.t:SetWidth(30) v.t:SetJustifyH("CENTER") v:SetWidth(30) v:ClearAllPoints() v:SetPoint("TOPLEFT", C, "TOPLEFT", px - 30, -(y + 19 - v:GetHeight() / 2))
        key(px - 30 - 26, "−", function() setUI("fz", math.max(10, c.font - 1)) end)
        local fb = get("fontbtn", function() local b = box(CreateFrame("Button", nil, C), 4) b.l = fs(b, 11.5) b.l:SetPoint("LEFT", 10, 0) b.ar = b:CreateTexture(nil, "OVERLAY") b.ar:SetTexture(MEDIA .. "tri_down", "CLAMP", "CLAMP", "TRILINEAR") b.ar:SetSize(7, 7) b.ar:SetPoint("LEFT", b.l, "RIGHT", 4, 0) return b end)
        local cur = c.face or "maple"
        fb.l:SetFont(faceFile(cur), 11.5, "") fb.l:SetText(FNM[cur] or "메이플스토리") col(fb.l, SX.gold) fb.ar:SetVertexColor(SX.gold[1], SX.gold[2], SX.gold[3])
        if fontOpen then fb.ar:SetTexCoord(0, 1, 1, 0) else fb.ar:SetTexCoord(0, 1, 0, 1) end
        local fw = math.floor(10 + fb.l:GetStringWidth() + 4 + 7 + 8 + 0.5)
        fb:SetSize(fw, 24) fb:SetPoint("TOPLEFT", C, "TOPLEFT", px - 30 - 26 - 10 - fw, -(y + 7))
        if fontOpen then fb.bg({ COPPER[1], COPPER[2], COPPER[3] }, 56 / 255) else fb.bg({ 1, 1, 1 }, 31 / 255) end
        act(fb, function() fontOpen = not fontOpen end)
        y = y + 38
        if fontOpen then
          y = y + 5
          local fl = {}
          for _, k in ipairs({ "maple", "wow", "bing", "malgun" }) do fl[#fl + 1] = { k, FNM[k], faceFile(k), 12 } end
          seg(fl, cur, function(k) fontOpen = false setUI("face", k) end, 2)
          y = y + 5
          local gl = text("굵기", 12, SX.cream, 4, 9)
          local save = y
          local ox = 4 + gl.t:GetStringWidth() + 12
          local cw2 = (SXW - ox + 5) / 2 - 5
          for i, it in ipairs({ { false, "보통" }, { true, "얇게" } }) do
            local o = get("seg", function() local b = box(CreateFrame("Button", nil, C), 6) b.l = fs(b, 11.5) b.l:SetPoint("CENTER", 0, 0) return b end)
            local on = ((c.thin and true or false) == it[1])
            o:SetPoint("TOPLEFT", C, "TOPLEFT", ox + (i - 1) * (cw2 + 5), -y) o:SetSize(cw2, 30)
            if on then o.bg({ COPPER[1], COPPER[2], COPPER[3] }, 230 / 255) else o.bg({ 1, 1, 1 }, 13 / 255) end
            o.l:SetFont(fontFile(), 12, "") o.l:SetText(it[2]) col(o.l, on and SX.dark or SX.seg)
            act(o, function() setUI("thin", it[1]) end)
          end
          y = save + 35
        end
      end
      do
        y = y + 12
        local l = text("배경 진하기", 12.5, SX.cream, 2) local v = text(string.format("%d%%", math.floor(c.bg * 100 + 0.5)), 12, SX.gold, 0)
        v.t:SetWidth(SXW - 2) v.t:SetJustifyH("RIGHT")
        y = y + l:GetHeight() + 4
        local sl = get("slider", function()
          local f = CreateFrame("Button", nil, C)
          f.tk = f:CreateTexture(nil, "BACKGROUND") f.tk:SetColorTexture(1, 1, 1, 38 / 255) f.tk:SetHeight(4) f.tk:SetPoint("LEFT") f.tk:SetPoint("RIGHT")
          f.fl = f:CreateTexture(nil, "ARTWORK") f.fl:SetColorTexture(COPPER[1], COPPER[2], COPPER[3], 1) f.fl:SetHeight(4) f.fl:SetPoint("LEFT")
          f.kn = f:CreateTexture(nil, "OVERLAY") f.kn:SetTexture(MEDIA .. "hb_disc", "CLAMP", "CLAMP", "TRILINEAR") f.kn:SetSize(14, 14) f.kn:SetVertexColor(SX.gold[1], SX.gold[2], SX.gold[3], 1)
          function f.show(v01) local W = SXW - 4 f.fl:SetWidth(math.max(0.01, v01 * W)) f.kn:ClearAllPoints() f.kn:SetPoint("LEFT", math.max(0, v01 * W - 7), 0) if f.lab then f.lab.t:SetText(string.format("%d%%", math.floor(v01 * 100 + 0.5))) end end
          local function at() local x = GetCursorPosition() / f:GetEffectiveScale() local v01 = math.floor(math.max(0, math.min(1, (x - f:GetLeft()) / (SXW - 4))) * 20 + 0.5) / 20 return v01 end
          f:SetScript("OnMouseDown", function(self) self.drag = true local v01 = at() cfg().bg = v01 applyBg() self.show(v01) end)
          NT.onUpdate(f, function(self) if self.drag then if not IsMouseButtonDown("LeftButton") then self.drag = nil setUI("bg", cfg().bg) else local v01 = at() if v01 ~= cfg().bg then cfg().bg = v01 applyBg() self.show(v01) end end end end)
          return f
        end)
        sl.lab = v
        sl:SetPoint("TOPLEFT", C, "TOPLEFT", 0, -y) sl:SetSize(SXW, 22) sl.show(c.bg)
        y = y + 24
      end
      local function lbl(str) y = y + 10 local o = text(str, 12.5, SX.cream, 2) y = y + o:GetHeight() + 6 end
      lbl("글 사라짐")
      local fv = c.fade or 60
      seg({ { 15, "15초" }, { 30, "30초" }, { 60, "1분" }, { 120, "2분" }, { 0, "안 사라짐" } }, fv, function(v) setUI("fade", v) end)
      lbl("대화창 인터페이스")
      seg({ { false, "가만히 두면 투명" }, { true, "항상 보이기" } }, c.keep and true or false, function(v) setUI("keep", v) end)
      lbl("번역 끈 동안 대화창")
      seg({ { false, "낭만 대화창" }, { true, "와우 기본 대화창" } }, c.native and true or false, function(v) setUI("native", v) end)
      lbl("번역 중 입력")
      seg({ { false, "번역창으로 입력" }, { true, "와우 기본 대화창 같이 쓰기", new = true } }, c.dual and true or false, function(v) setUI("dual", v) end)
      do
        y = y + 14
        local fon = NT.feedEnabled and NT.feedEnabled() or false
        local card = get("card", function()
          local f = box(CreateFrame("Frame", nil, C), 8)
          edge(f, 8, { 0.431, 0.353, 0.208, 1 })
          f.lb = f:CreateTexture(nil, "BORDER") f.lb:SetColorTexture(0.431, 0.353, 0.208, 1) f.lb:SetWidth(2) f.lb:SetPoint("TOPLEFT", 1, -4) f.lb:SetPoint("BOTTOMLEFT", 1, 4)
          f.hd = CreateFrame("Button", nil, f) f.hd:SetPoint("TOPLEFT", 12, -10) f.hd:SetPoint("TOPRIGHT", -12, -10) f.hd:SetHeight(30)
          f.t = fs(f.hd, 13.5) f.t:SetPoint("TOPLEFT", 0, 0) f.s = fs(f.hd, 10) f.s:SetPoint("TOPLEFT", f.t, "BOTTOMLEFT", 0, -2)
          return f
        end)
        card.bg({ 0.878, 0.725, 0.353 }, 13 / 255)
        card:SetPoint("TOPLEFT", C, "TOPLEFT", 0, -y) card:SetWidth(SXW)
        card.t:SetFont(fontFile(), 13.5, "") card.t:SetText("집중 대화창") col(card.t, SX.gold)
        card.s:SetFont(fontFile(), 10, "") card.s:SetText(fon and "화면 가운데(캐릭터 머리 위)에 대화와 번역을 크게 · 전장에서도 여기서 번역" or "켜 두면 전장에서도 이 창으로 번역을 볼 수 있어요") col(card.s, { 0.749, 0.682, 0.525 })
        local tg = toggle(card.hd, fon) tg:ClearAllPoints() tg:SetPoint("RIGHT", 0, 0)
        card.hd:SetScript("OnClick", function()
          local D = NT.db() D.partyFeedOn = not (D.partyFeedOn == true)
          if not D.partyFeedOn and NT.feedClear then pcall(NT.feedClear) end
          feedChanged()
          rebuild()
        end)
        local y0 = y
        y = y + 10 + 30 + 4
        if fon then
          local function sub(str, top) y = y + (top or 8) local o = text(str, 10.5, SX.mut, 14) y = y + o:GetHeight() + 4 end
          local save = SXW
          SXW = save - 24
          local cx0 = 12
          sub("띄울 대화 (모든 탭 공통)", 2)
          local cl = {}
          for _, it in ipairs({ { "party", "파티", "aaaaff" }, { "raid", "공격대", "ff7f00" }, { "inst", "인던", "aad4ff" }, { "guild", "길드", "40ff40" }, { "whisper", "귓말", "ff80ff" }, { "say", "일반 · 외침", "ffffff" } }) do
            cl[#cl + 1] = { label = it[2], color = hxc(it[3]), on = c.center[it[1]] and true or false, f = function() c.center[it[1]] = not c.center[it[1]] end }
          end
          if st.vok then cl[#cl + 1] = { label = "디스코드 음성", color = hxc("ffe9b8"), on = (st.vc ~= false), f = function() st.vc = not (st.vc ~= false) toPC("vcen", "", (st.vc ~= false) and "1" or "0") end } end
          local before = used.chip or 0
          chips(cl)
          for i = before + 1, used.chip do local o = pools.chip[i] local p, rel, rp, x0, y1 = o:GetPoint(1) o:ClearAllPoints() o:SetPoint(p, rel, rp, x0 + cx0, y1) end
          sub("채널")
          local jl = joinedBases()
          if #jl == 0 then local o = text("게임에서 채널 목록을 받으면 나와요", 11, SX.mut, 14) y = y + o:GetHeight() + 6
          else
            local chl = {}
            local chOn = c.center.channel and true or false
            for _, j in ipairs(jl) do chl[#chl + 1] = { label = j.n .. ". " .. j.b, color = hxc("ffc0c0"), on = chOn and centerChOn(j.b) and true or false, f = function() toggleChOff(j.b) end } end
            before = used.chip or 0
            chips(chl)
            for i = before + 1, used.chip do local o = pools.chip[i] local p, rel, rp, x0, y1 = o:GetPoint(1) o:ClearAllPoints() o:SetPoint(p, rel, rp, x0 + cx0, y1) end
          end
          SXW = save
          y = y + 4
          local ab = get("adj", function()
            local b = box(CreateFrame("Frame", nil, C), 6) b.l = fs(b, 12.5) b.l:SetPoint("BOTTOMLEFT", b, "LEFT", 12, 1) b.s = fs(b, 9.5) b.s:SetPoint("TOPLEFT", b, "LEFT", 12, -1)
            b.btn = box(CreateFrame("Button", nil, b), 4) b.btn:SetSize(70, 22) b.btn:SetPoint("RIGHT", -8, 0) b.btn.l = fs(b.btn, 11.5) b.btn.l:SetPoint("CENTER", 0, 0)
            return b
          end)
          ab:SetPoint("TOPLEFT", C, "TOPLEFT", 12, -y) ab:SetSize(SXW - 24, 38) ab.bg({ 1, 1, 1 }, 10 / 255)
          ab.l:SetFont(fontFile(), 12.5, "") ab.l:SetText("위치 · 크기 · 줄 수 · 글자 · 사라짐") col(ab.l, SX.cream)
          ab.s:SetFont(fontFile(), 9.5, "") ab.s:SetText("글자 " .. tostring(c.cfont or 13) .. " · 조절하기를 누르면 끌어서 옮기고 크기를 바꿔요") col(ab.s, SX.mut)
          ab.btn.l:SetFont(fontFile(), 11.5, "") ab.btn.l:SetText("조절하기") col(ab.btn.l, SX.dark) ab.btn.bg({ COPPER[1], COPPER[2], COPPER[3] }, 230 / 255)
          ab.btn:SetWidth(math.floor(ab.btn.l:GetStringWidth() + 24.5))
          ab.btn:SetScript("OnClick", function() s:Hide() if NT.feedMove and not (NT.feedMoving and NT.feedMoving()) then pcall(NT.feedMove) end end)
          y = y + 38 + 12
        else
          y = y + 6
        end
        card:SetHeight(y - y0)
      end
      do
        y = y + 10
        local function link(x, str, c0, f)
          local o = get("link", function() local b = CreateFrame("Button", nil, C) b.l = fs(b, 11.5) b.l:SetPoint("LEFT", 0, 0) return b end)
          o.l:SetFont(fontFile(), 11.5, "") o.l:SetText(str) col(o.l, c0)
          local w = math.floor(o.l:GetStringWidth() + 0.5) o:SetSize(w, 18) o:SetPoint("TOPLEFT", C, "TOPLEFT", x, -y)
          o:SetScript("OnClick", f)
          return x + w + 14
        end
        local x = link(0, "사용법", SX.gold, function()
          s:Hide()
          for _, ln in ipairs({ "── 대화창 사용법 ──", "· Enter = 입력 · Tab = 보낼 곳 바꾸기 · Esc = 입력 취소", "· 탭 오른쪽 클릭 = 그 탭에 보일 대화 고르기 · 탭 끌기 = 따로 떼기", "· Ctrl + 오른쪽 클릭 = 창 위치 잠금·풀기" }) do DEFAULT_CHAT_FRAME:AddMessage("|cffe3c39a" .. ln .. "|r") end
        end)
        x = link(x, "대화창 위치·크기 처음대로", { 0.878, 0.541, 0.439 }, function() local c1 = cfg() c1.pos, c1.w, c1.h = nil, nil, nil place() end)
        local pm = NT.feedMoving and NT.feedMoving()
        link(x, pm and "파티 대화 옮기기 끝" or "파티 대화 옮기기", SX.gold, function()
          local on = NT.feedMove and NT.feedMove()
          if UIErrorsFrame then UIErrorsFrame:AddMessage(on and "파티 대화 옮기기 — 끌어서 이동 · 오른쪽 아래 끌기 = 크기 · 다 옮기면 다시 누르기" or "파티 대화 위치 잠금", 1, 0.84, 0.42) end
          rebuild()
        end)
        y = y + 18 + 10
        local sp = get("sep", function() local f = CreateFrame("Frame", nil, C) f.t = f:CreateTexture(nil, "ARTWORK") f.t:SetColorTexture(1, 1, 1, 20 / 255) f.t:SetPoint("LEFT", -15, 0) f.t:SetPoint("RIGHT", 15, 0) f.t:SetHeight(1) return f end)
        sp:SetPoint("TOPLEFT", C, "TOPLEFT", 0, -y) sp:SetSize(SXW, 1)
        y = y + 7
        local i3 = text("탭 오른쪽 클릭: 그 탭에 보일 대화 · Ctrl + 오른쪽 클릭: 창 위치 잠금·풀기", 9.5, SX.mut, 0)
        y = y + i3:GetHeight()
      end
      C:SetHeight(y) SC:SetHeight(y)
      local maxH = math.floor(UIParent:GetHeight() * 0.86)
      s:SetHeight(math.min(maxH, y + 22))
      local m = math.max(0, y - sf:GetHeight()) if sf:GetVerticalScroll() > m then sf:SetVerticalScroll(m) end
    end
    s.rebuild = rebuild
    s:SetScript("OnShow", function(self)
      self:SetFrameStrata("TOOLTIP") self:SetFrameLevel(50) self:Raise()
      fontOpen = false
      sf:SetVerticalScroll(0)
      rebuild()
    end)
    s:Hide()
    return s
  end
  function NT.chatSettingsRefresh() if settings and settings:IsShown() and settings.rebuild then pcall(settings.rebuild) end end
  NT.feedBtnText = NT.chatSettingsRefresh

  local plusBtn = nil
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
    m:SetPoint("TOPLEFT", P, "TOPLEFT", 12, -34) m:SetPoint("BOTTOMRIGHT", P, "BOTTOMRIGHT", -12, 36)
    m:SetJustifyH("LEFT") m:SetMaxLines(500) m:SetFrameLevel(P:GetFrameLevel() + 3)
    m:SetHyperlinksEnabled(true)
    m:SetScript("OnHyperlinkClick", function(self, link, text, button)
      local who = link and link:match("^player:([^:]+)")
      if who and who ~= "" then
        if button == "RightButton" then if NT.nameMenu then pcall(NT.nameMenu, who) end else NT.whoInfo(who) end
        return
      end
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
        if IsControlKeyDown() then local w = UD.of(self.key) if w then UD.lock(w.id) else lockClick(self, btn) end else openFilter(self) end
        return
      end
      selTab(self.key)
    end)
    md:SetScript("OnEnter", function(self) GameTooltip:SetOwner(self, "ANCHOR_TOP") GameTooltip:AddLine(self.tip or "", 1, 0.84, 0.42) GameTooltip:AddLine("오른쪽 클릭: 보일 대화 고르기", 0.8, 0.8, 0.8) GameTooltip:Show() end)
    md:SetScript("OnLeave", function() GameTooltip:Hide() end)
    md:RegisterForDrag("LeftButton") md:SetScript("OnDragStart", function(self) UD.tabDragStart(self) end) md:SetScript("OnDragStop", function(self) UD.tabDragStop(self) end)
    tabBtns[tb.key] = md
    return md
  end
  rebuildTabs = function()
    if not P then return end
    wipe(medals)
    local list = allTabs()
    local keep, prev = {}, nil
    for _, tb in ipairs(list) do keep[tb.key] = true end
    UD.prune(keep)
    for _, tb in ipairs(list) do
      if not frames[tb.key] then makeFrame(tb.key) applyFont() applyFade() refill(tb.key) end
      local md = tabBtns[tb.key] or makeTabBtn(tb)
      md.t:SetText(tb.label)
      md:SetSize(50, 28)
      md.tip = tb.name or tb.label
      if not UD.of(tb.key) then
        md:SetParent(P.chrome) md:SetFrameLevel(P:GetFrameLevel() + 6)
        md:ClearAllPoints()
        if prev then md:SetPoint("BOTTOMLEFT", prev, "BOTTOMRIGHT", 2, 0) else md:SetPoint("BOTTOMLEFT", P.tabBar, "BOTTOMLEFT", 8, 0) end
        md:Show()
        medals[#medals + 1] = md
        prev = md
      end
    end
    UD.layout()
    if NT.pushUG then C_Timer.After(0, NT.pushUG) end
    for _, tb in ipairs(list) do UD.anchor(tb.key) end
    for k, md in pairs(tabBtns) do if not keep[k] then md:Hide() if frames[k] then frames[k]:Hide() end end end
    if not plusBtn then
      plusBtn = flatTab(P.chrome, "+")
      plusBtn.t:SetFont(UIFONT, 15, "") plusBtn.t:SetPoint("CENTER", 0, 0.5)
      plusBtn.t:SetTextColor(COPPER[1], COPPER[2], COPPER[3])
      plusBtn:SetSize(24, 28)
      plusBtn.hl = plate(plusBtn, "HIGHLIGHT", 4, R_TOP) for _, x in ipairs(plusBtn.hl) do x:SetVertexColor(1, 1, 1, 0.09) end
      plusBtn:SetFrameLevel(P:GetFrameLevel() + 6)
      plusBtn:SetScript("OnClick", addTab)
      plusBtn:SetScript("OnEnter", function(self) GameTooltip:SetOwner(self, "ANCHOR_TOP") GameTooltip:AddLine("탭 추가", 1, 0.84, 0.42) GameTooltip:Show() end)
      plusBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    plusBtn:ClearAllPoints() plusBtn:SetPoint("BOTTOMLEFT", prev, "BOTTOMRIGHT", 2, 0)
    local room = (#TS().ctabs < 4)
    local pr, gr = prev and prev:GetRight(), (P.friendsBtn or P.gear) and (P.friendsBtn or P.gear):GetLeft()
    if room and pr and gr and pr + 28 > gr then room = false end
    plusBtn:SetShown(room)
    if not keep[active] or UD.of(active) then active = "all" end
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

  UD.win, UD.pool = {}, {}
  function UD.list() local c = cfg() if type(c.undock) ~= "table" then c.undock = {} end return c.undock end
  function UD.get(id) for _, w in ipairs(UD.list()) do if w.id == id then return w end end end
  function UD.of(key) for _, w in ipairs(UD.list()) do for _, k in ipairs(w.tabs) do if k == key then return w end end end end
  function UD.isAct(key) local w = UD.of(key) if w then return w.act == key end return active == key end
  function UD.newId() local i = 1 while UD.get("u" .. i) do i = i + 1 end return "u" .. i end
  function UD.trOn() return NT.trOn() end
  function UD.paintLock(U, w)
    local lk = U.lockBtn
    local c = w.locked and { OFFTXT, OFFTXT, OFFTXT } or COPPER
    for _, t in ipairs(lk.parts) do t:SetVertexColor(c[1], c[2], c[3], 1) end
    local dy = w.locked and 0 or 2
    lk.top:ClearAllPoints() lk.l:ClearAllPoints() lk.r:ClearAllPoints()
    lk.top:SetPoint("CENTER", 0, 4.75 + dy) lk.l:SetPoint("CENTER", -2.5, 2.5 + dy) lk.r:SetPoint("CENTER", 2.5, 2.5 + dy)
    if U.grip then U.grip:SetShown(not w.locked) end
  end
  function UD.place(w)
    local U = UD.win[w.id] if not U then return end
    U:ClearAllPoints()
    if not w.pos then local l, t = P:GetRight() or 460, P:GetTop() or 260 w.pos = { l + 12, t - (w.h or 150) } end
    if NT.stripY then w.pos[2] = NT.stripY(U, w.pos[1], w.pos[2]) end
    U:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", w.pos[1], w.pos[2])
    U:SetSize(w.w or 320, w.h or 150)
  end
  function UD.save(w, U)
    local l, b = U:GetLeft(), U:GetBottom()
    if l and b then w.pos = { l, b } end
    w.w, w.h = U:GetWidth(), U:GetHeight()
  end
  function UD.lock(id)
    local w, U = UD.get(id), UD.win[id] if not (w and U) then return end
    w.locked = not w.locked
    UD.paintLock(U, w)
    local nm = tabBtns[w.act] and tabBtns[w.act].t:GetText() or "따로 뗀"
    if UIErrorsFrame then UIErrorsFrame:AddMessage(nm .. (w.locked and " 창 고정" or " 창 고정 풀림"), 1, 0.84, 0.42) end
  end
  function UD.lockClick(id, btn) if btn == "RightButton" and IsControlKeyDown() and not UD.trOn() then UD.lock(id) end end
  function UD.hi(key)
    key = key or ""
    if UD.hiKey == key then return end
    UD.hiKey = key
    if P and P.tabBar and P.tabBar.hi then P.tabBar.hi(key == "main") end
    for id, U in pairs(UD.win) do if U.tabBar and U.tabBar.hi then U.tabBar.hi(key == id) end end
  end
  function UD.moveStart(id)
    local w, U = UD.get(id), UD.win[id]
    if not (w and U) or w.locked or InCombatLockdown() or UD.trOn() then return end
    U.moving = true U:StartMoving()
  end
  function UD.moveStop(id)
    local w, U = UD.get(id), UD.win[id]
    if not (w and U and U.moving) then return end
    U.moving = nil U:StopMovingOrSizing() UD.hi(nil)
    if U.SetUserPlaced then pcall(U.SetUserPlaced, U, false) end
    if P.tabBar:IsMouseOver(4, -4, 0, 0) then UD.dockAll(id) return end
    UD.save(w, U) UD.place(w)
  end
  function UD.make(w)
    local U = UD.win[w.id]
    if U then return U end
    U = table.remove(UD.pool)
    if not U then
      U = CreateFrame("Frame", nil, P)
      U:SetFrameStrata("LOW") U:SetMovable(true) U:SetResizable(true) U:SetClampedToScreen(true)
      U:EnableMouse(true) U:RegisterForDrag("LeftButton")
      if U.SetResizeBounds then U:SetResizeBounds(180, 90, 2000, 1400) elseif U.SetMinResize then U:SetMinResize(180, 90) end
      local ch = CreateFrame("Frame", nil, U) ch:SetAllPoints()
      U.chrome = ch
      U.fill = plate(ch, "BACKGROUND", 6, R_ALL)
      U.tabBar = strip(ch, 28, "TOP", 20 / 255, R_TOP, 6)
      edge(ch, 6, EDGEC) hsep(ch, true, 28)
      local lk = CreateFrame("Button", nil, ch) lk:SetSize(24, 28) lk:SetPoint("RIGHT", U.tabBar, "RIGHT", -4, 0)
      lk.parts = {}
      local function px(pw, ph, x, y) local t = lk:CreateTexture(nil, "ARTWORK") t:SetColorTexture(1, 1, 1, 1) t:SetSize(pw, ph) t:SetPoint("CENTER", x, y) lk.parts[#lk.parts + 1] = t return t end
      lk.body = px(10, 7, 0, -3) lk.l = px(1.5, 5, -2.5, 2.5) lk.r = px(1.5, 5, 2.5, 2.5) lk.top = px(6.5, 1.5, 0, 4.75)
      lk:SetScript("OnClick", function() if not UD.trOn() then UD.lock(U.id) end end)
      lk:SetScript("OnEnter", function(self) local w0 = UD.get(U.id) GameTooltip:SetOwner(self, "ANCHOR_TOP") GameTooltip:AddLine((w0 and w0.locked) and "잠김 · 눌러서 풀기" or "풀림 · 눌러서 잠그기", 1, 0.84, 0.42) GameTooltip:Show() end)
      lk:SetScript("OnLeave", function() GameTooltip:Hide() end)
      U.lockBtn = lk
      local grip = CreateFrame("Button", nil, ch) grip:SetSize(12, 12) grip:SetPoint("BOTTOMRIGHT", U, "BOTTOMRIGHT", -1, 1)
      grip.tx = grip:CreateTexture(nil, "OVERLAY") grip.tx:SetAllPoints() grip.tx:SetTexture(MEDIA .. "grip2", "CLAMP", "CLAMP", "TRILINEAR") grip.tx:SetVertexColor(COPPER[1], COPPER[2], COPPER[3], 0.6)
      grip:SetScript("OnMouseDown", function() local w0 = UD.get(U.id) if not w0 or w0.locked or InCombatLockdown() or UD.trOn() then return end U.gripping = true U:StartSizing("BOTTOMRIGHT") end)
      grip:SetScript("OnMouseUp", function() if not U.gripping then return end U.gripping = nil U:StopMovingOrSizing() local w0 = UD.get(U.id) if w0 then UD.save(w0, U) UD.place(w0) end end)
      U.grip = grip
      U:SetScript("OnDragStart", function() UD.moveStart(U.id) end)
      U:SetScript("OnDragStop", function() UD.moveStop(U.id) end)
      U:SetScript("OnMouseUp", function(_, btn) UD.lockClick(U.id, btn) end)
      local a, idle, acc = 1, 0, 0
      NT.onUpdate(U, function(self, el)
        local eb = ChatFrame1EditBox
        local want = self:IsMouseOver(6, -4, -4, 4) or UD.tdrag or self.moving or self.gripping or (fpop and fpop:IsShown() and fpop.key and UD.of(fpop.key) and UD.of(fpop.key).id == self.id)
        if want then idle = 0 else idle = idle + el end
        local target = want and 1 or ((cfg().keep or idle <= 4) and 1 or 0)
        if self.moving then UD.hi(P.tabBar:IsMouseOver(4, -4, 0, 0) and "main" or nil) end
        do local w0 = UD.get(self.id) self.grip:SetShown((w0 and not w0.locked and (self:IsMouseOver() or self.gripping)) and true or false) end
        local ua = UD.trOn() and 0 or 1
        if self:GetAlpha() ~= ua then self:SetAlpha(ua) end
        if ua == 0 then target = 0 if a ~= 0 then a = 0 self.chrome:SetAlpha(0) end end
        if a ~= target then a = target > a and math.min(target, a + el * 6) or math.max(target, a - el * 1.5) self.chrome:SetAlpha(a) end
        acc = acc + el
        if acc > 0.5 then
          acc = 0
          local w0 = UD.get(self.id)
          if w0 then for _, k in ipairs(w0.tabs) do local m = frames[k] if m and m:GetFrameLevel() <= self:GetFrameLevel() then m:SetFrameLevel(self:GetFrameLevel() + 3) end local md = tabBtns[k] if md and md:GetFrameLevel() <= self:GetFrameLevel() + 1 then md:SetFrameLevel(self:GetFrameLevel() + 6) end end end
          if self.lockBtn:GetFrameLevel() <= self:GetFrameLevel() + 1 then self.lockBtn:SetFrameLevel(self:GetFrameLevel() + 6) end
        end
      end)
    end
    U.id = w.id
    U:SetFrameLevel(P:GetFrameLevel() + 20)
    U.chrome:SetFrameLevel(U:GetFrameLevel())
    U.lockBtn:SetFrameLevel(U:GetFrameLevel() + 6) U.grip:SetFrameLevel(U:GetFrameLevel() + 8)
    for _, t in ipairs(U.fill) do t:SetVertexColor(0.067, 0.067, 0.071, cfg().bg) end
    UD.win[w.id] = U
    UD.place(w) UD.paintLock(U, w)
    U:Show()
    return U
  end
  function UD.drop(id)
    local U = UD.win[id] if not U then return end
    UD.win[id] = nil U:Hide() U.moving, U.gripping = nil, nil
    UD.pool[#UD.pool + 1] = U
  end
  function UD.prune(keep)
    local l = UD.list()
    for i = #l, 1, -1 do
      local w = l[i]
      local n = {}
      for _, k in ipairs(type(w.tabs) == "table" and w.tabs or {}) do if keep[k] and k ~= "all" then n[#n + 1] = k end end
      w.tabs = n
      if #n == 0 then UD.drop(w.id) table.remove(l, i) else
        local ok = false for _, k in ipairs(n) do if k == w.act then ok = true end end
        if not ok then w.act = n[1] end
      end
    end
  end
  function UD.anchor(key)
    local m = frames[key] if not m then return end
    local w = UD.of(key)
    local U = w and UD.win[w.id]
    m:ClearAllPoints()
    if U then
      m:SetPoint("TOPLEFT", U, "TOPLEFT", 12, -34) m:SetPoint("BOTTOMRIGHT", U, "BOTTOMRIGHT", -12, 10)
      m:SetFrameLevel(U:GetFrameLevel() + 3)
      m:SetScript("OnDragStart", function() local w0 = UD.of(key) if w0 then UD.moveStart(w0.id) end end)
      m:SetScript("OnDragStop", function() local w0 = UD.of(key) if w0 then UD.moveStop(w0.id) end end)
      m:SetScript("OnMouseUp", function(_, btn) local w0 = UD.of(key) if w0 then UD.lockClick(w0.id, btn) end end)
    else
      m:SetPoint("TOPLEFT", P, "TOPLEFT", 12, -34) m:SetPoint("BOTTOMRIGHT", P, "BOTTOMRIGHT", -12, 36)
      m:SetFrameLevel(P:GetFrameLevel() + 3)
      m:SetScript("OnDragStart", dragStart) m:SetScript("OnDragStop", dragStop) m:SetScript("OnMouseUp", lockClick)
    end
  end
  function UD.layout()
    for _, w in ipairs(UD.list()) do
      local U = UD.make(w)
      local prev
      for _, k in ipairs(w.tabs) do
        local md = tabBtns[k]
        if md then
          md:SetParent(U.chrome) md:SetFrameLevel(U:GetFrameLevel() + 6)
          md:ClearAllPoints()
          if prev then md:SetPoint("BOTTOMLEFT", prev, "BOTTOMRIGHT", 2, 0) else md:SetPoint("BOTTOMLEFT", U.tabBar, "BOTTOMLEFT", 8, 0) end
          md:Show() medals[#medals + 1] = md
          prev = md
        end
      end
    end
  end
  function UD.moveTab(key, to, pos)
    if not key or key == "all" or not tabBtns[key] then return end
    local src = UD.of(key)
    if src and src.id == to then return end
    if src then
      for i, k in ipairs(src.tabs) do if k == key then table.remove(src.tabs, i) break end end
      if src.act == key then src.act = src.tabs[1] end
    end
    if to == "new" then
      local w = { id = UD.newId(), tabs = { key }, act = key, locked = false, w = 320, h = 150 }
      if pos then w.pos = { pos[1], pos[2] - w.h } end
      table.insert(UD.list(), w)
    elseif to and to ~= "main" then
      local w = UD.get(to)
      if w then w.tabs[#w.tabs + 1] = key w.act = key end
    else
      active = key
    end
    for i = #UD.list(), 1, -1 do local w = UD.list()[i] if #w.tabs == 0 then UD.drop(w.id) table.remove(UD.list(), i) end end
    rebuildTabs()
    selTab(key)
  end
  function UD.dockAll(id)
    local l = UD.list()
    for i, w in ipairs(l) do if w.id == id then table.remove(l, i) break end end
    UD.drop(id)
    rebuildTabs()
    selTab(active)
  end
  function UD.target(d)
    if P.tabBar:IsMouseOver(4, -4, 0, 0) then return d.from and "main" or nil end
    for _, w in ipairs(UD.list()) do local U = UD.win[w.id] if U and U:IsShown() and w.id ~= d.from and U.tabBar:IsMouseOver(4, -4, 0, 0) then return w.id end end
    local src = d.from and UD.win[d.from] or P
    if src:IsMouseOver() then return nil end
    for _, w in ipairs(UD.list()) do local U = UD.win[w.id] if U and U:IsMouseOver() then return nil end end
    return "new"
  end
  function UD.cursor() local x, y = GetCursorPosition() local s = UIParent:GetEffectiveScale() return x / s, y / s end
  function UD.tabDragStart(md)
    if InCombatLockdown() or UD.trOn() then return end
    local w = UD.of(md.key)
    if (w and w.locked) or (not w and cfg().locked) then return end
    if (w and w.tabs[1] == md.key) or (not w and md.key == "all") then
      UD.mv = { id = w and w.id }
      if w then UD.moveStart(w.id) else dragStart() end
      return
    end
    UD.tdrag = { key = md.key, from = w and w.id, md = md }
    if UD.tipDone then UD.tipDone() end
    if not UD.ghost then
      local g = flatTab(UIParent, "")
      g:SetFrameStrata("TOOLTIP") g:EnableMouse(false)
      g.disc:SetColorTexture(COPPER[1], COPPER[2], COPPER[3], 0.35) g.disc:Show()
      g.t:SetTextColor(1, 1, 1)
      local box = CreateFrame("Frame", nil, UIParent) box:SetFrameStrata("TOOLTIP") box:SetSize(320, 150) box:EnableMouse(false)
      for _, e in ipairs({ { "TOPLEFT", "TOPRIGHT", 0, 1 }, { "BOTTOMLEFT", "BOTTOMRIGHT", 0, 1 }, { "TOPLEFT", "BOTTOMLEFT", 1, 0 }, { "TOPRIGHT", "BOTTOMRIGHT", 1, 0 } }) do
        local l = box:CreateTexture(nil, "OVERLAY") l:SetColorTexture(0.89, 0.76, 0.6, 0.6) l:SetPoint(e[1]) l:SetPoint(e[2]) if e[3] == 1 then l:SetWidth(1.5) else l:SetHeight(1.5) end
      end
      local bf = box:CreateTexture(nil, "BACKGROUND") bf:SetAllPoints() bf:SetColorTexture(0.89, 0.76, 0.6, 0.05)
      box.t = box:CreateFontString(nil, "OVERLAY") box.t:SetFont(STANDARD_TEXT_FONT, 12, "") box.t:SetPoint("CENTER") box.t:SetTextColor(0.89, 0.76, 0.6)
      local mk = UIParent:CreateTexture(nil, "OVERLAY") mk:SetColorTexture(COPPER[1], COPPER[2], COPPER[3], 1) mk:SetSize(3, 20)
      local mf = CreateFrame("Frame", nil, UIParent) mf:SetFrameStrata("TOOLTIP") mf:SetSize(3, 20) mf:EnableMouse(false)
      mk:SetParent(mf) mk:SetAllPoints()
      g.box, g.mark = box, mf
      NT.onUpdate(g, function(self)
        local d = UD.tdrag if not d then return end
        local x, y = UD.cursor()
        self:ClearAllPoints() self:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y + 4)
        local tg = UD.target(d)
        UD.hi(tg ~= "new" and tg or nil)
        self.box:SetShown(tg == "new") self.mark:SetShown(tg ~= nil and tg ~= "new")
        if tg == "new" then
          self.box:ClearAllPoints() self.box:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x - 40, y + 14)
          self.box.t:SetText((d.md.t:GetText() or "") .. " 창이 따로 생겨요")
        elseif tg then
          local bar = (tg == "main") and P.tabBar or (UD.win[tg] and UD.win[tg].tabBar)
          local last
          if tg == "main" then for _, b in ipairs(medals) do if not UD.of(b.key) then last = b end end
          else local w0 = UD.get(tg) if w0 then last = tabBtns[w0.tabs[#w0.tabs]] end end
          self.mark:ClearAllPoints()
          if last then self.mark:SetPoint("LEFT", last, "RIGHT", 1, 0) elseif bar then self.mark:SetPoint("LEFT", bar, "LEFT", 6, 0) end
        end
      end)
      UD.ghost = g
    end
    local g = UD.ghost
    g.t:SetText(md.t:GetText() or "") g:SetSize(md:GetWidth(), 24)
    g:Show()
    md:SetAlpha(0.3)
  end
  function UD.tabDragStop(md)
    if UD.mv then local m = UD.mv UD.mv = nil if m.id then UD.moveStop(m.id) else dragStop() end return end
    local d = UD.tdrag if not d then return end
    local tg = UD.target(d)
    UD.tdrag = nil UD.hi(nil)
    if UD.ghost then UD.ghost:Hide() UD.ghost.box:Hide() UD.ghost.mark:Hide() end
    d.md:SetAlpha(1)
    if not tg then return end
    local pos
    if tg == "new" then local x, y = UD.cursor() pos = { x - 40, y + 14 } end
    UD.moveTab(d.key, tg, pos)
  end
  do
    local tip
    function UD.tipDone() NT.db().tipUndock = true if tip then tip:Hide() end end
    local tk, acc = CreateFrame("Frame"), 0
    NT.onUpdate(tk, function(self, el)
      acc = acc + el if acc < 0.25 then return end acc = 0
      if NT.db().tipUndock then if tip then tip:Hide() end self:SetScript("OnUpdate", nil) return end
      local md = tabBtns.whisper
      if md and UD.of("whisper") then md = nil end
      if not md then md = medals[#medals] end
      if not (P and P:IsVisible() and md and md:IsVisible() and not UD.trOn()) then if tip then tip:Hide() end return end
      if not tip then
        tip = CreateFrame("Frame", nil, UIParent) tip:SetFrameStrata("DIALOG") tip:SetSize(300, 51) tip:EnableMouse(true)
        local bg = tip:CreateTexture(nil, "BACKGROUND") bg:SetTexture(MEDIA .. "tip_bubble", "CLAMP", "CLAMP", "TRILINEAR") bg:SetTexCoord(0, 1200 / 2048, 0, 204 / 256) bg:SetAllPoints()
        local t1 = tip:CreateFontString(nil, "OVERLAY") t1:SetFont(UIFONT, 12.5, "") t1:SetTextColor(TABON[1], TABON[2], TABON[3]) t1:SetPoint("TOPLEFT", 47, -9) t1:SetText("이제 탭 분리가 가능해요")
        local t2 = tip:CreateFontString(nil, "OVERLAY") t2:SetFont(UIFONT, 10.5, "") t2:SetTextColor(TABOFF[1], TABOFF[2], TABOFF[3]) t2:SetPoint("TOPLEFT", t1, "BOTTOMLEFT", 0, -3) t2:SetText("탭을 끌어서 밖에 놓으면 따로 창이 생겨요")
        local x = CreateFrame("Button", nil, tip) x:SetSize(22, 22) x:SetPoint("CENTER", tip, "TOPRIGHT", -18, -22)
        x.t = x:CreateTexture(nil, "OVERLAY") x.t:SetTexture(MEDIA .. "tip_x", "CLAMP", "CLAMP", "TRILINEAR") x.t:SetSize(12, 12) x.t:SetPoint("CENTER") x.t:SetVertexColor(0.56, 0.525, 0.435)
        x:SetScript("OnEnter", function(b) b.t:SetVertexColor(TABON[1], TABON[2], TABON[3]) end)
        x:SetScript("OnLeave", function(b) b.t:SetVertexColor(0.56, 0.525, 0.435) end)
        x:SetScript("OnClick", UD.tipDone)
      end
      tip:ClearAllPoints() tip:SetPoint("BOTTOMLEFT", md, "TOP", -42, 2)
      tip:Show()
    end)
  end
  function NT.undockGeo()
    if not P then return "" end
    local _, ph = GetPhysicalScreenSize()
    local sh = (UIParent:GetTop() or 768) * UIParent:GetEffectiveScale() * ph / 768
    local out = {}
    for _, w in ipairs(UD.list()) do
      local U = UD.win[w.id]
      if U and U:IsShown() and U:GetLeft() then
        local s = U:GetEffectiveScale() * ph / 768
        out[#out + 1] = string.format("%s,%d,%d,%d,%d,%s,%s,%s", w.id, math.floor(U:GetLeft() * s + 0.5), math.floor(sh - U:GetTop() * s + 0.5), math.floor(U:GetWidth() * s + 0.5), math.floor(U:GetHeight() * s + 0.5), w.locked and "1" or "0", tostring(w.act or ""), table.concat(w.tabs, "/"))
      end
    end
    return table.concat(out, ";")
  end

  local function build()
    if P then return end
    P = CreateFrame("Frame", "NangmanTrChat", UIParent)
    P:SetFrameStrata("LOW") P:SetMovable(true) P:SetResizable(true) P:SetClampedToScreen(true)
    P:EnableMouse(true) P:RegisterForDrag("LeftButton")
    P:SetScript("OnDragStart", dragStart) P:SetScript("OnDragStop", dragStop)
    P:SetScript("OnMouseUp", lockClick)
    place()
    local chrome = CreateFrame("Frame", nil, P) chrome:SetAllPoints() chrome:SetFrameLevel(P:GetFrameLevel())
    P.chrome = chrome
    fillTex = plate(chrome, "BACKGROUND", 6, R_ALL)
    applyBg()
    local tabBar = strip(chrome, 28, "TOP", 20 / 255, R_TOP, 6)
    edge(chrome, 6, EDGEC) hsep(chrome, true, 28) hsep(chrome, false, 30)
    P.tabBar = tabBar
    for _, tb in ipairs(TABS) do makeFrame(tb.key) end
    applyFont() applyFade()
    local cap = CreateFrame("Button", "NangmanTrChatInput", chrome)
    cap:SetHeight(30) cap:SetPoint("BOTTOMLEFT", P, "BOTTOMLEFT", 0, 0) cap:SetPoint("BOTTOMRIGHT", P, "BOTTOMRIGHT", 0, 0)
    cap:SetFrameLevel(P:GetFrameLevel() + 4)
    for _, t in ipairs(plate(cap, "BACKGROUND", 6, R_BOT)) do t:SetVertexColor(1, 1, 1, 10 / 255) end
    cap.ph = cap:CreateFontString(nil, "OVERLAY") cap.ph:SetFont(UIFONT, 11.5, "") cap.ph:SetTextColor(MUTED, MUTED, MUTED) cap.ph:SetText("메시지 입력…")
    cap:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    cap:SetScript("OnClick", function(self, btn)
      if btn == "RightButton" then lockClick(self, btn) return end
      local open = (ChatFrameUtil and ChatFrameUtil.OpenChat) or ChatFrame_OpenChat
      if open then pcall(open, "", ChatFrame1) end
    end)
    cap:RegisterForDrag("LeftButton") cap:SetScript("OnDragStart", dragStart) cap:SetScript("OnDragStop", dragStop)
    local ch = CreateFrame("Frame", nil, cap) ch:SetPoint("LEFT", cap, "LEFT", 6, 0) ch:SetHeight(19)
    ch.bgp = plate(ch, "BACKGROUND", 3, R_ALL)
    ch.t = ch:CreateFontString(nil, "OVERLAY") ch.t:SetFont(UIFONT, 11, "") ch.t:SetPoint("LEFT", 8, 0)
    ch.ar = ch:CreateTexture(nil, "OVERLAY") ch.ar:SetTexture(MEDIA .. "tri_down", "CLAMP", "CLAMP", "TRILINEAR") ch.ar:SetSize(7, 7) ch.ar:SetPoint("LEFT", ch.t, "RIGHT", 3, -0.5)
    function ch.paint(name, c)
      ch.t:SetText(name)
      ch:SetWidth(math.floor((ch.t:GetStringWidth() or 20) + 3 + 7 + 16 + 0.5))
      for _, x in ipairs(ch.bgp) do x:SetVertexColor(c[1], c[2], c[3], 38 / 255) end
      local r, g, b = math.min(1, c[1] + 15 / 255), math.min(1, c[2] + 15 / 255), math.min(1, c[3] + 15 / 255)
      ch.t:SetTextColor(r, g, b) ch.ar:SetVertexColor(r, g, b)
    end
    ch.paint("일반", { 1, 1, 1 })
    cap.ph:SetPoint("LEFT", ch, "RIGHT", 8, 0)
    P.chMedal = ch
    local gear = CreateFrame("Button", nil, chrome) gear:SetSize(24, 28) gear:SetPoint("RIGHT", tabBar, "RIGHT", -4, 0)
    gear:SetFrameLevel(P:GetFrameLevel() + 6)
    gear.icon = gear:CreateTexture(nil, "ARTWORK") gear.icon:SetSize(16.6, 16.6) gear.icon:SetPoint("CENTER", 0, 0)
    gear.icon:SetTexture(MEDIA .. "gear", "CLAMP", "CLAMP", "TRILINEAR")
    gear.icon:SetVertexColor(TABOFF[1], TABOFF[2], TABOFF[3])
    gear:SetScript("OnEnter", function(self) GameTooltip:SetOwner(self, "ANCHOR_TOP") GameTooltip:AddLine("대화창 설정", 1, 0.84, 0.42) GameTooltip:Show() end)
    gear:SetScript("OnLeave", function(self) GameTooltip:Hide() end)
    gear:SetScript("OnClick", function()
      settings = settings or makeSettings()
      if settings:IsShown() then settings:Hide() else settings:ClearAllPoints() settings:SetPoint("BOTTOMRIGHT", P, "TOPRIGHT", 0, 8) settings:Show() end
    end)
    do
      local cen = CreateFrame("Button", nil, cap) cen:SetPoint("RIGHT", cap, "RIGHT", -5, 0) cen:SetFrameLevel(cap:GetFrameLevel() + 4)
      cen:SetSize(28, 19)
      local function ct(file, w, h, u, layer) local t = cen:CreateTexture(nil, layer) t:SetTexture(MEDIA .. file, "CLAMP", "CLAMP", "TRILINEAR") t:SetTexCoord(0, u[1], 0, u[2]) t:SetSize(w, h) t:SetPoint("CENTER") return t end
      local cf, cr = ct("cen_fill", 28, 19, { 224 / 256, 152 / 256 }, "BACKGROUND"), ct("cen_rim", 28, 19, { 224 / 256, 152 / 256 }, "BORDER")
      cen.pl = { set = function(bg, rim) cf:SetVertexColor(bg[1], bg[2], bg[3], bg[4]) if rim then cr:SetVertexColor(rim[1], rim[2], rim[3], rim[4]) cr:Show() else cr:Hide() end end }
      cen.g = { ct("cen_icon", 14, 14, { 112 / 128, 112 / 128 }, "ARTWORK") }
      local tr = CreateFrame("Button", nil, cap) tr:SetPoint("RIGHT", cen, "LEFT", -4, 0) tr:SetFrameLevel(cap:GetFrameLevel() + 4)
      tr.pl = pill(tr, 19)
      tr.t = tr:CreateFontString(nil, "OVERLAY") tr.t:SetFont(UIFONT, 10.5, "") tr.t:SetPoint("CENTER", 0, 0)
      local function trOn2() return NT.trOn() end
      local function paint()
        local fon = NT.feedEnabled and NT.feedEnabled() or false
        if fon then cen.pl.set({ 0.878, 0.725, 0.353, 1 }, nil) else cen.pl.set({ 0, 0, 0, 0.004 }, { 0.910, 0.780, 0.416, 0.35 }) end
        local c = fon and { 0.078, 0.078, 0.078, 1 } or { 0.741, 0.702, 0.604, 1 }
        for _, t in ipairs(cen.g) do t:SetVertexColor(c[1], c[2], c[3], c[4]) end
        local on = trOn2()
        tr.t:SetText(on and "번역 ON" or "번역 OFF")
        tr.pl.size(math.floor((tr.t:GetStringWidth() or 40) + 18 + 0.5))
        if on then tr.pl.set({ 0.725, 0.557, 0.373, 46 / 255 }, { 0.725, 0.557, 0.373, 204 / 255 }) tr.t:SetTextColor(0.890, 0.765, 0.604)
        else tr.pl.set({ 1, 1, 1, 10 / 255 }, { 1, 1, 1, 38 / 255 }) tr.t:SetTextColor(0.416, 0.416, 0.416) end
      end
      cen:SetScript("OnClick", function() local D = NT.db() D.partyFeedOn = not (D.partyFeedOn == true) if not D.partyFeedOn and NT.feedClear then pcall(NT.feedClear) end paint() feedChanged() if NT.chatSettingsRefresh then NT.chatSettingsRefresh() end end)
      cen:SetScript("OnEnter", function(self) GameTooltip:SetOwner(self, "ANCHOR_TOP") GameTooltip:AddLine("집중 대화창", 1, 0.84, 0.42) GameTooltip:AddLine((NT.feedEnabled and NT.feedEnabled()) and "켜짐 (클릭 = 끄기)" or "꺼짐 (클릭 = 켜기)", 0.9, 0.9, 0.9) GameTooltip:Show() end)
      cen:SetScript("OnLeave", function() GameTooltip:Hide() end)
      do
        local tip
        local function done() NT.db().tipFocus = true if tip then tip:Hide() end end
        local tk, acc, shown = CreateFrame("Frame"), 0, 0
        NT.onUpdate(tk, function(self, el)
          acc = acc + el if acc < 0.25 then return end
          if NT.db().tipFocus then if tip then tip:Hide() end self:SetScript("OnUpdate", nil) return end
          if not (P and P:IsVisible() and cen:IsVisible()) then acc = 0 if tip then tip:Hide() end return end
          if tip and tip:IsShown() then shown = shown + acc if shown > 15 then done() end acc = 0 return end
          acc = 0
          if not tip then
            tip = CreateFrame("Frame", nil, UIParent) tip:SetFrameStrata("DIALOG") tip:EnableMouse(true)
            local bg = tip:CreateTexture(nil, "BACKGROUND") bg:SetTexture(MEDIA .. "tip_bubble", "CLAMP", "CLAMP", "TRILINEAR") bg:SetTexCoord(0, 1200 / 2048, 0, 204 / 256) bg:SetAllPoints()
            local t1 = tip:CreateFontString(nil, "OVERLAY") t1:SetFont(UIFONT, 12.5, "") t1:SetTextColor(TABON[1], TABON[2], TABON[3]) t1:SetPoint("TOPLEFT", 47, -9) t1:SetText("집중 대화창")
            local t2 = tip:CreateFontString(nil, "OVERLAY") t2:SetFont(UIFONT, 10.5, "") t2:SetTextColor(TABOFF[1], TABOFF[2], TABOFF[3]) t2:SetPoint("TOPLEFT", t1, "BOTTOMLEFT", 0, -3) t2:SetText("전장 입장 시에는 집중 대화창에서 번역을 보실 수 있어요")
            tip:SetSize(math.max(300, math.ceil(t2:GetStringWidth() + 84)), 51)
            local x = CreateFrame("Button", nil, tip) x:SetSize(22, 22) x:SetPoint("CENTER", tip, "TOPRIGHT", -18, -22)
            x.t = x:CreateTexture(nil, "OVERLAY") x.t:SetTexture(MEDIA .. "tip_x", "CLAMP", "CLAMP", "TRILINEAR") x.t:SetSize(12, 12) x.t:SetPoint("CENTER") x.t:SetVertexColor(0.56, 0.525, 0.435)
            x:SetScript("OnEnter", function(b) b.t:SetVertexColor(TABON[1], TABON[2], TABON[3]) end)
            x:SetScript("OnLeave", function(b) b.t:SetVertexColor(0.56, 0.525, 0.435) end)
            x:SetScript("OnClick", done)
          end
          tip:ClearAllPoints() tip:SetPoint("BOTTOMLEFT", cen, "TOP", -42, 2)
          tip:Show()
        end)
      end
      tr:SetScript("OnClick", function() if NT.setTranslate then NT.setTranslate(not (NT.trOn and NT.trOn())) end paint() end)
      tr:SetScript("OnEnter", function(self) GameTooltip:SetOwner(self, "ANCHOR_TOP") GameTooltip:AddLine("번역", 1, 0.84, 0.42) GameTooltip:AddLine("클릭 = 번역창으로 (번역 프로그램이 켜져 있어야 해요)", 0.9, 0.9, 0.9) GameTooltip:Show() end)
      tr:SetScript("OnLeave", function() GameTooltip:Hide() end)
      cap.paintBtns = paint
      local pt = CreateFrame("Frame", nil, cap) local acc = 0
      NT.onUpdate(pt, function(_, e) acc = acc + e if acc > 0.5 then acc = 0 paint() end end)
      paint()
    end
    P.cap = cap
    P.gear = gear
    local fr = CreateFrame("Button", nil, chrome) fr:SetSize(24, 28) fr:SetPoint("RIGHT", gear, "LEFT", -2, 0)
    fr:SetFrameLevel(P:GetFrameLevel() + 6)
    fr.icon = fr:CreateTexture(nil, "ARTWORK") fr.icon:SetSize(17.9, 17.9) fr.icon:SetPoint("CENTER", 0, 0)
    fr.icon:SetTexture(MEDIA .. "friends", "CLAMP", "CLAMP", "TRILINEAR")
    fr.icon:SetVertexColor(TABOFF[1], TABOFF[2], TABOFF[3])
    fr:SetScript("OnEnter", function(self) self.icon:SetVertexColor(TABUL[1], TABUL[2], TABUL[3]) GameTooltip:SetOwner(self, "ANCHOR_TOP") GameTooltip:AddLine("친구 목록", 1, 0.84, 0.42) GameTooltip:Show() end)
    fr:SetScript("OnLeave", function(self) self.icon:SetVertexColor(TABOFF[1], TABOFF[2], TABOFF[3]) GameTooltip:Hide() end)
    fr:SetScript("OnClick", function()
      if ToggleFriendsFrame then pcall(ToggleFriendsFrame, 1) elseif FriendsFrame then if FriendsFrame:IsShown() then HideUIPanel(FriendsFrame) else ShowUIPanel(FriendsFrame) end end
    end)
    P.friendsBtn = fr
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
    rebuildTabs()
    local mw, mh = math.max(1000, math.floor(UIParent:GetWidth())), math.max(700, math.floor(UIParent:GetHeight()))
    if P.SetResizeBounds then P:SetResizeBounds(260, 120, mw, mh) elseif P.SetMinResize then P:SetMinResize(260, 120) P:SetMaxResize(mw, mh) end
    local grip = CreateFrame("Button", nil, chrome)
    grip:SetSize(12, 12) grip:SetPoint("BOTTOMRIGHT", P, "BOTTOMRIGHT", -1, 1) grip:SetFrameLevel(P:GetFrameLevel() + 8)
    grip.tx = grip:CreateTexture(nil, "OVERLAY") grip.tx:SetAllPoints() grip.tx:SetTexture(MEDIA .. "grip2", "CLAMP", "CLAMP", "TRILINEAR") grip.tx:SetVertexColor(COPPER[1], COPPER[2], COPPER[3], 0.6)
    grip:SetScript("OnMouseDown", function() if cfg().locked or InCombatLockdown() then return end P.gripping = true P:StartSizing("BOTTOMRIGHT") end)
    grip:SetScript("OnMouseUp", function() if not P.gripping then return end P.gripping = nil P:StopMovingOrSizing() savePos() place() if NT.geoNow then NT.geoNow() end end)
    P.grip = grip
    local eb = ChatFrame1EditBox
    if eb then
      local guard
      local CIN = CreateFrame("Frame", "NangmanTrCenterInput")
      CIN:SetFrameStrata("DIALOG") CIN:SetHeight(32) CIN:Hide()
      for _, tx in ipairs(plate(CIN, "BACKGROUND", 6, R_ALL)) do tx:SetVertexColor(0.067, 0.067, 0.071, 0.88) end
      local function centerOK() return not NT.trOn() and NT.feedEnabled and NT.feedEnabled() and _G.NangmanTrPartyFeed and _G.NangmanTrPartyFeed:GetLeft() and eb:HasFocus() end
      local function ebSkin(on)
        for _, r in ipairs({ eb:GetRegions() }) do if r.GetObjectType and r:GetObjectType() == "Texture" then r:SetAlpha(on and 0 or 1) end end
        local lang = _G["ChatFrame1EditBoxLanguage"] if lang then lang:SetAlpha(on and 0 or 1) lang:EnableMouse(not on) end
      end
      local function placeEB0()
        if NT.chatNative() then
          CIN:Hide()
          if eb.__ntPar and eb:GetParent() ~= eb.__ntPar then
            pcall(eb.SetParent, eb, eb.__ntPar)
            if eb.__ntPts then eb:ClearAllPoints() for _, pt in ipairs(eb.__ntPts) do pcall(eb.SetPoint, eb, unpack(pt)) end end
            ebSkin(false)
          end
          return
        end
        ebSkin(true)
        pcall(eb.SetFont, eb, fontFile(), math.max(13, cfg().font), "")
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
      end
      local function placeEB()
        if guard then return end
        guard = true
        pcall(placeEB0)
        guard = false
      end
      eb:HookScript("OnEditFocusGained", function() C_Timer.After(0, placeEB) end)
      eb:HookScript("OnEditFocusLost", function() C_Timer.After(0, placeEB) end)
      if eb.__ntPar == nil then eb.__ntPar = eb:GetParent() or false; eb.__ntPts = {} for i = 1, eb:GetNumPoints() do eb.__ntPts[i] = { eb:GetPoint(i) } end end
      pcall(eb.SetParent, eb, P)
      eb:SetFrameLevel(cap:GetFrameLevel() + 3)
      ebSkin(true)
      placeEB()
      P.placeEB = placeEB
      C_Timer.NewTicker(1, function()
        if NT.chatNative() or eb:HasFocus() then return end
        local par = eb:GetParent()
        if par ~= P and par ~= CIN then pcall(placeEB) end
      end)
      NT.hsf(eb, "SetPoint", function() if not guard then C_Timer.After(0, placeEB) end end)
    end
    local n = ChatFrame1.GetNumMessages and ChatFrame1:GetNumMessages() or 0
    for i = math.max(1, n - 200), n do
      local ok, t, r, g, b = pcall(ChatFrame1.GetMessageInfo, ChatFrame1, i)
      if ok and t then route(t, r, g, b) end
    end
    for _, md in ipairs(medals) do md.unread = nil end
    for _, md in ipairs(medals) do
      if md.key == "whisper" then
        local sp = md:CreateTexture(nil, "OVERLAY", nil, 3)
        sp:SetTexture(DISC, "CLAMP", "CLAMP", "TRILINEAR") sp:SetVertexColor(DOT[1], DOT[2], DOT[3], 1)
        sp:SetSize(6, 6) sp:SetPoint("LEFT", md.t, "RIGHT", 5, 0) sp:Hide()
        md.spin = sp
        local wev = CreateFrame("Frame")
        for _, e in ipairs({ "CHAT_MSG_WHISPER", "CHAT_MSG_BN_WHISPER" }) do pcall(wev.RegisterEvent, wev, e) end
        NT.onEvent(wev, function() if not (UD.isAct and UD.isAct("whisper")) then sp:Show() end end)
      end
    end
    selTab("all")
    local function hx(s) return { tonumber(s:sub(1, 2), 16) / 255, tonumber(s:sub(3, 4), 16) / 255, tonumber(s:sub(5, 6), 16) / 255 } end
    local CHP = { SAY = { "일반", hx("ffffff") }, YELL = { "외침", hx("ff4040") }, EMOTE = { "감정", hx("ff8040") }, PARTY = { "파티", hx("aaaaff") }, PARTY_LEADER = { "파티", hx("aaaaff") },
      RAID = { "공대", hx("ff7f00") }, RAID_LEADER = { "공대", hx("ff7f00") }, RAID_WARNING = { "경보", hx("ff4809") }, INSTANCE_CHAT = { "인던", hx("aad4ff") }, INSTANCE_CHAT_LEADER = { "인던", hx("aad4ff") },
      GUILD = { "길드", hx("40ff40") }, OFFICER = { "관리", hx("40c040") }, WHISPER = { "귓말", hx("ff80ff") }, BN_WHISPER = { "귓말", hx("00fff6") }, CHANNEL = { "채널", hx("ffc0c0") } }
    local CHT = { SAY = { "일", { 0.47, 0.43, 0.37 } }, YELL = { "외", { 0.7, 0.2, 0.2 } }, PARTY = { "파", { 0.24, 0.39, 0.78 } }, PARTY_LEADER = { "파", { 0.24, 0.39, 0.78 } },
      RAID = { "공", { 0.75, 0.42, 0.12 } }, RAID_WARNING = { "경", { 0.8, 0.3, 0.1 } }, INSTANCE_CHAT = { "인", { 0.75, 0.42, 0.12 } }, GUILD = { "길", { 0.16, 0.55, 0.24 } },
      OFFICER = { "관", { 0.15, 0.45, 0.2 } }, WHISPER = { "귓", { 0.67, 0.24, 0.59 } }, BN_WHISPER = { "귓", { 0.2, 0.55, 0.75 } }, EMOTE = { "감", { 0.75, 0.45, 0.2 } }, CHANNEL = { "채", { 0.6, 0.5, 0.35 } } }
    local a, acc, idle = 1, 0, 0
    NT.onUpdate(P, function(self, el)
      if sizing then
        if not IsMouseButtonDown("LeftButton") then sizing = nil savePos()
        else
          local x, y = GetCursorPosition()
          local es = self:GetEffectiveScale()
          self:SetSize(math.max(260, math.min(math.max(1000, UIParent:GetWidth()), sizing.w + (x - sizing.x) / es)), math.max(120, math.min(math.max(700, UIParent:GetHeight()), sizing.h + (y - sizing.y) / es)))
        end
      end
      local typing = eb and eb:HasFocus()
      local want = (typing or self:IsMouseOver(6, -4, -4, 4) or (settings and settings:IsShown()) or (fpop and fpop:IsShown()) or sizing or self.gripping or UD.tdrag or UD.mv) and 1 or nil
      if want then idle = 0 else idle = idle + el end
      local target = want or ((cfg().keep or idle <= 4 or NT.tr().bgOff) and 1 or 0)
      if a ~= target then
        a = target > a and math.min(target, a + el * 6) or math.max(target, a - el * 1.5)
        if not NT.trOn() then chrome:SetAlpha(a) end
      end
      if P.grip then P.grip:SetShown(not cfg().locked and (self:IsMouseOver() or self.gripping) and true or false) end
      cap.ph:SetShown(not (eb and eb:IsShown() and (typing or (eb:GetText() or "") ~= "")))
      acc = acc + el
      if acc > 0.2 then
        acc = 0
        if eb then
          local t = eb:GetAttribute("chatType") or "SAY"
          if ch.cur ~= t then
            ch.cur = t
            local info = CHP[t] or CHP.SAY
            ch.paint(info[1], info[2])
          end
        end
      end
    end)
    NT.hsf(ChatFrame1, "AddMessage", function(_, text, r, g, b) if chHook(text) then return end route(commText(text), r, g, b) end)
    hideBlizz()
    C_Timer.NewTicker(2, function() pcall(hideBlizz) end)
    local lastNat
    local function syncNative()
      local nat = NT.chatNative() and true or false
      if nat == lastNat then return end
      lastNat = nat
      if nat then P:Hide() else P:Show() end
      if P.placeEB then pcall(P.placeEB) end
      if nat then pcall(showBlizz) else pcall(hideBlizz) end
      if nat and not NT.chatDual() and NT.feedClear then pcall(NT.feedClear) end
      if not nat then pcall(applyBg) end
    end
    NT.syncNative = function() lastNat = nil pcall(syncNative) end
    local lastBgOff
    C_Timer.NewTicker(1, function()
      local v = NT.tr().bgOff and true or false
      if v ~= lastBgOff then lastBgOff = v pcall(applyBg) end
    end)
    C_Timer.NewTicker(0.3, function() pcall(syncNative) end)
    syncNative()
  end

  local ce = CreateFrame("Frame")
  ce:RegisterEvent("PLAYER_LOGIN")
  NT.onEvent(ce, function() C_Timer.After(1, function() local ok, err = pcall(build) if not ok then print("|cffff6060[번역기 대화창]|r " .. tostring(err)) end end) end)
end

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
    if IsShiftKeyDown() or IsControlKeyDown() or IsAltKeyDown() then return end
    local cp = _G.NangmanTrChat
    if cp and cp.IsMouseOver and cp:IsShown() and cp:IsMouseOver() then return end
    for _, eb in ipairs(boxes()) do
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
  NT.onEvent(f, function() C_Timer.After(0, leave) end)
end

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
  local kf = CreateFrame("Frame") kf:RegisterEvent("PLAYER_LOGIN") NT.onEvent(kf, function() pcall(addHash) end)
end

do
  local last = 0
  local function closeMenus()
    if Menu and Menu.GetManager then pcall(function() Menu.GetManager():CloseMenus() end) end
    if CloseDropDownMenus then pcall(CloseDropDownMenus) end
  end
  function NT.whoInfo(who)
    if type(who) ~= "string" or who == "" then return end
    local short = who:match("^([^%-]+)") or who
    if C_FriendList and C_FriendList.SendWho then pcall(C_FriendList.SendWho, 'n-"' .. short .. '"')
    elseif SendWho then pcall(SendWho, 'n-"' .. short .. '"') end
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
  NT.hsf("SetItemRef", function(link, text, button)
    if not IsShiftKeyDown() or type(link) ~= "string" or NT.secret(link) then return end
    local who = link:match("^player:([^:]+)")
    if not who or who == "" then return end
    local now = GetTime()
    if now - last < 0.3 then return end
    last = now
    if button == "RightButton" then
      NT.nameMenu(who)
    else
      if ChatEdit_GetActiveWindow and ChatEdit_GetActiveWindow() then return end
      local short = who:match("^([^%-]+)") or who
      if C_FriendList and C_FriendList.SendWho then pcall(C_FriendList.SendWho, 'n-"' .. short .. '"')
      elseif SendWho then pcall(SendWho, 'n-"' .. short .. '"') end
    end
  end)
end

do
  local WORLD = { "공개", "거래", "수비", "파티찾기", "세계", "서비스", "초보", "general", "trade", "localdefense", "lookingforgroup", "worlddefense", "services", "newcomer" }
  local function isWorld(nm)
    local l = nm:lower()
    for _, w in ipairs(WORLD) do if l:find(w, 1, true) then return true end end
    return false
  end
  local NEED = { "SAY", "EMOTE", "YELL", "GUILD", "OFFICER", "GUILD_ACHIEVEMENT", "PARTY", "PARTY_LEADER", "RAID", "RAID_LEADER", "RAID_WARNING",
    "INSTANCE_CHAT", "INSTANCE_CHAT_LEADER", "WHISPER", "BN_WHISPER", "SYSTEM", "LOOT", "MONEY", "COMBAT_XP_GAIN", "COMBAT_FACTION_CHANGE", "SKILL",
    "MONSTER_SAY", "MONSTER_YELL", "MONSTER_EMOTE", "MONSTER_WHISPER", "RAID_BOSS_EMOTE", "RAID_BOSS_WHISPER" }
  local function groups()
    if not ChatFrame1 or type(ChatTypeGroup) ~= "table" then return end
    local have = {}
    if type(ChatFrame1.messageTypeList) == "table" then for _, g in pairs(ChatFrame1.messageTypeList) do if type(g) == "string" then have[g] = true end end end
    for _, g in ipairs(NEED) do
      if ChatTypeGroup[g] and not have[g] then
        if ChatFrame_AddMessageGroup then pcall(ChatFrame_AddMessageGroup, ChatFrame1, g)
        elseif ChatFrame1.AddMessageGroup then pcall(ChatFrame1.AddMessageGroup, ChatFrame1, g) end
      end
    end
  end
  local function sub()
    pcall(groups)
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
  NT.onEvent(f, function()
    if pend then return end
    pend = true
    C_Timer.After(4, function() pend = nil pcall(sub) end)
  end)
end

do
  local function keepNative(f)
    if not (NT.chatNative and NT.chatNative() and NT.chatCfg and NT.chatCfg().keep) or type(f) ~= "table" or not f.GetName then return end
    local nm = f:GetName() if not nm then return end
    local a = f.oldAlpha or DEFAULT_CHATFRAME_ALPHA or 0.25
    if CHAT_FRAME_TEXTURES then
      for _, v in ipairs(CHAT_FRAME_TEXTURES) do
        local o = _G[nm .. v]
        if o and o:IsShown() then if UIFrameFadeRemoveFrame then UIFrameFadeRemoveFrame(o) end o:SetAlpha(a) end
      end
    end
    local tab = _G[nm .. "Tab"]
    if tab then if UIFrameFadeRemoveFrame then UIFrameFadeRemoveFrame(tab) end tab:SetAlpha(CHAT_FRAME_TAB_NORMAL_MOUSEOVER_ALPHA or 1) end
  end
  if FCF_FadeOutChatFrame then NT.hsf("FCF_FadeOutChatFrame", function(f) pcall(keepNative, f) end) end
  C_Timer.NewTicker(1, function()
    if not (NT.chatNative and NT.chatNative() and NT.chatCfg and NT.chatCfg().keep) then return end
    for i = 1, (NUM_CHAT_WINDOWS or 10) do local f = _G["ChatFrame" .. i] if f and f:IsShown() then pcall(keepNative, f) end end
  end)
end
