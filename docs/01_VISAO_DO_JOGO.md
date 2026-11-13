> **Documento-base histórico (v0.1).** A direção de produto e arte aprovada em 13/11/2026 é [DIRECAO_JOGO_V2_2026-11-13.md](DIRECAO_JOGO_V2_2026-11-13.md). A V2 coloca **gestão da oficina** em primeiro plano e mecânica prática detalhada quando aplicável. Esta revisão não implementou código.

# OFICINA 24H — Documento de visão e design

**Versão:** 0.1 — Documento-base  
**Plataforma:** Roblox  
**Gênero:** Simulação / RPG leve / Tycoon social / Gestão de oficina  
**Público pretendido:** adolescentes mais velhos e adultos; comunicação e apresentação voltadas a 16+, sem presumir classificação etária específica da plataforma.

---

## 1. Visão

Oficina 24H é um jogo social em um bairro mecânico compartilhado. Cada jogador começa com uma oficina pequena e desenvolve sua carreira como mecânico e proprietário. Clientes NPC chegam com reclamações e defeitos; o jogador precisa diagnosticar, escolher o serviço adequado, possuir o equipamento necessário e executar o reparo.

O crescimento não é apenas cosmético. Uma oficina maior deve conseguir atender mais veículos, executar serviços mais avançados e empregar profissionais com especializações diferentes.

A camada social nasce de uma necessidade real do sistema: um proprietário não consegue dominar todas as especialidades no início. Ele pode convidar outro jogador para executar um serviço, contratar um NPC mais caro ou recusar o trabalho. O profissional contratado ganha experiência e remuneração; o proprietário mantém a parcela acordada.

**Promessa central:** construir uma oficina respeitada, desenvolver uma especialidade e formar uma equipe para aceitar trabalhos cada vez mais complexos.

## 2. Fantasia do jogador

O jogador deve sentir que:
- começou como mecânico iniciante;
- aprendeu uma especialidade por prática;
- reconhece problemas que antes não conseguia resolver;
- investiu em equipamentos que desbloqueiam novas possibilidades;
- conquistou clientes e reputação;
- precisa de outros profissionais para crescer;
- transformou um espaço simples em uma oficina reconhecida no bairro.

A progressão deve ser compreensível e visível. O jogador não deve depender de menus abstratos para perceber que evoluiu.

## 3. Pilares

### Pilar A — Ser mecânico (core loop)
1. Receber um cliente e ouvir a reclamação.
2. Inspecionar o veículo e levantar hipóteses.
3. Identificar o defeito real — que pode ou não corresponder à reclamação.
4. Verificar habilidade, equipamento e peças necessárias.
5. Executar o serviço, sozinho ou com ajuda.
6. Receber pagamento, reputação e XP.
7. Desbloquear serviços mais complexos.

O diagnóstico precisa ter valor próprio. Um cliente pode relatar um ruído na suspensão, mas o defeito verdadeiro pode estar em outra peça. O jogador é recompensado por acertar, não por clicar em todas as opções.

### Pilar B — Construir a oficina (progressão)
A oficina evolui em capacidade:
- mais vagas de atendimento;
- elevadores e bancadas;
- máquinas de pneus e balanceamento;
- scanners e equipamentos de diagnóstico;
- ferramentas de motor, elétrica, suspensão e funilaria;
- área de recepção e exposição;
- contratação de profissionais;
- acesso a serviços de maior complexidade.

A expansão deve alterar o que o jogador consegue fazer. Itens puramente decorativos podem existir, mas não substituem progressão funcional.

### Pilar C — Relações e competição (social)
- convidar um especialista para trabalhar em uma ordem de serviço;
- aceitar ou recusar propostas de trabalho;
- visitar oficinas de outros jogadores;
- comparar reputação, especialidades e capacidade;
- competir por clientes por meio de preço, qualidade, rapidez e reputação;
- contratar profissionais NPC quando não houver jogador disponível;
- construir uma carreira que pode evoluir de funcionário para proprietário.

A competição é comercial e transparente. Não existe destruição do progresso alheio.

## 4. Ciclo de jogo

### Ciclo curto — 1 a 5 minutos
Receber ordem → diagnosticar → escolher serviço → reparar → receber feedback e recompensa.

