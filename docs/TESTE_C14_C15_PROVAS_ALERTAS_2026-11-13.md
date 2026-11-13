# C14 e C15 — prova ampliada de repasse e reivindicações sob auditoria

Data: 13/11/2026. Escopo: implementação de código no GitHub, não homologação de gameplay.

## C14 — prova de repasse independente do extrato
- `OwnerSettlementProofRules` mantém **até 1024** provas compactas para repasses colaborativos, separadas do `RepairLedger` de 64 itens. Cada prova tem JobId/token privados, UserId do contratado, valores do dono e contratado, serviço/veículo e timestamp.
- Schema **v7**: `OwnerSettlementProofs` é sanitizado em `DataService.reconcile`, gravado no **mesmo perfil** que saldo e ledger do proprietário, e omitido de `GetSnapshot`.
- `CreditRepairOnce` recebe opcionalmente os dados de divisão do contratado quando o crédito é da OS colaborativa. Rejeita prova duplicada dentro do arquivo e preserva o histórico de recebimento.
- A recuperação verifica primeiro a prova C14 com vínculo ao UserId correto, valores e serviço. Uma prova divergente **bloqueia** fallback ao ledger curto. Para pagamentos anteriores ao schema 7, há fallback ao ledger existente.
- **Limite:** a retenção de 1024 ainda pode expirar antes de uma reivindicação muito antiga; não é arquivo permanente nem confirmação de atomicidade entre jogadores.

## C15 — prevenção de corrida e visibilidade segura
- `SettlementClaimRules.Recoverable` exige que a reivindicação tenha pelo menos **600 segundos**; evita que o processo de recuperação pague XP/moedas enquanto o `FinishRepair` original ainda está concluindo a OS.
- Reivindicações não resolvidas **não são apagadas automaticamente**. Uma contagem agregada (quantas pendentes, quantas acima de 24 horas) é exibida em **Ordens > Concluídas**, sem JobId/token ou nomes de contas.
- `ReconcileWorkerClaims` avisa no log do servidor sobre reivindicações antigas (mais de 24 horas), com limite de um aviso por usuário por dia e sem tokens.
- Testes escritos em `OwnerSettlementProofRulesTest`, `SettlementClaimRulesTest` e `PersistenceTest` exercitam retenção após 70 ordens, identidade do contratado, valores adulterados, resumo privado, janela de segurança e migração v5–v7.

## Procedimento obrigatório de homologação no Roblox Studio
1. Rodar `tools/RunAllTests.luau` e `tools/StudioPlaceAudit.luau` dentro do place correto; registrar total de PASS/FAIL.
2. Com dois usuários, salvar a claim do mecânico, concluir e persistir a parcela do dono, simular falha da parcela do mecânico e derrubar o servidor.
3. Após o período de segurança, reconectar o mecânico: verificar crédito e XP **uma só vez**, recibo e extrato; repetir reconexões e tentativas.
4. Repetir o caso com **mais de 64** reparos do proprietário antes da volta do mecânico, para comprovar recuperação via `OwnerSettlementProofs`.
5. Testar claim sem prova ou com valores/WorkerUserId divergentes: jamais creditar. Verificar resumo na HUD mobile, gamepad e telas estreitas.
6. Injetar falhas `UpdateAsync` e `GetAsync`, trocar servidores, testar perda de sessão, limites e orçamento DataStore.

## P0 aberto
- **Sem transação distribuída atômica:** duas chaves de DataStore não podem ser gravadas em conjunto.
- O arquivo de 1024 provas tem capacidade limitada. Permanecem pendentes mecanismos de retenção de longo prazo sem apagar provas ainda reivindicáveis, auditoria administrativa e tratamento de órfãs.
- A janela de 600 s significa atraso de recuperação após crash, intencional nesta implementação conservadora.
- Minijogo timing legado, efeitos auxiliares de progressão, dispositivos reais, áudio, arte, desempenho e multiplayer real continuam sem homologação nesta rodada.
- Os contratos estáticos e o build Rojo do GitHub Actions NÃO executam os testes Luau no Studio.
