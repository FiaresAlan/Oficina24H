# V2-16 — Homologação Studio, beta fechado e decisão Go/No-Go

**Estado em 13/11/2026:** pacote de engenharia para homologação entregue na PR #27 (draft), **não é aprovação de release nem execução de testes no Roblox Studio**. O código continua isolado da `main`. Não publicar antes dos gates abaixo e autorização do proprietário. O CI verde cobre contratos de código e build Rojo, não física nem os modelos 3D no place.

## 1. Resultado inicial observável

**Go/No-Go: NO-GO / BLOQUEADO**. A matriz `V2ReleaseGateRules.Gates` possui 16 critérios: nenhum tem evidência de aprovação neste repositório. O manifesto `docs/release/V2_RELEASE_EVIDENCE.json` foi criado com `Status=Pending`, e os bloqueios já conhecidos `merge_main`, `inventory_fifo` e `licenses` estão `Blocked`. A PR #27 aparece como não mesclável na API GitHub no checkpoint desta rodada; conferir novamente na hora da reconciliação, pois a `main` muda durante o QA V1.

**Dependências fundamentais reais:**

- **Integração:** rever PR #27 contra a `main` atual, preservar todas as mudanças C1–C31/V1 do Claude, resolver conflitos em branch de integração, nunca usar force-push sobre a `main`. Só então definir o SHA candidato.
- **V2-08:** fornecedores Econômico/Padrão/Premium e lotes FIFO por qualidade continuam não concluídos. São P0; o gate `inventory_fifo` deve permanecer bloqueado até implementação, teste de migração de dados e verificação Studio.
- **V2-11:** direção do Hatch está em código, mas física (torque, rede, câmeras, checkpoints, rodas, queda, retorno) ainda precisa passar Play Server com 2 jogadores e dispositivos de toque/gamepad.
- **V2-12/13:** `V2DriveScenarioRules.LiveEnabled=false`. Estes fluxos **não devem ser habilitados por simplesmente iniciar o beta**. Ou homologar em PR de ativação específica com novo QA ou manter desligados no build beta.
- **Licenças:** pendências sobre sprites do HUD, ícones cedidos informalmente, esportivo vermelho e direitos de logos/marcas; `Perfil → Créditos` é atribuição, não autorização para uso. Ver `docs/ORIGEM_ASSETS.md`.

## 2. Checklist operacional de Studio (primeiro Edit, depois Play)

1. Criar **cópia privada de homologação** do place original. Importar ao place os GLBs licenciados que já foram baixados, restaurar organização em `ServerStorage.Assets`, e usar Rojo para sincronizar os scripts da **branch V2 candidata**; não sobrescrever o place V1 ativo. Confirmar SHA completo candidato.
2. No **Roblox Studio, Command Bar do lado servidor, modo Edit**, executar:
   ```luau
   print(require(game.ServerStorage.Tools.RunAllTests))
   print(require(game.ServerStorage.Tools.StudioPlaceAudit))
   print(require(game.ServerStorage.Tools.V2ReleasePlaceAudit))
   print(require(game.ServerStorage.Tools.V2BetaSmokeAudit))
   ```
   O `RunAllTests` já inclui `V2ReleaseGateRulesTest`, `V2BetaSmokeAudit`, testes de remotos, economia, assets, perfis e as suítes antigas de reparos. **Salvar a saída integral e o SHA**. `WARN` exige revisão; qualquer `FAIL` ou erro de require bloqueia o gate `studio_suites`.
