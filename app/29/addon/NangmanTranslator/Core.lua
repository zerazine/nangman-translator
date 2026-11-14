-- 낭만타우렌 와우 포에버 번역기 (게임 애드온) · 공용 자리
-- 바깥 번역 프로그램(NangmanTranslator)과 짝으로 움직이는 번역 전용 작은 애드온
-- ForeverKit(제작자 개인 툴킷)이 켜져 있으면 아무것도 하지 않음 (한 줄 알림만)
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
-- toc의 OptionalDeps: ForeverKit → 툴킷이 켜져 있으면 늘 이 애드온보다 먼저 읽힘
NT.inert = loaded("ForeverKit") or (ForeverKitTranslate ~= nil)

function NT.secret(v) return issecretvalue and issecretvalue(v) end

-- 저장 자리 (계정 공통 · 어떤 캐릭으로 접속해도 같은 설정)
function NT.db()
  NangmanTranslatorDB = NangmanTranslatorDB or {}
  return NangmanTranslatorDB
end
function NT.tr()
  local d = NT.db()
  if type(d.translate) ~= "table" then d.translate = {} end
  return d.translate
end
-- 번역 켜짐 = 번역창을 대화창으로 쓰는 중
function NT.trOn()
  local d = NangmanTranslatorDB
  return d and type(d.translate) == "table" and d.translate.on and true or false
end

function NT.say(t) print("|cffe6c066[번역기]|r " .. t) end

do
  local f = CreateFrame("Frame")
  f:RegisterEvent("PLAYER_LOGIN")
  f:SetScript("OnEvent", function()
    if NT.inert then
      print("|cffe6c066[번역기]|r ForeverKit이 켜져 있어서 낭만타우렌 번역기 애드온은 쉬어요 (툴킷 번역 기능을 그대로 씀)")
    end
  end)
end
