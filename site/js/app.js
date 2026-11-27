/* ============================================================
   TORMENTALIA — interatividade do site
   Navegação, manual em abas, galeria de cartas, modal,
   lightbox e partículas do hero. Sem dependências externas.
   ============================================================ */

(function () {
  'use strict';

  var reduceMotion = window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  /* --------------------------------------------------------
     Utilidades
     -------------------------------------------------------- */
  function $(sel, ctx) { return (ctx || document).querySelector(sel); }
  function $$(sel, ctx) { return Array.prototype.slice.call((ctx || document).querySelectorAll(sel)); }

  function normalize(text) {
    return String(text || '')
      .normalize('NFD')
      .replace(/[\u0300-\u036f]/g, '')
      .toLowerCase()
      .trim();
  }

  function pad2(n) { return (n < 10 ? '0' : '') + n; }

  function chanceLabel(chance) {
    if (typeof chance !== 'number' || isNaN(chance)) return '—';
    var pct = Math.round(chance * 1000) / 10;
    return (pct % 1 === 0 ? pct.toFixed(0) : pct.toFixed(1)) + '%';
  }

  /* --------------------------------------------------------
     Armadilha de foco (focus trap) para diálogos
     -------------------------------------------------------- */
  var FOCUSABLE = 'a[href], button:not([disabled]), input:not([disabled]), select:not([disabled]), textarea:not([disabled]), [tabindex]:not([tabindex="-1"])';

  function trapFocus(container, event) {
    if (event.key !== 'Tab') return;
    var items = $$(FOCUSABLE, container).filter(function (el) {
      return el.offsetParent !== null || el === document.activeElement;
    });
    if (!items.length) return;
    var first = items[0];
    var last = items[items.length - 1];
    if (event.shiftKey && document.activeElement === first) {
      event.preventDefault();
      last.focus();
    } else if (!event.shiftKey && document.activeElement === last) {
      event.preventDefault();
      first.focus();
    }
  }

  /* --------------------------------------------------------
     Cabeçalho: estado ao rolar + menu mobile
     -------------------------------------------------------- */
  var header = $('.site-header');
  var nav = $('#nav');
  var menuToggle = $('.menu-toggle');

  function onScrollHeader() {
    if (!header) return;
    header.classList.toggle('is-scrolled', window.scrollY > 24);
  }
  window.addEventListener('scroll', onScrollHeader, { passive: true });
  onScrollHeader();

  function closeMenu() {
    if (!nav || !menuToggle) return;
    nav.classList.remove('is-open');
    menuToggle.setAttribute('aria-expanded', 'false');
    menuToggle.setAttribute('aria-label', 'Abrir menu');
  }

  if (menuToggle && nav) {
    menuToggle.addEventListener('click', function () {
      var open = nav.classList.toggle('is-open');
      menuToggle.setAttribute('aria-expanded', open ? 'true' : 'false');
      menuToggle.setAttribute('aria-label', open ? 'Fechar menu' : 'Abrir menu');
    });
    nav.addEventListener('click', function (event) {
      if (event.target.closest('a')) closeMenu();
    });
    document.addEventListener('keydown', function (event) {
      if (event.key === 'Escape' && nav.classList.contains('is-open')) {
        closeMenu();
        menuToggle.focus();
      }
    });
    window.addEventListener('resize', function () {
      if (window.innerWidth > 760) closeMenu();
    });
  }

  /* --------------------------------------------------------
     Navegação: link ativo por página + scroll spy das âncoras
     -------------------------------------------------------- */
  var navLinks = $$('.nav a[href]');
  var currentFile = location.pathname.split('/').pop() || 'index.html';
  var anchorLinks = [];
  var pageLinks = [];

  navLinks.forEach(function (link) {
    var href = link.getAttribute('href') || '';
    var hashAt = href.indexOf('#');
    var file = hashAt === -1 ? href : href.slice(0, hashAt);
    var id = hashAt === -1 ? '' : href.slice(hashAt + 1);
    var isCurrent = !file || file === currentFile;

    if (id && isCurrent) {
      var section = document.getElementById(id);
      if (section) {
        anchorLinks.push({ link: link, section: section });
        return;
      }
    }
    if (!id && isCurrent) pageLinks.push(link);
  });

  function markPageLinks() {
    pageLinks.forEach(function (link) { link.classList.add('is-active'); });
  }

  function updateSpy() {
    if (!anchorLinks.length) return;
    var marker = window.scrollY + 140;
    var current = anchorLinks[0];
    for (var i = 0; i < anchorLinks.length; i++) {
      if (anchorLinks[i].section.offsetTop <= marker) current = anchorLinks[i];
    }
    anchorLinks.forEach(function (item) { item.link.classList.remove('is-active'); });
    if (current) current.link.classList.add('is-active');
  }
  window.addEventListener('scroll', updateSpy, { passive: true });
  updateSpy();
  markPageLinks();

  /* --------------------------------------------------------
     Reveal on scroll
     -------------------------------------------------------- */
  var revealItems = $$('[data-reveal]');
  if (reduceMotion || !('IntersectionObserver' in window)) {
    revealItems.forEach(function (el) { el.classList.add('is-visible'); });
  } else {
    var revealObserver = new IntersectionObserver(function (entries) {
      entries.forEach(function (entry) {
        if (entry.isIntersecting) {
          entry.target.classList.add('is-visible');
          revealObserver.unobserve(entry.target);
        }
      });
    }, { threshold: 0.12, rootMargin: '0px 0px -40px 0px' });
    revealItems.forEach(function (el) { revealObserver.observe(el); });
  }

  /* --------------------------------------------------------
     Manual: abas
     -------------------------------------------------------- */
  var manualTabs = $$('.manual-tab');
  var manualPanels = $$('.manual-panel');

  function activateTab(tab, focusIt) {
    if (!tab) return;
    var key = tab.getAttribute('data-tab');
    manualTabs.forEach(function (t) {
      var active = t === tab;
      t.classList.toggle('is-active', active);
      t.setAttribute('aria-selected', active ? 'true' : 'false');
      t.setAttribute('tabindex', active ? '0' : '-1');
    });
    manualPanels.forEach(function (panel) {
      var match = panel.id === 'panel-' + key;
      if (match) {
        panel.removeAttribute('hidden');
        panel.classList.add('is-active');
      } else {
        panel.setAttribute('hidden', '');
        panel.classList.remove('is-active');
      }
    });
    if (focusIt) tab.focus();
  }

  manualTabs.forEach(function (tab) {
    tab.addEventListener('click', function () { activateTab(tab, false); });
    tab.addEventListener('keydown', function (event) {
      var index = manualTabs.indexOf(tab);
      var next = -1;
      if (event.key === 'ArrowDown' || event.key === 'ArrowRight') next = (index + 1) % manualTabs.length;
      if (event.key === 'ArrowUp' || event.key === 'ArrowLeft') next = (index - 1 + manualTabs.length) % manualTabs.length;
      if (event.key === 'Home') next = 0;
      if (event.key === 'End') next = manualTabs.length - 1;
      if (next >= 0) {
        event.preventDefault();
        activateTab(manualTabs[next], true);
      }
    });
  });

  // Deep link: manual.html#capitulo abre o capítulo correspondente (e também
  // aceita #panel-<capitulo>, caso o navegador já tenha dado scroll nele).
  function activateFromHash() {
    if (!manualTabs.length || !location.hash) return;
    var key = location.hash.slice(1);
    var el = document.getElementById(key) || document.getElementById('tab-' + key);
    if (!el) return;
    if (el.classList.contains('manual-tab')) { activateTab(el, false); return; }
    if (el.classList.contains('manual-panel')) {
      var tab = manualTabs.filter(function (t) { return t.getAttribute('aria-controls') === el.id; })[0];
      if (tab) activateTab(tab, false);
    }
  }
  activateFromHash();
  window.addEventListener('hashchange', activateFromHash);

  /* --------------------------------------------------------
     Galeria de cartas
     -------------------------------------------------------- */
  var CARDS = (window.OCDM_CARDS || []).slice();
  var grid = $('#card-grid');
  var emptyState = $('#card-empty');
  var statusEl = $('#filter-status');
  var searchInput = $('#card-search');
  var filterButtons = $$('.filter-btn[data-filter]');
  var currentFilter = 'all';
  var currentQuery = '';
  var visibleCards = CARDS.slice();

  function cardTile(card) {
    var button = document.createElement('button');
    button.type = 'button';
    button.className = 'card-tile';
    button.setAttribute('data-class', card.classKey);
    button.setAttribute('data-id', String(card.id));
    button.setAttribute('aria-label', 'Ver detalhes da carta ' + card.name);

    var art = document.createElement('span');
    art.className = 'card-tile-art';
    var img = document.createElement('img');
    img.src = card.image;
    img.alt = card.name;
    img.width = 377;
    img.height = 661;
    img.loading = 'lazy';
    art.appendChild(img);

    var info = document.createElement('span');
    info.className = 'card-tile-info';
    var dot = document.createElement('span');
    dot.className = 'card-tile-dot';
    var name = document.createElement('span');
    name.className = 'card-tile-name';
    name.textContent = card.name;
    var chance = document.createElement('span');
    chance.className = 'card-tile-chance';
    chance.textContent = chanceLabel(card.chance);
    info.appendChild(dot);
    info.appendChild(name);
    info.appendChild(chance);

    button.appendChild(art);
    button.appendChild(info);
    button.addEventListener('click', function () {
      openCardModal(card.id, button);
    });
    return button;
  }

  function renderGallery() {
    if (!grid) return;
    var query = normalize(currentQuery);
    visibleCards = CARDS.filter(function (card) {
      var matchClass = currentFilter === 'all' || card.classKey === currentFilter;
      var haystack = normalize(card.name + ' ' + card.subtitle + ' ' + card.className + ' ' + card.effect + ' ' + card.description);
      var matchQuery = !query || haystack.indexOf(query) !== -1;
      return matchClass && matchQuery;
    });

    grid.textContent = '';
    var fragment = document.createDocumentFragment();
    visibleCards.forEach(function (card) { fragment.appendChild(cardTile(card)); });
    grid.appendChild(fragment);

    if (emptyState) emptyState.hidden = visibleCards.length !== 0;
    if (statusEl) {
      var label = visibleCards.length === 1 ? 'carta' : 'cartas';
      var suffix = '';
      if (currentFilter !== 'all') {
        var cls = (window.OCDM_CLASSES || []).filter(function (c) { return c.key === currentFilter; })[0];
        if (cls) suffix = ' · ' + cls.name;
      }
      if (currentQuery) suffix += ' · busca "' + currentQuery + '"';
      statusEl.textContent = visibleCards.length + ' ' + label + suffix;
    }
  }

  filterButtons.forEach(function (btn) {
    btn.addEventListener('click', function () {
      currentFilter = btn.getAttribute('data-filter') || 'all';
      filterButtons.forEach(function (b) { b.classList.toggle('is-active', b === btn); });
      renderGallery();
    });
  });

  if (searchInput) {
    var searchTimer = null;
    searchInput.addEventListener('input', function () {
      currentQuery = searchInput.value;
      if (searchTimer) clearTimeout(searchTimer);
      searchTimer = setTimeout(renderGallery, 120);
    });
  }

  function clearFilters() {
    currentFilter = 'all';
    currentQuery = '';
    if (searchInput) searchInput.value = '';
    filterButtons.forEach(function (b) {
      b.classList.toggle('is-active', b.getAttribute('data-filter') === 'all');
    });
    renderGallery();
    if (searchInput) searchInput.focus();
  }

  var clearBtn = $('#clear-filters');
  if (clearBtn) clearBtn.addEventListener('click', clearFilters);

  var emptyClearBtn = $('#empty-clear');
  if (emptyClearBtn) emptyClearBtn.addEventListener('click', clearFilters);

  function randomFrom(list) {
    if (!list.length) return null;
    return list[Math.floor(Math.random() * list.length)];
  }

  var randomBtn = $('#random-card');
  if (randomBtn) {
    randomBtn.addEventListener('click', function () {
      var pool = visibleCards.length ? visibleCards : CARDS;
      var card = randomFrom(pool);
      if (card) openCardModal(card.id, randomBtn);
    });
  }

  renderGallery();

  /* --------------------------------------------------------
     Modal de carta
     -------------------------------------------------------- */
  var modal = $('#card-modal');
  var modalDialog = $('.card-modal-dialog', modal || document);
  var modalIndex = 0;
  var lastFocused = null;

  function setModalContent(card, index) {
    if (!modal) return;
    modalIndex = index;
    modalDialog.setAttribute('data-class', card.classKey);

    var img = $('#card-modal-image');
    img.src = card.image;
    img.alt = 'Carta ' + card.name;

    $('#card-modal-class').textContent = card.className;
    $('#card-modal-rarity').textContent = card.rarity || '—';
    $('#card-modal-title').textContent = card.name;
    $('#card-modal-subtitle').textContent = card.subtitle || '';
    $('#card-modal-description').textContent = card.description || '';
    $('#card-modal-effect').textContent = card.effect || '—';

    var extra = $('#card-modal-extra');
    var extras = [];
    if (card.target) extras.push('Alvo: ' + card.target);
    if (card.duration) extras.push('Duração: ' + card.duration);
    if (extras.length) {
      extra.textContent = extras.join(' · ');
      extra.removeAttribute('hidden');
    } else {
      extra.setAttribute('hidden', '');
    }

    $('#card-modal-chance').textContent = chanceLabel(card.chance);
    $('#card-modal-duration').textContent = card.duration || '—';
    $('#card-modal-target').textContent = card.target || '—';
    $('#card-modal-weight').textContent = card.weight != null ? String(card.weight) : '—';
    $('#card-modal-tip').textContent = card.tip || '—';
    $('#card-modal-index').textContent = 'Carta ' + pad2(index + 1) + ' de ' + pad2(CARDS.length);
  }

  function cardIndexById(id) {
    for (var i = 0; i < CARDS.length; i++) {
      if (String(CARDS[i].id) === String(id)) return i;
    }
    return -1;
  }

  function openCardModal(id, trigger) {
    if (!modal) return;
    var index = cardIndexById(id);
    if (index < 0) return;
    lastFocused = trigger || document.activeElement;
    setModalContent(CARDS[index], index);
    modal.removeAttribute('hidden');
    document.body.style.overflow = 'hidden';
    var closeBtn = $('.modal-close', modal);
    if (closeBtn) closeBtn.focus();
  }

  function closeCardModal() {
    if (!modal || modal.hasAttribute('hidden')) return;
    modal.setAttribute('hidden', '');
    document.body.style.overflow = '';
    if (lastFocused && typeof lastFocused.focus === 'function') lastFocused.focus();
  }

  function stepCard(delta) {
    if (!CARDS.length) return;
    var next = (modalIndex + delta + CARDS.length) % CARDS.length;
    setModalContent(CARDS[next], next);
  }

  if (modal) {
    $$('[data-close-modal]', modal).forEach(function (el) {
      el.addEventListener('click', closeCardModal);
    });
    var prevBtn = $('#card-prev');
    var nextBtn = $('#card-next');
    if (prevBtn) prevBtn.addEventListener('click', function () { stepCard(-1); });
    if (nextBtn) nextBtn.addEventListener('click', function () { stepCard(1); });
    var modalRandom = $('#card-modal-random');
    if (modalRandom) {
      modalRandom.addEventListener('click', function () {
        stepCard(1 + Math.floor(Math.random() * (CARDS.length - 1)));
      });
    }
    modal.addEventListener('keydown', function (event) {
      if (event.key === 'Escape') { event.preventDefault(); closeCardModal(); return; }
      if (event.key === 'ArrowLeft') { event.preventDefault(); stepCard(-1); return; }
      if (event.key === 'ArrowRight') { event.preventDefault(); stepCard(1); return; }
      trapFocus(modalDialog, event);
    });
  }

  /* --------------------------------------------------------
     Lightbox de screenshots
     -------------------------------------------------------- */
  var lightbox = $('#lightbox');
  var shots = $$('.shot-card');
  var shotData = shots.map(function (shot) {
    var img = $('img', shot);
    var caption = $('.shot-caption strong', shot);
    var sub = $('.shot-caption small', shot);
    return {
      src: img ? img.getAttribute('src') : '',
      alt: img ? img.getAttribute('alt') : '',
      title: caption ? caption.textContent : '',
      sub: sub ? sub.textContent : ''
    };
  });
  var lightboxIndex = 0;
  var lightboxLastFocused = null;

  function setLightbox(index) {
    if (!lightbox || !shotData.length) return;
    lightboxIndex = (index + shotData.length) % shotData.length;
    var data = shotData[lightboxIndex];
    var img = $('#lightbox-image');
    img.src = data.src;
    img.alt = data.alt;
    $('#lightbox-caption').textContent = data.title + (data.sub ? ' — ' + data.sub : '');
  }

  function openLightbox(index, trigger) {
    if (!lightbox || !shotData.length) return;
    lightboxLastFocused = trigger || document.activeElement;
    setLightbox(index);
    lightbox.removeAttribute('hidden');
    document.body.style.overflow = 'hidden';
    var closeBtn = $('.lightbox-close', lightbox);
    if (closeBtn) closeBtn.focus();
  }

  function closeLightbox() {
    if (!lightbox || lightbox.hasAttribute('hidden')) return;
    lightbox.setAttribute('hidden', '');
    document.body.style.overflow = '';
    if (lightboxLastFocused && typeof lightboxLastFocused.focus === 'function') lightboxLastFocused.focus();
  }

  shots.forEach(function (shot) {
    shot.addEventListener('click', function () {
      openLightbox(parseInt(shot.getAttribute('data-shot'), 10) || 0, shot);
    });
  });

  if (lightbox) {
    $$('[data-close-lightbox]', lightbox).forEach(function (el) {
      el.addEventListener('click', closeLightbox);
    });
    var lbPrev = $('#lightbox-prev');
    var lbNext = $('#lightbox-next');
    if (lbPrev) lbPrev.addEventListener('click', function () { setLightbox(lightboxIndex - 1); });
    if (lbNext) lbNext.addEventListener('click', function () { setLightbox(lightboxIndex + 1); });
    lightbox.addEventListener('keydown', function (event) {
      if (event.key === 'Escape') { event.preventDefault(); closeLightbox(); return; }
      if (event.key === 'ArrowLeft') { event.preventDefault(); setLightbox(lightboxIndex - 1); return; }
      if (event.key === 'ArrowRight') { event.preventDefault(); setLightbox(lightboxIndex + 1); return; }
      trapFocus($('.lightbox-inner', lightbox), event);
    });
  }

  /* --------------------------------------------------------
     Partículas do hero
     -------------------------------------------------------- */
  var canvas = $('#particles');
  var ctx = canvas && canvas.getContext ? canvas.getContext('2d') : null;
  if (canvas && ctx && !reduceMotion) {
    var particles = [];
    var rafId = null;
    var width = 0;
    var height = 0;
    var dpr = Math.min(window.devicePixelRatio || 1, 2);

    function resizeCanvas() {
      var rect = canvas.getBoundingClientRect();
      width = rect.width;
      height = rect.height;
      canvas.width = Math.floor(width * dpr);
      canvas.height = Math.floor(height * dpr);
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    }

    function makeParticle(spawnAnywhere) {
      return {
        x: Math.random() * width,
        y: spawnAnywhere ? Math.random() * height : height + Math.random() * 40,
        r: Math.random() * 1.8 + 0.6,
        vy: -(Math.random() * 0.25 + 0.08),
        vx: (Math.random() - 0.5) * 0.18,
        alpha: Math.random() * 0.5 + 0.15,
        color: Math.random() > 0.6 ? '255, 95, 210' : (Math.random() > 0.5 ? '69, 214, 255' : '246, 196, 83)')
      };
    }

    function initParticles() {
      resizeCanvas();
      var count = Math.min(70, Math.max(30, Math.round(width / 18)));
      particles = [];
      for (var i = 0; i < count; i++) particles.push(makeParticle(true));
    }

    function tick() {
      ctx.clearRect(0, 0, width, height);
      for (var i = 0; i < particles.length; i++) {
        var p = particles[i];
        p.x += p.vx;
        p.y += p.vy;
        if (p.y < -10 || p.x < -10 || p.x > width + 10) {
          particles[i] = makeParticle(false);
          continue;
        }
        ctx.beginPath();
        ctx.fillStyle = 'rgba(' + p.color + ', ' + p.alpha + ')';
        ctx.arc(p.x, p.y, p.r, 0, Math.PI * 2);
        ctx.fill();
      }
      rafId = window.requestAnimationFrame(tick);
    }

    initParticles();
    tick();

    var resizeTimer = null;
    window.addEventListener('resize', function () {
      if (resizeTimer) clearTimeout(resizeTimer);
      resizeTimer = setTimeout(initParticles, 180);
    });

    document.addEventListener('visibilitychange', function () {
      if (document.hidden) {
        if (rafId) window.cancelAnimationFrame(rafId);
        rafId = null;
      } else if (!rafId) {
        tick();
      }
    });
  }

  /* --------------------------------------------------------
     Sugestoes: formulario ligado ao adaptador Firebase (REST, sem CDN)
     -------------------------------------------------------- */
  (function initSugestoes() {
    var form = $('#suggestion-form');
    if (!form) return;

    var status = $('#sugestao-status');
    var submit = $('#sugestao-enviar');
    var api = window.OCDM_FirebaseAPI;
    var connection = $('#connection-text');
    var note = $('#connection-note');

    function mensagem(texto, classe) {
      status.textContent = texto;
      status.className = 'form-status' + (classe ? ' ' + classe : '');
    }

    if (connection && note) {
      if (api && api.configurado()) {
        connection.textContent = 'Canal ativo: suas ideias serao enviadas ao Firebase.';
      } else {
        connection.textContent = 'Canal em preparacao: preencha js/firebase-config.js para ativar o envio.';
        note.classList.add('is-offline');
      }
    }

    form.addEventListener('submit', function (event) {
      event.preventDefault();
      if (!api) {
        mensagem('Modulo de envio nao carregado.', 'is-error');
        return;
      }
      var dados = {
        nome: $('#sugestao-nome') ? $('#sugestao-nome').value : '',
        categoria: $('#sugestao-categoria') ? $('#sugestao-categoria').value : 'ideia',
        titulo: $('#sugestao-titulo') ? $('#sugestao-titulo').value : '',
        mensagem: $('#sugestao-mensagem') ? $('#sugestao-mensagem').value : '',
      };
      var erro = api.validar(dados);
      if (erro) {
        mensagem(erro, 'is-error');
        return;
      }
      submit.disabled = true;
      mensagem('Enviando...');
      api.enviarSugestao(dados).then(function () {
        form.reset();
        mensagem('Sugestao enviada! Obrigado por ajudar o Tormentalia.', 'is-ok');
      }).catch(function (e) {
        mensagem(e && e.message ? e.message : 'Falha no envio.', 'is-error');
      }).then(function () {
        submit.disabled = false;
      });
    });
  })();
})();
