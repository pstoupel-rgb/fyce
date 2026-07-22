// face-api est chargé dynamiquement (voir init) : si le CDN échoue, l'app reste
// utilisable, seule la reconnaissance est désactivée.
const FACEAPI_ESM = 'https://cdn.jsdelivr.net/npm/@vladmandic/face-api/dist/face-api.esm.js';
const MODEL_URL = 'https://cdn.jsdelivr.net/npm/@vladmandic/face-api/model';
let faceapi = null;

// ---- Économie « troc » : on ne paie pas, on contribue pour développer ----
const WELCOME_POINTS = 1;     // révélation offerte à l'arrivée
const UNLOCK_COST = 1;        // développer un négatif = 1 révélation
const SHARE_REWARD = 2;       // contribuer (partager / inviter) = +2
const EARN_ON_DOWNLOAD = 1;   // quelqu'un développe une photo de toi = +1

// ---- Events de démo ----
const EVENTS = [
  { id:'duplex', name:'Le Duplex', place:'Paris · Club', when:'Samedi dernier', emoji:'🪩', grad:'linear-gradient(135deg,#5b78ef,#9d5cff)' },
  { id:'sunset', name:'Sunset Festival', place:'Marseille · Plage', when:'Il y a 2 semaines', emoji:'🎪', grad:'linear-gradient(135deg,#ff7a59,#ff4d94)' },
  { id:'colorrun', name:'Color Run', place:'Lyon · Parc', when:'Le mois dernier', emoji:'🏃', grad:'linear-gradient(135deg,#12a074,#3ec6ff)' },
];

// ---- Persistance locale ----
const KEY = 'pp_v1';
const store = {
  data: { face:null, faceThumb:null, points:0, unlocked:[], history:[], threshold:0.55, started:false, friends:[] },
  load(){ try{ Object.assign(this.data, JSON.parse(localStorage.getItem(KEY)||'{}')); }catch(_){} },
  save(){ localStorage.setItem(KEY, JSON.stringify(this.data)); },
};

// ---- État de session ----
const state = {
  refDescriptor:null,   // Float32Array
  modelsReady:false,
  currentEvent:null,
  matches:[],           // { id, file, url, thumb, distance }
  urls:[],              // objectURLs à révoquer
  friendMatches:[],     // { id, file, url, thumb, who:[noms] }
  friendUrls:[],
};

const FRIEND_COLORS = ['#ff4d94','#5b78ef','#f7b733','#0ba360','#9d5cff','#ff7a59','#3ec6ff'];
const escapeHtml = s => String(s).replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));

const cfg = window.SUPABASE_CONFIG || {};
const supabaseReady = !!(cfg.url && cfg.anonKey && !String(cfg.url).includes('YOUR-') && !String(cfg.anonKey).includes('YOUR-'));

const $ = s => document.querySelector(s);
const el = {};
['modelBanner','walletPill','pointsBal',
 'refInput','refAvatar','refBtn','refStatus','meAvatar',
 'eventList','evTitle','evMeta','photosInput','loadBtn','evProgress','evBar','evProgressTxt','evEmpty','matchHead','matchCount','recapBtn','grid',
 'unlockSheet','unlockImg','unlockTitle','unlockDesc','unlockConfirm','unlockDownload','unlockClose',
 'walletSheet','walletBal','contribBtn','simEarn','history','walletClose',
 'recapSheet','recapTitle','recapGrid','recapShare','recapClose',
 'menuBtn','menuSheet','threshold','threshVal','sbStatus','wipeBtn','menuClose','toast',
 'friendsCard','friendsRow','friendPhotoInput','importFriendsBtn','friendsPhotosInput',
 'fProgress','fBar','fProgressTxt','fEmpty','fHead','fCount','friendsGrid',
 'shareSheet','shImg','shWho','shBtns','shClose'
].forEach(id => el[id] = document.getElementById(id));

// ---------- Navigation ----------
function showScreen(name){
  document.querySelectorAll('[data-screen]').forEach(s => s.hidden = s.dataset.screen !== name);
}
document.querySelectorAll('[data-nav]').forEach(b => b.addEventListener('click', () => showScreen(b.dataset.nav)));

const open = s => el[s].hidden = false;
const close = s => el[s].hidden = true;

