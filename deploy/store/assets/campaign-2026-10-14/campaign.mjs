// A new, editable campaign layout. Original UI screenshots are embedded as
// unchanged images; typography and device frames are native HTML/CSS layers.
export const formats = {
  Google_Play: { width: 1080, height: 1920, device: 'android' },
  Apple_iPhone: { width: 1206, height: 2622, device: 'iphone' },
  Apple_iPad: { width: 2064, height: 2752, device: 'ipad' },
};

export const androidCards = [
  { id: '01_alltag', source: 'sources/android/home.png', layout: 'hero', bg: '#ffd8c5',
    de: { title: 'Weniger morgen.\nMehr machen.', subtitle: 'Mach aus deinen Gewohnheiten Quests.', label: 'DEIN ALLTAG. DEIN SPIEL.', alt: 'Aura Quest: tägliche Gewohnheiten, abgeschlossene Quests und Wochenrückblick auf der Startseite.' },
    en: { title: 'Less someday.\nMore today.', subtitle: 'Turn everyday habits into quests.', label: 'YOUR DAY. YOUR GAME.', alt: 'Aura Quest home screen with daily habits, completed quests and a weekly recap.' } },
  { id: '02_fortschritt', source: 'sources/android/progress.png', layout: 'straight', bg: '#efe8fb',
    de: { title: 'Kleine Schritte.\nSichtbar weiter.', subtitle: 'Ziele abhaken. Fortschritt sehen. Dranbleiben.', label: 'JEDER SCHRITT ZÄHLT.', alt: 'Quest-Details mit erreichtem Leseziel, Fortschrittsbalken, Streak und Gesamtfortschritt.' },
    en: { title: 'Small steps.\nReal progress.', subtitle: 'Check off goals. See progress. Keep going.', label: 'EVERY STEP COUNTS.', alt: 'Quest details showing a completed reading goal, progress bar, streak and total progress.' } },
  { id: '03_zusammen', source: 'sources/android/quests.png', layout: 'tilt', bg: '#c9eee4',
    de: { title: 'Allein geht.\nZusammen knallt.', subtitle: 'Gemeinsame Quests für dich und deine Freunde.', label: 'MOTIVATION TRIFFT CO-OP.', alt: 'Quest-Übersicht mit mehreren Gewohnheiten und einer kooperativen Lesequest.' },
    en: { title: 'Good solo.\nBetter together.', subtitle: 'Shared quests for you and your friends.', label: 'MOTIVATION MEETS CO-OP.', alt: 'Quest list with several habits and a cooperative reading quest.' } },
  { id: '04_deine_ziele', source: 'sources/android/create.png', layout: 'straight', bg: '#ffdf9e',
    de: { title: 'Deine Ziele.\nDeine Regeln.', subtitle: 'Abhaken, Fortschritt sammeln oder etwas lassen.', label: 'LESEN. TRAINIEREN. WENIGER SCROLLEN.', alt: 'Neue Quest erstellen: Zielarten Abhaken, Fortschritt und Vermeiden sowie Spielmodi und eigene Einheiten.' },
    en: { title: 'Your goals.\nYour rules.', subtitle: 'Check off, track progress or break a habit.', label: 'READ. TRAIN. SCROLL LESS.', alt: 'Quest creation with check-off, progress and avoid goals, game modes and custom units.' } },
  { id: '05_perks', source: 'sources/android/perks.png', layout: 'perk', bg: '#eadcff',
    de: { title: 'Aura sammeln.\nPerks zünden.', subtitle: 'Heists, Schutz und Roasts mit virtueller Aura.', label: 'DRANBLEIBEN DARF SPASS MACHEN.', alt: 'Quest Perks mit virtueller Aura: Aura Heist, Aura Ward und Targeted Roast.' },
    en: { title: 'Earn Aura.\nUnleash Perks.', subtitle: 'Heists, shields and roasts with virtual Aura.', label: 'MAKE CONSISTENCY MORE FUN.', alt: 'Quest Perks using virtual Aura: Aura Heist, Aura Ward and Targeted Roast.' } },
];

