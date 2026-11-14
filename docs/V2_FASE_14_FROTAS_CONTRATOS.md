# Oficina 24H — V2-14 | Frotas, propostas, operação e relacionamento comercial

**Engenharia em 13/11/2026 — PR #27.** A V2-14 é independente do gate de dirigibilidade da V2-11; contratos existentes continuam gerando ordens normais sem exigir dirigir veículos. Testes estáticos/compilação Rojo são executados no CI; **testes Luau, Play Solo/multiplayer, economia e UI no Studio não foram executados nesta rodada.**

## Ciclo de negócio

1. Depois de concluir o onboarding e registrar a oficina, o servidor sorteia **uma proposta de empresa** entre cinco áreas que a oficina realmente consegue atender: pneus, motor, elétrica, funilaria e suspensão.
2. A proposta aparece na aba **Ordens → Equipe**, sem escurecer a HUD. O jogador tem **130 segundos para escolher**. Pode recusar ou deixar expirar sem multa de moeda/reputação; o próximo convite respeita o cooldown da V1.
3. A interface apresenta capacidade atual de boxes/mecânicos, ocupação, número de defeitos atendíveis na área, peças por família com estoque insuficiente de referência e **duas condições de contrato cotadas pelo servidor**:
   - **Prazo normal:** pagamento de bônus e duração herdados de `ContractRules.Terms`.
   - **Entrega prioritária:** bônus ~20% maior, prazo ~22% menor.
   - Histórico positivo com o mesmo parceiro acrescenta 2% ao prêmio por contrato concluído, até **+10%**, sem bônus de reputação extra.
4. As propostas comparam contribuição bruta prevista da própria oficina, colaboração com 25% de repasse e NPC avulso (~55% sobre OS) **antes de peças, folha e variação de qualidade**. O valor de prêmio da frota está separado dos pagamentos individuais de OS. Não é promessa de lucro líquido.
5. Após aceitar, parte dos clientes NPC que chegarem à oficina pertence à frota. Cada OS sorteada pelo `createJob` obrigatoriamente usa um defeito realmente atendível pelo nível da especialização e equipamentos atuais. O identificador da frota vai no Job como vínculo **servidor-only** e o snapshot só informa o nome público da empresa.
6. O dono pode fazer o serviço, atribuir um funcionário na mesma aba, convidar um colaborador na OS ou contratar NPC avulso depois do diagnóstico; **essas opções já existem na V1/V2-05** e não foram substituídas por um crédito direto ao contratar.
7. Quando o **pagamento regular da OS** foi aplicado pela rotina existente, `rateService` avisa `ContractService.FleetDone(owner, token, job.Id, referênciaBruta, método)`. O servidor rejeita JobId duplicado, contrato expirado e token de outra frota. Acompanhamento separa Proprietário, Equipe, Colaborador e NPC avulso.
8. Ao completar a meta, o bônus de contrato e a reputação são creditados **uma única vez** por `DataService.RecordFleetOutcomeOnce`; o histórico da parceria aumenta e o jogo notifica o dono e o servidor. Falhar por tempo registra apenas expiração, sem punição adicional.
9. Nova oportunidade aparece depois do cooldown do contrato; nenhum botão envia preço, bônus, Company, deadline, JobId falso ou chave financeira para conceder pagamento.

## Implementação

**`src/shared/V2FleetBusinessRules.lua`**
- `Quote` estima custos de peças e capacidade a partir do catálogo de 15 defeitos, habilidades, equipamentos e estoque real; não usa uma lista simulada de carros/vagas.
- `TermsFromQuote` aceita somente `Standard` e `Express`; valores são calculados uma vez pelo servidor e mantidos na proposta.
- `NewAccounts`, `SanitizeAccounts`, `Record`, `PartnerBonus` e `PublicAccounts` limitam a memória persistente a 96 chaves e 20 eventos recentes; controlam relações apenas com as cinco empresas cadastradas, normalizam campos corrompidos e não replicam keys.

**`src/server/ContractService.lua`**
- `Offer` gera proposta opcional; `Negotiate` valida aceite/recusa/modo/prazo. `Active`, `WantsFleet` e `FleetDone` continuam compatíveis com geração de clientes/OS da V1.
- `FleetDone` exige JobId único + token do contrato ativo; contador por carro e registro do executor não podem incrementar em replay.
- `endContract` registra o bônus por GUID servidor único no **mesmo perfil** de moedas e reputação, remove contrato e notifica. Falhas de disponibilidade do perfil não anunciam sucesso e entram em nova tentativa no próximo tick.
- Jogadores desconectados não recebem bônus de contrato pendente; timers de contratos são por sessão, como na V1. O histórico de contratos *concluídos/expirados* é persistente, mas o contrato incompleto não é retomado entre servidores.

