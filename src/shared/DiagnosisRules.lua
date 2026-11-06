--!strict
-- Regras PURAS do diagnóstico por escolha: o cliente relata um sintoma (às vezes enganoso) e o jogador precisa identificar
-- o defeito entre 3 candidatos. O servidor guarda as opções e valida a escolha; cada palpite errado reduz a qualidade
-- do reparo (ver RepairRules.DiagnosisPoints) e a opção errada fica bloqueada.
local DiagnosisRules = {}

DiagnosisRules.OptionCount = 3

-- Opções: o defeito real, o defeito que o sintoma relatado sugere (quando a reclamação enganou) e candidatos plausíveis
-- (preferindo a mesma especialização). Embaralhadas. `rand()` em [0,1).
function DiagnosisRules.BuildOptions(defects: { [string]: any }, realId: string, hintId: string?, rand: () -> number): { string }
	local real = defects[realId]
	local chosen: { string } = { realId }
	local used: { [string]: boolean } = { [realId] = true }
	local function add(id: string)
		if not used[id] and defects[id] and #chosen < DiagnosisRules.OptionCount then
			used[id] = true
			table.insert(chosen, id)
		end
	end
	if hintId then
		add(hintId)
	end
	local function pool(sameSpecialization: boolean): { string }
		local ids = {}
		for id, defect in pairs(defects) do
			if not used[id] and ((defect.Specialization == real.Specialization) == sameSpecialization) then
				table.insert(ids, id)
			end
		end
		table.sort(ids) -- ordem estável antes de sortear (pairs não garante ordem)
		return ids
	end
	for _, sameSpecialization in ipairs({ true, false, true, false }) do
		if #chosen >= DiagnosisRules.OptionCount then
			break
		end
		local ids = pool(sameSpecialization)
		if #ids > 0 then
			add(ids[math.min(#ids, math.floor(rand() * #ids) + 1)])
		end
	end
	for i = #chosen, 2, -1 do -- Fisher-Yates
		local j = math.min(i, math.floor(rand() * i) + 1)
		chosen[i], chosen[j] = chosen[j], chosen[i]
	end
	return chosen
end

-- "invalid" (fora das opções ou já tentada), "wrong" ou "correct".
function DiagnosisRules.Judge(options: { string }, wrong: { [string]: boolean }, realId: string, choice: any): string
	if type(choice) ~= "string" or wrong[choice] then
		return "invalid"
	end
	local isOption = false
	for _, id in ipairs(options) do
		if id == choice then
			isOption = true
		end
	end
	if not isOption then
		return "invalid"
	end
	return choice == realId and "correct" or "wrong"
end

return DiagnosisRules
