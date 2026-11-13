# C16/C17 — upgrade de equipamentos por plataforma e mecânicos trabalhando (13/11/2026)

## Inspiração e compatibilidade
O usuário descreveu um simulador de fazenda em que basta pisar numa plataforma verde para comprar melhorias. A Oficina 24H **já possuía** loja de autopeças, 11 tipos de equipamento (incluindo o kit inicial), modelos físicos, quatro níveis de prédio e funcionários NPC. A nova rodada **não substitui** a loja nem libera equipamentos pagos antes de comprá-los.

## C16 — níveis I, II e III e compra por aproximação
- `shared/EquipmentUpgradeRules.lua`: cada equipamento possuído evolui de nível 1 até nível 3. Os custos para subir ao nível seguinte vêm do custo original do catálogo: mínimo de 180 moedas na primeira melhoria, 420 na segunda; itens mais caros custam proporcionalmente mais.
- `DataService` migra perfil para **schema v8** e guarda `EquipmentLevels`, incluindo a atualização dos usuários antigos para nível 1.
- Cada nível fornece um pequeno ganho de eficiência em reparos (até o teto de 4 pontos na nota), bônus financeiro de até +6% em serviços com a máquina e melhorias discretas de tempo/qualidade dos mecânicos NPC.
- `EquipmentUpgradePads` cria plataformas verdes em frente a cada equipamento possuído dentro da oficina, com nome, próximo nível e preço.
- O servidor examina se o `HumanoidRootPart` do **proprietário** entrou no volume do pad. Há um evento de compra **por entrada**; permanecer parado não compra o nível seguinte. Sem confiança em cliques remotos do cliente.
- O preço e a posse são revalidados no servidor; custo é debitado da conta persistível pelo DataService e não pode ficar negativo. A máquina ganha indicativo físico de nível II/III e a loja mostra `Instalado · N2`.
- Ao comprar novas máquinas na loja ou ampliar a oficina, as placas são reorganizadas conforme os slots físicos existentes. No nível máximo a plataforma de melhoria desaparece.
- **UX importante:** não existe tela de confirmação: pisar intencionalmente no pad compra automaticamente. Evitar posicionar as placas em corredores de passagem obrigatória.

## C17 — primeiro mecânico mais cedo e trabalho visível
- A Oficina nível 1 (2 boxes) já permite 1 mecânico; Centro Automotivo nível 2 permite 2. A garagem inicial ainda não permite contratar.
- O funcionário sai do seu ponto de descanso e tenta caminhar pelo caminho calculado até o carro, com animação de caminhada. O `NpcKit` existente mantém fallback de reposicionamento se ficar preso.
- O NPC mostra frases de diagnóstico/troca de peças/testes, segura uma chave procedural, executa um ciclo visível de movimentação e informa o avanço pelo atributo `RepairProgress`.
- Uma ordem com um único carro fica 25 segundos reservada ao dono antes de ser automaticamente assumida; com duas ordens disponíveis, o funcionário pode ajudar imediatamente.
- Continua consumindo peças, usando equipamento exigido e recebendo salário fixo. As máquinas melhoradas aceleram o trabalho, aumentam moderadamente a qualidade e geram pequena melhoria no valor do serviço.
- Se o mecânico for removido/demitido antes da conclusão, o trabalho não deve cobrar peças nem gerar pagamento automaticamente.

## Testes de regressão **escritos**, ainda não executados no Studio
- `tools/EquipmentUpgradeTest.luau`: preço e evolução em todo o catálogo, limite 3, sanitização, eficiência/recompensas e velocidade dos NPCs.
- `tools/StaffAssignmentTest.luau`: 0, 1 e 2 carros, direito de preferência de 25 s.
- `tools/PersistenceTest.luau`: kit inicial, schema v8, compra de níveis II/III, saldo insuficiente, nível máximo e reconexão.
- `tools/CatalogTest.luau`: limites de funcionários adequados ao prédio.
- `tools/ci/verify_contracts.py`: checa a ligação real dos módulos com o servidor e a lógica de compra física.

## Roteiro para teste no Roblox Studio (PENDENTE)
1. Abrir a oficina nível 0 com 250 moedas: localizar a plataforma verde do Kit de ferramentas, pisar uma vez e confirmar nível II e débito de 180 moedas. Permanecer parado não pode comprar nível III.
2. Sair e entrar no pad: verificar aviso de saldo insuficiente sem compra indevida. Adicionar 420 moedas via QA Studio e comprar nível III (deve custar 420). A placa deve desaparecer no nível máximo.
3. Sair do servidor e entrar novamente; nível III, histórico de débito e saldo devem permanecer. Repetir com outro equipamento adquirido na Loja.
4. Comprar/instalar nova máquina e ampliar prédio: placas devem aparecer nos slots atualizados; não ocupar o caminho essencial dos boxes, estoque ou TV.
5. Evoluir para Oficina nível 1 (2 boxes), contratar um mecânico pelo quadro físico. Testar 1 carro esperando por 24 s (o jogador mantém prioridade) e após 25 s (NPC começa), e 2 carros (NPC ajuda sem espera).
6. Observar NPC percorrendo o trajeto até o carro e de volta, animação de caminhada, chave visual e mensagens de andamento. Repetir com avatar R6/R15/asset ausente e verificar fallback de pathfinding.
7. Verificar peças, salário, tempo de 60 s versus máquina nível III (~50 s), preço com bônus de até 6%, satisfação do cliente e que dispensar o funcionário durante a OS não paga automaticamente.
8. Testar dois jogadores em oficinas diferentes, respawn, latência, mobile/gamepad e 60 FPS. Compra só pode ocorrer na própria oficina.

## Riscos conhecidos
- Modelos e animações de NPC dependem dos assets em `ServerStorage.Assets.Clientes`, ou dos fallbacks já existentes. Sem assets adequados, não se pode garantir a animação no Studio.
- `NpcKit.WalkPath` permite fallback de posicionamento ao travar, por isso o movimento não é garantidamente contínuo em todo layout do prédio. Precisa ser testado.
- A compra física não pede confirmação, por design. A posição das plataformas precisa de homologação visual para não gerar compras acidentais.
- Novos ganhos financeiros e contratação em nível 1 podem exigir ajustes de balanceamento após playtests.
- CI atual valida código e build Rojo, **não** roda o Roblox Studio nem comprova o gameplay.