### Ciclo de sessão — 10 a 25 minutos
Atender vários clientes, melhorar uma habilidade, juntar dinheiro para um equipamento, colaborar com outro jogador ou visitar oficinas.

### Ciclo de longo prazo
Desbloquear especializações, montar uma equipe, ampliar a oficina, elevar a reputação e conquistar contratos/clientes mais exigentes.

## 5. Sistema de habilidades

As habilidades pertencem ao personagem, não à oficina. Se o jogador sair de uma equipe ou abrir seu próprio negócio, mantém o XP e os níveis conquistados.

Especializações iniciais:

| Especialização | Exemplos de serviços |
|---|---|
| Pneus e rodas | reparo de pneu, troca, balanceamento, alinhamento |
| Motor | manutenção básica, diagnóstico, reparo avançado |
| Elétrica | bateria, fusíveis, diagnóstico elétrico, eletrônica |
| Suspensão e freios | pastilhas, amortecedores, diagnóstico e componentes |
| Funilaria e pintura | pequenos amassados, carroceria, pintura e restauração |

Cada serviço exige:
1. nível mínimo na habilidade correspondente;
2. equipamento instalado na oficina;
3. peças/insumos disponíveis, quando o sistema de estoque for implementado.

O protótipo usa requisitos simples e valores configuráveis. Os níveis não devem ser tratados como definitivos.

### Progressão recomendada
- XP por serviço concluído corretamente;
- XP parcial por etapas legítimas, como diagnóstico ou desmontagem;
- bônus moderado por serviço mais complexo;
- redução de repetição abusiva, se necessária;
- níveis desbloqueiam novos serviços, não apenas multiplicadores de dinheiro.

O jogador não deve ganhar XP integral por um serviço que não executou. O profissional que efetivamente trabalha recebe XP mesmo quando atua na oficina de outra pessoa.

## 6. Equipamentos e capacidade

Habilidade não substitui equipamento. Um mecânico experiente não consegue executar um serviço se a oficina não possui a máquina ou ferramenta necessária.

Exemplos:
- macaco/elevador: acesso a serviços sob o veículo;
- desmontadora de pneus: troca e reparo de pneus;
- balanceadora: balanceamento;
- scanner: diagnóstico eletrônico;
- bancada de motor: reparos avançados;
- estação elétrica: diagnóstico e reparo elétrico.

Equipamentos devem ter custo, requisito de espaço e benefício operacional claro. Não introduzir durabilidade/manutenção de equipamentos no primeiro protótipo.

## 7. Clientes e ordens de serviço

Clientes são inicialmente NPCs. Cada ordem possui:
- veículo;
- reclamação declarada;
- defeito real;
- especialidade necessária;
- serviço recomendado;
- recompensa;
- prazo opcional, apenas em versão posterior.

Nem toda reclamação precisa ser verdadeira. Isso cria espaço para diagnóstico honesto e evita que o jogo seja apenas uma sequência de botões.

No protótipo, manter o número de defeitos baixo e os resultados legíveis. Não criar dezenas de peças ou simulação mecânica realista antes de provar a diversão.

## 8. Trabalho em equipe e contratação

### Contratação de jogador
Quando o proprietário recebe um serviço que não consegue executar:
1. O painel apresenta a especialidade e o requisito.
2. Mostra jogadores online elegíveis, quando houver.
3. O proprietário envia convite com percentual proposto.
4. O profissional aceita ou recusa.
5. Se aceitar, entra na ordem de serviço e executa a etapa para a qual possui habilidade.
6. O pagamento é dividido conforme o acordo.
7. O profissional recebe XP na própria especialização.

A oferta deve ser explícita e aceita antes de qualquer trabalho. O proprietário não pode alterar unilateralmente a divisão depois do aceite.

### NPC contratado
Se não houver jogador disponível, a oficina pode contratar um NPC:
- custa mais que contratar um jogador;
- tem habilidade e desempenho previsíveis;
- não transfere XP ao proprietário;
- exige que a oficina tenha o equipamento necessário.

O NPC é uma válvula de continuidade, não a opção economicamente superior. Assim, o jogo funciona com baixa população, mas jogar com pessoas oferece vantagens sociais e econômicas.

### Carreira do funcionário
Um jogador pode trabalhar em oficinas alheias e, posteriormente, abrir a própria oficina. Ele leva habilidades e experiência, mas não leva equipamentos, dinheiro da empresa ou patrimônio do proprietário.

