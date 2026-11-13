--!strict
-- Extrato somente visual, a partir dos lançamentos privados que o servidor já saneou.
-- Totais são apenas dos ÚLTIMOS N eventos (não representam todo o patrimônio do jogador).
local RepairStatementRules = {}
local function finite(x: any): boolean
	return type(x) == "number" and x == x and x ~= math.huge and x ~= -math.huge
end
local function safeString(x: any, max: number): string
	return type(x) == "string" and string.sub(x, 1, max) or ""
end
function RepairStatementRules.Build(entries: any): any
	local rows = {}
	if type(entries) == "table" then
		for i, value in ipairs(entries) do
			if #rows >= 20 then break end
			if type(value) == "table" and finite(value.Amount) and value.Amount >= 0
				and value.Amount <= 1e8 and (value.Role == "Owner" or value.Role == "Worker") then
				table.insert(rows, {
					Service = safeString(value.Service, 64),
					Vehicle = safeString(value.Vehicle, 60),
					Amount = math.floor(value.Amount),
					Role = value.Role,
					At = finite(value.At) and math.max(0, math.floor(value.At)) or 0,
					Quality = finite(value.Quality) and math.clamp(math.floor(value.Quality), 0, 100) or nil,
					Stars = finite(value.Stars) and math.clamp(math.floor(value.Stars), 0, 5) or nil,
					SortIndex = i,
				})
			end
		end
	end
	table.sort(rows, function(a, b)
		if a.At == b.At then return a.SortIndex < b.SortIndex end
		return a.At > b.At
	end)
	local total, own, worker, qualityTotal, qualityCount = 0, 0, 0, 0, 0
	for _, row in ipairs(rows) do
		total += row.Amount
		if row.Role == "Worker" then worker += row.Amount else own += row.Amount end
		if row.Quality then
			qualityTotal += row.Quality
			qualityCount += 1
		end
		row.SortIndex = nil
	end
	return {
		Rows = rows, Count = #rows, Total = total, OwnerEarnings = own, WorkerEarnings = worker,
		AverageQuality = qualityCount > 0 and math.floor(qualityTotal / qualityCount + 0.5) or nil,
	}
end
return RepairStatementRules
