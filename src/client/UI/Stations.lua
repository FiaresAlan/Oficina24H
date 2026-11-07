--!strict
-- Stations (cliente): onde ficam as estações físicas do jogador e um "GPS" até elas.
--   orders -> TV de ordens (dentro da oficina; a lista abre de qualquer lugar, mas aceitar só na TV)
--   stock  -> prateleira do estoque (dentro da oficina)
--   shop   -> Loja de Autopeças do bairro
-- O servidor valida a distância de verdade; aqui é só para guiar o jogador e abrir a tela quando ele está perto.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)

local Stations = {}

local player = Players.LocalPlayer

function Stations.MyPlot(): Instance?
	local plots = workspace:FindFirstChild("Plots")
	for _, plot in ipairs(plots and plots:GetChildren() or {}) do
		if plot:GetAttribute("OwnerUserId") == player.UserId then
			return plot
		end
	end
	return nil
end

-- A peça física da estação (para destacar e medir distância).
function Stations.Target(kind: string): BasePart?
	if kind == "shop" then
		local areas = workspace:FindFirstChild("PublicAreas")
		local shop = areas and areas:FindFirstChild("LojaAutopecas")
		return shop and shop:IsA("BasePart") and shop or nil
	end
	local plot = Stations.MyPlot()
	local folder = plot and plot:FindFirstChild("Estacoes")
	if not folder then
		return nil
	end
	if kind == "orders" then
		local tv = folder:FindFirstChild("TV_Ordens")
		return tv and tv:IsA("BasePart") and tv or nil
	elseif kind == "stock" then
		local shelf = folder:FindFirstChild("Prateleira")
		local anchor = shelf and shelf:FindFirstChild("PromptPonto")
		return anchor and anchor:IsA("BasePart") and anchor or nil
	end
	return nil
end

function Stations.Distance(kind: string): number
	local target = Stations.Target(kind)
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if not target or not hrp or not hrp:IsA("BasePart") then
		return math.huge
	end
	if kind == "shop" then
		local rel = target.CFrame:PointToObjectSpace(hrp.Position)
		local half = target.Size / 2
		local dx = math.max(math.abs(rel.X) - half.X, 0)
		local dz = math.max(math.abs(rel.Z) - half.Z, 0)
		return math.sqrt(dx * dx + dz * dz)
	end
	return (hrp.Position - target.Position).Magnitude
end

function Stations.IsNear(kind: string): boolean
	local limit = kind == "shop" and Config.ShopDistance or Config.StationDistance
	return Stations.Distance(kind) <= limit
end

-- Linha brilhante do jogador até a estação + destaque, por alguns segundos.
local guide: { Instance } = {}
function Stations.Guide(kind: string, seconds: number?)
	local target = Stations.Target(kind)
	if target then
		Stations.GuideTo(target, seconds, function(): boolean
			return Stations.IsNear(kind)
		end)
	end
end

-- Mesma luz-guia para qualquer peça do mundo (usada também pelo guia do 1º atendimento). `arrived` encerra a guia.
function Stations.GuideTo(target: BasePart, seconds: number?, arrived: (() -> boolean)?)
	for _, inst in ipairs(guide) do
		inst:Destroy()
	end
	table.clear(guide)
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if not target or not hrp then
		return
	end
	local a0 = Instance.new("Attachment")
	a0.Parent = hrp
	local a1 = Instance.new("Attachment")
	a1.Parent = target
	local beam = Instance.new("Beam")
	beam.Attachment0 = a0
	beam.Attachment1 = a1
	beam.Width0, beam.Width1 = 0.6, 0.6
	beam.Color = ColorSequence.new(Color3.fromRGB(255, 196, 40))
	beam.LightEmission = 1
	beam.FaceCamera = true
	beam.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	beam.TextureMode = Enum.TextureMode.Wrap
	beam.TextureLength = 3
	beam.TextureSpeed = 2
	beam.Transparency = NumberSequence.new(0.2)
	beam.Parent = hrp
	local highlight = Instance.new("Highlight")
	highlight.FillColor = Color3.fromRGB(255, 196, 40)
	highlight.OutlineColor = Color3.fromRGB(255, 196, 40)
	highlight.FillTransparency = 0.7
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Parent = target.Parent and target.Parent:IsA("Model") and target.Parent or target
	TweenService:Create(highlight, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { FillTransparency = 0.45 }):Play()
	guide = { a0, a1, beam, highlight }
	local mine = guide
	task.delay(seconds or 12, function()
		if guide == mine then
			for _, inst in ipairs(guide) do
				inst:Destroy()
			end
			table.clear(guide)
		end
	end)
	-- some sozinho ao chegar
	task.spawn(function()
		while guide == mine and #guide > 0 do
			local hrp2 = character and character:FindFirstChild("HumanoidRootPart")
			local near = arrived and arrived() or (not arrived and hrp2 and hrp2:IsA("BasePart") and (hrp2.Position - target.Position).Magnitude < 12)
			if near then
				for _, inst in ipairs(guide) do
					inst:Destroy()
				end
				table.clear(guide)
				break
			end
			task.wait(0.3)
		end
	end)
end

Stations.FarText = {
	stock = "Vá até a prateleira do estoque, dentro da sua oficina (siga a luz).",
	shop = "Vá até a Loja de Autopeças do bairro para comprar (siga a luz).",
	orders = "Para aceitar, vá até a TV de ordens dentro da oficina.",
}

return Stations