Não prender o jogador a um emprego. Sair deve ser simples e não pode apagar XP já conquistado.

## 9. Competição comercial — sem sabotagem

A competição deve acontecer por meios que criem decisões, não frustração:
- preço e qualidade do serviço;
- rapidez e capacidade de atendimento;
- reputação e avaliações;
- especialização;
- publicidade/eventos;
- contratação e retenção de profissionais;
- contratos e desafios do bairro;
- comparação pública de resultados.

**Removido do escopo:** roubo de entregas, roubo de materiais, sabotagem de veículos, sabotagem de equipamentos e ações que retirem diretamente patrimônio ou progresso de outro jogador.

Não criar mecânicas de griefing ou formas de bloquear a oficina concorrente.

## 10. Economia

Fontes iniciais:
- pagamento por serviço;
- bônus por diagnóstico correto;
- bônus moderado por qualidade/reputação.

Usos:
- compra de equipamentos;
- expansão de vagas;
- contratação de NPC;
- peças e insumos (quando estoque for introduzido);
- melhorias visuais.

Evitar inflação por repetição simples. O valor de um serviço deve refletir complexidade, habilidade e equipamento, mas não depender de grind excessivo.

Não introduzir monetização pay-to-win no protótipo. Primeiro validar se o loop principal é divertido.

## 11. Bairro e experiência social

O bairro é um espaço compartilhado com oficinas próximas. A proposta inicial é pequena: quatro terrenos lógicos, com espaço para expansão posterior.

O jogo deve:
- funcionar com um jogador, usando clientes NPC;
- ficar melhor com outros jogadores, por meio de cooperação, visitas e competição;
- não exigir servidor cheio para iniciar uma sessão;
- manter os jogadores próximos visualmente, favorecendo encontros espontâneos;
- permitir que cada oficina seja reconhecível e personalizável.

A presença de NPCs mantém o ciclo funcionando quando há poucos jogadores. Jogadores reais devem oferecer flexibilidade, especialização e interação que o NPC não reproduz.

## 12. Retenção e progressão saudável

Usar:
- metas curtas e claras;
- feedback imediato de diagnóstico e reparo;
- desbloqueios compreensíveis;
- coleção de equipamentos e melhorias;
- reputação visível;
- objetivos de sessão e de longo prazo;
- autonomia para escolher especialização;
- cooperação que gere benefício real.

Evitar:
- punição artificial por ficar offline;
- tarefas diárias obrigatórias;
- probabilidades escondidas;
- loot boxes pagas;
- perda de progresso por ações de terceiros;
- timers longos usados apenas para forçar retorno.

## 13. Escopo do primeiro protótipo (vertical slice)

**Objetivo:** comprovar que diagnosticar e reparar é divertido e que a cooperação entre dois jogadores funciona.

Incluir:
- bairro compacto;
- quatro terrenos lógicos;
- uma oficina funcional;
- três veículos NPC;
- seis defeitos no catálogo, mas começar com três ativos;
- três a cinco serviços;
- habilidades e equipamentos;
- ordens de serviço;
- diagnóstico;
- conclusão e pagamento;
- XP e reputação;
- convite de um jogador para colaborar;
- opção de NPC como alternativa.

Não incluir ainda:
- roubo ou sabotagem;
- mercado global;
- estoque complexo;
- dezenas de veículos;
- personalização profunda;
- contratos corporativos;
- salários por hora;
- sistema avançado de funcionários;
- mundo aberto grande;
- física detalhada de motores.

## 14. Critérios de validação

Testar com 1, 2 e 4 jogadores. Observar:
- o jogador entende o que fazer sem explicação externa?
- consegue concluir o primeiro serviço em poucos minutos?
- diagnóstico parece uma decisão ou apenas adivinhação?
- habilidade e equipamento são compreensíveis?
- a progressão cria uma meta concreta?
- o convite de trabalho é fácil de entender?
- o funcionário sente que vale a pena ajudar?
- com apenas um jogador, o jogo continua funcional?
- com dois jogadores, a experiência fica claramente melhor?

Não expandir conteúdo antes de observar jogadores reais. A primeira meta não é quantidade de sistemas; é provar um ciclo repetível.