// ---------- Toast ----------
let toastT;
function toast(msg){
  el.toast.textContent = msg; el.toast.hidden = false;
  clearTimeout(toastT); toastT = window.setTimeout(() => el.toast.hidden = true, 2300);
}

// ---------- Init ----------
async function init(){
  registerSW();
  store.load();
  el.threshold.value = store.data.threshold;
  el.threshVal.textContent = (+store.data.threshold).toFixed(2);
  renderPoints();
  renderEvents();
  updateSupabaseStatus();
  wire();

  if (store.data.face){
    state.refDescriptor = new Float32Array(store.data.face);
    if (store.data.faceThumb){
      el.meAvatar.style.backgroundImage = `url(${store.data.faceThumb})`;
      el.refAvatar.style.backgroundImage = `url(${store.data.faceThumb})`;
      el.refAvatar.classList.add('ok');
    }
    el.walletPill.hidden = false;
    showScreen('home');
  } else {
    showScreen('onboarding');
  }

  // Chargement de la reconnaissance en tâche de fond (ne bloque pas l'UI).
  try {
    faceapi = await import(FACEAPI_ESM);
    await Promise.all([
      faceapi.nets.ssdMobilenetv1.loadFromUri(MODEL_URL),
      faceapi.nets.faceLandmark68Net.loadFromUri(MODEL_URL),
      faceapi.nets.faceRecognitionNet.loadFromUri(MODEL_URL),
    ]);
    state.modelsReady = true;
    el.modelBanner.hidden = true;
    el.refBtn.setAttribute('aria-disabled','false');
    if (!store.data.face) el.refStatus.textContent = 'Prêt. Scanne ton visage pour commencer.';
  } catch(_){
    el.modelBanner.textContent = 'Reconnaissance indisponible (vérifie ta connexion).';
    el.modelBanner.classList.add('err');
  }
}

function wire(){
  el.refInput.addEventListener('change', e => onReference(e.target.files[0]));
  el.photosInput.addEventListener('change', e => onPhotos([...e.target.files]));
  el.walletPill.addEventListener('click', openWallet);
  el.walletClose.addEventListener('click', () => close('walletSheet'));
  el.menuBtn.addEventListener('click', () => open('menuSheet'));
  el.menuClose.addEventListener('click', () => close('menuSheet'));
  el.recapBtn.addEventListener('click', openRecap);
  el.recapClose.addEventListener('click', () => close('recapSheet'));
  el.recapShare.addEventListener('click', shareRecap);
  el.unlockClose.addEventListener('click', () => close('unlockSheet'));
  el.contribBtn.addEventListener('click', () => addPoints(SHARE_REWARD, 'Contribution : partage de l’event'));
  el.simEarn.addEventListener('click', () => addPoints(EARN_ON_DOWNLOAD, 'Quelqu’un a développé ta photo'));
  el.wipeBtn.addEventListener('click', wipe);
  el.friendsCard.addEventListener('click', () => { renderFriendsRow(); showScreen('friends'); });
  el.friendPhotoInput.addEventListener('change', e => addFriend(e.target.files[0]));
  el.friendsPhotosInput.addEventListener('change', e => onFriendPhotos([...e.target.files]));
  el.shClose.addEventListener('click', () => el.shareSheet.hidden = true);
  el.threshold.addEventListener('input', e => {
    store.data.threshold = +e.target.value; store.save();
    el.threshVal.textContent = (+e.target.value).toFixed(2);
  });
  document.querySelectorAll('.pack').forEach(p =>
    p.addEventListener('click', () => buyPack(+p.dataset.pack, p.dataset.price)));
}

