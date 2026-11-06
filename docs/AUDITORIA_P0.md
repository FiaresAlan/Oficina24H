# Auditoria P0 — Oficina 24H contra o Product Master Document v2.0

Data: 2026-11-06. Auditoria **somente leitura**: nenhum arquivo do jogo foi alterado. O place foi apenas lido e rodado no Play (Studio).
Método: leitura do repositório e dos scripts, consultas no Studio por MCP, Play com 1 jogador, leitura (somente leitura) do DataStore real.
Rótulos do documento: **Implementado** (testado), **Parcial**, **Ausente**, **Não testado**.

## 1. Cabeçalho do relatório (seção 22)

| Campo | Conteúdo |
|---|---|
| Commit/versão | **Não há repositório git** no projeto (pasta `OFICINA24h`). Identificação: place `Oficina24H_Teste`, placeId 98576673620657, universo 10774930385, salvo na nuvem pelo Product Owner após o minijogo (2026-11-06). Código-fonte em `src/` (Rojo 7.7.1). |
| Ambiente testado | Roblox Studio (Play, 1 jogador, servidor local), com **API Services ligado** (DataStore real acessível do Studio). Simulações de tela por `ViewportOverride`. Nenhum dispositivo real, nenhum segundo jogador, nenhum servidor publicado. |
| Testes automáticos | 594 verificações passam (Catalog 419, Customer 59, Repair 36, Plot 27, Persistence 53). Não substituem multiplayer real nem celular (seção 18.1). |

## 2. Matriz P0 (seção 5)

