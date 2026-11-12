--!strict
-- Contrato de layout baseado em viewport real. Evita largura fixa que sai da tela no mobile.
-- Não depende de UI/Player: pode ser testado sem renderizar a HUD.
local HudLayoutRules = {}

export type Layout = {
	Scale: number,
	Width: number,
	Height: number,
	Compact: boolean,
	Tight: boolean,
	DockSize: number,
	DockHeight: number,
	StatusWidth: number,
	DetailsWidth: number,
	DetailsTop: number,
	DetailsHeight: number,
}

function HudLayoutRules.Plan(viewport: Vector2, touch: boolean): Layout
	local x = math.max(280, viewport.X)
	local y = math.max(260, viewport.Y)
	-- UI em unidades lógicas: limite inferior preserva touch targets ao invés de miniaturizar tudo.
	local factor = math.min(x / 1672, y / 941)
	local scale = math.clamp(factor, touch and 0.78 or 0.7, 1.3)
	local width, height = x / scale, y / scale
	local compact = width < 1480
	local tight = width < 850
	local gap = 6
	local dockHeight = compact and 70 or 88
	local available = width - 28 - 16 - gap * 5
	local dockSize = math.clamp(math.floor(available / 6), 48, 80)
	local detailsTop = compact and 166 or 108
	local reserve = compact and dockHeight + 36 or 20
	return {
		Scale = scale, Width = width, Height = height,
		Compact = compact, Tight = tight,
		DockSize = dockSize, DockHeight = dockHeight,
		StatusWidth = math.min(250, math.max(170, width - 158)),
		DetailsWidth = math.min(454, math.max(250, width - 28)),
		DetailsTop = detailsTop,
		DetailsHeight = math.max(100, height - detailsTop - reserve),
	}
end

return HudLayoutRules