export const appleCards = [
  { id: '01_alltag', source: 'home_neo.png', layout: 'hero', bg: '#ffd8c5',
    de: { title: 'Weniger morgen.\nMehr machen.', subtitle: 'Lesen. Fokus. Training. Deine täglichen Quests.', label: 'DEIN ALLTAG. DEIN SPIEL.', alt: 'Aura Quest Home mit täglichen Quests zum Lesen, Fokussieren und gemeinsamen Training.' },
    en: { title: 'Less someday.\nMore today.', subtitle: 'Reading. Focus. Training. Your daily quests.', label: 'YOUR DAY. YOUR GAME.', alt: 'Aura Quest home with daily quests for reading, focus and shared training.' } },
  { id: '02_zusammen', source: 'quests_neo.png', layout: 'tilt', bg: '#c9eee4',
    de: { title: 'Allein geht.\nZusammen knallt.', subtitle: 'Gemeinsame Quests für dich und deine Freunde.', label: 'MOTIVATION TRIFFT CO-OP.', alt: 'Quest-Übersicht mit sichtbarem Lesefortschritt, Aura und einer Trainingsquest für vier Personen.' },
    en: { title: 'Good solo.\nBetter together.', subtitle: 'Shared quests for you and your friends.', label: 'MOTIVATION MEETS CO-OP.', alt: 'Quest list with reading progress, Aura and a cooperative training quest for four people.' } },
  { id: '03_fortschritt', source: 'quests_neo.png', layout: 'bottom', bg: '#f4e9dc',
    de: { title: 'Dein Fortschritt.\nIm Blick.', subtitle: 'Jede Einheit zählt. Dein Fortschritt bleibt sichtbar.', label: 'DEIN FORTSCHRITT. DEINE AURA.', alt: 'Neo-Brutalist-Questübersicht mit Lesefortschritt, Aura und kooperativer Trainingsquest.' },
    en: { title: 'Your progress.\nIn plain sight.', subtitle: 'Every session counts. Keep your progress in view.', label: 'YOUR PROGRESS. YOUR AURA.', alt: 'Neo-Brutalist quest list showing reading progress, Aura and a cooperative training quest.' } },
  { id: '04_checkins', source: 'home_neo.png', layout: 'night', bg: '#231b37', darkBackdrop: true,
    de: { title: 'Heute zählt.\nJeder Check-in.', subtitle: 'Lesen. Fokus. Training. Mach deinen Haken dran.', label: 'CHECK-INS STATT AUSREDEN.', alt: 'Neo-Brutalist-Startseite mit täglicher Lesequest, Fortschritt sowie Check-ins für Fokus und Training.' },
    en: { title: 'Today counts.\nEvery check-in.', subtitle: 'Reading. Focus. Training. Make it count.', label: 'MORE CHECK-INS. FEWER EXCUSES.', alt: 'Neo-Brutalist home showing a daily reading goal, progress and check-ins for focus and training.' } },
];

