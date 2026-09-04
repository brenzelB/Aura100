/* ═══════════════════════════════════════════════════════════
   AURA QUEST — Landingpage

   Kein Framework, keine Abhaengigkeiten. Drei Aufgaben:
     1. Store-Verweise an einer Stelle pflegbar halten
     2. Einblenden beim Scrollen
     3. Die Sabotage-Demo — der einzige echte Effekt der Seite
   ═══════════════════════════════════════════════════════════ */

/* ── Hier spaeter die echten Store-Adressen eintragen ─────
   Sonst nichts aendern: Alle Knoepfe mit .js-store holen sich
   ihr Ziel von hier. */
const APP_STORE_URL   = '#';   // Apple App Store
const GOOGLE_PLAY_URL = '#';   // Google Play Store

(function wireStoreLinks() {
  const map = { ios: APP_STORE_URL, play: GOOGLE_PLAY_URL };
  document.querySelectorAll('.js-store').forEach((el) => {
    const url = map[el.dataset.store];
    if (!url || url === '#') {
      // Solange es keinen Link gibt, ist der Knopf kein Link.
      // Ein Verweis, der nirgendwohin fuehrt, ist schlechter als
      // einer, der sichtbar noch nicht bereit ist.
      el.setAttribute('aria-disabled', 'true');
      el.addEventListener('click', (e) => {
        if (el.getAttribute('href') === '#get') return; // Ankersprung erlauben
        e.preventDefault();
      });
      return;
    }
    el.href = url;
    el.rel = 'noopener';
    el.removeAttribute('aria-disabled');
  });
})();

/* ── Sprachwechsel ───────────────────────────────────────
   Der Verweis funktioniert schon ohne dieses Skript. Es haengt nur
   den aktuellen Abschnitt an: Wer auf der Sabotage steht und die
   Sprache wechselt, landet wieder dort statt ganz oben. Die
   Abschnitts-Kennungen sind in beiden Fassungen gleich. */
(function keepPlaceOnLanguageSwitch() {
  document.querySelectorAll('.js-lang').forEach((el) => {
    el.addEventListener('click', () => {
      const near = [...document.querySelectorAll('section[id]')]
        .filter((s) => s.getBoundingClientRect().top <= 120)
        .pop();
      if (near) el.href = el.getAttribute('href') + '#' + near.id;
    });
  });
})();

/* ── Einblenden beim Scrollen ───────────────────────────── */
(function reveal() {
  const items = document.querySelectorAll('.reveal');
  const reduce = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  if (reduce || !('IntersectionObserver' in window)) {
    items.forEach((el) => el.classList.add('is-in'));
    return;
  }

  const io = new IntersectionObserver((entries) => {
    entries.forEach((entry, i) => {
      if (!entry.isIntersecting) return;
      // Gestaffelt, aber knapp: mehr als ~60 ms Versatz wirkt
      // wie Verzoegerung statt wie Rhythmus.
      setTimeout(() => entry.target.classList.add('is-in'), i * 55);
      io.unobserve(entry.target);
    });
  }, { rootMargin: '0px 0px -12% 0px', threshold: 0.1 });

  items.forEach((el) => io.observe(el));
})();

/* ── Die Sabotage-Demo ──────────────────────────────────────
   Statt zu beschreiben, was ein Angriff anrichtet, richtet die
   Seite ihn am Besucher aus. Deshalb kostet jeder Klick auch
   echte Aura vom Zaehler - die Mechanik der App in klein.       */
