// =============================================================================
// NARRATIVA DO TUTORIAL — dados puros (sem renderizacao).
//
// Fluxo dos dados:
//   NARRATIVA (este arquivo) -> RENDERIZACAO (CutscenePlayer/CaixaLegenda)
//   -> ASSETS (quadro.image, hoje null = placeholder)
//
// PARA COLOCAR UMA ARTE DEFINITIVA:
//   troque `image: null` pelo require da imagem 16:9, ex.:
//     image: require('../../assets/sprites/cutscenes/scene01/frame01.png')
//   Nada mais precisa mudar. Sugestao de organizacao dos arquivos:
//     src/assets/sprites/cutscenes/scene01/frame01.png ... frame08.png
//     src/assets/sprites/cutscenes/scene02/frame01.png ... frame06.png
//   Enquanto image for null, o CutscenePlayer mostra o placeholder 16:9
//   com o id estavel, o titulo e a descricao da imagem que deve entrar ali.
// =============================================================================

export const FALANTE = {
  PROTAGONISTA: 'PROTAGONISTA',
  GUIA: 'GUIA',
};

// Nome do mundo (narrativa): Tormentalia.
const NOME_DO_LUGAR = 'Tormentalia';

export const CENA_01 = {
  id: 'SCENE_01',
  titulo: 'O ESCRITORIO',
  quadros: [
    {
      id: 'SCENE_01_FRAME_01',
      numero: 1,
      image: require('../assets/sprites/historia_inicial/1.png'),
      titulo: 'PROTAGONISTA NO ESCRITORIO',
      descricao:
        'Protagonista sentado sozinho em sua mesa, visto por tras, olhando para o computador. ' +
        'O escritorio esta muito bagunçado e aparenta nao ser organizado ha muito tempo. ' +
        'Existem papeis sobre a mesa e espalhados pelo chao. ' +
        'Na tela do computador aparecem dividas e graficos financeiros despencando. ' +
        'O protagonista demonstra desespero atraves da postura corporal.',
      dialogues: [
        { speaker: FALANTE.PROTAGONISTA, text: 'Eu lutei tanto para conseguir o que tenho hoje...' },
        { speaker: FALANTE.PROTAGONISTA, text: 'Passei horas estudando Administracao na universidade.' },
        { speaker: FALANTE.PROTAGONISTA, text: 'Sem o apoio de ninguem, eu tentei.' },
        { speaker: FALANTE.PROTAGONISTA, text: 'Eu realmente tentei...' },
      ],
    },
    {
      id: 'SCENE_01_FRAME_02',
      numero: 2,
      image: require('../assets/sprites/historia_inicial/2.png'),
      titulo: 'A JANELA QUEBRADA',
      descricao:
        'Protagonista de costas diante da janela quebrada do escritorio. ' +
        'Ele observa os grandes predios da cidade. ' +
        'Os predios sao enormes e ele parece pequeno e impotente diante deles.',
      dialogues: [
        { speaker: FALANTE.PROTAGONISTA, text: 'Mas peixe pequeno nao sobrevive em mar de tubaroes...' },
        { speaker: FALANTE.PROTAGONISTA, text: 'E agora...' },
      ],
      // Pequena pausa dramatica antes de avancar (spec 12).
      pausaAntesProximo: 1500,
    },
    {
      id: 'SCENE_01_FRAME_03',
      numero: 3,
      image: require('../assets/sprites/historia_inicial/3.png'),
      titulo: 'A CARTA DE DEMISSAO',
      descricao:
        'Um funcionario entrega ao protagonista uma carta de demissao. ' +
        'O escritorio continua decadente e baguncado.',
      dialogues: [
        { speaker: FALANTE.PROTAGONISTA, text: 'Sinto que o meu sonho chegou ao fim.' },
        { speaker: FALANTE.PROTAGONISTA, text: 'Eu nao queria desistir...' },
        { speaker: FALANTE.PROTAGONISTA, text: 'Mas, no fundo, eu sei que parte disso e culpa minha.' },
        { speaker: FALANTE.PROTAGONISTA, text: 'Culpa da minha pessima lideranca...' },
      ],
    },
    {
      id: 'SCENE_01_FRAME_04',
      numero: 4,
      image: require('../assets/sprites/historia_inicial/4.png'),
      titulo: 'ELA VOANDO EMBORA',
      descricao:
        'Protagonista observa pela janela sua esposa indo embora em um carro. ' +
        'Ele permanece parado dentro do escritorio observando o carro se afastar.',
      dialogues: [
        { speaker: FALANTE.PROTAGONISTA, text: 'Culpa minha por ter sido um pessimo marido.' },
        { speaker: FALANTE.PROTAGONISTA, text: 'Culpa minha por ter colocado tudo a perder.' },
        { speaker: FALANTE.PROTAGONISTA, text: 'Parece que tudo que eu tentei construir esta desaparecendo.' },
      ],
    },
    {
      id: 'SCENE_01_FRAME_05',
      numero: 5,
      image: require('../assets/sprites/historia_inicial/5.png'),
      titulo: 'O QUADRO DO PAI',
      descricao:
        'Protagonista sozinho no escritorio olhando para um quadro ou fotografia de seu pai.',
      dialogues: [
        { speaker: FALANTE.PROTAGONISTA, text: 'Desculpa, pai...' },
        { speaker: FALANTE.PROTAGONISTA, text: 'Desculpa por ser um fracassado.' },
        { speaker: FALANTE.PROTAGONISTA, text: 'Eu tentei seguir os seus passos.' },
        { speaker: FALANTE.PROTAGONISTA, text: 'Mas acho que...' },
        { speaker: FALANTE.PROTAGONISTA, text: '...eu vou dar um fim nisso.' },
      ],
      // Pausa dramatica longa antes do portal (spec 12).
      pausaAntesProximo: 2500,
    },
    {
      id: 'SCENE_01_FRAME_06',
      numero: 6,
      image: require('../assets/sprites/historia_inicial/6.png'),
      titulo: 'A LUZ ATRAS DELE',
      descricao:
        'Uma intensa luz branca surge atras do protagonista. ' +
        'Ele percebe a luz e comeca a se virar.',
      // Sem fala inicialmente: a caixa de legenda so aparece no primeiro toque.
      comecarSemCaixa: true,
      dialogues: [{ speaker: FALANTE.PROTAGONISTA, text: 'Ha...?' }],
    },
    {
      id: 'SCENE_01_FRAME_07',
      numero: 7,
      image: require('../assets/sprites/historia_inicial/7.png'),
      titulo: 'O PORTAL NO CHAO',
      descricao:
        'Um grande portal circular de luz branca surge no chao do escritorio. ' +
        'Papeis e objetos comecam a ser puxados para dentro dele.',
      dialogues: [{ speaker: FALANTE.PROTAGONISTA, text: 'O que e isso?!' }],
    },
    {
      id: 'SCENE_01_FRAME_08',
      numero: 8,
      image: require('../assets/sprites/historia_inicial/8.png'),
      titulo: 'SUGADO PELO PORTAL',
      descricao:
        'Protagonista sendo puxado violentamente para dentro do portal. ' +
        'Papeis, cadeira e objetos do escritorio tambem estao sendo sugados.',
      dialogues: [
        { speaker: FALANTE.PROTAGONISTA, text: 'SOCORRO!' },
        { speaker: FALANTE.PROTAGONISTA, text: 'ALGUEM ME AJUDA!' },
      ],
      // Fade to black + luz branca crescendo antes da Cena 2 (spec 13).
      transicaoSaida: 'portal',
    },
  ],
};

