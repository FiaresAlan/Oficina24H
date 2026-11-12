--!strict
local UserInputService = game:GetService("UserInputService")

-- Paleta e fontes do HUD (valores amostrados da imagem de referência). Gotham foi aposentada pelo Roblox:
-- títulos e números em Oswald (condensada e pesada), texto corrido em Builder Sans.
local Theme = {
	-- Oficina industrial: grafite, aço, marfim e âmbar. Reduz o azul neon da HUD antiga.
	Bg = Color3.fromRGB(14, 20, 24),
	BgDeep = Color3.fromRGB(8, 14, 18),
	Surface = Color3.fromRGB(26, 37, 42),
	Surface2 = Color3.fromRGB(37, 53, 60),
	Stroke = Color3.fromRGB(81, 104, 111),
	StrokeGlow = Color3.fromRGB(87, 168, 187),
	Lip = Color3.fromRGB(50, 68, 75),
	Accent = Color3.fromRGB(235, 179, 77),
	AccentText = Color3.fromRGB(36, 27, 14),
	Orange = Color3.fromRGB(223, 143, 56),
	OrangeEdge = Color3.fromRGB(133, 87, 38),
	Yellow = Color3.fromRGB(238, 193, 92),
	Blue = Color3.fromRGB(95, 180, 202),
	BlueDeep = Color3.fromRGB(31, 76, 89),
	Cyan = Color3.fromRGB(108, 190, 202),
	Green = Color3.fromRGB(100, 199, 146),
	Red = Color3.fromRGB(226, 105, 104),
	Text = Color3.fromRGB(236, 241, 241),
	Muted = Color3.fromRGB(166, 181, 184),
	Font = Enum.Font.BuilderSans,
	FontSemi = Enum.Font.BuilderSansMedium,
	FontBold = Enum.Font.BuilderSansBold,
	FontTitle = Enum.Font.Oswald,
	PanelTransparency = 0.07,
}

-- Altura mínima de alvo de toque (dedo) vs mouse.
function Theme.touchTarget(): number
	return UserInputService.TouchEnabled and 48 or 38
end

return Theme
