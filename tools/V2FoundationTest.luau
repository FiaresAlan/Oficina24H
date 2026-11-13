-- V2-00: nao toca perfil real/DataStore.
local Rules = require(game:GetService("ReplicatedStorage").Shared.V2CompatibilityRules)
local out = {}
local function test(name, ok) table.insert(out, (ok and "PASS " or "FAIL ") .. name) end
local p = {
 SchemaVersion=12, Coins=100, TotalEarned=120, Reputation=3, Employees=0, WorkshopLevel=1,
 Parts={}, SupplyRequests={}, Equipment={}, EquipmentLevels={}, OrderHistory={}, RepairLedger={},
 PendingClaims={}, PendingClaimAudits={}, OwnerSettlementProofs={},
 WorkerSettlementProofs={}, WorkerPaidTombstones={}
}
test("schema v12 e campos V1/V2", #Rules.Profile(p)==0)
p.Coins = -1
test("nega saldo negativo", #Rules.Profile(p)>0)
p.Coins = 100
p.SchemaVersion = 11
test("nego schema antigo", #Rules.Profile(p)>0)
p.SchemaVersion = 12
local s={Profile={Coins=100}, Jobs={}}
test("snapshot sem prova privada", #Rules.Snapshot(s)==0)
s.Profile.RepairLedger={}
test("nega ledger replicado", #Rules.Snapshot(s)>0)
test("nao altera perfil", p.Coins==100 and p.SchemaVersion==12)
return table.concat(out,"\n")
