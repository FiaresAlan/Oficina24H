# Auditoria geral — Oficina 24H (2026-11-07, madrugada)

Três auditorias independentes, cada uma seguindo a skill correspondente (fwjelaa-anti-exploit-review +
secure-remotes + datastore-safety; fwjelaa-performance-audit; fwjelaa-tutorial + trend-game +
monetization-compliance). Abaixo: o que foi achado, o que já foi corrigido e o que fica no plano.

## 1. Segurança e dados — sem falhas críticas ou altas
Verificado limpo: todos os remotes checam tipos e recusam NaN/inf/fração; checkout tudo-ou-nada; prompts conferem o
dono no servidor; vaga reservada antes de qualquer espera; sessão com trava (lease) e salvamento no fechamento;
falha de carga expulsa sem gravar padrão; gancho de QA só no Studio; a devolução do anexo antigo não se repete.

| Achado | Gravidade | Situação |
|---|---|---|
| Sair e voltar zerava o relógio do salário dos funcionários (nunca pagava) | Média | **Corrigido**: `NextPayAt` salvo no perfil; vencido enquanto fora = cobra ao voltar |
| Colaborador concluía sem minijogo, de longe da máquina, com pagamento e XP cheios | Média | **Corrigido**: precisa estar na máquina; vale qualidade padrão 85% e metade do XP |
| Mecânico avulso de qualquer lugar e passando por cima do colaborador | Baixa | **Corrigido**: só na TV de ordens e nunca com colaborador na ordem |
| Códigos promocionais legíveis pelo cliente | Baixa | **Corrigido**: lista só no servidor (`server/PromoCodes.lua`) com início/validade |
| Versão do esquema de dados não subia | Baixa | **Corrigido**: versão 3. (Recusar versão mais nova fica pendente: exige não gravar ao expulsar.) |
| Moedas ±inf/negativas e XP NaN não eram limpos | Baixa | **Corrigido** na carga |
| Ações em rajada forçavam o snapshot a remontar | Baixa | **Corrigido**: no máximo ~4 montagens/s por jogador |
| Distâncias usam a posição do personagem (cliente) | Aceito | Só afetam conveniência (loja, TV), não pagamentos |

## 2. Desempenho / celular (estimativa estática — medir em celular real antes/depois)
Pior caso estimado: 6 lotes nível 3 + 3 rivais + 12 carros andando ≈ 20–30 FPS em Android fraco; rede 100–200 kbps.

| Achado | Situação |
|---|---|
| SurfaceGuis desenhados a qualquer distância (~70 no mapa) | **Corrigido**: `MaxDistance = 140` |
| 36 marcadores de box semitransparentes (overdraw) | **Corrigido**: invisíveis (a marcação é a faixa e o elevador) |
| Cartão do cliente recriava a miniatura 3D a cada snapshot | **Corrigido**: só recria quando muda o cliente |
| Snapshot a cada 4 s | **Ajustado** para 6 s (as ações já atualizam na hora) |
| Carros movidos pelo servidor a cada frame (rede + tranco no 4G) | **Plano #1**: mandar caminho + hora de início uma vez e animar no cliente (VehicleFx); ~95% menos tráfego de carros |
| Triângulos/memória | **Plano #2**: StreamingEnabled (modelos Atomic), versões leves dos 18 carros estacionados |
| VehicleFx por frame | **Plano**: pular carros parados, `BulkMoveTo`, cachear atributos, desligar efeitos de longe |
| Snapshot leva histórico e transações | **Plano**: buscar histórico só ao abrir o Perfil |
| Prévias dos 21 carros em ReplicatedStorage | **Plano**: imagens prontas no lugar dos modelos |

## 3. Retenção e primeiros 60 segundos
Implementado nesta rodada:
- **Recompensa diária** com sequência de 7 dias (100 → 700 moedas + peças), tela abre sozinha ao entrar.
- **3 missões diárias** sorteadas por jogador/dia (14 tipos: reparos, faturamento, 5 estrelas, perfeitos, diagnóstico
  de primeira, VIP, especialidades, Hora do Rush), com moedas e reputação.
- **14 conquistas** permanentes (clientes 1/10/50/200, faturamento, VIP, perfeitos, olho clínico, prédio 1/2/3,
  sequência de 7 dias), pagas na hora; perfis antigos recebem as que já merecem.
- **Códigos promocionais** (OFICINA24H, MECANICO, TURBO) para divulgar nas redes.
- **Hora do Rush**: a cada 12 min, 3 min de clientes em dobro e serviços +50%, com aviso 30 s antes e faixa com
  contagem (motivo para ficar e voltar).
- **Combo do turno**: reparos seguidos com qualidade ≥ 70% pagam +10% cada (até +50%); cliente que desiste ou serviço
  abandonado zera.
- **Primeiro minuto**: o 1º cliente chega logo após registrar a oficina; os 2 primeiros têm defeitos que o estoque
  inicial resolve, sem reclamação enganosa e sem VIP; enquanto espera, o guia já leva até a TV; o ponteiro do guia
  agora tem luz-guia do pé do jogador até o alvo; funil do guia no Analytics (`LogOnboardingFunnelStepEvent`:
  registrou → aceitou → diagnosticou → reparou).

## 4. Próximas mecânicas recomendadas (ordem)
1. **Clientes fiéis e indicação**: quem dá 5★ entra numa lista de fregueses (até 8); 30% das chegadas vêm dela,
   pagam +25% e têm +50% de paciência; na 3ª visita indicam um VIP garantido. (Relação → volta no D7.)
2. **Contratos de frota** na TV a cada 20 min ("Táxi Veloz: 3 pneus em 8 min", 500 moedas + 6 reputação); se não
   cumprir, um rival "pega" e o painel da praça anuncia.
3. **Liga semanal do bairro** (reputação ganha na semana, faixas Bronze/Prata/Ouro com 300/800/2.000 moedas e selo
   no totem; global por OrderedDataStore com chave da semana).
4. **Projeto de restauração**: comprar uma sucata de preço fixo na Construtora, restaurar em 5 etapas (minijogo +
   peças), vender por 2,2× o investido ou expor na vitrine.
5. **Social**: +10% jogando no mesmo servidor que um amigo; "Curtir oficina" (+1 reputação, limite diário); visitar
   oficina pelo ranking da praça; conquistas como Badges.

## 5. Monetização (conforme regras de 2026 — conferir antes de publicar)
Nada à venda ainda. Proposta sem pay-to-win e sem itens aleatórios pagos:
- Passes: pacote de pintura/LED da fachada (149 R$), texto do letreiro personalizado com filtro (99 R$), uniforme
  colorido + buzina (79 R$), "Gerente" que repõe peças automaticamente pelo preço normal em moedas (249 R$).
- Produtos: entrega expressa de peças na prateleira (peças pagas em moedas, 15 R$), "café da equipe" (funcionários
  45 s em vez de 60 s por 20 min, 29 R$), pacote inicial de moedas 750 por 49 R$ (1 por dia).
- Servidor privado: 100 R$.
- Não vender: multiplicador de moedas, boxes/funcionários além do nível, pular requisitos de nível.
- Implementação: um único `ProcessReceipt` que grava a entrega junto com o PurchaseId; preço lido de
  `GetProductInfoAsync`; nada de prompt de compra durante o guia.
