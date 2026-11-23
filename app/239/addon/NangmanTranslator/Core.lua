local NT = {}
NangmanTr = NT

NT.MEDIA = "Interface\\AddOns\\NangmanTranslator\\media\\"

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