| # | Sistema | Status | Evidência | Lacuna |
|---|---|---|---|---|
| 1 | Bairro e terrenos | Implementado | 6 lotes independentes, atribuição/liberação testada (PlotTest 27 + simulação de 6 jogadores); Play com 1 jogador | Dois jogadores reais; navegação no celular |
| 2 | Oficina | Implementado | Prédio com interior, 2 vagas dentro, equipamentos pequenos dentro e grandes no pátio; Play | Só 2 vagas (aceitável no MVP); desempenho não medido em celular |
| 3 | Clientes/NPCs | **Parcial** | Chegada automática (a cada 12 s), espera com barra de paciência, desistência (cliente sai da lista), reclamação em linguagem simples, painel "Clientes aguardando" | **Não existe NPC físico** (só 1 Humanoid no mundo: o jogador). Não há conversa de investigação, saída visual, nem aviso de desistência |
| 4 | Ordens | Implementado | Criar, aceitar, dispensar, abandonar, concluir; limpeza por tempo; dono sai → ordem volta e veículo some; histórico persistido | Ordem **em andamento nunca expira** (prende a vaga até o jogador abandonar); sem mensagem "cliente desistiu" |
| 5 | Diagnóstico | **Parcial** | Sintoma e defeito são distintos (35% das reclamações descrevem outro problema); defeito só aparece após diagnosticar; servidor confere distância | O diagnóstico é **automático** (segurar E / botão). O jogador não investiga nem escolhe defeito/solução; o servidor não valida escolha nenhuma |
| 6 | Reparos/minigames | Implementado | 1 minigame genérico (3–5 etapas, dificuldade pelo nível do serviço) cobre os 14 serviços e as 5 especializações; qualidade, nota, gorjeta e pagamento no servidor; 9 ataques recusados | Só **1 tipo** de minigame; equilíbrio de dificuldade sem dados de jogadores; celular real |
| 7 | Peças/estoque | Implementado | Compra (carrinho tudo-ou-nada), estoque persistido, consumo único na conclusão, compatibilidade por defeito; 12 payloads maliciosos de Checkout recusados | Sem faixas de qualidade de peça (ver 9) |
| 8 | Equipamentos | Implementado | Serviço bloqueado com mensagem clara quando falta o equipamento (testado com Desmontadora ausente/presente); compra e modelo físico | — |
| 9 | Qualidade | **Parcial** | Execução (acerto + rapidez) e habilidade (sobra de nível alarga a zona) afetam qualidade, nota e gorjeta | **Equipamento e peça não afetam a qualidade** (só liberam o serviço). O doc pede os quatro fatores |
| 10 | Habilidades | **Defeito** | 5 especializações, XP, níveis, lista do que cada nível libera | **Motor não tem serviço de nível 1** (Overheating exige 2, Misfire 3, Overhaul 5) e o XP é por especialização: **o Motor nunca sobe** |
| 11 | Economia | Implementado | Receita, custo de peças, compra de equipamento, preço 70–150% com efeito no mercado; sem aluguel (conforme o doc) | Mecânico NPC fica com 45% do preço sem minigame e sem XP (renda de pouco esforço); equilíbrio sem dados |
| 12 | Avaliações | Implementado | Nota, comentário derivado dos fatores reais, aviso imediato, perfil e histórico persistidos | — |
| 13 | Perfil | Implementado | Nível/XP, reputação, média, clientes atendidos, histórico; atualiza com dados do servidor | Taxa de retorno ausente (permitida pelo doc) |
| 14 | HUD/UI | **Parcial** | HUD e 5 painéis no estilo da referência; PC testado; 7 tamanhos medidos | **Celular real não testado**. Botões sem função: Configurações, Sair (desabilitados), aba Conquistas, Ferramentas/Acessórios e Consumíveis vazias. O doc proíbe botões e painéis decorativos |
| 15 | Multiplayer | **Não testado** | Dados por UserId; ordens, estoque e ações validam o dono; 6 jogadores simulados | Nenhum teste com 2 jogadores reais. Jogadores veem os prompts "E" dos carros dos outros (o servidor recusa, mas confunde) |
| 16 | Persistência | **Parcial** | Verificado: perfil v2 (moedas, XP, avaliações, histórico) **foi gravado e relido do DataStore real** pelo Studio, com trava de sessão | Não testado: servidor publicado, 2 servidores, reconexão, BindToClose real. **O Studio usa a mesma chave de produção** (sem sufixo de teste) e o perfil do dono já está contaminado por testes |
| 17 | Onboarding | **Ausente** | Só dicas do "Painel de ordem" | Nenhum tutorial guiado do primeiro atendimento |
| — | Segurança | Parcial (boa) | Distância, tipo, estado e frequência validados; ~40 payloads maliciosos recusados; sessão de reparo de uso único; falha real achada e corrigida | Revisão final pendente; o limitador global de 0,25 s descarta ações sem resposta (pode perder um "finalizar reparo") |
| — | Desempenho | **Não testado** | 1031 partes (todas ancoradas), 42 luzes sem sombra, 3748 instâncias, sem streaming | Medição em celular; carros com ~17–18 mil triângulos cada (até 12 ao mesmo tempo) |
| — | Origem de assets/áudio | Parcial | 3 carros CC0 (Grab3D, conferido na pesquisa); sem áudio algum | Sprites do HUD vieram de **imagens de referência** do Product Owner (origem a confirmar); sem registro único de origem |

## 3. Critérios de aceitação (seção 10)

| Área | Situação |
|---|---|
| Onboarding | Não atendido (sem tutorial) |
| Ordens | Atendido no Play; falta cenário "em andamento" que expira |
| Diagnóstico | Parcial (sintoma ≠ defeito, mas sem investigação) |
| Reparo | Atendido (matriz de precisão/erros nos 36 testes e no Play) |
| Peças | Atendido (saldo/quantidade conferidos) |
| Equipamentos | Atendido |
| Progressão | **Falha**: Motor trava; demais ok |
| Avaliação | Atendido |
| Multiplayer | Não testado |
| Persistência | Parcial (Studio com DataStore real; falta publicado) |
| Mobile | Não testado (dispositivo real) |
| Segurança | Atendido nos casos testados; revisão final pendente |
| Performance | Não medido |