// ---------- Visage de référence ----------
async function onReference(file){
  if (!file) return;
  if (!state.modelsReady){ toast('Reconnaissance en cours de chargement…'); return; }
  el.refStatus.textContent = 'Analyse du visage…';
  const img = await loadImage(file);
  const thumb = toCanvas(img, 240).toDataURL('image/jpeg', 0.8);

  const det = await faceapi.detectSingleFace(toCanvas(img, 512)).withFaceLandmarks().withFaceDescriptor();
  URL.revokeObjectURL(img.src);
  if (!det){ el.refStatus.textContent = 'Aucun visage détecté. Essaie une autre photo.'; return; }

  state.refDescriptor = det.descriptor;
  store.data.face = Array.from(det.descriptor);
  store.data.faceThumb = thumb;
  if (!store.data.started){ store.data.started = true; store.data.points = WELCOME_POINTS; store.data.history.unshift({t:'Bienvenue 🎉', n:WELCOME_POINTS}); }
  store.save();

  el.refAvatar.style.backgroundImage = `url(${thumb})`;
  el.refAvatar.classList.add('ok');
  el.meAvatar.style.backgroundImage = `url(${thumb})`;
  el.walletPill.hidden = false;
  renderPoints();
  toast(`Visage enregistré · +${WELCOME_POINTS} révélation offerte`);
  window.setTimeout(() => showScreen('home'), 700);
}

// ---------- Events ----------
function renderEvents(){
  el.eventList.innerHTML = EVENTS.map(ev => `
    <button class="event-card" data-ev="${ev.id}" style="background:${ev.grad}">
      <span class="ev-badge">${ev.emoji} Ouvrir</span>
      <span class="ev-when">${ev.when}</span>
      <span class="ev-name">${ev.name}</span>
      <span class="ev-place">${ev.place}</span>
    </button>`).join('');
  el.eventList.querySelectorAll('.event-card').forEach(c =>
    c.addEventListener('click', () => openEvent(c.dataset.ev)));
}

function openEvent(id){
  state.currentEvent = EVENTS.find(e => e.id === id);
  clearMatches();
  el.evTitle.textContent = state.currentEvent.name;
  el.evMeta.textContent = `${state.currentEvent.place} · ${state.currentEvent.when}`;
  el.evEmpty.hidden = true;
  el.matchHead.hidden = true;
  el.grid.innerHTML = '';
  showScreen('event');
}

// ---------- Scan des photos de l'event ----------
async function onPhotos(files){
  if (!state.refDescriptor){ toast('Scanne d’abord ton visage.'); return; }
  if (!state.modelsReady){ toast('Reconnaissance en cours de chargement…'); return; }
  if (!files.length) return;

  clearMatches();
  el.grid.innerHTML=''; el.evEmpty.hidden = true; el.matchHead.hidden = true;
  el.evProgress.hidden = false;

  const th = +store.data.threshold;
  for (let i=0;i<files.length;i++){
    setProgress(i+1, files.length);
    try{
      const m = await analyze(files[i], th);
      if (m){ state.matches.push(m); renderGrid(); }
    }catch(_){}
    await raf();
  }
  el.evProgress.hidden = true;

  if (!state.matches.length){ el.evEmpty.hidden = false; }
  else {
    el.matchHead.hidden = false;
    el.matchCount.textContent = `${state.matches.length} photo(s) où tu es`;
  }
}

async function analyze(file, threshold){
  const img = await loadImage(file);
  const canvas = toCanvas(img, 640);
  const results = await faceapi.detectAllFaces(canvas).withFaceLandmarks().withFaceDescriptors();
  if (!results.length){ URL.revokeObjectURL(img.src); return null; }
  let best = Infinity;
  for (const r of results){ const d = faceapi.euclideanDistance(state.refDescriptor, r.descriptor); if (d<best) best=d; }
  if (best > threshold){ URL.revokeObjectURL(img.src); return null; }

  const thumb = toCanvas(img, 300).toDataURL('image/jpeg', 0.72);
  const url = img.src; state.urls.push(url);
  return { id:`${file.name}-${file.size}-${file.lastModified}`, file, url, thumb, distance:best };
}

function clearMatches(){ state.urls.forEach(u=>URL.revokeObjectURL(u)); state.urls=[]; state.matches=[]; }

// ---------- Grille (flou / déblocage) ----------
function isUnlocked(id){ return store.data.unlocked.includes(id); }

function renderGrid(){
  el.grid.innerHTML = state.matches.map(m => {
    const unlocked = isUnlocked(m.id);
    return `<div class="tile ${unlocked?'':'locked'}" data-id="${m.id}">
      <img src="${m.thumb}" alt="">
      ${unlocked
        ? '<span class="done">✓</span>'
        : `<div class="lock"><span class="ic">🎞️</span><span class="cost">Développer</span></div>`}
    </div>`;
  }).join('');
  el.grid.querySelectorAll('.tile').forEach(t => t.addEventListener('click', () => openUnlock(t.dataset.id)));
}