export const CENA_02 = {
  id: 'SCENE_02',
  titulo: 'O MUNDO',
  quadros: [
    {
      id: 'SCENE_02_FRAME_01',
      numero: 1,
      image: null,
      fundo: 'ciclico',
      titulo: 'UM MUNDO EM RUINAS',
      descricao:
        'Protagonista em um mundo pos-apocaliptico. ' +
        'Ceu em tons de vermelho, vinho e preto. ' +
        'Estruturas destruidas, predios quebrados, arvores secas, chao rachado, destrocos e vazio. ' +
        'Ao fundo: pessoas extremamente magras caminham de maneira mecanica, algumas sendo ' +
        'controladas por dispositivos eletronicos. Algumas criaturas atacam essas pessoas. ' +
        'As criaturas possuem expressoes estranhas e parecem estar com uma especie de ' +
        'comportamento bugado. (sem gore explicito)',
      dialogues: [
        { speaker: FALANTE.GUIA, text: 'E ai, cara.' },
        { speaker: FALANTE.GUIA, text: 'Dormiu bem?' },
        { speaker: FALANTE.PROTAGONISTA, text: 'Onde estou?' },
        { speaker: FALANTE.GUIA, text: 'Nem te conto.' },
        { speaker: FALANTE.PROTAGONISTA, text: 'Eu estou no inferno?' },
        { speaker: FALANTE.GUIA, text: 'Mais ou menos isso.' },
        { speaker: FALANTE.GUIA, text: `Seja bem-vindo ao ${NOME_DO_LUGAR}.` },
        { speaker: FALANTE.PROTAGONISTA, text: `${NOME_DO_LUGAR}?` },
        { speaker: FALANTE.GUIA, text: 'Voce foi condenado por ELE.' },
        { speaker: FALANTE.GUIA, text: 'A ficar aqui em agonia.' },
        { speaker: FALANTE.GUIA, text: 'Parabens.' },
        { speaker: FALANTE.GUIA, text: 'Uhuuu...' },
      ],
    },
    {
      id: 'SCENE_02_FRAME_02',
      numero: 2,
      image: null,
      fundo: 'ciclico',
      titulo: 'A ESFERA DE LUZ',
      descricao:
        'Uma pequena esfera branca de luz aparece diante do protagonista. ' +
        'A esfera e o personagem chamado Guia.',
      dialogues: [
        { speaker: FALANTE.PROTAGONISTA, text: 'Condenado por quem?' },
        { speaker: FALANTE.GUIA, text: 'Por ELE.' },
        { speaker: FALANTE.GUIA, text: 'Para alguns, ele e o diabo necessario.' },
        { speaker: FALANTE.GUIA, text: 'Para outros, a propria vida.' },
        { speaker: FALANTE.GUIA, text: 'Para outros, a morte.' },
        { speaker: FALANTE.GUIA, text: 'Para poucos, uma mentira.' },
        { speaker: FALANTE.GUIA, text: 'E para muitos, a verdade.' },
        { speaker: FALANTE.GUIA, text: 'Ninguem sabe exatamente quem ele e.' },
        { speaker: FALANTE.GUIA, text: 'So sabemos que estamos aqui por causa dele.' },
      ],
    },
    {
      id: 'SCENE_02_FRAME_03',
      numero: 3,
      image: null,
      fundo: 'ciclico',
      titulo: 'O GUIA FLUTUA',
      descricao:
        'Protagonista observa o mundo ao redor enquanto o Guia, representado por uma esfera ' +
        'branca de luz, flutua diante dele.',
      dialogues: [
        { speaker: FALANTE.PROTAGONISTA, text: 'Mas o que ele quer comigo?' },
        { speaker: FALANTE.GUIA, text: 'O mesmo que quer com todo mundo.' },
        { speaker: FALANTE.GUIA, text: 'Duelo.' },
        { speaker: FALANTE.PROTAGONISTA, text: 'Duelo?' },
        { speaker: FALANTE.GUIA, text: 'Voce nao vai sobreviver muito tempo aqui se nao souber duelar.' },
        { speaker: FALANTE.GUIA, text: 'Mas voce parece um cara legal.' },
        { speaker: FALANTE.GUIA, text: 'Entao vou te dar uma coisa para comecar.' },
      ],
    },
    {
      id: 'SCENE_02_FRAME_04',
      numero: 4,
      image: null,
      fundo: 'ciclico',
      titulo: 'O DECK INICIAL',
      descricao:
        'Guia apresenta o deck inicial ao protagonista. ' +
        'O deck aparece entre os dois.',
      dialogues: [
        { speaker: FALANTE.GUIA, text: 'Esse e o seu deck inicial.' },
        { speaker: FALANTE.GUIA, text: 'Todo mundo que chega aqui recebe um.' },
        {
          speaker: FALANTE.GUIA,
          text: 'Quando uma batalha comeca, as cartas sao embaralhadas e distribuidas entre os jogadores.',
        },
      ],
      // Depois da ultima fala: o jogador TOCA NO DECK (nao avanca sozinho).
      acaoAoTerminar: 'mostrarDeck',
    },
    {
      id: 'SCENE_02_FRAME_05',
      numero: 5,
      image: null,
      fundo: 'ciclico',
      titulo: 'AS CARTAS DO JOGO',
      descricao: 'Interface mostrando o deck inicial do jogador e suas cartas.',
      dialogues: [
        { speaker: FALANTE.PROTAGONISTA, text: 'Por que o Karl Marx esta na carta?' },
        { speaker: FALANTE.GUIA, text: 'Ah...' },
        { speaker: FALANTE.GUIA, text: 'Esqueci de explicar.' },
        {
          speaker: FALANTE.GUIA,
          text: 'Ele fez com que todos os duelos daqui usassem cartas relacionadas a Administracao.',
        },
      ],
    },
    {
      id: 'SCENE_02_FRAME_06',
      numero: 6,
      image: null,
      fundo: 'ciclico',
      titulo: 'AS CATEGORIAS DE CARTAS',
      descricao:
        'Interface mostrando exemplos das categorias de cartas:\n' +
        'Acao;\nMedida/Efeito;\nProtecao;\nCoringa.',
      dialogues: [
        { speaker: FALANTE.GUIA, text: 'Existem diferentes tipos de cartas.' },
        {
          speaker: FALANTE.GUIA,
          text: 'As cartas de Acao permitem atacar ou provocar mudancas durante o duelo.',
          destaque: 'ACAO',
        },
        {
          speaker: FALANTE.GUIA,
          text: 'As Medidas alteram situacoes e recursos.',
          destaque: 'EFEITO',
        },
        {
          speaker: FALANTE.GUIA,
          text: 'As Defesas protegem voce dos seus adversarios.',
          destaque: 'PROTECAO',
        },
        {
          speaker: FALANTE.GUIA,
          text: 'E os Coringas possuem efeitos especiais.',
          destaque: 'CORINGA',
        },
        { speaker: FALANTE.GUIA, text: 'Voce precisa aprender a combinar tudo isso.' },
        { speaker: FALANTE.PROTAGONISTA, text: 'Estrategia nao e exatamente o meu ponto forte.' },
        { speaker: FALANTE.GUIA, text: 'Mas valendo a sua vida...' },
        { speaker: FALANTE.GUIA, text: '...acho que voce consegue tirar leite de pedra.' },
        { speaker: FALANTE.GUIA, text: 'La ele.' },
      ],
      acaoAoTerminar: 'fim',
    },
  ],
};

