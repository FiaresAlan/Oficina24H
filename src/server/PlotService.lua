--!strict
-- PlotService: atribui, libera e consulta os terrenos físicos (Workspace.Plots.PlotN).
-- Autoridade do servidor: apenas este módulo escreve OwnerUserId nos lotes.
-- Atribuição é síncrona (sem yield entre ler e gravar), portanto não há corrida entre jogadores.
local Players = game:GetService("Players")

local PlotService = {}

local plotsFolder: Folder? = nil
local plotByUser: { [number]: Folder } = {}

local function setSign(plot: Folder, text: string)
	local sign = plot:FindFirstChild("Sign")
	local label = sign and sign:FindFirstChild("Label", true)
	if label and label:IsA("TextLabel") then
		label.Text = text
	end
end

local function setSpawn(plot: Folder, enabled: boolean)
	local spawn = plot:FindFirstChild("Spawn")
	if spawn and spawn:IsA("SpawnLocation") then
		spawn.Enabled = enabled
	end
end

local function freePlot(): Folder?
	if not plotsFolder then
		return nil
	end
	local candidates = {}
	for _, plot in ipairs(plotsFolder:GetChildren()) do
		if plot:IsA("Folder") and plot:GetAttribute("OwnerUserId") == 0 then
			table.insert(candidates, plot)
		end
	end
	table.sort(candidates, function(a, b)
		return (a:GetAttribute("PlotId") :: number) < (b:GetAttribute("PlotId") :: number)
	end)
	return candidates[1]
end

function PlotService.GetPlot(player: Player): Folder?
	return plotByUser[player.UserId]
end

function PlotService.GetPlotById(plotId: number): Folder?
	if not plotsFolder then
		return nil
	end
	for _, plot in ipairs(plotsFolder:GetChildren()) do
		if plot:GetAttribute("PlotId") == plotId then
			return plot :: Folder
		end
	end
	return nil
end

function PlotService.GetCapacity(): number
	return plotsFolder and #plotsFolder:GetChildren() or 0
end

function PlotService.GetOccupied(): number
	local n = 0
	for _ in pairs(plotByUser) do
		n += 1
	end
	return n
end

-- Retorna true se a posição está sobre a área do lote (usado para validar distância de ações).
function PlotService.IsInsidePlot(plot: Folder, position: Vector3, margin: number?): boolean
	local base = plot:FindFirstChild("Base")
	if not base or not base:IsA("BasePart") then
		return false
	end
	local m = margin or 0
	local rel = base.CFrame:PointToObjectSpace(position)
	return math.abs(rel.X) <= base.Size.X / 2 + m and math.abs(rel.Z) <= base.Size.Z / 2 + m
end

function PlotService.Assign(player: Player): (boolean, string, Folder?)
	if plotByUser[player.UserId] then
		return true, "Você já possui um terreno.", plotByUser[player.UserId]
	end
	local plot = freePlot()
	if not plot then
		return false, "Não há terrenos livres neste servidor.", nil
	end

	plot:SetAttribute("OwnerUserId", player.UserId)
	plot:SetAttribute("OwnerName", player.DisplayName)
	plotByUser[player.UserId] = plot
	setSign(plot, "OFICINA DE " .. string.upper(player.DisplayName))
	setSpawn(plot, true)

	local spawn = plot:FindFirstChild("Spawn")
	if spawn and spawn:IsA("SpawnLocation") then
		player.RespawnLocation = spawn
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			character:PivotTo(spawn.CFrame + Vector3.new(0, 4, 0))
		end
	end
	return true, "Terreno " .. tostring(plot:GetAttribute("PlotId")) .. " atribuído.", plot
end

function PlotService.Release(player: Player)
	local plot = plotByUser[player.UserId]
	if not plot then
		return
	end
	plotByUser[player.UserId] = nil
	local equipment = plot:FindFirstChild("Equipment")
	if equipment then
		equipment:Destroy() -- os equipamentos pertencem ao perfil do jogador, não ao lote
	end
	plot:SetAttribute("OwnerUserId", 0)
	plot:SetAttribute("OwnerName", nil)
	local priceText = plot:FindFirstChild("PriceText", true)
	if priceText and priceText:IsA("TextLabel") then
		priceText.Text = "OFICINA\nLIVRE"
	end
	setSign(plot, "LOTE " .. tostring(plot:GetAttribute("PlotId")) .. " - LIVRE")
	setSpawn(plot, false)
	player.RespawnLocation = nil
end

-- Somente testes (tools/PlotTest.luau): usa a pasta de lotes sem conectar eventos de Players.
function PlotService._initForTesting(folder: Folder)
	plotsFolder = folder
	plotByUser = {}
end

function PlotService.Start()
	plotsFolder = workspace:WaitForChild("Plots", 15) :: Folder?
	if not plotsFolder then
		warn("[PlotService] Workspace.Plots não encontrado; terrenos indisponíveis.")
		return
	end

	-- Recuperação: se o Studio manteve donos antigos salvos no place, limpa antes de começar.
	for _, plot in ipairs(plotsFolder:GetChildren()) do
		plot:SetAttribute("OwnerUserId", 0)
		plot:SetAttribute("OwnerName", nil)
	end

	Players.PlayerAdded:Connect(function(player)
		PlotService.Assign(player)
	end)
	Players.PlayerRemoving:Connect(PlotService.Release)
	for _, player in ipairs(Players:GetPlayers()) do
		PlotService.Assign(player)
	end
end

return PlotService
