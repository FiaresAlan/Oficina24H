--!strict
-- Orçamento por janela fixa (padrão 1 s) para chamadas que não passam pelo throttle genérico de ações:
-- RepairAction (cada clique do procedimento precisa de ACK) e montagens de snapshot (GetSnapshot).
-- Puro e determinístico: o chamador fornece o relógio. Nunca concede moedas, só decide se atende.
local RequestBudgetRules = {}

export type State = { Start: number, Count: number }

local function finite(n: any): boolean
	return type(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge
end

-- true = pode atender agora (e consome 1 do orçamento); false = acima do limite nesta janela.
function RequestBudgetRules.Take(states: { [number]: State }, userId: number, now: number, limit: number, window: number?): boolean
	if type(states) ~= "table" or not finite(userId) or not finite(now) or not finite(limit) or limit < 1 then
		return false
	end
	local span = if finite(window) and (window :: number) > 0 then window :: number else 1
	local state = states[userId]
	if not state or now < state.Start or now - state.Start >= span then
		state = { Start = now, Count = 0 }
		states[userId] = state
	end
	if state.Count >= limit then
		return false
	end
	state.Count += 1
	return true
end

function RequestBudgetRules.Clear(states: { [number]: State }, userId: number)
	if type(states) == "table" then
		states[userId] = nil
	end
end

-- Eco seguro para o cliente: só devolve strings curtas e números finitos que ele próprio enviou.
function RequestBudgetRules.EchoString(value: any, maxLength: number?): string?
	if type(value) ~= "string" or #value > (maxLength or 64) then
		return nil
	end
	return value
end

function RequestBudgetRules.EchoNumber(value: any): number?
	if not finite(value) then
		return nil
	end
	return value
end

return RequestBudgetRules
