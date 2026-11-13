--!strict
-- Política de despacho: primeiro carro é reservado ao jogador durante 25 segundos.
-- Com dois carros aguardando o mecânico ajuda imediatamente.
local Rules = {}
Rules.SoloWaitSeconds = 25
function Rules.ShouldDispatch(waiting: number, oldestSeconds: number): boolean
	return type(waiting) == "number" and type(oldestSeconds) == "number"
		and (waiting >= 2 or (waiting >= 1 and oldestSeconds >= Rules.SoloWaitSeconds))
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
