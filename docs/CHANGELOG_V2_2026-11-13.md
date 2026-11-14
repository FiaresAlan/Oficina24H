# CHANGELOG OFICINA 24H — V2 | Engenharia até V2-15

**Atualizado:** 13/11/2026. **Estado:** PR #27 (draft) em branch isolada. Não corresponde a uma publicação, merge na `main` ou homologação Roblox Studio.

## V2-15 — Segurança, performance, acessibilidade e auditoria

**Segurança:**
- Novo `V2RemoteSecurityRules`: até 44 ações em rajada / refil 26 por segundo por jogador, 12 snapshots em rajada / 8 por segundo, bloqueio de input profundo/circular/gigante/NaN/Instances.
- `Main.server.lua` aplica orçamento global a todos os comandos conhecidos, inclusive `RepairAction` e `CheckRepairResult` antes da economia; limpa estado por usuário no logout.
- A cadeia original de liquidação V1 permanece única; nada no cliente pode conceder moedas ou alterar prova de OS.

**Desempenho:**
- `V2VisualBudgetRules`: pré-filtro **antes de Clone** para carros dirigíveis e NPCs/carrocerias visuais por partes, quantidade de instâncias, SurfaceAppearance e limites físicos. Fallback procedural se o Hatch real exceder.
- `V2DriveService`: máximo de 5 rigs físicos simultâneos/servidor; mantém network ownership exclusivo do servidor e cancela com retorno ao box.
- `V2NeighborhoodAmbient` e `V2NeighborhoodAssets` rejeitam modelos excessivos antes de replicar/clonar; figurantes continuam cosméticos sem colisão.
- StreamingEnabled auditado apenas no Studio; não configurado por script no lugar errado.

**Persistência e economia:**
- `ContractService.endContract` só informa prêmio depois de `DataService.Save` confirmar; falha gera estado pendente e tentativa posterior com a **mesma** chave de concessão.
- Pontos da liga e bônus de contrato não são recalculados/reconcedidos no retry; o livro caixa diferencia entradas de frota de pagamento de OS.
- `V2FleetContractTest` simula Save falho, retry, JobId repetido e prova de pagamento no mesmo perfil sem duplicação.

**UX e inclusão:**
- Perfil salva `Accessibility` com DriveHaptics / DriveSfx / LowDetail e migrador conservador.
- Três botões dentro de Ordens → Equipe; a pista de diagnóstico conserva mensagem textual quando áudio/vibração são desligados. Modo leve limita figurantes e FOV.
- Aba Perfil → Créditos reúne fontes/atrelamentos conhecidos e alerta sobre direitos de HUD, ícones externos, modelo esportivo e uso de marcas.

**Testes e auditoria:**
- Novas suites `V2RemoteSecurityTest`, `V2RuntimeAssetBudgetTest`, `V2AccessibilityTest`, `V2CreditsTest`, `V2ReleasePlaceAudit`, mais Save/Load na suite `PersistenceTest` e retry em `V2FleetContractTest`.
- Scripts registrados em `RunAllTests.luau` e verificação estática `tools/ci/verify_contracts.py`.
- Documentação detalhada, riscos, matriz adversarial e gate em [V2_FASE_15_HARDENING_RELEASE.md](V2_FASE_15_HARDENING_RELEASE.md).
- **Ainda não executado:** runtime Luau/Studio, multiplayer, FPS, áudio real, streaming no place, licença de cada asset, reconciliação com novas correções V1/main.

## V2-12/13 (rodada anterior)

- Test-drive contextual de diagnóstico (seed e telemetria do servidor, pistas, sem renda por colisão) e verificação de qualidade pós-reparo com retrabalho opcional e liquidação V1 única; **`LiveEnabled=false` até homologar V2-11**.
- Documentação [diagnóstico](V2_FASE_12_DIAGNOSTICO_DRIVE.md) e [qualidade](V2_FASE_13_QUALIDADE_RETRABALHO.md).

## V2-14 (rodada anterior)

- Propostas negociáveis de frota, duas modalidades de prazo/bônus, cotações por capacidade/estoque, vínculo com staff/colaborador/NPC, relacionamentos persistentes e bônus idempotente em perfil; melhorado na V2-15 para aguardar Save.
- Documentação [frotas e contratos](V2_FASE_14_FROTAS_CONTRATOS.md).

## Pendências obrigatórias antes de publicação

- **V2-08:** fornecedores econômico/padrão/premium e lotes FIFO por qualidade ainda não concluídos.
- **V2-11/12/13:** homologação real de física, segurança, UX, qualidade e DataStore; `LiveEnabled` continua false.
- **V2-14/15:** testes reais multiusuário, celular, gamepad, stress de remotes, conclusões de frota e persistência de bônus/reputação.
- **Legal:** licença de sprites do HUD, autorização escrita do pacote de ícones, origem do esportivo vermelho, atribuições de obras CC BY reativadas e marcas. Tela de créditos não resolve direito de uso.
- **Tradução:** `Locale.lua` suporta `pt-BR` atualmente; expansão internacional exige `en-US` e revisão de textos V2.
- **Release:** branch V2 deve ser revisada e reconciliada com a `main` atual, sem sobrescrever o trabalho de homologação V1 do Claude, e beta fechado aprovado explicitamente pelo proprietário.

**Os quadrados [S] do checklist permanecem abertos.**
