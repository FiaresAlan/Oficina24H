local R = require(game.ReplicatedStorage.Shared.CustomerPersonaRules)
local out = {}
local function check(name, ok)
	table.insert(out, (ok and "PASS " or "FAIL ") .. name)
end
check("cinco arquétipos com rótulos", #R.Order == 5 and R.Get("Urgent").Label == "Com pressa")
check("sorteio padrão no início", R.Pick(function() return 0 end) == "Standard")
check("sorteio último no fim", R.Pick(function() return 0.999 end) == "Friendly")
check("sorteio determinístico", R.Pick(function() return 0.48 end) == R.Pick(function() return 0.48 end))
check("sorteio NaN não trava", R.Pick(function() return 0/0 end) == "Standard")
check("tipo desconhecido é neutro", R.Get("Desconhecido").Label == "Cliente comum")
check("cliente urgente espera menos", R.Patience(300, "Urgent") < R.Patience(300, "Standard"))
check("cliente tranquilo espera mais", R.Patience(300, "Friendly") > R.Patience(300, "Standard"))
check("paciência definida e positiva", R.Patience(300, "Standard") == 300 and R.Patience(0, "Urgent") == 0)
check("cliente econômico mais sensível a preço", R.PriceSensitivity("Budget") > R.PriceSensitivity("Urgent"))
check("premium urgente moderado", R.PayMultiplier("Urgent") > 1 and R.PayMultiplier("Urgent") < 1.2)
check("preço econômico não gera premiação extra", R.PayMultiplier("Budget") <= 1)
local ctx = { PriceMultiplier = 1.3, WaitSeconds = 200, PatienceSeconds = 300, Quality = 65 }
check("cliente apressado penaliza demora", R.RatingAdjustment("Urgent", ctx) < 0)
check("cliente econômico penaliza preço alto", R.RatingAdjustment("Budget", ctx) < 0)
check("exigente penaliza baixa qualidade", R.RatingAdjustment("Demanding", ctx) < 0)
check("exigente premia qualidade 90+", R.RatingAdjustment("Demanding",
	{ Quality = 95, PriceMultiplier = 1, WaitSeconds = 10, PatienceSeconds = 300 }) > 0)
check("sem qualidade não penaliza exigente invisivelmente", R.RatingAdjustment("Demanding",
	{ PriceMultiplier = 1, WaitSeconds = 10, PatienceSeconds = 300 }) == 0)
check("padrão não muda avaliação existente", R.RatingAdjustment("Standard", ctx) == 0)
check("ctx inválido volta neutro", R.RatingAdjustment("Urgent", nil) == 0)
local Market = require(game.ReplicatedStorage.Shared.CustomerRules)
local candidate = { Price = 1.4, Reputation = 10, SpecLevel = 1,
	ServiceableCount = 2, OpenJobs = 0, Capacity = 3, Distance = 100 }
candidate.PriceSensitivity = R.PriceSensitivity("Budget")
local economicalScore = Market.Score(candidate)
candidate.PriceSensitivity = R.PriceSensitivity("Urgent")
local hurryScore = Market.Score(candidate)
check("cliente econômico evita preço alto", economicalScore < hurryScore)
candidate.PriceSensitivity = 0 / 0
check("sensibilidade de preço adulterada não vira NaN", Market.Score(candidate) == Market.Score(candidate))
check("cliente exigente comenta reparo abaixo de 70", Market.CommentKey(
	{ PriceMultiplier = 1, WaitSeconds = 100, PatienceSeconds = 300,
	LevelMargin = 0, ByNpc = false, Quality = 65, PersonaId = "Demanding" }, 3) == "rating_comment_sloppy")
return table.concat(out, "\n")
