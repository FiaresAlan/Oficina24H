--!strict
-- Estado da interface: guarda o último snapshot enviado pelo servidor e notifica as telas.
-- O cliente só EXIBE dados e SOLICITA ações; valores e regras são decididos no servidor.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remotes = ReplicatedStorage:WaitForChild("OficinaRemotes")
local actionEvent = remotes:WaitForChild("Action") :: RemoteEvent
local snapshotFunction = remotes:WaitForChild("GetSnapshot") :: RemoteFunction

local Store = {}

Store.Snapshot = nil :: any
Store.Changed = Instance.new("BindableEvent") -- dispara após cada atualização do snapshot
Store.Message = Instance.new("BindableEvent") -- (texto, sucesso) vindo do servidor
Store.Invite = Instance.new("BindableEvent") -- convite de trabalho recebido
Store.RepairStart = Instance.new("BindableEvent") -- servidor sorteou o desafio do minijogo (Plan, Vehicle, Service)
Store.RepairActionAck = Instance.new("BindableEvent") -- servidor confirmou/rejeitou um ajuste do procedimento
Store.RepairOutcome = Instance.new("BindableEvent") -- consulta idempotente do comprovante de entrega
Store.RepairQualityPending = Instance.new("BindableEvent") -- V2-13: avaliação mecânica selada, sem crédito
Store.DriveCue = Instance.new("BindableEvent") -- V2-12: sinal seguro emitido pelo servidor no test-drive
Store.DiagnoseStart = Instance.new("BindableEvent") -- servidor enviou as opções de diagnóstico (Options, Complaint...)
Store.DiagnoseDone = Instance.new("BindableEvent") -- diagnóstico correto
Store.RepairDone = Instance.new("BindableEvent") -- resultado do reparo (Quality, Tip, Stars...)
Store.Rated = Instance.new("BindableEvent") -- avaliação de cliente confirmada pelo servidor (Stars, CommentKey, ReputationDelta, Service)
Store.SnapshotClock = 0 -- os.clock() do último snapshot (para animar tempos de espera entre atualizações)

local refreshing = false

function Store.Refresh()
	if refreshing then
		return
	end
	refreshing = true
	local ok, snapshot = pcall(function()
		return snapshotFunction:InvokeServer()
	end)
	refreshing = false
	if ok and type(snapshot) == "table" and snapshot.Profile then
		Store.Snapshot = snapshot
		Store.SnapshotClock = os.clock()
		Store.Changed:Fire(snapshot)
	end
end

function Store.Act(name: string, payload: { [string]: any }?)
	actionEvent:FireServer(name, payload or {})
end

actionEvent.OnClientEvent:Connect(function(kind: string, payload: any)
	if type(payload) ~= "table" then
		return
	end
	if kind == "Result" then
		local text = tostring(payload.Message or "")
		if text ~= "" then -- ações que só abrem uma tela (ex.: diagnóstico) respondem sem texto
			Store.Message:Fire(text, payload.Success == true, type(payload.Action) == "string" and payload.Action or "")
		end
		task.delay(0.15, Store.Refresh)
	elseif kind == "WorkInvite" then
		Store.Invite:Fire(payload)
	elseif kind == "Rated" then
		Store.Rated:Fire(payload)
	elseif kind == "DiagnoseStart" then
		Store.DiagnoseStart:Fire(payload)
	elseif kind == "DiagnoseDone" then
		Store.DiagnoseDone:Fire(payload)
	elseif kind == "Notice" then
		Store.Message:Fire(tostring(payload.Message or ""), payload.Success == true, "")
		task.delay(0.3, Store.Refresh) -- avisos (contrato, freguês, Rush) costumam mudar o estado
	elseif kind == "RepairActionAck" then
		Store.RepairActionAck:Fire(payload)
	elseif kind == "RepairOutcome" then
		Store.RepairOutcome:Fire(payload)
	elseif kind == "RepairStart" then
		Store.RepairStart:Fire(payload)
	elseif kind == "RepairDone" then
		Store.RepairDone:Fire(payload)
    elseif kind == "RepairQualityPending" then
        Store.RepairQualityPending:Fire(payload)
        task.delay(0.15,Store.Refresh)
    elseif kind == "DriveCue" then
        Store.DriveCue:Fire(payload)
	end
end)

-- Atualização periódica: novas ordens chegam do servidor sem ação do jogador.
task.spawn(function()
	while true do
		Store.Refresh()
		task.wait(6) -- as ações já pedem atualização na hora; o ciclo é só para novidades do servidor
	end
end)

return Store
