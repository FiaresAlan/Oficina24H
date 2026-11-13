-- C24: prova detalhada só pode ser compactada se o dono já confirmou
-- BAIXA no seu DataStore, worker não possui claim e o tombstone bloquear replay.
local Paid = require(game.ReplicatedStorage.Shared.WorkerSettlementProofRules)
local Archive = require(game.ReplicatedStorage.Shared.WorkerProofArchiveRules)
local Tombs = require(game.ReplicatedStorage.Shared.WorkerPaidTombstoneRules)
local Owner = require(game.ReplicatedStorage.Shared.OwnerSettlementProofRules)
local lines, errors = {}, 0
local function check(name: string, ok: boolean)
	if not ok then errors += 1 end
	table.insert(lines, (ok and "PASS " or "FAIL ") .. name)
end
local at = 1790000000
local token = "c24aaaaa-1111-2222-3333-cccccccccccc"
local proof = Paid.Make("job_24", token, 160, at, "Freios", "Hatch", 2401)
local ownerProof = Owner.Make("job_24", token, 2402, 80, 160, "Freios", "Hatch", at)
local ownerRaw = { OwnerSettlementProofs = { ownerProof } }
check("C24: não liberar antes da baixa do dono", not Archive.CanCompact(proof,
	ownerRaw, {}, 2401))
ownerRaw.OwnerSettlementProofs = {}
check("C24: IDs devem corresponder", not Archive.CanCompact(proof, ownerRaw, {}, 2403))
check("C24: perfil do dono indisponível preserva prova",
	not Archive.CanCompact(proof, nil, {}, 2401))
check("C24: sem lista de provas no dono, não compacta",
	not Archive.CanCompact(proof, {}, {}, 2401))
check("C24: sem lista de claims no worker, não compacta",
	not Archive.CanCompact(proof, ownerRaw, nil, 2401))
local claim = {
	OwnerUserId = 2401, JobId = "job_24", Token = token,
	OwnerPay = 80, WorkerPay = 160, XP = 20, Quality = 90,
	Service = "Freios", Vehicle = "Hatch", Spec = "Brakes", At = at,
}
check("C24: presença de claim impede compactação",
	not Archive.CanCompact(proof, ownerRaw, { claim }, 2401))
check("C24: quitado e sem claim é elegível",
	Archive.CanCompact(proof, ownerRaw, {}, 2401))
check("C24: sem vínculo histórico com dono não é elegível",
	not Archive.CanCompact(Paid.Make("legacy", token, 160, at,
		"Freios", "Hatch"), ownerRaw, {}, 2401))
local batch, cursor = Archive.Batch({ proof, proof, proof, proof, proof }, 1,
	at + Archive.GraceSeconds)
check("C24: máximo de 4 consultas", #batch == Archive.MaxReadsPerPass and cursor == 5)
local nextBatch, nextCursor = Archive.Batch({ proof, proof, proof, proof, proof },
	cursor, at + Archive.GraceSeconds)
check("C24: cursor circular alcança todos", #nextBatch == 4 and nextCursor == 4)
local young = Paid.Make("young", "c24bbbb-1111-2222-3333-cccccccccccc",
	2, at + 800, "Freios", "Hatch", 2401)
local chosen = Archive.Batch({ young, proof }, 1, at + Archive.GraceSeconds)
check("C24: não consulta provas recentes", #chosen == 1 and chosen[1] == proof)
local originals, tombs = { proof }, {}
check("C24: compactação troca prova por tombstone",
	Tombs.Compact(originals, tombs, "job_24", token)
	and #originals == 0 and #tombs == 1 and Tombs.Find(tombs, "job_24", token) ~= nil)
check("C24: nova compactação do mesmo token é recusada",
	not Tombs.Compact(originals, tombs, "job_24", token))
check("C24: sanitize remove tombstones corrompidos ou duplicados",
	#Tombs.Sanitize({ tombs[1], tombs[1], { JobId = "invalid" } }) == 1)
local paidLedger = {}
check("C24: migração não ressuscita prova compactada", (function()
	local Ledger = require(game.ReplicatedStorage.Shared.SettlementLedgerRules)
	Ledger.Record(paidLedger, "job_24", token, 160,
		"Worker", at, "Freios", "Hatch")
	return #Paid.FromLedger({}, paidLedger, tombs) == 0
end)())
local nearLimit = {}
for i = 1, Tombs.MaxEntries do
	nearLimit[i] = { JobId = "job_" .. i,
		Token = string.format("c24dddd-1111-2222-3333-%012d", i) }
end
local another = Paid.Make("another", "c24eeee-1111-2222-3333-cccccccccccc",
	120, at, "Freios", "Hatch", 2401)
local stillDetailed = { another }
check("C24: tombstones lotados não apagam prova detalhada",
	not Tombs.Compact(stillDetailed, nearLimit, another.JobId, another.Token)
	and #stillDetailed == 1 and #nearLimit == Tombs.MaxEntries)
table.insert(lines, errors == 0 and "TODOS OS TESTES PASSARAM"
	or (errors .. " TESTE(S) FALHARAM"))
return table.concat(lines, "\n")
