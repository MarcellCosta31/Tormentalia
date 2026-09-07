import { criarBaralho, embaralhar, TIPO_CARTA } from '../cards/cartas';

const SALDO_INICIAL = 20;
const SALDO_EMERGENCIA = 5;
const MAX_TURNOS = 10;
const CARTAS_POR_MAO = 7;

export const STATUS_JOGADOR = {
  ATIVO: 'ATIVO',
  EMERGENCIA: 'EMERGENCIA',
  ELIMINADO: 'ELIMINADO'
};

export const criarJogador = (nome, isIA = false) => ({
  id: Date.now() + Math.random(),
  nome,
  isIA,
  saldo: SALDO_INICIAL,
  status: STATUS_JOGADOR.ATIVO,
  mao: [],
  buffs: [],
  saldoEmergenciaUsado: false
});

export const criarEstadoJogo = (nomesJogadores) => {
  const baralho = embaralhar(criarBaralho());
  const jogadores = nomesJogadores.map((nome, index) => 
    criarJogador(nome, index > 0) // Primeiro jogador é humano, resto é IA
  );

  // Distribui cartas iniciais
  jogadores.forEach(jogador => {
    for (let i = 0; i < CARTAS_POR_MAO; i++) {
      if (baralho.length > 0) {
        jogador.mao.push(baralho.pop());
      }
    }
  });

  return {
    jogadores,
    baralho,
    turnoAtual: 1,
    jogadorAtualIndex: 0,
    jogoAcabou: false,
    vencedor: null,
    log: ['🎮 Jogo começar! Turno 1']
  };
};

export const verificarRisco = (risco) => {
  const chance = Math.random() * 100;
  return chance >= risco; // true = sucesso, false = falha
};

export const aplicarEfeitoCarta = (carta, jogador, jogadores, bonus = null) => {
  const resultado = {
    sucesso: true,
    mensagem: '',
    efeitoAplicado: null
  };

  // Verifica se é carta medida
  if (carta.tipo !== TIPO_CARTA.MEDIDA && carta.tipo !== TIPO_CARTA.CORINGA) {
    return { sucesso: false, mensagem: 'Só pode jogar cartas medidas!' };
  }

  // Aplica efeitos do bônus primeiro
  let riscoModificado = carta.risco;
  let efeitoModificado = { ...carta.efeito };

  if (bonus) {
    // Remove risco
    if (bonus.efeito.tipo === 'REMOVE_RISCO') {
      riscoModificado = 0;
    }
    // Reduz risco
    else if (bonus.efeito.tipo === 'REDUZ_RISCO') {
      riscoModificado = Math.floor(riscoModificado * (1 - bonus.efeito.valor / 100));
    }
    // Multiplica efeito
    else if (bonus.efeito.tipo === 'MULTIPLICA_EFEITO') {
      efeitoModificado.valor = Math.floor(efeitoModificado.valor * bonus.efeito.valor);
    }
    // Dinheiro extra
    else if (bonus.efeito.tipo === 'DINHEIRO_EXTRA') {
      efeitoModificado.valor += bonus.efeito.valor;
    }
    // Protege contra falha
    else if (bonus.efeito.tipo === 'PROTEGE_FALHA') {
      resultado.protegido = true;
    }
  }

  // Verifica risco para cartas medidas
  if (carta.tipo === TIPO_CARTA.MEDIDA) {
    const sucesso = verificarRisco(riscoModificado);
    
    if (!sucesso && !resultado.protegido) {
      // Falha - efeito reverso ou nada
      resultado.sucesso = false;
      resultado.mensagem = `❌ ${carta.nome} falhou!`;
      
      if (bonus?.efeito.tipo === 'PROTEGE_FALHA') {
        resultado.mensagem = `🛡️ ${carta.nome} falhou, mas o seguro protegeu!`;
        resultado.sucesso = true;
      } else {
        // Efeito reverso (perde metade do valor)
        if (efeitoModificado.tipo === 'DINHEIRO') {
          efeitoModificado.valor = Math.floor(efeitoModificado.valor * -0.5);
          jogador.saldo += efeitoModificado.valor;
          resultado.mensagem += ` Perdeu R$ ${Math.abs(efeitoModificado.valor)}!`;
        }
        return resultado;
      }
    }
  }

  // Aplica o efeito
  switch (efeitoModificado.tipo) {
    case 'DINHEIRO':
      jogador.saldo += efeitoModificado.valor;
      if (efeitoModificado.valor > 0) {
        resultado.mensagem = `💰 ${jogador.nome} ganhou R$ ${efeitoModificado.valor}!`;
      } else {
        resultado.mensagem = `💸 ${jogador.nome} perdeu R$ ${Math.abs(efeitoModificado.valor)}!`;
      }
      break;

    case 'TODOS':
      jogadores.forEach(j => {
        if (j.status !== STATUS_JOGADOR.ELIMINADO) {
          j.saldo += efeitoModificado.valor;
        }
      });
      resultado.mensagem = `🌍 Todos perderam R$ ${Math.abs(efeitoModificado.valor)}!`;
      break;

    case 'OPONENTE':
      const oponentesAtivos = jogadores.filter(j => 
        j.id !== jogador.id && j.status !== STATUS_JOGADOR.ELIMINADO
      );
      if (opONENTESAtivos.length > 0) {
        const oponente = oponentesAtivos[Math.floor(Math.random() * oponentesAtivos.length)];
        oponente.saldo += efeitoModificado.valor;
        resultado.mensagem = `🎯 ${oponente.nome} perdeu R$ ${Math.abs(efeitoModificado.valor)}!`;
      }
      break;

    case 'BUFF':
      jogador.buffs.push({
        tipo: efeitoModificado.tipo,
        valor: efeitoModificado.valor,
        duracao: efeitoModificado.duracao
      });
      resultado.mensagem = `✨ ${jogador.nome} recebeu um buff de ${efeitoModificado.valor > 0 ? '+' : ''}${efeitoModificado.valor} por ${efeitoModificado.duracao} turnos!`;
      break;

    case 'ALEATORIO':
      const opcao = efeitoModificado.opcoes[Math.floor(Math.random() * efeitoModificado.opcoes.length)];
      if (opcao.tipo === 'DINHEIRO') {
        jogador.saldo += opcao.valor;
        resultado.mensagem = `🎲 ${opcao.valor > 0 ? 'Ganhou' : 'Perdeu'} R$ ${Math.abs(opcao.valor)}!`;
      } else if (opcao.tipo === 'TODOS_PERDEM') {
        jogadores.forEach(j => {
          if (j.status !== STATUS_JOGADOR.ELIMINADO) {
            j.saldo -= opcao.valor;
          }
        });
        resultado.mensagem = `🎲 Todos perderam R$ ${opcao.valor}!`;
      }
      break;
  }

  resultado.efeitoAplicado = efeitoModificado;
  return resultado;
};

