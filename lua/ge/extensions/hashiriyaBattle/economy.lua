-- Hashiriya Battle: Geld und Preise (Yen)
local M = {}

-- Umrechnungsfaktor von BeamNG-Preisen ($) in Yen. Hier anpassen, wenn sich das Geld
-- zu leicht oder zu knapp anfühlt.
M.usdToYen = 150

-- Rundet auf "japanisch wirkende" Preise: zwei signifikante Stellen, knapp darunter.
-- Beispiel: 3.510.000 -> 3.498.000, 452.000 -> 449.800
function M.roundJapanese(yen)
  yen = math.floor(yen)
  if yen < 1000 then
    return math.floor(yen / 10 + 0.5) * 10
  end
  local digits = #tostring(yen)
  local step = 10 ^ (digits - 2)
  local base = math.floor(yen / step) * step
  return math.floor(base - step * 0.02)
end

function M.usdToPrice(usd)
  return M.roundJapanese(usd * M.usdToYen)
end

function M.formatYen(yen)
  local s = tostring(math.floor(yen))
  local negative = s:sub(1, 1) == '-'
  if negative then s = s:sub(2) end
  s = s:reverse():gsub('(%d%d%d)', '%1,'):reverse()
  if s:sub(1, 1) == ',' then s = s:sub(2) end
  return (negative and '-' or '') .. '¥' .. s
end

return M
