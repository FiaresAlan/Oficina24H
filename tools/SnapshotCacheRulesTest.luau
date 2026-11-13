-- C27: comprar, atender e melhorar equipamentos invalida o HUD sem atraso.
local Cache = require(game.ReplicatedStorage.Shared.SnapshotCacheRules)
local lines, errors, builds = {}, 0, 0
local function check(name, ok)
	if not ok then errors += 1 end
	table.insert(lines, (ok and "PASS " or "FAIL ") .. name)
end
local states, score = {}, 10
local function build()
	builds += 1
	return { Score = score }
end
local first = Cache.Get(states, 2701, 100, build)
check("C27: primeira leitura cria snapshot", first.Score == 10 and builds == 1)
score = 20
check("C27: requests repetidos usam cache por 400ms",
	Cache.Get(states, 2701, 100.2, build) == first and builds == 1)
Cache.Invalidate(states, 2701)
local fresh = Cache.Get(states, 2701, 100.21, build)
check("C27: ação invalida cache antes de 250ms",
	fresh.Score == 20 and fresh ~= first and builds == 2)
check("C27: requests sem mutação não recompilam snapshot",
	Cache.Get(states, 2701, 100.3, build) == fresh and builds == 2)
score = 30
check("C27: expiração normal após 400ms atualiza",
	Cache.Get(states, 2701, 100.7, build).Score == 30 and builds == 3)
check("C27: cache por jogador isolado",
	Cache.Get(states, 2702, 100.7, build).Score == 30 and builds == 4)
score = 40
Cache.Invalidate(states, 2701)
check("C27: invalidação de A não altera cache B",
	Cache.Get(states, 2702, 100.8, build).Score == 30
	and Cache.Get(states, 2701, 100.8, build).Score == 40)
Cache.Invalidate(states, 2701)
local stale = Cache.Get(states, 2701, 101, function()
	Cache.Invalidate(states, 2701)
	return { Score = -1 }
end)
check("C27: montagem em yield não repõe cache de geração antiga",
	stale.Score == -1 and states[2701].Cached == nil)
score = 50
check("C27: nova leitura após yield usa nova geração",
	Cache.Get(states, 2701, 101.01, build).Score == 50)
Cache.Clear(states, 2701)
check("C27: saída limpa memória da sessão", states[2701] == nil)
check("C27: reentrada do usuário não reutiliza dados antigos",
	Cache.Get(states, 2701, 101.02, build).Score == 50
	and states[2701].Generation == 0)
Cache.Clear(states, 2701)
local afterLeave = Cache.Get(states, 2701, 102, function()
	Cache.Clear(states, 2701)
	return { Score = -2 }
end)
check("C27: montagem encerrada após leave não reanexa cache",
	afterLeave.Score == -2 and states[2701] == nil)
table.insert(lines, errors == 0 and "TODOS OS TESTES PASSARAM"
	or (errors .. " TESTE(S) FALHARAM"))
return table.concat(lines, "\n")
