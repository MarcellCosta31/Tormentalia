const fs = require('fs');
const path = require('path');
const babel = require('@babel/core');

const ROOT = path.resolve(__dirname, '..');
const TMP = path.join(__dirname, '_build');

function listarJs(dir, acc = []) {
  for (const nome of fs.readdirSync(dir)) {
    const cheio = path.join(dir, nome);
    const stat = fs.statSync(cheio);
    if (stat.isDirectory()) listarJs(cheio, acc);
    else if (nome.endsWith('.js')) acc.push(cheio);
  }
  return acc;
}

// 1) Parse de todos os arquivos .js de src/ com babel-preset-expo
const arquivos = listarJs(path.join(ROOT, 'src'));
arquivos.push(path.join(ROOT, 'App.js'));

let falhas = 0;
for (const arquivo of arquivos) {
  try {
    babel.transformFileSync(arquivo, {
      presets: [require.resolve('babel-preset-expo')],
      configFile: false,
      babelrc: false,
    });
  } catch (e) {
    falhas++;
    console.log('PARSE FALHOU:', path.relative(ROOT, arquivo));
    console.log('   ', e.message.split('\n')[0]);
  }
}
console.log(`parse: ${arquivos.length - falhas}/${arquivos.length} ok`);

// 2) Compila os modulos do motor para CJS e roda o smoke test
const modulos = ['cartasTGA.js', 'baralhoCartas.js', 'motorEfeitos.js'];
const dirs = ['cards', 'hooks'];

fs.rmSync(TMP, { recursive: true, force: true });
for (const dir of dirs) {
  fs.mkdirSync(path.join(TMP, dir), { recursive: true });
}
for (const modulo of modulos) {
  const origem = path.join(ROOT, 'src', 'cards', modulo);
  const destino = path.join(TMP, 'cards', modulo);
  const { code } = babel.transformFileSync(origem, {
    plugins: [require.resolve('@babel/plugin-transform-modules-commonjs')],
    configFile: false,
    babelrc: false,
  });
  fs.writeFileSync(destino, code);
}
{
  const origem = path.join(ROOT, 'src', 'hooks', 'useCombat.js');
  const destino = path.join(TMP, 'hooks', 'useCombat.js');
  const { code } = babel.transformFileSync(origem, {
    plugins: [require.resolve('@babel/plugin-transform-modules-commonjs')],
    configFile: false,
    babelrc: false,
  });
  fs.writeFileSync(destino, code);
}

const combat = require(path.join(TMP, 'hooks', 'useCombat.js'));
const { gerarBaralhoCompleto, COPIAS_POR_CARTA, TOTAL_CARTAS } = require(path.join(TMP, 'cards', 'baralhoCartas.js'));
const { CARTAS_TGA } = require(path.join(TMP, 'cards', 'cartasTGA.js'));

const erros = [];
function check(cond, msg) {
  if (!cond) erros.push(msg);
}

// --- baralho ---
const baralho = gerarBaralhoCompleto();
check(baralho.length === 60, `baralho deveria ter 60 cartas, tem ${baralho.length}`);
check(COPIAS_POR_CARTA === 3, 'COPIAS_POR_CARTA deveria ser 3');
check(TOTAL_CARTAS === 60, 'TOTAL_CARTAS deveria ser 60');
check(new Set(baralho.map((c) => c.uid)).size === 60, 'uids duplicados');
const porId = {};
baralho.forEach((c) => { porId[c.id] = (porId[c.id] || 0) + 1; });
check(Object.keys(porId).length === 20, `deveria ter 20 ids distintos, tem ${Object.keys(porId).length}`);
check(Object.values(porId).every((n) => n === 3), 'cada id deveria ter exatamente 3 copias');
check(CARTAS_TGA.length === 20, `CARTAS_TGA deveria ter 20 cartas, tem ${CARTAS_TGA.length}`);
const tiposValidos = ['CORINGA', 'ACAO', 'EFEITO', 'PROTECAO'];
check(CARTAS_TGA.every((c) => tiposValidos.includes(c.tipo)), 'tipo invalido em cartasTGA');
check(CARTAS_TGA.every((c) => typeof c.chanceSucesso === 'number' && c.chanceSucesso >= 0 && c.chanceSucesso <= 1), 'chanceSucesso invalida');
check(CARTAS_TGA.every((c) => typeof c.titulo === 'string' && c.titulo.length > 0), 'titulo vazio');

