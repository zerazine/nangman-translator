local D = NangmanTranslator_LinkData or {}
local Q, QK, I, IK, S, R = D.q or {}, D.qk or {}, D.i or {}, D.ik or {}, D.s or {}, D.r or {}
local KI
local function kiName(k)
  if not KI then KI = {} for id, v in pairs(IK) do if not KI[v] then KI[v] = I[id] end end end
  return KI[k]
end
local ko = GetLocale and GetLocale() == "koKR"
local function learn() NangmanTranslatorLinkLearn = NangmanTranslatorLinkLearn or {} return NangmanTranslatorLinkLearn end
local function sec(v) return issecretvalue and issecretvalue(v) end
local function hasKo(s) return s:find("[\234-\237][\128-\191][\128-\191]") ~= nil end

local PROF = { Alchemy = "연금술", Blacksmithing = "대장기술", Enchanting = "마법부여", Engineering = "기계공학", Leatherworking = "가죽세공", Tailoring = "재봉술", Cooking = "요리", ["First Aid"] = "응급치료", Fishing = "낚시", Mining = "채광", Herbalism = "약초채집", Skinning = "무두질", Jewelcrafting = "보석세공", Inscription = "주문각인", Poisons = "독", Smelting = "제련" }
local PROFEN = {}
for k, v in pairs(PROF) do PROFEN[v] = k end

function NangmanTranslator_LinkEN(t, force)
  if not ko or type(t) ~= "string" or sec(t) or not t:find("|H", 1, true) then return t end
  if not force and hasKo((t:gsub("|H.-|h.-|h", ""))) then return t end
  return (t:gsub("(|H(%a+):(%d+)[^|]*|h)%[(.-)%](|h)", function(h, k, id, nm, e)
    if not hasKo(nm) then return nil end
    id = tonumber(id)
    local en
    if k == "quest" then en = Q[id] or learn()[id]
    elseif k == "item" then en = I[id]
    elseif k == "spell" then en = S[id]
    elseif k == "enchant" then
      local pf, rest = nm:match("^(.-): (.+)$")
      if not (pf and PROFEN[pf]) then rest = nm end
      en = S[id] or R[rest] or kiName(rest)
      if en and pf and PROFEN[pf] then en = PROFEN[pf] .. ": " .. en end
    end
    if en then return h .. "[" .. en .. "]" .. e end
  end):gsub("(|Htrade:[^|]*|h)%[(.-)%](|h)", function(h, nm, e)
    if not hasKo(nm) then return nil end
    local sid = h:match(":(%d+):%d+|h$") or h:match(":(%d+)|h$")
    local en = (sid and S[tonumber(sid)]) or PROFEN[nm]
    if en then return h .. "[" .. en .. "]" .. e end
  end))
end

local function koQuest(id)
  local f = C_QuestLog and (C_QuestLog.GetTitleForQuestID or C_QuestLog.GetQuestInfo)
  if f then
    local ok, t = pcall(f, id)
    if ok and type(t) == "string" and hasKo(t) then return t end
  end
  return QK[id]
end
local function koItem(id)
  local f = (C_Item and C_Item.GetItemNameByID) or (C_Item and C_Item.GetItemInfo) or GetItemInfo
  if f then
    local ok, n = pcall(f, id)
    if ok and type(n) == "string" and hasKo(n) then return n end
  end
  return IK[id]
end

local function qie(t)
  if not t:find("[[", 1, true) then return t end
  t = t:gsub("|Hquestie:(%d+)[^|]*|h%[%[(%d+)%] ([^%[%]|]-) %(%d+%)%]|h", "|Hquest:%1:%2|h[%3]|h")
  local out, pos = {}, 1
  while true do
    local s, e, lv, nm, id = t:find("%[%[(%d+)%] ([^%[%]|]-) %((%d+)%)%]", pos)
    if not s then break end
    out[#out + 1] = t:sub(pos, s - 1)
    if s > 2 and t:sub(s - 2, s - 1) == "|h" then out[#out + 1] = t:sub(s, e)
    else out[#out + 1] = "|cffffff00|Hquest:" .. id .. ":" .. lv .. "|h[" .. nm .. "]|h|r" end
    pos = e + 1
  end
  out[#out + 1] = t:sub(pos)
  return table.concat(out)
end

local function mine(sender, ev, guid)
  if ev == "CHAT_MSG_WHISPER_INFORM" or ev == "CHAT_MSG_BN_WHISPER_INFORM" then return true end
  if type(guid) == "string" and not sec(guid) and UnitGUID and guid == UnitGUID("player") then return true end
  if type(sender) ~= "string" or sec(sender) then return false end
  return (Ambiguate and Ambiguate(sender, "short") or sender:match("^[^-]+")) == UnitName("player")
end

local function koSpell(id)
  local f = (C_Spell and C_Spell.GetSpellName) or GetSpellInfo
  if not f then return nil end
  local ok, n = pcall(f, id)
  if ok and type(n) == "string" and hasKo(n) then return n end
end
local function koTrade(h, nm)
  local sid = h:match(":(%d+):%d+|h$") or h:match(":(%d+)|h$")
  return (sid and koSpell(tonumber(sid))) or PROF[nm]
end

function NangmanTranslator_LinkKO(t, sender, ev, guid)
  if mine(sender, ev, guid) then return t end
  if not ko or type(t) ~= "string" or sec(t) then return t end
  t = qie(t)
  if not t:find("|H", 1, true) then return t end
  return (t:gsub("(|H(%a+):(%d+)[^|]*|h)%[(.-)%](|h)", function(h, k, id, nm, e)
    if hasKo(nm) then return nil end
    id = tonumber(id)
    if k == "quest" and not Q[id] and nm ~= "" and not nm:find("[^ -~]") then learn()[id] = nm end
    local n
    if k == "quest" then n = koQuest(id)
    elseif k == "item" then n = koItem(id)
    elseif k == "spell" then n = koSpell(id)
    elseif k == "enchant" then
      n = koSpell(id)
      local pf = nm:match("^(.-): ")
      if n and pf and PROF[pf] then n = PROF[pf] .. ": " .. n end
    end
    if n then return h .. "[" .. n .. "]" .. e end
  end):gsub("(|Htrade:[^|]*|h)%[(.-)%](|h)", function(h, nm, e)
    if hasKo(nm) then return nil end
    local n = koTrade(h, nm)
    if n then return h .. "[" .. n .. "]" .. e end
  end))
end

if ko and ChatFrame_AddMessageEventFilter then
  local function filt(_, ev, msg, ...)
    if type(msg) ~= "string" or sec(msg) or not (msg:find("|H", 1, true) or msg:find("[[", 1, true)) then return false end
    local ok, n = pcall(NangmanTranslator_LinkKO, msg, (...), ev, (select(11, ...)))
    if ok and type(n) == "string" and n ~= msg then return false, n, ... end
    return false
  end
  for _, e in ipairs({ "SAY", "YELL", "EMOTE", "PARTY", "PARTY_LEADER", "RAID", "RAID_LEADER", "RAID_WARNING", "INSTANCE_CHAT", "INSTANCE_CHAT_LEADER", "GUILD", "OFFICER", "WHISPER", "WHISPER_INFORM", "BN_WHISPER", "BN_WHISPER_INFORM", "CHANNEL" }) do
    ChatFrame_AddMessageEventFilter("CHAT_MSG_" .. e, filt)
  end
end