const escape = value => String(value).replace(/[&<>"']/g, x => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[x]);

export function cardsFor(platform) {
  if (platform === 'Google_Play') return androidCards;
  const prefix = platform === 'Apple_iPad' ? 'ipad' : 'iphone';
  return appleCards.map(card => ({ ...card, source: `sources/${prefix}/${card.source}` }));
}

export function campaignHtml(platform, language, index, base = './') {
  const format = formats[platform];
  const cards = cardsFor(platform);
  const card = cards[index];
  const copy = card[language];
  const h = format.height / format.width * 1080;
  const isPad = format.device === 'ipad';
  const isPhone = format.device === 'iphone';
  const bottomTitle = card.id === '02_fortschritt' || card.layout === 'bottom';
  const phoneWidth = isPad ? 680 : isPhone ? 765 : 625;
  const screenRatio = isPad ? 2752 / 2064 : isPhone ? 2622 / 1206 : 2856 / 1280;
  const frameInset = isPad ? 48 : 40;
  const deviceHeight = (phoneWidth - frameInset) * screenRatio + frameInset;
  const headerTop = bottomTitle ? h - (isPad ? 338 : 400) : isPad ? 122 : 146;
  const titleSize = bottomTitle ? (isPad ? 74 : isPhone ? 96 : 89) : isPad ? 91 : 96;
  const deviceTop = bottomTitle ? (isPad ? 140 : isPhone ? 168 : 135) : isPad ? 400 : isPhone ? 574 : 485;
  const rotation = { hero: -8, straight: 0, tilt: 7, perk: -6, bottom: -7, night: 7 }[card.layout];
  const phoneLeft = (1080 - phoneWidth) / 2 + (card.layout === 'hero' ? 28 : card.layout === 'tilt' ? -10 : 0);
  const title = copy.title.split('\n').map(escape).join('<br>');
  return `<!doctype html><html lang="${language}"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Aura Quest — ${escape(copy.title.replace('\n', ' '))}</title>
  <style>
  @font-face{font-family:Editorial;src:url('${base}sources/fonts/DMSerifDisplay-Regular.ttf')}@font-face{font-family:Inter;src:url('${base}sources/fonts/Inter-Regular.ttf');font-weight:400}@font-face{font-family:Inter;src:url('${base}sources/fonts/Inter-Bold.ttf');font-weight:700}@font-face{font-family:Inter;src:url('${base}sources/fonts/Inter-Black.ttf');font-weight:900}
  *{box-sizing:border-box}html,body{margin:0;width:${format.width}px;height:${format.height}px;overflow:hidden;background:${card.bg}}
  .stage{position:relative;width:1080px;height:${h}px;transform:scale(${format.width / 1080});transform-origin:0 0;background:${card.bg};color:${card.darkBackdrop ? '#f9f0df' : '#211d2c'};overflow:hidden}
  .brand{position:absolute;left:65px;top:48px;display:flex;align-items:center;gap:13px;font:900 30px Inter;letter-spacing:-1px;z-index:5}.brand img{width:55px;height:55px;border-radius:14px;border:2px solid #211d2c}.edition{position:absolute;right:67px;top:65px;font:700 17px Inter;letter-spacing:2px;opacity:.72}
  .headline{position:absolute;left:56px;right:56px;top:${headerTop}px;z-index:5;text-align:center}.headline h1{margin:0;font:400 ${titleSize}px/.99 Editorial;letter-spacing:-3px}.headline p{font:400 ${isPad ? 26 : 28}px/1.4 Inter;margin:25px auto 0;max-width:890px;letter-spacing:-.5px}
  .backdrop{position:absolute;width:${isPad ? 900 : 1010}px;height:${isPad ? 900 : 1010}px;border-radius:50%;background:${card.darkBackdrop ? '#382845' : card.layout === 'perk' ? '#d2bde8' : '#f8b899'};left:${isPad ? 60 : -45}px;top:${isPad ? 430 : deviceTop + 300}px;opacity:${card.layout === 'bottom' ? '.4' : '.55'}}
  .device{position:absolute;left:${phoneLeft}px;top:${deviceTop}px;width:${phoneWidth}px;height:${deviceHeight}px;padding:${isPad ? 22 : 18}px;background:linear-gradient(112deg,#707070 0%,#171717 12%,#080808 55%,#454545 99%);border:2px solid #5e5e5e;border-radius:${isPad ? 40 : 74}px;transform:rotate(${rotation}deg);box-shadow:23px 40px 53px #31212548,4px 6px 0 #171717;z-index:2}
  .screen{height:100%;width:100%;border-radius:${isPad ? 20 : 55}px;overflow:hidden;background:#f5f0df;position:relative}.screen img{position:absolute;display:block;width:100%;height:auto;left:0;top:0}.android .screen img{width:calc(100% + 4px);left:-2px;top:-2px}
  .device:before,.device:after{content:'';position:absolute;left:-6px;width:5px;background:#303030;border-radius:2px}.device:before{height:54px;top:165px}.device:after{height:87px;top:244px}.ipad.device:before,.ipad.device:after{display:none}
  .accent{position:absolute;left:${isPad ? 26 : 10}px;top:${isPad ? 570 : h - 870}px;width:${isPad ? 68 : 83}px;height:${isPad ? 68 : 83}px;border:4px solid ${card.darkBackdrop ? '#d9ef91' : '#211d2c'};border-radius:50%;z-index:1}.accent:after{content:'+';display:block;text-align:center;font:400 63px/.98 Inter;color:${card.darkBackdrop ? '#d9ef91' : '#211d2c'}}
  .rule{position:absolute;bottom:109px;left:66px;right:66px;border-top:2px solid ${card.darkBackdrop ? '#b99ccd' : '#211d2c'};opacity:.35;z-index:4}.footer{position:absolute;left:66px;right:66px;bottom:64px;z-index:5;display:flex;justify-content:space-between;align-items:center;font:700 ${isPad ? 17 : 18}px Inter;letter-spacing:1.7px}.footer span:last-child{letter-spacing:0;font-weight:900}
  </style></head><body><main class="stage" aria-label="${escape(copy.alt)}"><div class="brand"><img src="${base}sources/icon.png" alt="">AURA QUEST</div><div class="edition">THE QUEST EDIT</div><header class="headline"><h1>${title}</h1><p>${escape(copy.subtitle)}</p></header><div class="backdrop"></div><div class="accent"></div><div class="device ${format.device}" aria-label="${escape(copy.alt)}"><div class="screen"><img src="${base}${card.source}" alt="${escape(copy.alt)}"></div></div><div class="rule"></div><footer class="footer"><span>${escape(copy.label)}</span><span>${String(index + 1).padStart(2, '0')} / ${String(cards.length).padStart(2, '0')}</span></footer></main></body></html>`;
}

export function featureHtml(language, base = './') {
  const de = language === 'de';
  return `<!doctype html><html lang="${language}"><head><meta charset="utf-8"><title>Aura Quest Feature Graphic</title><style>
  @font-face{font-family:Editorial;src:url('${base}sources/fonts/DMSerifDisplay-Regular.ttf')}@font-face{font-family:Inter;src:url('${base}sources/fonts/Inter-Regular.ttf');font-weight:400}@font-face{font-family:Inter;src:url('${base}sources/fonts/Inter-Black.ttf');font-weight:900}*{box-sizing:border-box}html,body{margin:0;width:1024px;height:500px;overflow:hidden;background:#ffd8c5;color:#211d2c}.brand{position:absolute;left:59px;top:51px;display:flex;align-items:center;gap:12px;font:900 24px Inter;letter-spacing:-1px}.brand img{width:45px;border-radius:10px;border:2px solid #211d2c}h1{position:absolute;left:58px;top:114px;font:400 67px/.98 Editorial;letter-spacing:-2px;margin:0;z-index:3}p{position:absolute;left:60px;top:280px;font:400 21px/1.45 Inter;max-width:500px;margin:0;z-index:3}.circle{position:absolute;left:650px;top:80px;width:310px;height:310px;border-radius:50%;background:#f9bc97}.mark{position:absolute;right:65px;top:112px;width:250px;height:250px;border-radius:42px;border:3px solid #211d2c;transform:rotate(-8deg)}footer{position:absolute;bottom:55px;left:60px;font:900 13px Inter;letter-spacing:2px}.line{position:absolute;left:60px;right:60px;bottom:95px;border-top:1px solid #211d2c55}</style></head><body><div class="brand"><img src="${base}sources/icon.png" alt="">AURA QUEST</div><h1>${de ? 'Weniger morgen.<br>Mehr machen.' : 'Less someday.<br>More today.'}</h1><p>${de ? 'Gewohnheiten werden Quests.<br>Mit Freunden, Fortschritt und einer Portion Chaos.' : 'Turn habits into quests.<br>With friends, progress and a little chaos.'}</p><div class="circle"></div><img class="mark" src="${base}sources/icon.png" alt="Aura Quest"><div class="line"></div><footer>${de ? 'DEIN ALLTAG. DEIN SPIEL.' : 'YOUR DAY. YOUR GAME.'}</footer></body></html>`;
}