// --- serialize (importante para o multiplayer) ---
try {
  JSON.stringify(combat.criarEstadoInicial('Teste'));
} catch (e) {
  erros.push('estado nao serializavel: ' + e.message);
}

// --- jogo 1v1 simulado ---
function simular1v1() {
  let estado = combat.criarEstadoInicial('P1');
  for (let i = 0; i < 300 && !estado.fimDeJogo; i++) {
    const idx = estado.jogadorAtivoIndex;
    const jogador = estado.jogadores[idx];
    if (jogador.mao.length > 0) {
      const carta = jogador.mao[Math.floor(Math.random() * jogador.mao.length)];
      estado = combat.jogarCartaSemComprar(estado, jogador.id, carta.uid, null);
    }
    estado = combat.fimDeTurno(estado);
    estado.jogadores.forEach((j, k) => {
      check(Number.isFinite(j.saldo), `saldo invalido (1v1 rodada ${i}, jog ${k}): ${j.saldo}`);
      check(Array.isArray(j.efeitos), `efeitos nao-array (1v1 rodada ${i}, jog ${k})`);
      check(j.mao.length <= 9, `mao > 9 (1v1 rodada ${i}, jog ${k}): ${j.mao.length}`);
    });
    check(Array.isArray(estado.log), 'log invalido');
    if (i % 10 === 0) JSON.stringify(estado);
  }
  return estado;
}

// --- jogo N (4 jogadores) simulado ---
function simularN() {
  let estado = combat.criarEstadoMultiplayerN(['A', 'B', 'C', 'D']);
  for (let i = 0; i < 300 && !estado.fimDeJogo; i++) {
    const idx = estado.jogadorAtivoIndex;
    const jogador = estado.jogadores[idx];
    if (jogador.mao.length > 0) {
      const carta = jogador.mao[Math.floor(Math.random() * jogador.mao.length)];
      const vivos = estado.jogadores
        .map((j, k) => ({ k, falido: j.falido }))
        .filter((j) => !j.falido && j.k !== idx);
      const alvo = carta.precisaAlvo && vivos.length
        ? vivos[Math.floor(Math.random() * vivos.length)].k
        : null;
      estado = combat.jogarCartaSemComprarN(estado, idx, carta.uid, alvo);
    }
    estado = combat.fimDeTurnoN(estado);
    estado.jogadores.forEach((j, k) => {
      check(Number.isFinite(j.saldo), `saldo invalido (N rodada ${i}, jog ${k}): ${j.saldo}`);
      check(j.mao.length <= 9, `mao > 9 (N rodada ${i}, jog ${k}): ${j.mao.length}`);
    });
    if (i % 10 === 0) JSON.stringify(estado);
  }
  return estado;
}

for (let s = 0; s < 40; s++) simular1v1();
for (let s = 0; s < 40; s++) simularN();

// --- efeitos especificos ---
const { executarCarta, processarInicioTurno, duracaoTurno, TURNO_BASE_SEGUNDOS } = require(path.join(TMP, 'cards', 'motorEfeitos.js'));

function baseEstado() {
  const bar = gerarBaralhoCompleto();
  const mao = [];
  for (let i = 0; i < 7; i++) mao.push(bar.shift());
  return {
    turnoAtual: 1,
    maxTurnos: 10,
    jogadorAtivoIndex: 0,
    direcaoTurno: 1,
    baralho: bar,
    pilhaDescarte: [],
    jogadores: [
      { id: 1, nome: 'P1', isIA: false, avatar: null, saldo: 1000, usouFundoEmergencia: false, mao, areaSegura: [], falido: false, protegido: false, protegeContra: null, efeitos: [] },
      { id: 2, nome: 'P2', isIA: true, avatar: null, saldo: 1000, usouFundoEmergencia: false, mao: [...mao], areaSegura: [], falido: false, protegido: false, protegeContra: null, efeitos: [] },
    ],
    fimDeJogo: null,
    log: [],
    batalhaIniciada: false,
  };
}

