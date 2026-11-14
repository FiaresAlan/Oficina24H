--!strict
-- Política de despacho: primeiro carro é reservado ao jogador durante 25 segundos.
-- Com dois carros aguardando o mecânico ajuda imediatamente.
local Rules = {}
Rules.SoloWaitSeconds = 25
function Rules.ShouldDispatch(waiting: number, oldestSeconds: number): boolean
	return type(waiting) == "number" and type(oldestSeconds) == "number"
		and (waiting >= 2 or (waiting >= 1 and oldestSeconds >= Rules.SoloWaitSeconds))
end
-- Homologação V1 (place real): o funcionário tomava a OS enquanto o dono conversava, examinava ou preparava o
-- carro, e o trabalho do jogador se perdia. Uma OS em que o dono mexeu há menos de 25 s é dele.
Rules.OwnerIdleSeconds = 25
function Rules.OwnerIsWorking(lastTouch: any, now: number): boolean
	return type(lastTouch) == "number" and lastTouch == lastTouch and type(now) == "number"
		and now - lastTouch < Rules.OwnerIdleSeconds
end
function Rules.EligibleJob(waiting: number, jobWaitingSeconds: number): boolean
	return waiting >= 2 or jobWaitingSeconds >= Rules.SoloWaitSeconds
end
-- Uma ordem pode ter um único funcionário executor. A reserva é criada
-- SINCRONAMENTE no tick, antes de qualquer task.spawn/yield de pathfinding.
function Rules.IsReserved(busy: any, jobId: any): boolean
	return type(busy) == "table" and type(jobId) == "string" and busy[jobId] == true
end
function Rules.TryReserve(busy: any, jobId: any): boolean
	if type(busy) ~= "table" or type(jobId) ~= "string" or jobId == ""
		or Rules.IsReserved(busy, jobId) then return false end
	busy[jobId] = true
	return true
end
function Rules.Release(busy: any, jobId: any): boolean
	if not Rules.IsReserved(busy, jobId) then return false end
	busy[jobId] = nil
	return true
end
return Rules