function openUnlock(id){
  const m = state.matches.find(x => x.id === id); if (!m) return;
  el.unlockImg.src = m.url;
  const unlocked = isUnlocked(id);
  el.unlockTitle.textContent = unlocked ? 'Photo développée' : 'Développer la photo';
  el.unlockDesc.textContent = unlocked ? 'Elle est à toi — télécharge-la en pleine qualité.' : `Développer coûte ${UNLOCK_COST} révélation. Tu en as ${store.data.points}.`;
  el.unlockConfirm.hidden = unlocked;
  el.unlockConfirm.textContent = `🎞️ Développer (${UNLOCK_COST} révélation)`;
  el.unlockDownload.hidden = !unlocked;
  el.unlockConfirm.onclick = () => doUnlock(m);
  el.unlockDownload.onclick = () => download(m);
  open('unlockSheet');
}

function doUnlock(m){
  if (store.data.points < UNLOCK_COST){
    toast('Plus de révélation — contribue ou prends le raccourci.');
    close('unlockSheet'); openWallet(); return;
  }
  store.data.points -= UNLOCK_COST;
  store.data.unlocked.push(m.id);
  store.data.history.unshift({ t:`Développement`, n:-UNLOCK_COST });
  store.save(); renderPoints(); renderGrid();
  openUnlock(m.id); // rebascule en mode "télécharger"
  toast('Développée ! 🎉');
}

function download(m){
  const a = document.createElement('a');
  a.href = m.url; a.download = m.file.name || 'photo.jpg';
  document.body.appendChild(a); a.click(); a.remove();
}

// ---------- Portefeuille ----------
function renderPoints(){
  el.pointsBal.textContent = store.data.points;
  el.walletBal.textContent = store.data.points;
}
function addPoints(n, label){
  store.data.points += n;
  store.data.history.unshift({ t:label, n });
  store.save(); renderPoints(); renderHistory();
  toast(`+${n} révélation(s)`);
}
function buyPack(pts, price){
  store.data.points += pts;
  store.data.history.unshift({ t:`Raccourci (${price})`, n:pts });
  store.save(); renderPoints(); renderHistory();
  toast(`+${pts} révélations (démo)`);
}
function openWallet(){ renderHistory(); open('walletSheet'); }
function renderHistory(){
  const h = store.data.history.slice(0, 12);
  el.history.innerHTML = h.length
    ? h.map(x => `<li><span>${x.t}</span><span class="amt ${x.n>=0?'plus':'minus'}">${x.n>=0?'+':''}${x.n}</span></li>`).join('')
    : '<li class="empty">Aucune activité pour l’instant.</li>';
}

// ---------- Récap ----------
function openRecap(){
  const shots = state.matches.filter(m => isUnlocked(m.id));
  const pool = shots.length ? shots : state.matches;
  el.recapTitle.textContent = state.currentEvent ? state.currentEvent.name : 'Ta soirée';
  el.recapGrid.innerHTML = pool.slice(0,9)
    .map(m => `<img src="${m.thumb}" style="${isUnlocked(m.id)?'':'filter:blur(6px)'}">`).join('');
  open('recapSheet');
}
async function shareRecap(){
  const text = `J'étais à ${state.currentEvent?.name||'la soirée'} 📸 — retrouve tes photos sur Poze`;
  try{
    if (navigator.share){ await navigator.share({ title:'Poze', text }); }
    else { await navigator.clipboard?.writeText(text); toast('Texte de partage copié'); }
    addPoints(SHARE_REWARD, 'Partage du récap');
  }catch(_){}
}

// ---------- Vie privée ----------
function wipe(){
  if (!confirm('Supprimer ton empreinte de visage et toutes tes données locales ?')) return;
  localStorage.removeItem(KEY);
  store.data = { face:null, faceThumb:null, points:0, unlocked:[], history:[], threshold:0.55, started:false, friends:[] };
  state.refDescriptor = null; clearMatches(); clearFriendMatches();
  el.friendsGrid.innerHTML = ''; el.fHead.hidden = true;
  el.refAvatar.classList.remove('ok'); el.refAvatar.style.backgroundImage='';
  el.meAvatar.style.backgroundImage=''; el.walletPill.hidden = true;
  close('menuSheet'); renderPoints();
  el.refStatus.textContent = 'Tout est supprimé. Tu peux repartir de zéro.';
  showScreen('onboarding');
  toast('Données supprimées');
}