(function sabotage() {
  const overlay = document.getElementById('overlay');
  const meter   = document.getElementById('auraValue');
  const buttons = document.querySelectorAll('.attack');
  if (!overlay || !meter || !buttons.length) return;

  const reduce = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  let aura = 1450;
  let busy = false;

  /* Die Texte richten sich nach der Sprache der Seite. Eine Uebersetzung
     im Skript zu halten ist hier vertretbar: Es sind acht Zeilen, und
     eine eigene Sprachdatei fuer acht Zeilen waere mehr Aufwand als
     Nutzen. Waechst das, gehoert es ausgelagert. */
  const EN = document.documentElement.lang === 'en';

  /* Die Sprueche stammen aus der Sammlung der App
     (lib/core/text/roasts_300.dart), die englisch ist. */
  const ROASTS = EN ? [
    'Your quest log is a collection of abandoned dreams.',
    'You wanted to change. The stats disagree.',
    'Impressive, how reliably unreliable you are.',
  ] : [
    'Dein Quest-Log ist eine Sammlung aufgegebener Träume.',
    'Du wolltest dich ändern. Die Statistik sagt etwas anderes.',
    'Beeindruckend, wie zuverlässig du unzuverlässig bist.',
  ];

  const T = EN ? {
    roastTitle: '🔥 ROASTED',
    roastFoot: 'Three seconds. No way to dismiss it.',
    heistWon: '💰 CLEAN LIFT',
    heistLost: '🛡 MISSED',
    heistWonText: 'The heist landed — the aura from their next check-in is yours.',
    heistLostText: '25 % odds are 25 % odds. The stake is gone, the loot is not.',
    blackTitle: '🌙 LOCKED OUT',
    blackText: 'This is what it looks like when a quest mate locks you out. Two hours, nothing you log counts.',
  } : {
    roastTitle: '🔥 GEROASTET',
    roastFoot: 'Drei Sekunden. Wegklicken geht nicht.',
    heistWon: '💰 BEUTE',
    heistLost: '🛡 DANEBEN',
    heistWonText: 'Der Raubzug hat geklappt — die Aura seines nächsten Check-ins gehört dir.',
    heistLostText: '25 % Chance sind 25 % Chance. Der Einsatz ist weg, die Beute nicht.',
    blackTitle: '🌙 AUSGESPERRT',
    blackText: 'So sieht es aus, wenn ein Mitspieler dich sperrt. Zwei Stunden lang kannst du nichts eintragen.',
  };

  function setAura(next) {
    aura = Math.max(0, next);
    meter.textContent = aura;
    // Was man sich nicht mehr leisten kann, wird abgeschaltet -
    // sonst verspricht die Seite etwas, das sie nicht einloest.
    buttons.forEach((b) => {
      b.disabled = Number(b.dataset.cost) > aura;
    });
  }

  function show(html, ms) {
    overlay.innerHTML = html;
    overlay.hidden = false;
    // Ein Frame warten, sonst ueberspringt der Browser den
    // Uebergang und der Kasten erscheint hart.
    requestAnimationFrame(() => overlay.classList.add('is-on'));
    setTimeout(() => {
      overlay.classList.remove('is-on');
      setTimeout(() => { overlay.hidden = true; busy = false; }, 220);
    }, reduce ? 900 : ms);
  }

  const attacks = {
    roast() {
      const line = ROASTS[Math.floor(Math.random() * ROASTS.length)];
      const q = EN ? ['“', '”'] : ['„', '“'];
      show(
        '<p class="overlay__title">' + T.roastTitle + '</p>' +
        '<p class="overlay__sub">' + q[0] + line + q[1] + '</p>' +
        '<p class="overlay__sub" style="margin-top:1rem;opacity:.6">' +
        T.roastFoot + '</p>',
        3000
      );
    },
    heist() {
      // Echte Wahrscheinlichkeit aus der App: 150 Aura = 25 %.
      const won = Math.random() < 0.25;
      show(
        '<p class="overlay__title">' + (won ? T.heistWon : T.heistLost) + '</p>' +
        '<p class="overlay__sub">' + (won ? T.heistWonText : T.heistLostText) + '</p>',
        2200
      );
    },
    blackout() {
      let left = 2 * 60 * 60;
      show(
        '<p class="overlay__title">' + T.blackTitle + '</p>' +
        '<p class="overlay__sub">' + T.blackText + '</p>' +
        '<p class="overlay__timer" id="boTimer">2:00:00</p>',
        4200
      );
      const el = document.getElementById('boTimer');
      const tick = setInterval(() => {
        left -= 1;
        if (!el || !el.isConnected) return clearInterval(tick);
        const h = Math.floor(left / 3600);
        const m = String(Math.floor((left % 3600) / 60)).padStart(2, '0');
        const s = String(left % 60).padStart(2, '0');
        el.textContent = h + ':' + m + ':' + s;
      }, 1000);
      setTimeout(() => clearInterval(tick), 5000);
    },
  };

  buttons.forEach((btn) => {
    btn.addEventListener('click', () => {
      if (busy || btn.disabled) return;
      busy = true;
      setAura(aura - Number(btn.dataset.cost));
      attacks[btn.dataset.attack]();
    });
  });

  setAura(aura);
})();
