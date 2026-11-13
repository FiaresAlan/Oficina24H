--!strict
-- C27: snapshot autoritativo, cache por jogador e versão.
-- Invalidação não pode devolver estado anterior à última ação do usuário.
local Cache = {}
Cache.TtlSeconds = 0.4

function Cache.Invalidate(states: any, userId: number)
	local state = states[userId]
	if not state then
		states[userId] = { Generation = 1 }
		return
	end
	state.Generation += 1
	state.Cached = nil
end

function Cache.Clear(states: any, userId: number)
	states[userId] = nil
end

function Cache.Get(states: any, userId: number, now: number, build: () -> any): any
	local state = states[userId]
	if not state then
		state = { Generation = 0 }
		states[userId] = state
	end
	local cached = state.Cached
	if cached and type(now) == "number" and now == now
		and now >= cached.At and now - cached.At < Cache.TtlSeconds then
		return cached.Value
	end
	local generation = state.Generation
	local value = build()
	-- A montagem pode ceder execução: invalidar/remover a sessão durante
	-- o build impede que uma resposta antiga volte ao cache.
	if states[userId] == state and state.Generation == generation then
		state.Cached = { At = now, Value = value }
	end
	return value
end

return Cache