## 4. Bloqueadores do lançamento (seção 12) encontrados

1. **Motor sem rota inicial** → progresso impossível numa das cinco especializações. *(correção simples)*
2. **Fluxo principal incompleto frente ao doc**: sem NPC físico, sem conversa/investigação, diagnóstico automático.
3. **Sem onboarding** (checklist 20).
4. **Persistência de produção**: Studio e jogo publicado compartilham a chave; perfil do dono com dados de teste.
5. **Sem teste com 2 jogadores reais** e **sem teste em celular real** (obrigatórios).
6. **Botões e painéis decorativos** (doc seção 14).
7. **Origem do conteúdo** (sprites do HUD) a registrar; assets 3D sem registro formal.

## 5. Plano de fechamento (ordenado por dependência e risco)

| Ordem | Tarefa | Tamanho | Critério de conclusão |
|---|---|---|---|
| 1 | Motor com serviço de nível 1 (Overheating → nível 1) + teste de catálogo "toda especialização tem rota de nível 1" | pequeno | Teste novo passa; Motor sobe de nível jogando |
| 2 | Studio usa chave de teste (`_STUDIO`) + redefinir o perfil do dono antes do lançamento | pequeno | Play no Studio não toca a chave de produção |
| 3 | Remover/ocultar botões e abas sem função (Configurações, Sair, Conquistas, Ferramentas, Acessórios, Consumíveis) | pequeno | Nenhum botão desabilitado visível |
| 4 | Diagnóstico por investigação: escolher o defeito entre 3 candidatos; servidor valida; erro custa tempo/moedas e permite nova tentativa | médio | Casos certo/errado testados; defeito só aparece ao acertar |
| 5 | Cliente NPC físico associado à vaga e à ordem, conversa que revela sintomas, saída ao concluir/desistir; mensagem de desistência | médio/grande | NPC aparece, fala, sai; sem duplicata ao sair/entrar |
| 6 | Onboarding do 1º atendimento (skill `fwjelaa-tutorial`) | médio | Jogador novo conclui sem instrução externa (teste observado) |
| 7 | Prompts "E" só para o dono do carro; ack no limitador de ações do reparo | pequeno | 2 clientes: cada um vê só o seu |
| 8 | Ordem em andamento expira/pode ser cancelada com consequência clara | pequeno | Sem vaga presa |
| 9 | Reduzir triângulos dos carros (assistente 3D do Studio ou decimação) e medir | médio | Medição em celular real |
| 10 | Registro de origem dos assets (`docs/ORIGEM_ASSETS.md`) | pequeno | Cada asset com origem e condição |
| 11 | **Teste com 2 jogadores reais** no place de homologação + DataStore publicado | humano | Checklist 20 preenchido |
| 12 | **Teste em celular real** (fluxo completo por toque) | humano | Ciclo completo sem teclado |
| 13 | Teste fechado 15–20 pessoas | humano | Métricas da seção 19 |

## 6. Decisões necessárias do Product Owner (seção 17.2)

1. **Minigame:** o doc pede "seleção representativa de serviços". Hoje há **um** minigame genérico com dificuldade por serviço. Aceita para o lançamento, com variantes no P1?
2. **Qualidade:** aceitar "equipamento e peça como requisitos" (hoje) ou exigir efeito na qualidade (faixas de peça)? Recomendo adiar as faixas.
3. **NPC físico:** usar o assistente 3D do Studio (pipeline do doc) para os clientes? É a maior tarefa nova do P0.
4. **Mecânico NPC e colaboração/convites/ranking:** já existem (P2 no doc). Recomendo congelar e não expandir; ajustar o mecânico NPC só se o teste mostrar renda passiva.

## 7. Próxima tarefa (uma só)

**Corrigir o Motor sem rota de nível 1** (tarefa 1): menor esforço, destrava a progressão de uma das cinco especializações e fecha o único critério de aceitação que hoje **falha**.
Critério de conclusão: teste automatizado "toda especialização tem serviço de nível 1" passa e, no Play, um serviço de Motor concede XP e sobe de nível.

