--!strict
local UserInputService = game:GetService("UserInputService")

-- Paleta e fontes do HUD (valores amostrados da imagem de referência). Gotham foi aposentada pelo Roblox:
-- títulos e números em Oswald (condensada e pesada), texto corrido em Builder Sans.
local Theme = {
	Bg = Color3.fromRGB(13, 22, 35),
	BgDeep = Color3.fromRGB(6, 12, 24),
	Surface = Color3.fromRGB(18, 32, 55),
	Surface2 = Color3.fromRGB(30, 52, 88),
	Stroke = Color3.fromRGB(66, 96, 136),
	StrokeGlow = Color3.fromRGB(33, 156, 226),
	Lip = Color3.fromRGB(38, 72, 113),
	Accent = Color3.fromRGB(255, 176, 32),
	AccentText = Color3.fromRGB(40, 22, 4),
	Orange = Color3.fromRGB(253, 131, 1),
	OrangeEdge = Color3.fromRGB(146, 59, 0),
	Yellow = Color3.fromRGB(255, 221, 7),
	Blue = Color3.fromRGB(21, 148, 244),
	BlueDeep = Color3.fromRGB(4, 45, 106),
	Cyan = Color3.fromRGB(0, 157, 235),
	Green = Color3.fromRGB(46, 214, 82),
	Red = Color3.fromRGB(240, 40, 40),
	Text = Color3.fromRGB(243, 244, 248),
	Muted = Color3.fromRGB(150, 165, 190),
	Font = Enum.Font.BuilderSans,
	FontSemi = Enum.Font.BuilderSansMedium,
	FontBold = Enum.Font.BuilderSansBold,
	FontTitle = Enum.Font.Oswald,
	PanelTransparency = 0.04,
}

-- Altura mínima de alvo de toque (dedo) vs mouse.
function Theme.touchTarget(): number
	return UserInputService.TouchEnabled and 48 or 38
end

return Theme
