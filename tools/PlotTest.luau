-- Testes do PlotService com jogadores simulados (sem precisar de 2+ pessoas). Rodar no Edit via MCP.
-- Usa uma cópia isolada do módulo (clone + require) e restaura os lotes no final.
local ServerStorage = game:GetService("ServerStorage")
local source = game:GetService("ServerScriptService"):WaitForChild("Server"):WaitForChild("PlotService")

local results, failures = {}, 0
local function check(name: string, cond: boolean, detail: any?)
	if not cond then failures += 1 end
	table.insert(results, (cond and "PASS " or "FAIL ") .. name .. (cond and "" or (" -> " .. tostring(detail))))
end

local clone = source:Clone()
clone.Parent = ServerStorage
local PS = require(clone)
local plots = workspace:WaitForChild("Plots")
PS._initForTesting(plots)

local function reset()
	for _, p in ipairs(plots:GetChildren()) do
		p:SetAttribute("OwnerUserId", 0)
		p:SetAttribute("OwnerName", nil)
		local e = p:FindFirstChild("Equipment")
		if e then e:Destroy() end
		local lbl = p.Sign.SurfaceGui.Label
		lbl.Text = "LOTE " .. p:GetAttribute("PlotId") .. " - LIVRE"
	end
end
reset()

local function fake(id: number) return { UserId = id, DisplayName = "Jogador" .. id } end

-- 1. Seis jogadores recebem seis lotes distintos
local players, seen, distinct = {}, {}, true
for i = 1, 6 do
	local p = fake(1000 + i)
	players[i] = p
	local ok, _, plot = PS.Assign(p)
	check("jogador " .. i .. " recebe lote", ok and plot ~= nil)
	local id = plot and plot:GetAttribute("PlotId")
	if seen[id] then distinct = false end
	seen[id] = true
	check("lote do jogador " .. i .. " marca o dono", plot and plot:GetAttribute("OwnerUserId") == p.UserId)
end
check("seis lotes distintos", distinct)
check("ocupados = 6", PS.GetOccupied() == 6, PS.GetOccupied())

-- 2. Sétimo jogador é recusado
local seventh = fake(1007)
local ok7, msg7 = PS.Assign(seventh)
check("7º jogador sem lote", ok7 == false and PS.GetPlot(seventh) == nil, msg7)

-- 3. Atribuição repetida devolve o mesmo lote
local _, _, again = PS.Assign(players[2])
check("reatribuir não troca o lote", again == PS.GetPlot(players[2]) and PS.GetOccupied() == 6)

-- 4. Liberar e reaproveitar
local freed = PS.GetPlot(players[3])
local freedId = freed:GetAttribute("PlotId")
local eq = Instance.new("Folder"); eq.Name = "Equipment"; eq.Parent = freed
PS.Release(players[3])
check("liberação zera o dono", freed:GetAttribute("OwnerUserId") == 0)
check("liberação restaura a placa", freed.Sign.SurfaceGui.Label.Text:find("LIVRE") ~= nil, freed.Sign.SurfaceGui.Label.Text)
check("liberação remove equipamentos do lote", freed:FindFirstChild("Equipment") == nil)
check("jogador liberado sem lote", PS.GetPlot(players[3]) == nil)
local newcomer = fake(1008)
local _, _, got = PS.Assign(newcomer)
check("novo jogador ocupa o lote liberado", got and got:GetAttribute("PlotId") == freedId, got and got:GetAttribute("PlotId"))
check("7º continua sem lote após o novato ocupar a vaga", select(1, PS.Assign(seventh)) == false) -- cheio de novo (6/6)

-- 5. Liberar duas vezes / desconhecido não quebra
PS.Release(players[3]); PS.Release(fake(99999))
check("release repetido é inofensivo", PS.GetOccupied() == 6, PS.GetOccupied())

-- 6. Geometria: IsInsidePlot
local plot1 = PS.GetPlot(players[1])
local base = plot1.Base
check("centro está dentro do lote", PS.IsInsidePlot(plot1, base.Position))
check("ponto distante está fora", PS.IsInsidePlot(plot1, base.Position + Vector3.new(500, 0, 0)) == false)
check("margem amplia a área", PS.IsInsidePlot(plot1, base.Position + Vector3.new(base.Size.X / 2 + 5, 0, 0), 10))

-- 7. Donos nunca duplicados nos atributos
local owners = {}
local dup = false
for _, p in ipairs(plots:GetChildren()) do
	local o = p:GetAttribute("OwnerUserId")
	if o ~= 0 then
		if owners[o] then dup = true end
		owners[o] = true
	end
end
check("nenhum jogador dono de dois lotes", dup == false)

reset()
clone:Destroy()
table.insert(results, failures == 0 and "TODOS OS TESTES PASSARAM" or (failures .. " TESTE(S) FALHARAM"))
return table.concat(results, "\n")