function cartaPorId(id) {
  return CARTAS_TGA.find((c) => c.id === id);
}

// 1) Nosso (doacao 0-100%, chance 1)
{
  const st = baseEstado();
  const antes1 = st.jogadores[0].saldo;
  const antes2 = st.jogadores[1].saldo;
  const r = executarCarta(st, { idxJogador: 0, idxAlvo: 1, carta: cartaPorId(1) });
  const total = r.estado.jogadores[0].saldo + r.estado.jogadores[1].saldo;
  check(total === antes1 + antes2, `Nosso: dinheiro sumiu (${antes1}+${antes2} -> ${total})`);
  check(r.logEntrada.includes('Nosso'), 'Nosso: log sem titulo');
}

// 2) Toyotinho (chance 0.7, +/-400)
{
  const st = baseEstado();
  const r = executarCarta(st, { idxJogador: 0, idxAlvo: undefined, carta: cartaPorId(2) });
  const d = r.estado.jogadores[0].saldo - 1000;
  check(d === 400 || d === -400, `Toyotinho: delta inesperado ${d}`);
}

// 3) Vigarice (rouba 2 cartas, chance 1)
{
  const st = baseEstado();
  st.jogadores[1].mao = st.jogadores[1].mao.slice(0, 4);
  const r = executarCarta(st, { idxJogador: 0, idxAlvo: 1, carta: cartaPorId(4) });
  check(r.estado.jogadores[0].mao.length === 9, `Vigarice: mao do invocador = ${r.estado.jogadores[0].mao.length} (esperado 9)`);
  check(r.estado.jogadores[1].mao.length === 2, `Vigarice: mao do alvo = ${r.estado.jogadores[1].mao.length} (esperado 2)`);

  // 3b) Roubo AS CEGAS: uids escolhidos pelo jogador (uid invalido nao
  // consome a cota, so leva os 2 validos).
  const st2 = baseEstado();
  st2.jogadores[1].mao = st2.jogadores[1].mao.slice(0, 4);
  const alvoAntes = st2.jogadores[1].mao.map((c) => c.uid);
  const escolhidas = [alvoAntes[0], 'uid_inexistente', alvoAntes[2]];
  const r2 = executarCarta(st2, {
    idxJogador: 0,
    idxAlvo: 1,
    carta: cartaPorId(4),
    roubarUids: escolhidas,
  });
  const maoInv = r2.estado.jogadores[0].mao.map((c) => c.uid);
  const maoAlvoDepois = r2.estado.jogadores[1].mao.map((c) => c.uid);
  check(
    maoInv.includes(alvoAntes[0]) && maoInv.includes(alvoAntes[2]),
    'Vigarice cega: uids escolhidos nao foram para a mao'
  );
  check(
    !maoAlvoDepois.includes(alvoAntes[0]) && !maoAlvoDepois.includes(alvoAntes[2]),
    'Vigarice cega: cartas escolhidas continuam na mao do alvo'
  );
  check(
    maoInv.length === 9,
    `Vigarice cega: mao do invocador = ${maoInv.length} (esperado 9)`
  );
  check(
    maoAlvoDepois.length === 2,
    `Vigarice cega: mao do alvo = ${maoAlvoDepois.length} (esperado 2)`
  );
}

// 4) Presente do Noel (+200/-100 + debuff) - forca sucesso
{
  const st = baseEstado();
  const originalRandom = Math.random;
  Math.random = () => 0.1;
  const r = executarCarta(st, { idxJogador: 0, idxAlvo: 1, carta: cartaPorId(5) });
  Math.random = originalRandom;
  check(r.estado.jogadores[0].saldo === 1200, `Noel: invocador = ${r.estado.jogadores[0].saldo} (esperado 1200)`);
  check(r.estado.jogadores[1].saldo === 900, `Noel: alvo = ${r.estado.jogadores[1].saldo} (esperado 900)`);
  check(r.estado.jogadores[1].efeitos.some((e) => e.tipo === 'MOD_CHANCE'), 'Noel: debuff nao aplicado');
}