3. Rodar **Test → Start Server (2 jogadores)**. Inspecionar ao vivo as saídas da janela Server/Client, falta de models, suspensão/retorno do Hatch, `RemoteEvent` falsificado, equipamento, carteira, OS concorrente, colaboração e logout no meio do reparo.
4. Executar **cada um dos 15 defeitos** do catálogo, em modelos e níveis distintos, com diagnóstico/inspeção, abertura e fechamento de componentes, reparo físico, consumo de peças, recibo, atualização de qualidade, estrelas e dinheiro **exatamente uma vez**. Repetir a solicitação da última entrega e validar idempotência. Preencher [a matriz CSV de 15 serviços](release/V2_TEST_MATRIX_15_SERVICOS.csv) com status observado (`APROVADO`, `FALHOU` ou `BLOQUEADO`), evidência real, dispositivo, modelo, jogadores e SHA.
5. Rodar **novo perfil sem progresso**: os primeiros 30 segundos de atendimento guiado, primeiras 2–3 OS, melhoria de oficina nível 0→1, desbloqueio de 2ª vaga, contratação/atribuição de funcionário, estoque e receita. Não usar QA cheat neste teste.
6. Executar **fluxos de equipe/economia**: dois jogadores, convite e repasse, NPC avulso, funcionário, frotas Standard/Express, recusa/expiração, revenda, showroom, estoque, reposição, salários, saldo negativo proibido e importação de perfil anterior. Após Save falho/reconnect/replay, verificar o mesmo saldo/prova.
7. Testar **remotos adversos** em servidor de homologação, nunca produção: spam distribuído por ações, payload 121 entradas/NaN/Instance, tokens de reparo e carro de outro usuário, reenvio de `FinishRepair`, `CheckRepairResult` e `DriveInput`; nenhuma concessão monetária fora da liquidação.
8. Verificar **PC teclado, gamepad, celular/tablet**: botões de mínimo 44px, abrir menus sem escurecer gameplay, controle do veículo, retorno seguro, modo visual leve, haptics e SFX desligados, textos sem áudio, textos localizados em pt-BR, primeiro tutorial completo.
9. Conferir **Workspace.StreamingEnabled** com o place real, limites de assets PBR, colisão de veículos, animações e sons. Gravar FPS mínimo/p95 de frame time, memória e latência do servidor/client nos dispositivos-alvo. Não inventar limites/medidas que não foram coletados.
10. A equipe executa **beta fechado**, observa jogadores novos (sem instrução do desenvolvedor), registra desistências, qualidade do onboarding, 10–25 min de gameplay real, equilíbrio financeiro e P0/P1. Só passar para candidato de publicação depois de os bugs críticos serem corrigidos e QA repetido.

**Importante:** os módulos de QA não reconfiguram `StreamingEnabled`, não geram licenças e não acionam `DataStore` de produção. Não há acesso a uma máquina Roblox Studio desta conversa para executar esses passos aqui.

## 3. Matriz de evidências e verificação automatizada

**Regra pura:** `src/shared/V2ReleaseGateRules.lua`. **Teste de regra:** `tools/V2ReleaseGateRulesTest.luau`. **Auditoria do place:** `tools/V2BetaSmokeAudit.luau`. **Manifest honesto:** `docs/release/V2_RELEASE_EVIDENCE.json`. **Enforcer Python:** `tools/ci/release_gate.py`.

Para cada gate, preencher `Status` (`Passed|Failed|Blocked|Pending`), `Source` com o valor exigido pela regra, `Proof` com URL HTTPS verificável para logs/prints/comentário/relatório, `Notes` com observações reais (mínimo 12 caracteres), `VerifiedAt` em UTC ISO, `BuildSha` igual ao SHA completo **do build testado**. Exemplo de preenchimento apenas depois de ter o link real do teste; **não use um link inventado**.

| Gate | Fonte exigida | Evidência necessária |
|---|---|---|
| `ci_code` | CI | GitHub Actions para o SHA exato, sem falhas e build Rojo válido |
| `merge_main` | GitHub | PR/merge check sem conflitos + revisão de compatibilidade com V1 |
| `studio_suites` | Studio | Saída integral de RunAllTests e StudioPlaceAudit sem FAIL |
| `assets_place` | Studio | Inventário/prints do place e teste de scripts não confiáveis |
| `services_15` | Studio | Tabela de 15 reparos reais, saldo e recibo por serviço |
| `onboarding` | Studio | Gravação de sessão de jogador novo, upgrade nível 1 |
| `cooperation` | Studio | Dois jogadores e NPC/staff, desconexão e repartição |
| `data_safety` | Studio | Save/Load, falha de Save, replay, rollback e perfil migrado |
| `inventory_fifo` | Studio | Fornecedores/lotes FIFO P0 completos, importação e testes reais |
| `drive_physics` | Studio | Direção do Hatch real, controle/colisão/retorno em dois jogadores |
| `touch_gamepad` | Studio | Sessões reais touch e gamepad, legendas sem som |
| `performance` | Studio | Medidas de frame-time, memória e latência por dispositivo-alvo |
| `stream_audio` | Studio | StreamingEnabled, SFX, música e animações funcionando no place |
| `licenses` | Legal | Licenças e autorizações auditadas, sem assets sem direito de uso |
| `beta_closed` | Beta | Resultados fechados, bugs críticos eliminados e QA repetido |
| `owner_go` | Owner | Decisão explícita do proprietário ligada ao build testado |