---

# 8. Reauditoria de fechamento — 2026-11-06 (modelo da seção 22)

A auditoria acima descreve o projeto ANTES do lote de fechamento e fica como histórico. Esta seção é o estado atual.

## 8.1 Cabeçalho

| Campo | Conteúdo |
|---|---|
| Commit/versão | Ainda **não há repositório git**. Place `Oficina24H_Teste` (placeId 98576673620657), código em `src/` (Rojo 7.7.1). Registro de mudanças em `docs/PROGRESSO.md` e `.fwjelaa/ledger.jsonl`. |
| Ambiente testado | Roblox Studio: Play com 1 jogador e **servidor local com 2 clientes** (Player1/Player2). DataStore real só na chave de teste `_STUDIO`. Nenhum place publicado, nenhum celular, nenhuma latência real. |
| Testes automáticos | **639 verificações** passam (Catalog 424, Customer 59, Repair 60, Plot 27, Persistence 69). Verificador `-Scan`: nenhum achado novo (o único erro é de `tools/PersistenceTest.luau`, ferramenta de teste). |
| Revisão de segurança | Agente `roblox-reviewer`: 0 críticos, 4 altos (corrigidos e atacados no Play), 6 médios e 10 baixos. Corrigidos depois: M1, M3, M4, M5, M6, B1, B2, B3. Abertos: M2 (bot perfeito no minijogo, aceito) e B4–B10 (migração por versão, tipos exportados, tweens no servidor). |

## 8.2 Matriz P0 atual

| # | Sistema | Antes | Agora | Evidência | Lacuna |
|---|---|---|---|---|---|
| 1 | Bairro e terrenos | Implementado | Implementado | 2 jogadores locais: lotes distintos e liberação ao sair | 6 jogadores reais |
| 2 | Oficina | Implementado | Implementado | Play | Desempenho em celular |
| 3 | Clientes/NPCs | Parcial | **Implementado** | Cliente físico (3 modelos do assistente 3D), chegada de carro + caminhada animada, balão com o problema, conversa abre o diagnóstico, saída ao concluir/dispensar/expirar | Só 3 aparências; sem som; celular |
| 4 | Ordens | Implementado | Implementado | Ordem só abre quando o cliente chega; expiração de "aceita e esquecida" e de "sem atendimento" **testadas no Play** (-1 de reputação, vaga liberada, sem objetos órfãos) | — |
| 5 | Diagnóstico | Parcial | **Implementado** | Escolha entre 3 defeitos, servidor valida, palpite errado bloqueia e reduz a qualidade; entradas maliciosas recusadas | Equilíbrio sem dados |
| 6 | Reparos/minigames | Implementado | Implementado | Correção após erro (até 2); 1 tipo de minigame | **Decisão do PO:** só 1 tipo no lançamento? |
| 7 | Peças/estoque | Implementado | Implementado | Checkout atômico | Faixas de qualidade de peça adiadas (decisão do PO) |
| 8 | Equipamentos | Implementado | Implementado | Bloqueio com mensagem; eficiência afeta a qualidade | — |
| 9 | Qualidade | Parcial | **Implementado** | 6 fatores (execução, erros, habilidade, equipamento, peça, diagnóstico) com detalhamento na tela | Faixas de peça (adiadas) |
| 10 | Habilidades | Defeito | **Implementado** | Motor com serviço de nível 1 + teste de catálogo | — |
| 11 | Economia | Implementado | Implementado | Bônus único de 40 moedas no 1º serviço | Equilíbrio sem dados; mecânico NPC (P2) sem minijogo |
| 12 | Avaliações | Implementado | Implementado | Comentário por qualidade | — |
| 13 | Perfil | Implementado | Implementado | — | — |
| 14 | HUD/UI | Parcial | **Parcial** | Botões sem função removidos; HUD, diagnóstico e guia testados em PC e 7 tamanhos simulados | **Celular real não testado** |
| 15 | Multiplayer | Não testado | **Parcial** | Local: isolamento de lotes e ordens, 10 ações cruzadas recusadas, prompt só do dono, chegada por lado da rua, saída limpa | **Latência, 2 servidores e jogadores reais não testados** |
| 16 | Persistência | Parcial | **Parcial** | Chave `_STUDIO`; corrida de reentrada e último save corrigidos (testes); trava perdida expulsa o jogador | **Place publicado, 2 servidores e BindToClose reais não testados; perfil de produção do dono contaminado** |
| 17 | Onboarding | Ausente | **Implementado** | Guia de 5 passos pelo estado real do servidor, retomável, pula com confirmação, bônus único; testado com jogador novo | Teste observado com pessoa real |
| — | Segurança | Parcial (boa) | **Parcial (boa)** | 4 altos corrigidos; ataques no Play; gancho de QA só no Studio | M2, B4–B10 |
| — | Desempenho | Não testado | **Não testado** | Carro da rua usa 1 peça-raiz com solda | Carros ~17 mil triângulos (o PO está trazendo outros); 6 oficinas × 6 carros; celular |
| — | Origem de assets | Parcial | **Parcial** | `docs/ORIGEM_ASSETS.md` criado (carros CC0, NPCs e animações do assistente 3D, partes procedurais) | **Sprites do HUD e pacote de ícones: licença a confirmar** |

