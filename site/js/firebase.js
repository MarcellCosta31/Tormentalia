/* ============================================================
   Ponte com o Firebase via REST (sem SDK, sem CDN).

   O site permanece estatico: as sugestoes sao enviadas diretamente
   para a API REST do Firestore com a chave publica do projeto.
   Regras de seguranca do Firestore devem permitir criacao em
   `sugestoes/{id}` (leitura publica e opcional).
   ============================================================ */
(function () {
  'use strict';

  var cfg = window.OCDM_FIREBASE || {};

  function configurado() {
    return !!(cfg.apiKey && cfg.projectId && cfg.collection);
  }

  function valor(texto) {
    return { stringValue: String(texto == null ? '' : texto) };
  }

  function validar(dados) {
    var titulo = String(dados.titulo || '').trim();
    var mensagem = String(dados.mensagem || '').trim();
    if (titulo.length < 4) return 'Escreva um titulo com pelo menos 4 letras.';
    if (mensagem.length < 10) return 'Descreva sua ideia com pelo menos 10 letras.';
    if (titulo.length > 120) return 'O titulo esta muito longo (maximo 120 letras).';
    if (mensagem.length > 2000) return 'A mensagem esta muito longa (maximo 2000 letras).';
    return null;
  }

  function enviarSugestao(dados) {
    var erro = validar(dados);
    if (erro) return Promise.reject(new Error(erro));
    if (!configurado()) {
      return Promise.reject(new Error(
        'Conexao em preparacao: o Firebase ainda nao foi configurado.'
      ));
    }
    if (typeof fetch !== 'function') {
      return Promise.reject(new Error('Este navegador nao suporta envio online.'));
    }

    var documento = {
      fields: {
        nome: valor(String(dados.nome || '').trim() || 'ANONIMO'),
        categoria: valor(dados.categoria || 'ideia'),
        titulo: valor(String(dados.titulo).trim()),
        mensagem: valor(String(dados.mensagem).trim()),
        criadoEm: valor(new Date().toISOString()),
        status: valor('nova'),
        versao: valor('1.0-beta')
      }
    };

    var url = 'https://firestore.googleapis.com/v1/projects/'
      + encodeURIComponent(cfg.projectId)
      + '/databases/(default)/documents/'
      + encodeURIComponent(cfg.collection)
      + '?key=' + encodeURIComponent(cfg.apiKey);

    return fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(documento)
    }).then(function (resposta) {
      if (!resposta.ok) {
        throw new Error('Nao foi possivel enviar (HTTP ' + resposta.status + ').');
      }
      return resposta.json();
    }).then(function (dados) {
      return { ok: true, id: dados.name || null };
    });
  }

  window.OCDM_FirebaseAPI = {
    configurado: configurado,
    enviarSugestao: enviarSugestao,
    validar: validar
  };
})();