O enforcer **não autentica os links**, portanto uma aprovação administrativa do proprietário precisa verificar que cada URL demonstra realmente o critério correspondente. O arquivo de evidências *não é* um botão de publicação nem um RemoteEvent: nenhum dado do cliente deve alterá-lo.

### Comandos para Windows (PowerShell) ou GitHub Actions

```powershell
python tools/ci/release_gate.py --self-test

# Apenas relatório (código CI não deve ficar vermelho por QA ainda pendente)
python tools/ci/release_gate.py --mode report --sha <SHA_COMPLETO_DE_40_CARACTERES>

# O comando de autorização técnica: exit code 1 enquanto QUALQUER gate estiver faltando
python tools/ci/release_gate.py --mode enforce --sha <SHA_COMPLETO_DE_40_CARACTERES>
```

O GitHub Actions executa `--self-test` e `--mode report` em cada commit; **isso não ativa a experiência, não promove build e não muda o status draft da PR**.

**Atenção ao SHA e ao manifesto:** o candidato de jogo precisa ser congelado em SHA `X`; salvar depois o manifesto de QA na branch modifica o HEAD para SHA `Y`. Usar `--sha X` e publicar exatamente o build `X`, com as evidências mantidas em branch/documentação ou edição de manifesto sem substituir o build congelado; **não aprovar `Y` com testes só de `X`**. Se qualquer código do place mudar depois do teste, requer novo SHA de build e regressões afetadas.

## 4. Regras de autorização e bloqueadores

**GO técnico só quando 16/16 gates tiverem `Passed` com fonte, timestamp, notas, URL e SHA correto.** Ainda assim, inspeção humana dos artefatos precede qualquer publicação. `RunAllTests`, `StudioPlaceAudit`, `V2BetaSmokeAudit` e `GitHub Actions` não podem preencher o gate `owner_go` nem o `licenses`.

**P0/P1 = não publicar;** corrigir e testar de novo. Defeitos cosméticos menores podem ir para backlog P2 apenas com decisão explícita da equipe, sem transformar defeitos de gameplay/economia em cosméticos. Fases opcionais V2-12/13 ficam **desligadas** no beta se não houver teste físico e PR de ativação homologado.

O resultado final desta rodada continua sendo **NO-GO** por falta de execução Studio, conflitos de integração, V2-08 FIFO, licenças e beta. A contribuição da V2-16 é um mecanismo de validação e um roteiro **utilizável** assim que o proprietário/Claude executar o Studio.

## 5. Entregáveis e rastreabilidade

- `src/shared/V2ReleaseGateRules.lua`, `tools/V2ReleaseGateRulesTest.luau`: 16 critérios fail-closed; sem ativar gameplay.
- `tools/V2BetaSmokeAudit.luau`: medição estrutural observável do place, sem Side Effects de gameplay.
- `docs/release/V2_RELEASE_EVIDENCE.json`: manifesto inicial com 3 bloqueios conhecidos e 13 gates sem evidência, todos fechados.
- `docs/release/V2_TEST_MATRIX_15_SERVICOS.csv`: 15 linhas sincronizadas automaticamente com os IDs de `Catalog.Defects`, sem nenhum serviço marcado como já executado; o CI detecta lacunas e exige URL+SHA em linhas `APROVADO`.
- `tools/ci/release_gate.py` + `.github/workflows/code-health.yml`: autoverificação adversarial da regra e relatório de decisão, sem CI simular Studio.
- `tools/RunAllTests.luau`, `tools/ci/verify_contracts.py`: suítes e proteção dos contratos.
- `docs/CHECK_LIST_MESTRE_V2.md`, issue #26 e PR #27: status sem falsos checks de Studio.

**Resultado do projeto:** engenharia de QA V2-16 implementada, homologação do jogo ainda **pendente**. 