## 8.3 Critérios de aceitação (seção 10)

Onboarding: atendido no Play (falta teste observado) · Ordens: atendido · Diagnóstico: atendido · Reparo: atendido · Peças: atendido · Equipamentos: atendido · Progressão: atendido (Motor corrigido) · Avaliação: atendido · **Multiplayer: parcial (local)** · **Persistência: parcial** · **Mobile: não testado** · Segurança: atendido nos casos testados · **Performance: não medido**.

## 8.4 Bloqueadores restantes do lançamento (seção 12)

1. **Teste com 2 jogadores reais num place publicado de homologação** (DataStore real, 2 servidores) — tarefa 11.
2. **Teste em celular real**, fluxo completo por toque — tarefa 12.
3. **Licença dos sprites do HUD e do pacote de ícones** a confirmar por escrito.
4. ~~Perfil de produção do dono com dados de teste~~ — **RESOLVIDO em 2026-11-06**: o Product Owner autorizou e a entrada `u_11072958195` da chave de produção foi apagada (cópia local em `C:\Users\Administrador\.oficina24h\backups`, fora do repositório). No próximo login o perfil nasce do zero (250 moedas, guia ativo). Ainda vale conferir no place publicado de homologação.
5. **Desempenho medido** com os carros definitivos (tarefa 9, com o PO).
6. **Teste fechado** com 15–20 jogadores — tarefa 13 (métricas da seção 19).

## 8.5 Decisões que dependem do Product Owner (seção 17.2)

1. Lançar com **1 tipo de minigame** (dificuldade variável por serviço)? Variantes no P1?
2. Confirmar por escrito a licença dos sprites do HUD e do pacote de ícones.
3. ~~Autorizar o reset do perfil de produção do usuário dono~~ — autorizado e executado (ver 8.4, item 4).
4. Autorizar a publicação do place de homologação (nada é publicado sem ordem explícita).
5. M2 (bot perfeito no minijogo) fica aceito como limite do P0? Congelados (P2, não expandir): colaboração/convites, ranking, mecânico NPC.

## 8.6 Veredito honesto

O **código do P0 está completo e testado onde o Studio permite**. O MVP **ainda não está pronto para lançar** segundo o documento: faltam os testes com pessoas e dispositivos reais, a medição de desempenho e a confirmação de licenças. Nada nesta seção foi dado como concluído apenas por existir código.