// 5) Cris e Greg (divida 150-300, chance 0.9) - forca sucesso
{
  const st = baseEstado();
  const originalRandom = Math.random;
  Math.random = () => 0.1;
  const r = executarCarta(st, { idxJogador: 0, idxAlvo: 1, carta: cartaPorId(7) });
  Math.random = originalRandom;
  const perda = 1000 - r.estado.jogadores[1].saldo;
  check(perda >= 150 && perda <= 300, `Cris e Greg: perda ${perda} fora de 150-300`);
}

// 6) Protecao (Psicologia Industrial) bloqueia carta de efeito
{
  const st = baseEstado();
  const r1 = executarCarta(st, { idxJogador: 0, idxAlvo: undefined, carta: cartaPorId(10) });
  check(r1.estado.jogadores[0].protegido === true, 'Psicologia: protegido nao setado');
  check(r1.estado.jogadores[0].protegeContra === 'EFEITO', 'Psicologia: protegeContra errado');
  // carta de efeito/alvo contra P1 (idxAlvo 0, jogador 1) - forca sucesso
  const originalRandom = Math.random;
  Math.random = () => 0.1;
  const cartaEfeito = { ...cartaPorId(8), tipo: 'EFEITO' }; // Tempos (EFEITO)
  const r2 = executarCarta(r1.estado, { idxJogador: 1, idxAlvo: 0, carta: cartaEfeito });
  Math.random = originalRandom;
  check(r2.estado.jogadores[0].protegido === false, 'Psicologia: protecao nao consumida');
}

// 7) Empréstimo (+500 e divida parcelada) - forca sucesso
{
  const st = baseEstado();
  const originalRandom = Math.random;
  Math.random = () => 0.1;
  const r = executarCarta(st, { idxJogador: 0, idxAlvo: undefined, carta: cartaPorId(11) });
  Math.random = originalRandom;
  const p1 = r.estado.jogadores[0];
  check(p1.saldo === 1500, `Emprestimo: saldo ${p1.saldo} (esperado 1500)`);
  check(p1.efeitos.some((e) => e.tipo === 'DIVIDA_PARCELADA' && e.turnos === 5), 'Emprestimo: efeito parcelado ausente');
}

// 8) Seiton (+500 adiado) + tick de inicio de turno - forca sucesso
{
  const st = baseEstado();
  const originalRandom = Math.random;
  Math.random = () => 0.1;
  const r = executarCarta(st, { idxJogador: 0, idxAlvo: undefined, carta: cartaPorId(15) });
  Math.random = originalRandom;
  check(r.estado.jogadores[0].efeitos.some((e) => e.tipo === 'DINHEIRO_ADIADO'), 'Seiton: efeito adiado ausente');
  check(r.estado.jogadores[0].saldo === 1000, 'Seiton: pagou imediatamente (deveria adiar)');
  const r2 = processarInicioTurno(r.estado, 0);
  check(r2 !== r.estado, 'Seiton: tick de turno nao alterou estado');
  check(r2.jogadores[0].saldo === 1500, `Seiton: saldo apos tick = ${r2.jogadores[0].saldo} (esperado 1500)`);
  check(r2.jogadores[0].efeitos.length === 0, 'Seiton: efeito nao expirou');
}

// 9) Monstro inflacao (MOD_FALHA em todos)
{
  const st = baseEstado();
  const r = executarCarta(st, { idxJogador: 0, idxAlvo: 1, carta: cartaPorId(6) });
  check(r.estado.jogadores[0].efeitos.some((e) => e.tipo === 'MOD_FALHA'), 'Monstro: sem efeito no invocador');
  check(r.estado.jogadores[1].efeitos.some((e) => e.tipo === 'MOD_FALHA'), 'Monstro: sem efeito no alvo');
}

