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
	DockWidth: number,
	DockContentWidth: number,
	DockScrollable: boolean,
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
	local available = width - 28 - 16 - gap * 5
	-- Em telas muito estreitas, manter alvos de ~48 px físicos e rolar a faixa
	-- em vez de comprimir 6 botões até ficarem difíceis de tocar.
	local dockSize = math.clamp(math.floor(available / 6), 62, 80)
	local dockHeight = compact and dockSize or 88
	local dockContentWidth = dockSize * 6 + 5 * gap
	local dockWidth = math.min(width - 28, dockContentWidth + 16)
	local detailsTop = compact and 166 or 108
	local reserve = compact and dockHeight + 36 or 20
	return {
		Scale = scale, Width = width, Height = height,
		Compact = compact, Tight = tight,
		DockSize = dockSize, DockHeight = dockHeight,
		DockWidth = dockWidth, DockContentWidth = dockContentWidth,
		DockScrollable = dockContentWidth + 16 > dockWidth,
		StatusWidth = math.min(250, math.max(170, width - 158)),
		DetailsWidth = math.min(454, math.max(250, width - 28)),
		DetailsTop = detailsTop,
		DetailsHeight = math.max(100, height - detailsTop - reserve),
	}
end

return HudLayoutRules