function updateSupabaseStatus(){
  el.sbStatus.textContent = supabaseReady ? 'Configuré ✓' : 'Non configuré';
}

// ---------- Entre potes ----------
function knownPeople(){
  const list = [];
  if (state.refDescriptor) list.push({ name:'Toi', desc: state.refDescriptor });
  for (const f of store.data.friends) list.push({ name:f.name, desc:new Float32Array(f.descriptor) });
  return list;
}

function personAvatar(name){
  if (name === 'Toi') return { thumb: store.data.faceThumb, color:'#12a074' };
  const f = store.data.friends.find(x => x.name === name);
  return { thumb: f && f.thumb, color: (f && f.color) || '#5b78ef' };
}

function personChip(name){
  const a = personAvatar(name);
  return a.thumb
    ? `<span class="m" style="background-image:url(${a.thumb})"></span>`
    : `<span class="m" style="background:${a.color}">${escapeHtml(name[0])}</span>`;
}

function renderFriendsRow(){
  const you = `<div class="fr"><div class="av" style="${store.data.faceThumb ? `background-image:url(${store.data.faceThumb})` : 'background:#12a074'}">${store.data.faceThumb ? '' : 'T'}</div><div class="nm">Toi</div></div>`;
  const fr = store.data.friends.map(f =>
    `<div class="fr"><div class="av" style="background-image:url(${f.thumb})"></div><div class="nm">${escapeHtml(f.name)}</div></div>`).join('');
  const add = `<div class="fr" id="addFriend"><div class="av add">＋</div><div class="nm">Ajouter</div></div>`;
  el.friendsRow.innerHTML = you + fr + add;
  document.getElementById('addFriend').addEventListener('click', () => el.friendPhotoInput.click());
}

async function addFriend(file){
  if (!file) return;
  if (!state.modelsReady){ toast('Reconnaissance en cours de chargement…'); return; }
  const img = await loadImage(file);
  const thumb = toCanvas(img, 160).toDataURL('image/jpeg', 0.8);
  const det = await faceapi.detectSingleFace(toCanvas(img, 512)).withFaceLandmarks().withFaceDescriptor();
  URL.revokeObjectURL(img.src);
  if (!det){ toast('Aucun visage détecté sur cette photo.'); return; }
  const name = (prompt('Prénom de ton pote ?') || '').trim() || `Pote ${store.data.friends.length + 1}`;
  const color = FRIEND_COLORS[store.data.friends.length % FRIEND_COLORS.length];
  store.data.friends.push({ id:'f' + store.data.friends.length + '-' + name, name, descriptor:Array.from(det.descriptor), thumb, color });
  store.save();
  renderFriendsRow();
  toast(`${name} ajouté 👌`);
}

function clearFriendMatches(){ state.friendUrls.forEach(u => URL.revokeObjectURL(u)); state.friendUrls = []; state.friendMatches = []; }

async function onFriendPhotos(files){
  if (!state.refDescriptor){ toast('Scanne d’abord ton visage.'); return; }
  if (!state.modelsReady){ toast('Reconnaissance en cours de chargement…'); return; }
  if (!files.length) return;

  clearFriendMatches();
  el.friendsGrid.innerHTML = ''; el.fEmpty.hidden = true; el.fHead.hidden = true; el.fProgress.hidden = false;
  const people = knownPeople();
  const th = +store.data.threshold;

  for (let i = 0; i < files.length; i++){
    el.fBar.style.width = `${(i + 1) / files.length * 100}%`;
    el.fProgressTxt.textContent = `Analyse ${i + 1}/${files.length} — ${state.friendMatches.length} trouvée(s)`;
    try {
      const m = await analyzeFriends(files[i], people, th);
      if (m){ state.friendMatches.push(m); renderFriendsGrid(); }
    } catch (_) {}
    await raf();
  }
  el.fProgress.hidden = true;
  if (!state.friendMatches.length){ el.fEmpty.hidden = false; }
  else { el.fHead.hidden = false; el.fCount.textContent = `${state.friendMatches.length} photo(s) de vous`; }
}

