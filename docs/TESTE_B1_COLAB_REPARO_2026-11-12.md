# B1 — Mecânico contratado executa reparo real
**Data:** 12/11/2026  
**Branch:** `work/oficina24h-b1-colaboracao-com-reparo-2026-11-12`  
**Base:** `work/oficina24h-a3-inspecao-fisica-2026-11-12`  
**Validação feita:** auditoria estática de caminhos/contratos pelo GitHub. **Sem execução em Roblox Studio, sem simulação de dois jogadores e sem DataStore de homologação.**

## Problema de produto

Anteriormente, `CompleteCollaborativeJob` pagava ao contratado e ao dono sem executar o reparo. A OS recebia qualidade fixa de 85%, o trabalhador metade do XP e a oficina nota/reputação sem ver um procedimento real. Isso contradizia a proposta de emprego social.

## Alterações

1. **Atuação real:** aceitar convite marca o trabalhador como executor autorizado; o botão legado `CompleteCollaborativeJob` agora abre `StartRepair`, não paga nada diretamente.
2. **Autorização:** `CollaborationRules.IsAuthorized` aceita apenas o dono quando é executor ou o convidado quando o contrato foi aceito; outros são recusados.
3. **Equipamentos:** o contratado pode usar a máquina no **lote do dono**, nunca máquinas de terceiros; o lote de origem vem do servidor pelo `ProximityPrompt.Triggered`.
4. **Peças:** são verificadas e consumidas apenas do estoque do dono da OS.
5. **Qualidade:** o contratado executa o mesmo `RepairOperations` ou `RepairRules` que o dono faria e recebe qualidade real, com XP pela própria habilidade.
6. **Pagamento:** valor do serviço+gorjeta dividido em percentuais; sem bônus de combo e amigos do contratado, sem multiplicação artificial. Reputação, estrelas, comentário, evento de missão e contrato vão para a oficina dona.
7. **Ciclo de vida:** um funcionário não pode aceitar duas OS simultâneas; contratos não começam se o dono já iniciou um reparo; saída do dono encerra sessão e notifica o contratado; saída do trabalhador retorna a OS para o dono; expiração não interrompe minijogo válido.
8. **UI:** o convidado pode enxergar os prompts do carro da OS contratada e das máquinas daquela oficina. O servidor valida novamente cargo, OS, habilidade, distância, peça e equipamento.

## O que não foi construído

**Ainda não há dois jogadores manipulando ao mesmo tempo etapas diferentes do MESMO carro.** Este PR corrige a delegação enganosa e faz o trabalhador realmente reparar; cooperação simultânea com divisão de tarefas e guincho interno pertence ao próximo incremento P1/P2, após homologação.

## Testes escritos

`tools/CollaborationRulesTest.luau` cobre 13 cenários determinísticos: quem pode executar, quem não pode, transferência de cargo, soma do pagamento, limites e entradas inválidas. Registrado em `RunAllTests`.

## Casos obrigatórios em Studio (PENDENTES)

- [ ] Dois jogadores: A aceita carro, diagnostica e convida B com porcentagem definida; B aceita e o convite registra a autorização.
- [ ] A tenta executar a OS enquanto B está designado — negar.
- [ ] B tenta concluir sem chegar ao carro — negar.
- [ ] B usa o prompt do carro, executa pneu/bateria/arrefecimento, recebe a avaliação real; condição de peça, estoque e financeiro do A se atualizam.
- [ ] Conferir soma do dinheiro de A+B = serviço+gorjeta, sem duplicação e sem bonus de amigo/combo para contratado.
- [ ] Repetir o mesmo `FinishRepair` / `CompleteCollaborativeJob` duas vezes — não duplicar pagamento.
- [ ] B executa reparo de equipamento especializado na máquina do A; tentativa de usar máquina do C deve ser negada.
- [ ] B com habilidade insuficiente não consegue aceitar contrato que exige nível maior.
- [ ] B tenta aceitar contratos com A e C simultaneamente — negar segundo.
- [ ] B sai no meio do reparo — A retoma a OS; estado do carro/elevador é limpo.
- [ ] A sai durante o reparo de B — sessão fechada, sem recompensas, sem permissão residual.
- [ ] Contrato excede 180 segundos com minijogo ativo — não interromper o trabalho válido; após expirar sem sessão, reverter.
- [ ] Celular e gamepad: prompt do convidado visível, legível e acionável.
- [ ] DataStore publicado: saldo, skills e avaliação persistem para cada perfil correto.
- [ ] Outros jogadores não conseguem falsificar UserId, remuneração, JobId nem usar máquinas de terceiros.
- [ ] Rodar `RunAllTests` completo após sincronização da branch pelo Rojo.

## Riscos e dependências

- O fluxo de colaboração muda áreas sensíveis: `WorkshopService.FinishRepair`, `EquipmentService`, `Main.server`, `HUD`. **Não mesclar na main nem afirmar estabilidade antes de testar.**
- A experiência continua dependente dos modelos de veículos do place em `ServerStorage/Assets`.
- O quadro de contratos já exibe `CollabJobs`, mas orientação GPS até a oficina contratante ainda não está integrada.
- A interface de resultados mostra a parte recebida por B; A recebe avaliação e notificação.
- Compatibilidade: nenhum DataStore/schema foi alterado. Não foram publicados place/arte.