**`src/server/WorkshopService.lua`**
- O builder monta cotação apenas de especializações com pelo menos um defeito executável.
- `createJob` seleciona entre defeitos realizáveis para frotas, sem introduzir reparos impossíveis de concluir no prazo.
- `rateService` mantém o valor e a cadeia de pagamento da OS V1; apenas passa JobId e executor para o serviço de frota depois da liquidação. Funciona também para pagamentos colaborativos, staff e NPC sem criar caminho de payout paralelo.
- `GetSnapshot` omite `FleetAccounts` privado do perfil e retorna `ContractService.Snapshot` com proposta/cotação, andamento, margens de referência, histórico e parceiros sanitizados.

**`src/server/DataService.lua`**
- Campo aditivo **`FleetAccounts` no schema v15 existente**, gerado no perfil novo e saneado na reconciliação dos perfis anteriores. Não troca credenciais de sessão, histórico de OS, pagamentos de colaboradores, `RepairLedger` nem prova de recebimento da V1.
- `RecordFleetOutcomeOnce` usa `RewardKey` não replicado, valida parceiro, valor, reputação, registro e resultado; marca a chave, moeda e rep no mesmo objeto de perfil sem `yield`. Esse é o nível de atomicidade prometido. Uma falha de Save ainda requer retentativa e checagem de trava existente, não há transação cross-account.
- `FleetAccountSummary` entrega só conquistas e histórico resumido, sem o array de chaves de crédito.

**`src/server/Main.server.lua`**: ação `NegotiateFleet` no dispatcher com rate limiting comum; recebe apenas `Action` `Accept|Decline` e `Mode` `Standard|Express`; não recebe preço ou outro dado financeiro.

**`src/client/UI/Panels/Orders.lua`**: quadro comercial na aba Equipe com variantes, custo de peças, carga da oficina, decisões e receita de referência. Atribuição de funcionários já existente sinaliza quais OS são de frota. Sem nova aba principal da HUD, sem tela de escurecimento.

## Segurança, idempotência e reconexão

- **Contratos versus OS:** bônus da frota usa prova idempotente no perfil proprietário; pagamentos de OS e colaboradores continuam usando `SettleRepairOwnerOnce`, `WorkerSettlementProof`, `StageWorkerClaim` e recuperadores V1. Não se credita um contrato pela mera chegada do NPC, botão de atribuição, diagnóstico ou test-drive.
- **Spam/replay:** proposta só pode ser aceita uma vez; chave de crédito é GUID gerado no servidor, não enviado ao cliente. JobId concluído não é contado duas vezes. Uma instância de DataService recarregada de perfil salvo rejeita novamente o mesmo RewardKey.
- **Prazo:** expiração gera registro de resultado sem débito/reputação negativa; recusa também não dá multa. A estratégia de urgência paga mais, mas exige menos tempo.
- **Colaborador sai:** o contrato só avança quando a OS é liquidada; se falta quitação pelo sistema colaborativo da V1, não deve ser criado pagamento de frota só pela intenção de colaboração.
- **Dono desconecta:** as OS e contratos ainda ativos são descartados como na V1; o bônus *ainda não concedido* não é recebido. Resultados já registrados ficam no perfil após Save. **Retomada de contrato parcial entre sessões não foi implementada**; exigir produto decidir se esse comportamento de sessão é aceitável antes da publicação.
- **Custo real:** comparações são projeções. Preço final da OS depende da qualidade do reparo, gorjeta, comissão, estoque, folha e descontos; a cotação não afirma contribuição líquida realizada.

## QA e regressões

- `V2FleetBusinessRulesTest.luau`: preços, prazo/margem, disponibilidade de equipe/estoque/serviços, aceites válidos, falsificação, 5 empresas, bônus de relacionamento, migração de dados corrompidos, limites do histórico e replay.
- `V2FleetContractTest.luau`: proposta pendente, aceite Standard/Express, recusa, token estranho, JobId duplicado, proprietário, colaborador, funcionário, bônus único e relacionamento da empresa.
- `PersistenceTest.luau`: DataStore simulado salva/recarrega bônus, rep e key única entre instâncias A/B/C, replay não paga, expiração sem débito e resumo público sem chave.
- `tools/RunAllTests.luau` inclui ambas as novas suites; `tools/ci/verify_contracts.py` protege contratos de API, quote, segurança, payout único, dados privados e testes.

**Homologação Studio obrigatória:** rodar `RunAllTests` em Edit, 15 tipos de OS com 1–2 jogadores, ofertas das cinco empresas, dois modos, prazo, rede lenta, spam no remoto, staff/colaboradores, Save fail/timeout/disconnect, NPC, entrada de moedas e histórico após reload. Conferir se tempos, cotação e taxa de ofertas são divertidos e financeiramente compreensíveis. O CI prova apenas build Rojo + contratos textuais.
