# OFICINA 24H — TEST-DRIVE PARA DIAGNÓSTICO E VALIDAÇÃO (FUTURO V2)

**Proposta:** aprovada para planejamento, NÃO implementar agora.  
**Dependências:** V2-03 (rig dos carros), V2-04 (evidências e reparos), V2-11 (veículo dirigível por jogador), depois V2-12 e V2-13.  
**Objetivo de produto:** variar o trabalho de oficina, criar um momento satisfatório de direção e fazer o diagnóstico ter evidências, sem virar um jogo de corridas.

## Fantasia
O cliente reclama “faz barulho quando viro”, “treme acima de certa velocidade” ou “demora para pegar de manhã”. Em algumas OS, o mecânico precisa rodar um curto trecho e ouvir/sentir a falha. Em outras, basta inspeção na bancada. Às vezes, depois do reparo, um teste curto confirma o resultado.

## Gatilhos elegíveis e sintomas
| Sistema | Situação durante test-drive | Evidência | Ação associada |
|---|---|---|---|
| Rodas/pneus | vibração em faixa de velocidade | som + HUD “trepidação”, câmera sutil | balanceamento, roda/pneu |
| Suspensão | batida ao passar lombada | som curto + vibração visual | inspeção dos braços/buchas |
| Direção/alinhamento | veículo puxa para um lado | esforço/assistência de direção + indicador | geometria/alinhamento |
| Freios | ruído em frenagem e diferença de resposta | áudio + aviso visual claro | freios/disco |
| Ignição/motor | resposta falha sob aceleração | atraso/oscilar RPM + áudio | vela/ignição/circuito |
| Elétrica | aviso intermitente | luz do painel + leitura em scanner | bateria/alternador/fiação |

**Regras:** sem sorte arbitrária que gera culpa após reparo perfeito. Defeito + seed + condição tornam sintoma reproduzível. O servidor guarda o que realmente aconteceu; cliente só reproduz efeitos. Evidências não dependem exclusivamente de audição.

## Política de aleatoriedade
- A ocorrência é aleatória apenas **dentro de famílias elegíveis** e de uma curva de progressão que respeita o nível de oficina.
- Não aplicar ao tutorial nem obrigar 100% dos serviços a usar direção.
- Chance inicial será parâmetro de playtest, não número fechado na especificação.
- Servidor decide a elegibilidade no momento de criar/diagnosticar a OS e a preserva até conclusão.
- Um resultado coerente é garantido pela mesma seed no mesmo caso, apesar de o sintoma não aparecer exatamente no mesmo segundo.

## Fluxo 1 — Diagnóstico
1. Cliente informa queixa compatível com falha dinâmica.
2. Oficina oferece botão contextual “Testar na rua”; ao aceitar, bloqueia a OS para nova atribuição.
3. Criar sessão temporária em veículo de cliente; abrir portão/posicionar carro com seguridade.
4. Dirigir percurso curto, 45–90 s como objetivo inicial, checkpoints pequenos em lugar seguro.
5. O servidor observa velocidade, frenagem, curva ou trecho do percurso e registra a evidência conforme condições.
6. Jogador retorna e seleciona hipótese; OS reentra no fluxo comum de diagnóstico/reparo.
7. Se condução falhar, um protocolo alternativo preserva a ordem e permite continuar com inspeção de oficina.

## Fluxo 2 — Verificação após reparo
1. Após trabalho, apenas classes de serviço selecionadas oferecem “Conferir dirigindo”.
2. Estado “Aguardando validação” preserva peças/recibo sem conceder pagamento final duas vezes.
3. Um teste que demonstra correção confirma entrega; sintoma persistente JUSTIFICADO gera retrabalho.
4. Retrabalho tem custo/qualidade explicados e limite de tentativas para evitar punição por bug/latência.
5. Caso o jogador desconecte, veículo retorna ao box e OS permanece recuperável.

## Máquina de estados sugerida
Disponível → Reservado → Em percurso → Retorno → Evidência/Resultado → Oficina → Serviço/Entrega.  
Estados alternativos: cancelado, sem rede, timeout, acidente, reconexão. Nunca concluir OS só porque um cliente reportou checkpoint via RemoteEvent.

## Viabilidade Roblox
- Assento/controles/câmera/velocidade próprios; não reutilizar LotPath.Drive (movimento roteirizado de carros NPC) como prova de dirigibilidade.
- Network ownership sob motorista para sensação de controle, mas validar server-side distância/velocidade/rota, com tolerância à latência.
- Persistir vínculo da OS/estado de negócio; um carro de cliente não pode virar propriedade permanente do jogador.
- Aplicar limites de carros dirigíveis por servidor; priorizar performance mobile.
- Não recompensar por Touched, posição ou velocidade reportados só pelo cliente.
- Bloquear capô/portas abertos enquanto em movimento; recuperar veículo ao sair do assento.
- Rota segura no bairro e alternativa com assistência de direção para touch/gamepad.

Fontes técnicas: https://create.roblox.com/docs/physics/network-ownership ; https://create.roblox.com/docs/scripting/security/network-ownership

## Não fazer agora
- Corridas, disputas PvP de trânsito, mapa externo extenso, danos físicos destrutivos complexos, combustível detalhado ou simulação real de transmissão em todos os carros.
- Test-drive obrigatório após toda OS.
- Pagamento extra com base apenas na distância rodada ou evento de física.
- Mudança de veículo para low poly puro antes do teste de direção híbrida.

## Critérios de aceite futuros
- 1 carro piloto dirigível, com 1 sintoma baseado em seed; retorno/respawn/desconexão seguro.
- Pelo menos três classes de diagnóstico com pistas inequívocas e duas modalidades de verificação.
- Sem exploração por rota falsa e sem segunda recompensa.
- Testado em mobile/gamepad/PC, 2 jogadores e rede lenta.
- Comparação de playtests com/sem test-drive: aumenta variedade sem prejudicar a velocidade da oficina.

**Decisão:** manter exclusivamente nesta documentação até o usuário autorizar fases V2-11→13.
