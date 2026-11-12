--!strict
-- Invariantes de integridade para atendimento NPC, isoladas para testes de regressão.
local RivalRules = {}

export type SettlementState = {
	Active: boolean,
	BayReserved: boolean,
	VehiclePresent: boolean,
	Completed: boolean,
	Credited: boolean,
}

function RivalRules.CanSettle(state: SettlementState): boolean
	return state.Active == true
		and state.BayReserved == true
		and state.VehiclePresent == true
		and state.Completed == true
		and state.Credited == false
end

-- Um NPC não deve disputar uma segunda vaga que fisicamente não existe.
function RivalRules.BayCapacity(physicalBays: number, marketLimit: number): number
	if physicalBays ~= physicalBays or marketLimit ~= marketLimit then
		return 0
	end
	return math.max(0, math.min(math.floor(physicalBays), math.floor(marketLimit)))
end

return RivalRules
