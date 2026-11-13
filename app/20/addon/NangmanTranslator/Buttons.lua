-- 낭만타우렌 번역기 · 미니맵 버튼 두 개 (둥근 금테 메달 · 켜진 쪽만 불빛 · 꺼진 쪽은 회색)
--  번역 버튼 (가A · 8시 방향 200°) = 번역 켜기 + 번역창을 대화창으로
--  대화창 버튼 (사람 · 160°)       = 번역 끄기 + 와우 기본 대화창
--  늘 둘 중 하나만 켜짐 · 번역 프로그램의 '번역' 알약과 같은 상태 (/nttr 켜기·끄기 를 받으면 같이 바뀜)
local NT = NangmanTr
if not NT or NT.inert then return end

local MEDIA = NT.MEDIA
local btns = {}

local function paint(b, on)
  b.icon:SetDesaturated(not on)
  b.icon:SetVertexColor(on and 1 or 0.42, on and 1 or 0.42, on and 1 or 0.42)
  b.icon:SetAlpha(on and 1 or 0.7)
  b.ring:SetDesaturated(not on)
  b.ring:SetVertexColor(on and 1 or 0.6, on and 1 or 0.6, on and 1 or 0.6)
  b.glow:SetShown(on and true or false)
end
local function look()
  local tr = NT.trOn()
  if btns.tr then paint(btns.tr, tr) end
  if btns.chat then paint(btns.chat, not tr) end
end
NT.btnLook = look

-- (2026-11-13 대표 · 사용자 의견) 버튼을 끌어서 미니맵 둘레 아무 데나 옮길 수 있게 · 자리는 저장 (캐릭 공통)
local function place(b)
  local r = (Minimap:GetWidth() or 140) / 2 * 1.15
  local a = math.rad(b.deg or 0)
  b:ClearAllPoints()
  b:SetPoint("CENTER", Minimap, "CENTER", math.cos(a) * r, math.sin(a) * r)
end
local function make(name, icon, deg, key, onClick, tip)
  local b = CreateFrame("Button", name, Minimap)
  b:SetSize(26, 26)
  b:SetFrameLevel(Minimap:GetFrameLevel() + 12)
  b.key = key
  b.deg = tonumber(NT.db()[key]) or deg
  place(b)
  b.glow = b:CreateTexture(nil, "BACKGROUND") b.glow:SetTexture(MEDIA .. "glow") b.glow:SetBlendMode("ADD") b.glow:SetSize(58, 58) b.glow:SetPoint("CENTER") b.glow:SetVertexColor(1, 0.85, 0.45, 0.8)
  b.icon = b:CreateTexture(nil, "ARTWORK") b.icon:SetAllPoints() b.icon:SetTexture(MEDIA .. icon, "CLAMP", "CLAMP", "TRILINEAR")
  local okm, mk = pcall(b.CreateMaskTexture, b)
  if okm and mk then mk:SetTexture(MEDIA .. "mask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE") mk:SetAllPoints(b.icon) pcall(b.icon.AddMaskTexture, b.icon, mk) end
  b.ring = b:CreateTexture(nil, "OVERLAY") b.ring:SetTexture(MEDIA .. "medal_ring_aa", "CLAMP", "CLAMP", "TRILINEAR") b.ring:SetSize(26 / 0.80, 26 / 0.80) b.ring:SetPoint("CENTER")
  b.hi = b:CreateTexture(nil, "HIGHLIGHT") b.hi:SetTexture(MEDIA .. "glow") b.hi:SetBlendMode("ADD") b.hi:SetSize(50, 50) b.hi:SetPoint("CENTER") b.hi:SetVertexColor(1, 0.9, 0.6, 0.6)
  b:RegisterForClicks("LeftButtonUp")
  b:RegisterForDrag("LeftButton")
  b:SetScript("OnDragStart", function(self)
    GameTooltip:Hide()
    self:SetScript("OnUpdate", function(s)
      local mx, my = Minimap:GetCenter()
      if not mx then return end
      local sc = Minimap:GetEffectiveScale()
      local cx, cy = GetCursorPosition()
      s.deg = math.deg(math.atan2(cy / sc - my, cx / sc - mx)) % 360
      place(s)
    end)
  end)
  b:SetScript("OnDragStop", function(self)
    self:SetScript("OnUpdate", nil)
    self.dragEnd = GetTime()
    NT.db()[self.key] = math.floor(self.deg * 10 + 0.5) / 10
  end)
  b:SetScript("OnClick", function(self)
    if self.dragEnd and GetTime() - self.dragEnd < 0.3 then return end   -- 끌어서 옮긴 직후엔 클릭으로 안 침
    onClick() look()
  end)
  b:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    tip(GameTooltip)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  return b
end

local function build()
  if btns.tr or not Minimap then return end
  btns.tr = make("NangmanTrTranslateButton", "fk_trans", 200, "mmTrDeg", function() NT.setTranslate(true) end, function(tt)
    tt:SetText(NT.trOn() and "번역 켜짐 · 번역창을 대화창으로 쓰는 중" or "번역 켜기", 1, 0.85, 0.45)
    tt:AddLine("클릭 = 번역 켜기 + 번역창을 대화창으로", 0.9, 0.9, 0.9)
    tt:AddLine("번역 프로그램이 켜져 있어야 번역창이 보여요", 0.7, 0.7, 0.7)
    tt:AddLine("끌기 = 미니맵 둘레로 옮기기", 0.7, 0.7, 0.7)
  end)
  btns.chat = make("NangmanTrChatButton", "fk_people", 160, "mmChatDeg", function() NT.setTranslate(false) end, function(tt)
    tt:SetText(NT.trOn() and "게임 대화창으로 바꾸기" or "게임 대화창 쓰는 중 · 번역 꺼짐", 1, 0.85, 0.45)
    tt:AddLine("클릭 = 번역 끄기 + 와우 기본 대화창", 0.9, 0.9, 0.9)
    tt:AddLine("끌기 = 미니맵 둘레로 옮기기", 0.7, 0.7, 0.7)
  end)
  look()
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function() pcall(build) end)
