# Oficina 24H — V2-12 | Test-drive contextual para diagnóstico

**13/11/2026 — engenharia da V2-12 na PR #27.**
**Gate físico:** `src/shared/V2DriveScenarioRules.lua` contém `R.LiveEnabled=false`. É proposital: o código está integrado, mas ninguém recebe diagnósticos por test-drive até homologar **V2-11 no Roblox Studio** e habilitar por revisão de código. Não alegar teste real executado.

## Regra central

O test-drive é **opcional** e sorteado apenas entre OS com um dos defeitos de condução conhecidos e o **Hatch amarelo piloto**; exclui novatos. A decisão é única por OS, usando seed inteiro secreto do servidor (`Random.new(seed)`). Chance de diagnóstico selecionado: **38% entre elegíveis**. Cerca de **12%** dos sinais selecionados só aparecem a partir do terceiro checkpoint. Esses números são hipóteses de ritmo para beta, não garantias de prevalência por jogador.

| Defeito real (só servidor) | Pista visível, sem entregar resposta | Gatilho observado |
|---|---|---|
| Pneu furado, pneu gasto, roda desbalanceada | Oscilação ou vibração da roda/volante | Velocidade real >=15 |
| Suspensão solta, braço quebrado, desalinhamento | Oscilação nas curvas e correções de volante | Velocidade >=10 e direção >=0,22 |
| Pastilha gasta | Frenagem com rangido | Velocidade >=7 e solicitação de freio |
| Falha de ignição e retífica | Resposta irregular do motor | Velocidade >=8 e aceleração >=0,35 |
| Superaquecimento | Temperatura crítica | 22s de rodagem e velocidade >=5 |

`Catalog.Defects` continua autoritativo. O plano `V2DriveScenarioRules.Plan` é criado ao gerar a ordem (`createJob`) e não é enviado integralmente ao cliente. O snapshot público inclui **somente** se há oferta, se cliente foi consultado, se o teste já ocorreu e se há evidência. A seed, o defeito secreto e o checkpoint de disparo ficam no servidor.

## Experiência e integração

1. O cliente NPC chega, apresenta a reclamação e o jogador aceita a OS. Em casos selecionados aparece **“OBSERVAR SINTOMA NA RUA”** na aba Em andamento, sem acrescentar botão à HUD. Conversar com o cliente antes de iniciar permanece obrigatório.
2. O servidor valida propriedade da oficina, atribuição e estado do Hatch, portas/rodas fechadas, ausência de elevador/mechanics ocupados, exclusividade de sessão e proximidade do avatar.
3. O mesmo `V2DriveService` de V2-11 cria carro físico temporário, com rota ordenada e quatro checkpoints no espaço local do lote, aceitando apenas throttle/steer limitado. A cada amostra, `Rules.AssessMotion` e `V2DriveScenarioRules.HasCondition` verificam velocidade, curva, desaceleração, tempo e checkpoint **observados pelo servidor**.
4. Quando o gatilho acontece, **somente o motorista** recebe `DriveCue`: aviso textual no painel, cor âmbar/vermelha, efeito SFX licenciado do `SoundIds` e vibração opcional do gamepad. Jamais depende somente de áudio.
5. O motorista pode voltar a qualquer momento. **Só** a volta voluntária com 4 checkpoints e >=32 segundos é considerada conclusiva; alvo de design **45–90 segundos** a validar no Studio. A conclusão com sintoma reproduzido gera **uma pista** `DriveObservation`, sem `DefectId`, moeda ou XP, que aparece na janela de diagnóstico após a conversa/exame.
6. `DiagnosisEvidence.RequiresExam` e `DiagnosisRules.Judge` **continuam obrigatórios**. A pista de rua não adivinha o diagnóstico nem elimina inspeções de bancada.

Há no máximo uma rodagem diagnóstica **concluída** por OS e duas tentativas de início para tolerar um abortamento de conexão. Teste abandonado/colisão não reduz reputação, não consome peças e **nunca concede** evidência parcial como conclusão. Todos os elementos existem apenas enquanto a OS está ativa.

## Segurança

- Não há `Touched` ou `RemoteEvent` que registre o checkpoint, o defeito, o laudo, a nota ou o pagamento. O retorno só usa `V2DriveService.End`; `OnDriveOutcome` é callback privado registrado pelo `Main.server.lua`.
- O modo `DriveCar.Mode=Diagnosis` é validado pelo proprietário, OS em andamento, cenário selecionado, consulta realizada e ausência de sessão ativa. Enviar modo `FreeMoney`, a seed, um sinal falso ou ID de outra OS não libera nada.
- `DriveCue` é cosmético. A origem confiável é telemetria servidor de movimentação física, não valor recebido do cliente. A rotina financeira da V1 foi preservada.
- Sem ativo 3D importado, o Hatch físico fallback da V2-11 continua disponível, mas **não foi dirigido em Studio** nesta fase.

## Matriz de teste Studio necessária

- Rodar `tools/RunAllTests.luau`, incluindo `V2DriveScenarioTest`: determinismo seed, percentuais de teste, exames preservados, spoilers, gatilhos de aceleração/freio/curva/temperatura, checkpoint, replay, abortos.
- Em Play Solo e 2 jogadores: Hatch proprietário x visitante, veículo de outra OS, caso rookie, Sedan/Picape, 0/1/2 tentativas, sintoma antes/depois da condição de disparo, laudo após retorno, sem música/áudio como única pista.
- Validar 45–90s com trânsito e lotes invertidos; tentar teleporte, input inválido, clique com tremor, ping alto, queda de rede e reconexão. Confirmar nenhum XP/moeda no exame.
- Verificar acessibilidade sem vibração, áudio mutado, gamepad e botões touch.
- **Não habilitar `R.LiveEnabled=true` apenas porque o GitHub Actions está verde.** Requer V2-11 física aprovada e evidências registradas no checklist V2-16.

**Dependências:** V2-11 (homologação Studio pendente) e V2-04 (exames de diagnóstico/pivôs). **Próxima fase implementada em código:** V2-13 (verificação pós-reparo, também sob o mesmo gate).