export const aplicarEfeitoDeusMercado = (jogadores, baralho) => {
  if (baralho.length === 0) return null;

  const carta = baralho.pop();
  const resultado = {
    carta,
    efeitos: []
  };

  jogadores.forEach(jogador => {
    if (jador.status !== STATUS_JOGADOR.ELIMINADO) {
      if (carta.efeito.tipo === 'TODOS') {
        jogador.saldo += carta.efeito.valor;
        resultado.efeitos.push({
          jogador: jogador.nome,
          valor: carta.efeito.valor
        });
      }
    }
  });

  return resultado;
};

export const verificarSaldoEmergencia = (jogador) => {
  if (jogador.saldo <= 0 && jogador.status === STATUS_JOGADOR.ATIVO) {
    jogador.status = STATUS_JOGADOR.EMERGENCIA;
    jogador.saldo = SALDO_EMERGENCIA;
    jogador.saldoEmergenciaUsado = true;
    return true;
  }
  return false;
};

export const verificarEliminacao = (jogador) => {
  if (jogador.saldo <= 0 && jogador.status === STATUS_JOGADOR.EMERGENCIA) {
    jogador.status = STATUS_JOGADOR.ELIMINADO;
    return true;
  }
  return false;
};

export const verificarVencedor = (jogadores) => {
  const jogadoresAtivos = jogadores.filter(j => j.status !== STATUS_JOGADOR.ELIMINADO);
  
  if (jogadoresAtivos.length === 1) {
    return jogadoresAtivos[0];
  }
  
  if (jogadoresAtivos.length === 0) {
    return { empate: true };
  }

  // Ordena por saldo (maior para menor)
  const ordenados = [...jogadoresAtivos].sort((a, b) => b.saldo - a.saldo);
  
  // Verifica se há empate
  if (ordenados[0].saldo === ordenados[1]?.saldo) {
    return { empate: true, jogadores: ordenados.filter(j => j.saldo === ordenados[0].saldo) };
  }

  return ordenados[0];
};

export const passarTurno = (estadoJogo) => {
  const { jogadores, baralho, turnoAtual, jogadorAtualIndex } = estadoJogo;

  // Remove buffs expirados
  const jogador = jogadores[jogadorAtualIndex];
  jogador.buffs = jogador.buffs.filter(buff => {
    buff.duracao--;
    return buff.duracao > 0;
  });

  // Próximo jogador
  let proximoIndex = (jogadorAtualIndex + 1) % jogadores.length;
  
  // Se voltou ao início, avança turno
  let novoTurno = turnoAtual;
  if (proximoIndex === 0) {
    novoTurno = turnoAtual + 1;
  }

  // Verifica se o jogo acabou
  const jogoAcabou = novoTurno > MAX_TURNOS;
  
  // Verifica se só sobrou 1 jogador
  const jogadoresAtivos = jogadores.filter(j => j.status !== STATUS_JOGADOR.ELIMINADO);
  const acabouPorEliminacao = jogadoresAtivos.length <= 1;

  let vencedor = null;
  if (jogoAcabou || acabouPorEliminacao) {
    vencedor = verificarVencedor(jogadores);
  }

  return {
    ...estadoJogo,
    turnoAtual: novoTurno,
    jogadorAtualIndex: proximoIndex,
    jogoAcabou: jogoAcabou || acabouPorEliminacao,
    vencedor
  };
};

export const comprarCarta = (jogador, baralho) => {
  if (baralho.length > 0 && jogador.mao.length < CARTAS_POR_MAO) {
    const carta = baralho.pop();
    jogador.mao.push(carta);
    return carta;
  }
  return null;
};

export const descartarCarta = (jogador, cartaUid) => {
  const index = jogador.mao.findIndex(c => c.uid === cartaUid);
  if (index !== -1) {
    const carta = jogador.mao.splice(index, 1)[0];
    return carta;
  }
  return null;
};
