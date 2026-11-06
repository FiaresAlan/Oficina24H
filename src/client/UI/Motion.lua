--!strict
-- Tokens de movimento do HUD: todos os tweens da interface passam por aqui (skill fwjelaa-ui-builder).
-- Com "Reduzir movimento" ligado no Roblox, escalas e deslocamentos viram trocas imediatas (só cor/transparência animam).
local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")

local Motion = {}

Motion.Hover = TweenInfo.new(0.10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
Motion.Press = TweenInfo.new(0.05, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
Motion.Release = TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
Motion.Open = TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
Motion.Close = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
Motion.Fill = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
Motion.Slide = TweenInfo.new(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
Motion.Fade = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
Motion.Pulse = TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
Motion.Pop = TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

function Motion.reduced(): boolean
	return GuiService.ReducedMotionEnabled
end

-- Cria e toca um tween; sem movimento reduzido toca como pedido.
function Motion.play(instance: Instance, info: TweenInfo, goal: { [string]: any }): Tween
	local tween = TweenService:Create(instance, info, goal)
	tween:Play()
	return tween
end

-- Animação de escala: só quando o movimento não está reduzido (senão aplica direto).
function Motion.scale(uiScale: UIScale, value: number, info: TweenInfo)
	if Motion.reduced() then
		uiScale.Scale = value
	else
		TweenService:Create(uiScale, info, { Scale = value }):Play()
	end
end

-- Pulso contínuo de uma propriedade (brilho do botão selecionado). Retorna função para parar.
function Motion.loop(instance: Instance, property: string, from: number, to: number): () -> ()
	if Motion.reduced() then
		(instance :: any)[property] = (from + to) / 2
		return function() end
	end
	;(instance :: any)[property] = from
	local tween = TweenService:Create(instance, Motion.Pulse, { [property] = to })
	tween:Play()
	return function()
		tween:Cancel()
	end
end

return Motion
