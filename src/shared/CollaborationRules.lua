--!strict
-- Invariantes puras de colaboração: papel efetivo e repartição sem criar dinheiro.
local Config = require(script.Parent.Config)
local CollaborationRules = {}

local function finite(n: any): boolean
	return type(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge
end

function CollaborationRules.IsWorker(job: any, userId: number): boolean
	return type(job) == "table" and finite(userId)
		and job.CollaboratorUserId == userId
		and job.AssignedWorkerUserId == userId
		and job.OwnerUserId ~= userId
		and job.Status == "InProgress"
end

function CollaborationRules.IsAuthorized(job: any, userId: number): boolean
	return type(job) == "table" and finite(userId) and job.Status == "InProgress"
		and job.AssignedWorkerUserId == userId
		and (job.OwnerUserId == userId or CollaborationRules.IsWorker(job, userId))
end

function CollaborationRules.Split(total: number, percent: number): (number, number)
	if not finite(total) or total < 0 or not finite(percent) then
		return 0, 0
	end
	local amount = math.floor(total)
	local share = math.clamp(math.floor(percent), 1, Config.MaxServiceSplitPercent)
	local worker = math.floor(amount * share / 100)
	return amount - worker, worker
end

return CollaborationRules