// 10) Seiri (devolve 3 cartas + efeito TROCA_MAO) - forca sucesso
{
  const st = baseEstado();
  const originalRandom = Math.random;
  Math.random = () => 0.1;
  const r = executarCarta(st, { idxJogador: 0, idxAlvo: undefined, carta: cartaPorId(16) });
  Math.random = originalRandom;
  check(r.estado.jogadores[0].mao.length === 4, `Seiri: mao = ${r.estado.jogadores[0].mao.length} (esperado 4)`);
  check(r.estado.jogadores[0].efeitos.some((e) => e.tipo === 'TROCA_MAO'), 'Seiri: efeito ausente');
}

// 11) Timer de turno: base 20s, Sem tempo = 2s (3 turnos), Seiso = +2s (2 turnos)
{
  check(TURNO_BASE_SEGUNDOS === 20, `TURNO_BASE_SEGUNDOS = ${TURNO_BASE_SEGUNDOS} (esperado 20)`);
  check(duracaoTurno({ efeitos: [] }) === 20, 'duracao base deveria ser 20s');
  check(duracaoTurno(null) === 20, 'duracao sem jogador deveria ser 20s');

  const st = baseEstado();
  const originalRandom = Math.random;
  Math.random = () => 0.1;
  const r = executarCarta(st, { idxJogador: 0, idxAlvo: 1, carta: cartaPorId(3) }); // Sem tempo
  Math.random = originalRandom;
  check(r.estado.jogadores[1].efeitos.some((e) => e.tipo === 'TEMPO_TURNO' && e.modo === 'definir'), 'Sem tempo: efeito ausente');
  check(duracaoTurno(r.estado.jogadores[1]) === 2, `Sem tempo: duracao do oponente = ${duracaoTurno(r.estado.jogadores[1])} (esperado 2)`);
  check(duracaoTurno(r.estado.jogadores[0]) === 20, 'Sem tempo: invocador nao pode ser afetado');

  // Vale exatamente 3 turnos do oponente.
  let e1 = processarInicioTurno(r.estado, 1);
  check(duracaoTurno(e1.jogadores[1]) === 2, 'Sem tempo: 1o turno deveria ter 2s');
  let e2 = processarInicioTurno(e1, 1);
  check(duracaoTurno(e2.jogadores[1]) === 2, 'Sem tempo: 2o turno deveria ter 2s');
  let e3 = processarInicioTurno(e2, 1);
  check(duracaoTurno(e3.jogadores[1]) === 2, 'Sem tempo: 3o turno deveria ter 2s');
  let e4 = processarInicioTurno(e3, 1);
  check(duracaoTurno(e4.jogadores[1]) === 20, 'Sem tempo: apos 3 turnos deveria voltar a 20s');

  // Seiso: +2s por 2 turnos do proprio jogador.
  const st2 = baseEstado();
  Math.random = () => 0.1;
  const r2 = executarCarta(st2, { idxJogador: 0, idxAlvo: undefined, carta: cartaPorId(17) });
  Math.random = originalRandom;
  check(duracaoTurno(r2.estado.jogadores[0]) === 22, `Seiso: duracao = ${duracaoTurno(r2.estado.jogadores[0])} (esperado 22)`);
  let s1 = processarInicioTurno(r2.estado, 0);
  check(duracaoTurno(s1.jogadores[0]) === 22, 'Seiso: 1o turno deveria ter 22s');
  let s2 = processarInicioTurno(s1, 0);
  check(duracaoTurno(s2.jogadores[0]) === 22, 'Seiso: 2o turno deveria ter 22s');
  let s3 = processarInicioTurno(s2, 0);
  check(duracaoTurno(s3.jogadores[0]) === 20, 'Seiso: apos 2 turnos deveria voltar a 20s');
}

console.log('');
if (erros.length === 0) {
  console.log('SMOKE TEST: todos os testes passaram');
} else {
  console.log(`SMOKE TEST: ${erros.length} falha(s)`);
  erros.forEach((e) => console.log('  -', e));
  process.exitCode = 1;
}

