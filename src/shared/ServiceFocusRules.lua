--!strict
-- O próximo passo é derivado exclusivamente do snapshot público da oficina.
-- Nunca descobre defeito antes do diagnóstico, nem concede moedas/XP ou dispara ações.
local ServiceFocusRules = {}

export type Focus = {
	Kind: string,
	Title: string,
	Description: string,
	Target: string,
	JobId: string?,
	EquipmentId: string?,
}

local function focus(kind: string, title: string, description: string, target: string, jobId: any?, equipmentId: any?): Focus
	return {
		Kind = kind, Title = title, Description = description, Target = target,
		JobId = type(jobId) == "string" and jobId or nil,
		EquipmentId = type(equipmentId) == "string" and equipmentId or nil,
	}
end

local function valid(n: any): boolean
	return type(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge
end

function ServiceFocusRules.Urgency(job: any): number
	if type(job) ~= "table" then return 0 end
	local patience = job.PatienceSeconds
	local waiting = job.WaitSeconds
	if not valid(patience) or patience <= 0 or not valid(waiting) then return 0 end
	return math.clamp(waiting / patience, 0, 1)
end

function ServiceFocusRules.MissingParts(job: any, profile: any): boolean
	local req = type(job) == "table" and job.Requirement
	local parts = type(req) == "table" and req.Parts
	if type(parts) ~= "table" then return false end
	local owned = type(profile) == "table" and profile.Parts
	for partId, need in pairs(parts) do
		if type(partId) == "string" and valid(need) and need > 0 then
			local qty = type(owned) == "table" and owned[partId]
			if not valid(qty) or qty < need then return true end
		end
	end
	return false
end

function ServiceFocusRules.Select(snapshot: any): Focus
	if type(snapshot) ~= "table" then
		return focus("Loading", "CARREGANDO OFICINA", "Buscando próximas ordens", "orders")
	end
	if snapshot.HasWorkshop == false then
		return focus("Register", "ABRIR SUA OFICINA", "Registre sua oficina para começar", "orders")
	end
	local active, waiting
	for _, job in ipairs(type(snapshot.Jobs) == "table" and snapshot.Jobs or {}) do
		if type(job) == "table" and type(job.Id) == "string" then
			if job.Status == "InProgress" and not active then
				active = job
			elseif job.Status == "Available" then
				local urgency = ServiceFocusRules.Urgency(job)
				if not waiting or urgency > ServiceFocusRules.Urgency(waiting)
					or (urgency == ServiceFocusRules.Urgency(waiting) and job.Id < waiting.Id) then
					waiting = job
				end
			end
		end
	end
	if active then
		local vehicle = tostring(active.VehicleName or "Veículo")
		if active.CollaboratorUserId ~= nil then
			return focus("Delegated", "SERVIÇO DELEGADO", vehicle .. " · acompanhe o profissional", "orders", active.Id)
		end
		if not active.Diagnosed then
			return focus("Diagnose", "CONVERSAR E DIAGNOSTICAR", vehicle .. " · examine o carro", "vehicle", active.Id)
		end
		if ServiceFocusRules.MissingParts(active, snapshot.Profile) then
			return focus("Stock", "FALTAM PEÇAS", vehicle .. " · vá à loja de autopeças", "shop", active.Id)
		end
		if active.PrepRequired == true and active.PrepComplete ~= true then
			return focus("Prepare", "PREPARAR VEÍCULO", vehicle .. " · siga os pontos amarelos", "vehicle", active.Id)
		end
		local eq = type(active.Requirement) == "table" and active.Requirement.EquipmentId or nil
		if type(eq) == "string" and eq ~= "BasicToolset" then
			return focus("Equipment", "USAR EQUIPAMENTO", vehicle .. " · vá até a máquina da oficina", "equipment", active.Id, eq)
		end
		return focus("Repair", "EXECUTAR REPARO", vehicle .. " · use a ferramenta", "vehicle", active.Id)
	end

	for _, job in ipairs(type(snapshot.CollabJobs) == "table" and snapshot.CollabJobs or {}) do
		if type(job) == "table" and type(job.Id) == "string" then
			return focus("Collaboration", "TRABALHO CONTRATADO",
				tostring(job.VehicleName or "Veículo") .. " · vá até a oficina parceira", "vehicle", job.Id)
		end
	end
	if waiting then
		local urgent = ServiceFocusRules.Urgency(waiting) >= 0.75
		return focus(urgent and "Urgent" or "Waiting",
			urgent and "CLIENTE IMPACIENTE" or "CLIENTE AGUARDANDO",
			tostring(waiting.VehicleName or "Veículo") .. " · consulte a TV de ordens",
			"orders", waiting.Id)
	end
	return focus("Idle", "OFICINA DISPONÍVEL", "Aguarde o próximo cliente", "orders")
end

return ServiceFocusRules
