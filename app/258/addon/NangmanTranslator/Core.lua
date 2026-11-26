local NT = {}
NangmanTr = NT

NT.MEDIA = "Interface\\AddOns\\NangmanTranslator\\media\\"
pcall(function()
  local hold = {}
  for i, nm in ipairs({ "GJ_MapleBold", "GJ_MapleLight", "GJ_UI", "GJ_UILight", "GJ_Binggrae", "GJ_MalgunBold", "GJ_Malgun", "Pretendard-Bold", "Pretendard-Light", "GJ_WarhavenBold", "GJ_Warhaven" }) do
    local ok, fo = pcall(CreateFont, "NangmanPreFont" .. i)
    if ok and fo and pcall(fo.SetFont, fo, NT.MEDIA .. nm .. ".ttf", 12, "") then
      pcall(function() local h = UIParent:CreateFontString(nil, "OVERLAY") h:SetFontObject(fo) h:SetText("가A") h:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 2, 2) h:SetAlpha(0.02) hold[#hold + 1] = h end)
    end
  end
  if C_Timer then C_Timer.After(8, function() for _, h in ipairs(hold) do pcall(h.Hide, h) end end) end
end)

local function loaded(name)
  if C_AddOns and C_AddOns.IsAddOnLoaded then
    local ok, v = pcall(C_AddOns.IsAddOnLoaded, name)
    if ok and v then return true end
  end
  if IsAddOnLoaded then
    local ok, v = pcall(IsAddOnLoaded, name)
    if ok and v then return true end
  end
  return false
end
NT.inert = (ForeverKitTranslate ~= nil)

function NT.secret(v) return issecretvalue and issecretvalue(v) end

function NT.db()
  NangmanTranslatorDB = NangmanTranslatorDB or {}
  return NangmanTranslatorDB
end
function NT.tr()
  local d = NT.db()
  if type(d.translate) ~= "table" then d.translate = {} end
  return d.translate
end
function NT.trOn()
  local d = NangmanTranslatorDB
  return d and type(d.translate) == "table" and d.translate.on and true or false
end

function NT.say(t) print("|cffe6c066[번역기]|r " .. t) end

do
  local seen = {}
  function NT.safe(fn)
    return function(...)
      local ok, e = pcall(fn, ...)
      if not ok then
        local k = tostring(e)
        if not seen[k] then
          seen[k] = true
          local h = geterrorhandler and geterrorhandler()
          if h then pcall(h, k) end
        end
      end
    end
  end
  function NT.onUpdate(f, fn) f:SetScript("OnUpdate", fn and NT.safe(fn) or nil) end
  function NT.onEvent(f, fn) f:SetScript("OnEvent", fn and NT.safe(fn) or nil) end
  function NT.hsf(a, b, c) if c ~= nil then hooksecurefunc(a, b, NT.safe(c)) else hooksecurefunc(a, NT.safe(b)) end end
end

do
  local f = CreateFrame("Frame")
  f:RegisterEvent("PLAYER_LOGIN")
  f:SetScript("OnEvent", function()
    if NT.inert then
      print("|cffe6c066[번역기]|r ForeverKit 번역 기능이 켜져 있어서 낭만타우렌 번역기 애드온은 쉬어요 (툴킷 번역 기능을 그대로 씀)")
    end
  end)
end

do
  local SRV = { "공개", "거래", "수비", "파티찾기", "세계", "서비스", "초보", "general", "trade", "localdefense", "lookingforgroup", "worlddefense", "services", "newcomer" }
  local function base(n)
    if type(n) ~= "string" or NT.secret(n) then return nil end
    n = n:gsub("^%d+%.%s*", ""):gsub("%s+%-%s+.*$", ""):lower()
    if n == "" or n:find("^community:") then return nil end
    for _, w in ipairs(SRV) do if n:find(w, 1, true) then return nil end end
    return n
  end
  local function looks(m)
    if type(m) ~= "string" or NT.secret(m) or m:find("|H", 1, true) then return false end
    local s = m:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    local ns = s:gsub("%s", "")
    if #ns < 6 then return false end
    local sym = select(2, ns:gsub("[#$%%&*()+/:<=>@%[%]\\{}_`]", ""))
    if #ns >= 10 and sym / #ns >= 0.15 then return true end
    local a = s:match("^(%S+)%s")
    return (a and #a <= 6 and a:find("^%u[%u%d]+$") and s:find("%d[%.:]%w") and not s:find("%l%l%l") and not s:find("[\128-\255]")) and true or false
  end
  local function cdb() local d = NT.db() if type(d.dataCh) ~= "table" then d.dataCh = {} end return d.dataCh end
  function NT.isDataCh(n) local b = base(n) return (b and cdb()[b]) and true or false end
  local hits, human, memo, memoN = {}, {}, {}, 0
  local function unlist(name)
    local rm = ChatFrame_RemoveChannel or (ChatFrameUtil and ChatFrameUtil.RemoveChannel)
    if not rm then return end
    for i = 1, (NUM_CHAT_WINDOWS or 10) do local f = _G["ChatFrame" .. i] if f then pcall(rm, f, name) end end
  end
  local function judge(msg, chanStr, chanBase, lineID, guid)
    local nm = (type(chanBase) == "string" and chanBase ~= "" and not NT.secret(chanBase)) and chanBase or chanStr
    local b = base(nm)
    if not b then return false end
    local key = (lineID and not NT.secret(lineID)) and lineID or (b .. "\1" .. tostring(msg))
    if memo[key] ~= nil then return memo[key] end
    local d, drop = cdb(), false
    local mine = type(guid) == "string" and not NT.secret(guid) and guid == UnitGUID("player")
    if mine or not looks(msg) then
      human[b] = (human[b] or 0) + 1
      if d[b] and (mine or human[b] >= 2) then d[b] = nil if NT.chans then pcall(NT.chans) end end
    elseif d[b] then drop = true
    elseif not human[b] then
      hits[b] = (hits[b] or 0) + 1
      drop = true
      if hits[b] >= 3 then d[b] = true unlist(nm) if NT.chans then pcall(NT.chans) end end
    end
    memoN = memoN + 1 if memoN > 400 then memo, memoN = {}, 0 end
    memo[key] = drop
    return drop
  end
  function NT.chDrop(msg, chanStr, chanBase, lineID, guid)
    local ok, r = pcall(judge, msg, chanStr, chanBase, lineID, guid)
    return ok and r or false
  end
  local add = (ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter) or ChatFrame_AddMessageEventFilter
  if add then pcall(add, "CHAT_MSG_CHANNEL", function(_, _, msg, _, _, chanStr, _, _, _, _, chanBase, _, lineID, guid)
    if NT.inert then return false end
    return NT.chDrop(msg, chanStr, chanBase, lineID, guid)
  end) end
  local f = CreateFrame("Frame")
  f:RegisterEvent("PLAYER_ENTERING_WORLD")
  f:SetScript("OnEvent", function()
    C_Timer.After(5, function()
      if NT.inert or not GetChannelList then return end
      local l = { GetChannelList() }
      local step = (type(l[3]) == "boolean" or (l[3] == nil and #l >= 3)) and 3 or 2
      for i = 1, #l, step do local nm = l[i + 1] if type(nm) == "string" and NT.isDataCh(nm) then unlist(nm) end end
    end)
  end)
end