async function analyzeFriends(file, people, threshold){
  const img = await loadImage(file);
  const canvas = toCanvas(img, 640);
  const results = await faceapi.detectAllFaces(canvas).withFaceLandmarks().withFaceDescriptors();
  if (!results.length){ URL.revokeObjectURL(img.src); return null; }

  const present = new Set();
  for (const r of results){
    let best = Infinity, bestName = null;
    for (const p of people){
      const d = faceapi.euclideanDistance(p.desc, r.descriptor);
      if (d < best){ best = d; bestName = p.name; }
    }
    if (best <= threshold && bestName) present.add(bestName);
  }
  // On garde les photos où TOI es présent (photos de toi & tes amis).
  if (!present.has('Toi')){ URL.revokeObjectURL(img.src); return null; }

  const thumb = toCanvas(img, 300).toDataURL('image/jpeg', 0.72);
  const url = img.src; state.friendUrls.push(url);
  return { id:`${file.name}-${file.size}-${file.lastModified}`, file, url, thumb, who:[...present] };
}

function renderFriendsGrid(){
  el.friendsGrid.innerHTML = state.friendMatches.map(m =>
    `<div class="tile" data-id="${m.id}"><img src="${m.thumb}" alt=""><div class="whos">${m.who.map(personChip).join('')}</div></div>`).join('');
  el.friendsGrid.querySelectorAll('.tile').forEach(t => t.addEventListener('click', () => openShareFriend(t.dataset.id)));
}

function openShareFriend(id){
  const m = state.friendMatches.find(x => x.id === id); if (!m) return;
  el.shImg.src = m.url;
  el.shWho.textContent = `Sur cette photo : ${m.who.join(', ')}`;
  const others = m.who.filter(w => w !== 'Toi');
  let html = '';
  if (others.length){
    html = others.map(o => `<button class="btn btn-primary" data-who="${escapeHtml(o)}">📤 Partager à ${escapeHtml(o)}</button>`).join('');
    if (others.length > 1) html += `<button class="btn btn-bordered" data-who="__group">👥 Partager au groupe</button>`;
  } else {
    html = `<button class="btn btn-primary" data-who="__self">📤 Partager la photo</button>`;
  }
  el.shBtns.innerHTML = html;
  el.shBtns.querySelectorAll('button').forEach(b => b.addEventListener('click', () => sharePhoto(m, b.dataset.who)));
  el.shareSheet.hidden = false;
}

async function sharePhoto(m, who){
  const hint = (who && who !== '__group' && who !== '__self') ? `Une photo de nous, ${who} 📸` : 'Une photo de nous 📸';
  try {
    if (navigator.canShare && navigator.canShare({ files:[m.file] })){
      await navigator.share({ files:[m.file], title:'Poze', text: hint });
    } else {
      const a = document.createElement('a'); a.href = m.url; a.download = m.file.name || 'photo.jpg';
      document.body.appendChild(a); a.click(); a.remove();
      toast('Partage non supporté — photo téléchargée.');
    }
  } catch (_) {}
  el.shareSheet.hidden = true;
}

// ---------- Utils ----------
function loadImage(file){
  return new Promise((res, rej) => { const i=new Image(); i.onload=()=>res(i); i.onerror=rej; i.src=URL.createObjectURL(file); });
}
function toCanvas(img, maxSide){
  const s = Math.min(1, maxSide/Math.max(img.width, img.height));
  const c = document.createElement('canvas');
  c.width = Math.round(img.width*s); c.height = Math.round(img.height*s);
  c.getContext('2d').drawImage(img, 0, 0, c.width, c.height);
  return c;
}
function setProgress(done, total){
  el.evBar.style.width = `${done/total*100}%`;
  el.evProgressTxt.textContent = `Analyse ${done}/${total} — ${state.matches.length} trouvée(s)`;
}
const raf = () => new Promise(r => requestAnimationFrame(() => r()));
function registerSW(){ if ('serviceWorker' in navigator) navigator.serviceWorker.register('./service-worker.js').catch(()=>{}); }

// Exposé pour tests/déboguage
window.__pp = { store, state, showScreen, renderGrid, renderPoints, openUnlock, renderFriendsRow, renderFriendsGrid, openShareFriend };

init();
