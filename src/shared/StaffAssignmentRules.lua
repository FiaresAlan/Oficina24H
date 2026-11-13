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
return Rules