// Sequencia linear da cutscene (cena 1 -> cena 2).
export const CUTSCENE = [CENA_01, CENA_02];

// -----------------------------------------------------------------------------
// Falas do Guia durante a BATALHA do tutorial (spec 24-29).
// Guardadas aqui como dados para a proxima fase (TutorialBattleController).
// AINDA NAO SAO EXIBIDAS por nenhum componente — a batalha tutorial ainda
// nao foi integrada a ArenaCombate.
// ATENCAO: o timer real do jogo hoje e de 20s (a spec fala em 30s) — ajustar
// quando a batalha tutorial for integrada.
// -----------------------------------------------------------------------------
export const FALAS_BATALHA_TUTORIAL = [
  { speaker: FALANTE.GUIA, text: 'Primeiro, o jogo decide quem comeca.' },
  { speaker: FALANTE.GUIA, text: 'E pura sorte.' },
  { speaker: FALANTE.GUIA, text: 'Algo que voce claramente nao tem...' },
  { speaker: FALANTE.GUIA, text: '...so por estar aqui.' },
  { speaker: FALANTE.GUIA, text: 'E quem comecar pode jogar ate duas cartas por turno.' },
  { speaker: FALANTE.GUIA, text: 'Voce tambem pode passar a vez.' },
  { speaker: FALANTE.GUIA, text: 'As vezes guardar suas cartas e melhor do que atacar imediatamente.' },
  { speaker: FALANTE.GUIA, text: 'Quanto mais cartas voce guardar, mais opcoes tera para montar um ataque depois.' },
  { speaker: FALANTE.GUIA, text: 'Agora e sua vez.' },
  { speaker: FALANTE.GUIA, text: 'Voce pode segurar uma carta por alguns segundos para ve-la melhor.' },
  { speaker: FALANTE.GUIA, text: 'Tambem pode reorganizar as cartas na sua mao.' },
  { speaker: FALANTE.GUIA, text: 'Isso pode ajudar bastante na hora de pensar em uma estrategia.' },
  { speaker: FALANTE.GUIA, text: 'Mas nao pense demais.' },
  { speaker: FALANTE.GUIA, text: 'Seu adversario nao vai esperar para sempre.' },
  { speaker: FALANTE.GUIA, text: 'Voce tem 30 segundos para decidir sua jogada.' },
  { speaker: FALANTE.GUIA, text: 'Se o tempo acabar...' },
  { speaker: FALANTE.GUIA, text: '...voce perde a vez.' },
];

// Fala pos-timeout (intencional — o Guia fala demais e o turno expira).
export const FALAS_APOS_TIMEOUT = [
  { speaker: FALANTE.GUIA, text: 'Ops...' },
  { speaker: FALANTE.GUIA, text: 'Acho que falei tanto que seu oponente nao esperou mesmo.' },
  { speaker: FALANTE.GUIA, text: 'Foi mal.' },
  { speaker: FALANTE.GUIA, text: 'Boa sorte.' },
];
