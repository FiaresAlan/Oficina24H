-- C28: bloquear liquidação que terminou seu Save(worker) depois de
-- saída/reentrada do proprietário ou alteração do colaborador.
local Guard = require(game.ReplicatedStorage.Shared.RepairCommitGuard)
local lines, failed = {}, 0
local function check(name, ok)
	if not ok then failed += 1 end
	table.insert(lines, (ok and "PASS " or "FAIL ") .. name)
end
local job = {
	Id = "job_28", OwnerUserId = 2801, AssignedWorkerUserId = 2802,
	CollaboratorUserId = 2802, Status = "InProgress",
}
local jobs = { job_28 = job }
local function valid()
	return Guard.CanSettle(job, jobs.job_28, 2801, 2802, true, true, true)
end
check("C28: colaboração ativa permite liquidação", valid())
jobs.job_28 = nil
check("C28: dono saiu durante Save; OS removida não pode pagar",
	not valid())
jobs.job_28 = {
	Id = "job_28", OwnerUserId = 2801, AssignedWorkerUserId = 2802,
	CollaboratorUserId = 2802, Status = "InProgress",
}
check("C28: nova OS com mesmo ID não é a sessão original",
	not valid())
jobs.job_28 = job
check("C28: dono desconectado bloqueia mesmo antes da limpeza da OS",
	not Guard.CanSettle(job, jobs.job_28, 2801, 2802, true, false, true))
check("C28: worker desconectado bloqueia liquidação",
	not Guard.CanSettle(job, jobs.job_28, 2801, 2802, true, true, false))
job.CollaboratorUserId = nil
job.AssignedWorkerUserId = 2801
check("C28: cancelamento da colaboração impede pagamento capturado",
	not valid())
check("C28: dono pode retomar OS, mas sessão antiga do worker não",
	Guard.CanSettle(job, job, 2801, 2801, false, true, true)
	and not Guard.CanSettle(job, job, 2801, 2802, true, true, true))
job.Status = "Completed"
check("C28: OS já concluída não liquida novamente",
	not Guard.CanSettle(job, job, 2801, 2801, false, true, true))
job.Status = "InProgress"
job.AssignedWorkerUserId = 2802
job.CollaboratorUserId = 2802
check("C28: dono/worker invertidos não passam guarda",
	not Guard.CanSettle(job, job, 2802, 2801, true, true, true)
	and not Guard.CanSettle(job, job, 2801, 2802, false, true, true))
job.CollaborationSplitPercent = 30
check("C28: percentual contratado permanece válido durante Save",
	Guard.CanSettle(job, job, 2801, 2802, true, true, true, 30))
job.CollaborationSplitPercent = 45
check("C28: mudança de percentual durante Save cancela o pagamento antigo",
	not Guard.CanSettle(job, job, 2801, 2802, true, true, true, 30))
job.CollaborationSplitPercent = 30
check("C28: dados inválidos falham fechados",
	not Guard.CanSettle(nil, nil, 2801, 2802, true, true, true)
	and not Guard.CanSettle(job, job, 0, 2802, true, true, true))
table.insert(lines, failed == 0 and "TODOS OS TESTES PASSARAM"
	or (failed .. " TESTE(S) FALHARAM"))
return table.concat(lines, "\n")
