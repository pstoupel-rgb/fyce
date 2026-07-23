// face-api est chargé dynamiquement (voir init) : si le CDN échoue, l'app reste
// utilisable, seule la reconnaissance est désactivée.
const FACEAPI_ESM = 'https://cdn.jsdelivr.net/npm/@vladmandic/face-api/dist/face-api.esm.js';
const MODEL_URL = 'https://cdn.jsdelivr.net/npm/@vladmandic/face-api/model';
let faceapi = null;

// ---- Économie « troc » : on ne paie pas, on contribue pour développer ----
const WELCOME_POINTS = 1;     // reveal offerte à l'arrivée
const UNLOCK_COST = 1;        // développer un négatif = 1 reveal
const SHARE_REWARD = 2;       // contribuer (partager / inviter) = +2
const EARN_ON_DOWNLOAD = 1;   // quelqu'un développe une photo de toi = +1

// ---- Events de démo ----
const EVENTS = [
  { id:'duplex', name:'Le Duplex', place:'Paris · Club', when:'Last Saturday', emoji:'🪩', dot:'#7c5cff' },
  { id:'sunset', name:'Sunset Festival', place:'Marseille · Beach', when:'2 weeks ago', emoji:'🎪', dot:'#ff5da2' },
  { id:'colorrun', name:'Color Run', place:'Lyon · Park', when:'Last month', emoji:'🏃', dot:'#22d3ee' },
];

// ---- Persistance locale ----
const KEY = 'pp_v1';
const store = {
  data: { face:null, faceThumb:null, points:0, unlocked:[], history:[], threshold:0.55, started:false, friends:[], refCode:'', invitedBy:null },
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
  selectMode:false,
  selected:new Set(),
  faceTarget:null,
  backend:false,        // passe à true si Supabase est configuré (voir maybeInitBackend)
  BE:null,
};

let eventsList = EVENTS.slice();   // events affichés : démo par défaut, backend si dispo

const FRIEND_COLORS = ['#ff4d94','#5b78ef','#f7b733','#0ba360','#9d5cff','#ff7a59','#3ec6ff'];
const INVITE_WELCOME = 5;   // bonus de bienvenue si tu arrives via un lien d'invitation
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
 'joinBtn',
 'friendsCard','friendsRow','friendPhotoInput','importFriendsBtn','friendsPhotosInput','manualShareBtn','manualInput',
 'fProgress','fBar','fProgressTxt','fEmpty','fHead','fCount','friendsGrid',
 'shareSheet','shImg','shWho','shBtns','shClose',
 'inviteBtn','inviteSheet','inviteLink','inviteWa','inviteMail','inviteShare','inviteClose',
 'fSelect','selShare',
 'faceSheet','facePhoto','faceActions','faceShareAll','faceClose'
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
  ensureRefCode();
  const ref = new URLSearchParams(location.search).get('ref');
  if (ref && !store.data.started && !store.data.invitedBy){ store.data.invitedBy = ref; store.save(); }
  el.threshold.value = store.data.threshold;
  el.threshVal.textContent = (+store.data.threshold).toFixed(2);
  renderPoints();
  renderEvents();
  updateSupabaseStatus();
  wire();
  maybeInitBackend();   // se branche sur Supabase si configuré (sinon : mode local)

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
    if (!store.data.face) el.refStatus.textContent = 'Ready. Scan your face to start.';
  } catch(_){
    el.modelBanner.textContent = 'Recognition unavailable (check your connection).';
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
  el.recapShare.addEventListener('click', shareStory);
  el.unlockClose.addEventListener('click', () => close('unlockSheet'));
  el.contribBtn.addEventListener('click', () => addPoints(SHARE_REWARD, 'Contribution: shared the event'));
  el.simEarn.addEventListener('click', () => addPoints(EARN_ON_DOWNLOAD, 'Someone developed your photo'));
  el.wipeBtn.addEventListener('click', wipe);
  el.joinBtn.addEventListener('click', joinEventFlow);
  el.friendsCard.addEventListener('click', () => { renderFriendsRow(); showScreen('friends'); });
  el.friendPhotoInput.addEventListener('change', e => addFriend(e.target.files[0]));
  el.friendsPhotosInput.addEventListener('change', e => onFriendPhotos([...e.target.files]));
  el.manualInput.addEventListener('change', e => onManualPhotos([...e.target.files]));
  el.shClose.addEventListener('click', () => el.shareSheet.hidden = true);
  el.fSelect.addEventListener('click', () => {
    state.selectMode = !state.selectMode; state.selected.clear();
    el.fSelect.textContent = state.selectMode ? 'Cancel' : 'Select';
    el.selShare.hidden = true; renderFriendsGrid();
  });
  el.selShare.addEventListener('click', shareSelection);
  el.faceClose.addEventListener('click', () => el.faceSheet.hidden = true);
  el.faceShareAll.addEventListener('click', () => { el.faceSheet.hidden = true; openShareFriend(state.faceTarget); });
  el.inviteBtn.addEventListener('click', openInvite);
  el.inviteClose.addEventListener('click', () => el.inviteSheet.hidden = true);
  el.inviteWa.addEventListener('click', () => window.open('https://wa.me/?text=' + encodeURIComponent(inviteMsg()), '_blank'));
  el.inviteMail.addEventListener('click', () => { window.location.href = 'mailto:?subject=' + encodeURIComponent('Join me on Poze 📸') + '&body=' + encodeURIComponent(inviteMsg()); });
  el.inviteShare.addEventListener('click', async () => {
    try {
      if (navigator.share) await navigator.share({ title:'Poze', text:inviteMsg(), url:refLink() });
      else { await navigator.clipboard?.writeText(refLink()); toast('Link copied'); }
    } catch (_) {}
  });
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
  if (!state.modelsReady){ toast('Recognition still loading…'); return; }
  el.refStatus.textContent = 'Analyzing face…';
  const img = await loadImage(file);
  const thumb = toCanvas(img, 240).toDataURL('image/jpeg', 0.8);

  const det = await faceapi.detectSingleFace(toCanvas(img, 512)).withFaceLandmarks().withFaceDescriptor();
  URL.revokeObjectURL(img.src);
  if (!det){ el.refStatus.textContent = 'No face detected. Try another photo.'; return; }

  state.refDescriptor = det.descriptor;
  store.data.face = Array.from(det.descriptor);
  store.data.faceThumb = thumb;
  if (!store.data.started){
    store.data.started = true;
    const bonus = store.data.invitedBy ? INVITE_WELCOME : WELCOME_POINTS;
    store.data.points = bonus;
    store.data.history.unshift({ t: store.data.invitedBy ? 'Welcome (invited) 🎁' : 'Welcome 🎉', n: bonus });
  }
  store.save();

  el.refAvatar.style.backgroundImage = `url(${thumb})`;
  el.refAvatar.classList.add('ok');
  el.meAvatar.style.backgroundImage = `url(${thumb})`;
  el.walletPill.hidden = false;
  renderPoints();
  toast(`Face saved · +${store.data.points} reveal(s)`);
  window.setTimeout(() => showScreen('home'), 700);
}

// ---------- Events ----------
function renderEvents(){
  el.eventList.innerHTML = eventsList.map(ev => `
    <button class="event-card" data-ev="${ev.id}">
      <span class="cat-dot" style="background:${ev.dot};box-shadow:0 0 10px ${ev.dot}"></span>
      <span class="ev-badge">${ev.emoji} Open</span>
      <span class="ev-when">${ev.when}</span>
      <span class="ev-name">${ev.name}</span>
      <span class="ev-place">${ev.place}</span>
    </button>`).join('');
  el.eventList.querySelectorAll('.event-card').forEach(c =>
    c.addEventListener('click', () => openEvent(c.dataset.ev)));
}

function openEvent(id){
  state.currentEvent = eventsList.find(e => e.id === id);
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
  // Event backend : les photos choisies sont UPLOADÉES (pas de simulation locale).
  if (state.backend && state.currentEvent && state.currentEvent.backend) return uploadToEvent(files);
  if (!state.refDescriptor){ toast('Scan your face first.'); return; }
  if (!state.modelsReady){ toast('Recognition still loading…'); return; }
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
    el.matchCount.textContent = `${state.matches.length} photo(s) with you`;
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
        : `<div class="lock"><span class="ic">🎞️</span><span class="cost">Develop</span></div>`}
    </div>`;
  }).join('');
  el.grid.querySelectorAll('.tile').forEach(t => t.addEventListener('click', () => openUnlock(t.dataset.id)));
}

function openUnlock(id){
  const m = state.matches.find(x => x.id === id); if (!m) return;
  el.unlockImg.src = m.url;
  const unlocked = isUnlocked(id);
  el.unlockTitle.textContent = unlocked ? 'Photo developed' : 'Develop la photo';
  el.unlockDesc.textContent = unlocked ? 'Yours! Download it in full quality.' : `Developing costs ${UNLOCK_COST} reveal. You have ${store.data.points}.`;
  el.unlockConfirm.hidden = unlocked;
  el.unlockConfirm.textContent = `🎞️ Develop (${UNLOCK_COST} reveal)`;
  el.unlockDownload.hidden = !unlocked;
  el.unlockConfirm.onclick = () => doUnlock(m);
  el.unlockDownload.onclick = () => download(m);
  open('unlockSheet');
}

function doUnlock(m){
  if (store.data.points < UNLOCK_COST){
    toast('No reveals left — contribute or take the shortcut.');
    close('unlockSheet'); openWallet(); return;
  }
  store.data.points -= UNLOCK_COST;
  store.data.unlocked.push(m.id);
  store.data.history.unshift({ t:`Develop`, n:-UNLOCK_COST });
  store.save(); renderPoints(); renderGrid();
  revealTile(m.id); confetti(); vibrate(30);   // le moment magique ✨
  openUnlock(m.id); // rebascule en mode "télécharger"
  toast('Developed! 🎉');
}

function revealTile(id){
  const t = el.grid.querySelector(`.tile[data-id="${id}"]`);
  if (t){ t.classList.add('reveal'); window.setTimeout(() => t.classList.remove('reveal'), 700); }
}
function vibrate(ms){ try { if (navigator.vibrate) navigator.vibrate(ms); } catch (_) {} }

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
  toast(`+${n} reveal(s)`);
}
function buyPack(pts, price){
  store.data.points += pts;
  store.data.history.unshift({ t:`Shortcut (${price})`, n:pts });
  store.save(); renderPoints(); renderHistory();
  toast(`+${pts} reveals (demo)`);
}
function openWallet(){ renderHistory(); open('walletSheet'); }
function renderHistory(){
  const h = store.data.history.slice(0, 12);
  el.history.innerHTML = h.length
    ? h.map(x => `<li><span>${x.t}</span><span class="amt ${x.n>=0?'plus':'minus'}">${x.n>=0?'+':''}${x.n}</span></li>`).join('')
    : '<li class="empty">No activity yet.</li>';
}

// ---------- Récap ----------
function openRecap(){
  const shots = state.matches.filter(m => isUnlocked(m.id));
  const pool = shots.length ? shots : state.matches;
  el.recapTitle.textContent = state.currentEvent ? state.currentEvent.name : 'Your night';
  el.recapGrid.innerHTML = pool.slice(0,9)
    .map(m => `<img src="${m.thumb}" style="${isUnlocked(m.id)?'':'filter:blur(6px)'}">`).join('');
  open('recapSheet');
}
async function shareRecap(){
  const text = `I was at ${state.currentEvent?.name||'the night'} 📸 — find your photos on Poze`;
  try{
    if (navigator.share){ await navigator.share({ title:'Poze', text }); }
    else { await navigator.clipboard?.writeText(text); toast('Texte de partage copié'); }
    addPoints(SHARE_REWARD, 'Recap share');
  }catch(_){}
}

// ---------- Vie privée ----------
function wipe(){
  if (!confirm('Delete your faceprint and all local data?')) return;
  localStorage.removeItem(KEY);
  store.data = { face:null, faceThumb:null, points:0, unlocked:[], history:[], threshold:0.55, started:false, friends:[], refCode:'', invitedBy:null };
  ensureRefCode();
  state.refDescriptor = null; clearMatches(); clearFriendMatches();
  el.friendsGrid.innerHTML = ''; el.fHead.hidden = true;
  el.refAvatar.classList.remove('ok'); el.refAvatar.style.backgroundImage='';
  el.meAvatar.style.backgroundImage=''; el.walletPill.hidden = true;
  close('menuSheet'); renderPoints();
  el.refStatus.textContent = 'Everything deleted. You can start fresh.';
  showScreen('onboarding');
  toast('Data deleted');
}

function updateSupabaseStatus(){
  el.sbStatus.textContent = supabaseReady ? 'Configured ✓' : 'Not configured';
}

// ---------- Backend (Supabase) — additif, gardé par la config ----------
function maybeInitBackend(){
  const c = window.SUPABASE_CONFIG || {};
  if (!(c.url && c.anonKey && !String(c.url).includes('YOUR-') && !String(c.anonKey).includes('YOUR-'))) return;
  (async () => {
    try {
      const mod = await import('./backend.js');   // chargé seulement si configuré
      state.BE = mod.Backend; state.backend = true;
      await state.BE.signIn();
      await state.BE.ensureProfile('Poze user');
      store.data.points = await state.BE.walletBalance();
      renderPoints();
      el.joinBtn.hidden = false;
      await loadBackendEvents();
    } catch (_) { state.backend = false; state.BE = null; }
  })();
}

async function loadBackendEvents(){
  try {
    const evs = await state.BE.listEvents();
    if (evs.length){
      eventsList = evs.map(e => ({
        id:e.id, name:e.name, place:e.place || '', emoji:'🎟️', dot:'#7c5cff', backend:true,
        when: e.starts_at ? new Date(e.starts_at).toLocaleDateString('en-GB', { day:'numeric', month:'short' }) : '',
      }));
      renderEvents();
    }
  } catch (_) {}
}

async function joinEventFlow(){
  const code = (prompt('Event code (from the QR / link)?') || '').trim();
  if (!code) return;
  try { await state.BE.joinEvent(code); await loadBackendEvents(); toast('Joined the event 🎉'); }
  catch (_) { toast('Event not found.'); }
}

async function uploadToEvent(files){
  if (!files.length) return;
  el.grid.innerHTML = ''; el.evEmpty.hidden = true; el.matchHead.hidden = true;
  el.evProgress.hidden = false;
  try {
    await state.BE.uploadPhotos(state.currentEvent.id, files, (done, total) => {
      el.evBar.style.width = `${done/total*100}%`;
      el.evProgressTxt.textContent = `Uploading ${done}/${total}…`;
    });
    toast('Photos added to the event 🎉');
  } catch (_) { toast('Upload failed.'); }
  el.evProgress.hidden = true;
}

// ---------- With friends ----------
function knownPeople(){
  const list = [];
  if (state.refDescriptor) list.push({ name:'You', desc: state.refDescriptor });
  for (const f of store.data.friends) list.push({ name:f.name, desc:new Float32Array(f.descriptor) });
  return list;
}

function personAvatar(name){
  if (name === 'You') return { thumb: store.data.faceThumb, color:'#12a074' };
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
  const you = `<div class="fr"><div class="av" style="${store.data.faceThumb ? `background-image:url(${store.data.faceThumb})` : 'background:#12a074'}">${store.data.faceThumb ? '' : 'T'}</div><div class="nm">You</div></div>`;
  const fr = store.data.friends.map(f =>
    `<div class="fr"><div class="av" style="background-image:url(${f.thumb})"></div><div class="nm">${escapeHtml(f.name)}</div></div>`).join('');
  const add = `<div class="fr" id="addFriend"><div class="av add">＋</div><div class="nm">Add</div></div>`;
  el.friendsRow.innerHTML = you + fr + add;
  document.getElementById('addFriend').addEventListener('click', () => el.friendPhotoInput.click());
}

async function addFriend(file){
  if (!file) return;
  if (!state.modelsReady){ toast('Recognition still loading…'); return; }
  const img = await loadImage(file);
  const thumb = toCanvas(img, 160).toDataURL('image/jpeg', 0.8);
  const det = await faceapi.detectSingleFace(toCanvas(img, 512)).withFaceLandmarks().withFaceDescriptor();
  URL.revokeObjectURL(img.src);
  if (!det){ toast('No face detected in this photo.'); return; }
  const name = (prompt("Friend's first name?") || '').trim() || `Friend ${store.data.friends.length + 1}`;
  const color = FRIEND_COLORS[store.data.friends.length % FRIEND_COLORS.length];
  store.data.friends.push({ id:'f' + store.data.friends.length + '-' + name, name, descriptor:Array.from(det.descriptor), thumb, color });
  store.save();
  renderFriendsRow();
  toast(`${name} added 👌`);
}

function clearFriendMatches(){ state.friendUrls.forEach(u => URL.revokeObjectURL(u)); state.friendUrls = []; state.friendMatches = []; }

async function onFriendPhotos(files){
  if (!state.refDescriptor){ toast('Scan your face first.'); return; }
  if (!state.modelsReady){ toast('Recognition still loading…'); return; }
  if (!files.length) return;

  clearFriendMatches();
  el.friendsGrid.innerHTML = ''; el.fEmpty.hidden = true; el.fHead.hidden = true; el.fProgress.hidden = false;
  const people = knownPeople();
  const th = +store.data.threshold;

  for (let i = 0; i < files.length; i++){
    el.fBar.style.width = `${(i + 1) / files.length * 100}%`;
    el.fProgressTxt.textContent = `Analyzing ${i + 1}/${files.length} — ${state.friendMatches.length} found`;
    try {
      const m = await analyzeFriends(files[i], people, th);
      if (m){ state.friendMatches.push(m); renderFriendsGrid(); }
    } catch (_) {}
    await raf();
  }
  el.fProgress.hidden = true;
  if (!state.friendMatches.length){ el.fEmpty.hidden = false; }
  else { el.fHead.hidden = false; el.fCount.textContent = `${state.friendMatches.length} photo(s) of you`; }
}

async function analyzeFriends(file, people, threshold){
  const img = await loadImage(file);
  const canvas = toCanvas(img, 640);
  const results = await faceapi.detectAllFaces(canvas).withFaceLandmarks().withFaceDescriptors();
  if (!results.length){ URL.revokeObjectURL(img.src); return null; }

  const cw = canvas.width, ch = canvas.height;
  const present = new Set();
  const faces = results.map(r => {
    let best = Infinity, bestName = null;
    for (const p of people){
      const d = faceapi.euclideanDistance(p.desc, r.descriptor);
      if (d < best){ best = d; bestName = p.name; }
    }
    const name = (best <= threshold) ? bestName : null;
    if (name) present.add(name);
    const box = r.detection.box;                // position normalisée (0-1)
    return { x:box.x/cw, y:box.y/ch, w:box.width/cw, h:box.height/ch, name };
  });
  // On garde les photos où TOI es présent (photos de toi & tes amis).
  if (!present.has('You')){ URL.revokeObjectURL(img.src); return null; }

  const thumb = toCanvas(img, 300).toDataURL('image/jpeg', 0.72);
  const url = img.src; state.friendUrls.push(url);
  return { id:`${file.name}-${file.size}-${file.lastModified}`, file, url, thumb, who:[...present], faces, blurred:new Set() };
}

function renderFriendsGrid(){
  el.friendsGrid.innerHTML = state.friendMatches.map(m => {
    const sel = state.selected.has(m.id);
    return `<div class="tile ${state.selectMode && sel ? 'sel' : ''}" data-id="${m.id}"><img src="${m.thumb}" alt="">
      ${state.selectMode ? `<span class="pick">${sel ? '✓' : ''}</span>` : ''}
      <div class="whos">${m.who.map(personChip).join('')}</div></div>`;
  }).join('');
  el.friendsGrid.querySelectorAll('.tile').forEach(t => t.addEventListener('click', () => {
    if (state.selectMode) togglePick(t.dataset.id); else openFaceTag(t.dataset.id);
  }));
}

function togglePick(id){
  if (state.selected.has(id)) state.selected.delete(id); else state.selected.add(id);
  renderFriendsGrid();
  el.selShare.hidden = state.selected.size === 0;
  el.selShare.textContent = `📤 Share selection (${state.selected.size})`;
}

async function shareSelection(){
  const picked = state.friendMatches.filter(m => state.selected.has(m.id));
  if (!picked.length) return;
  const files = await Promise.all(picked.map(m => fileFor(m)));
  try {
    if (navigator.canShare && navigator.canShare({ files })){
      await navigator.share({ files, title:'Poze', text:'Our photos 📸' });
    } else {
      files.forEach(f => { const a = document.createElement('a'); a.href = URL.createObjectURL(f); a.download = f.name || 'photo.jpg'; a.click(); });
      toast('Sharing not supported — photos downloaded.');
    }
  } catch (_) {}
}

function openShareFriend(id){
  const m = state.friendMatches.find(x => x.id === id); if (!m) return;
  el.shImg.src = m.url;
  const others = m.who.filter(w => w !== 'You');
  el.shWho.textContent = m.who.length ? `In this photo: ${m.who.join(', ')}` : 'Choose who to send to';

  let html = '';
  // 1) Destinataires détectés sur la photo
  others.forEach(o => html += `<button class="btn btn-primary" data-who="${escapeHtml(o)}">📤 Share with ${escapeHtml(o)}</button>`);
  if (others.length > 1) html += `<button class="btn btn-primary" data-who="__group">👥 Share with group</button>`;

  // 2) N'importe quel autre pote (utile pour les photos de leurs enfants)
  const rest = store.data.friends.map(f => f.name).filter(n => !others.includes(n));
  if (rest.length){
    html += `<p class="hint" style="text-align:center;margin:12px 0 4px">${others.length ? 'Or send to another friend' : 'Send to a friend'}</p>`;
    rest.forEach(n => html += `<button class="btn btn-bordered" data-who="${escapeHtml(n)}">📤 ${escapeHtml(n)}</button>`);
  }
  if (!others.length && !rest.length) html += `<button class="btn btn-primary" data-who="__self">📤 Share the photo</button>`;

  el.shBtns.innerHTML = html;
  el.shBtns.querySelectorAll('button').forEach(b => b.addEventListener('click', () => sharePhoto(m, b.dataset.who)));
  el.shareSheet.hidden = false;
}

// Envoi manuel : pas de reconnaissance (ex. photos où seul l'enfant d'un ami apparaît).
async function onManualPhotos(files){
  if (!files.length) return;
  el.fEmpty.hidden = true;
  for (const file of files){
    try {
      const img = await loadImage(file);
      const thumb = toCanvas(img, 300).toDataURL('image/jpeg', 0.72);
      state.friendUrls.push(img.src);
      state.friendMatches.unshift({ id:`m-${file.name}-${file.size}-${file.lastModified}`, file, url:img.src, thumb, who:[], faces:[], blurred:new Set() });
    } catch (_) {}
    await raf();
  }
  el.fHead.hidden = false;
  el.fCount.textContent = `${state.friendMatches.length} photo(s)`;
  renderFriendsGrid();
  toast('Tap a photo then choose the friend to send it to');
}

async function sharePhoto(m, who){
  const hint = (who && who !== '__group' && who !== '__self') ? `A photo of us, ${who} 📸` : 'A photo of us 📸';
  const file = await fileFor(m);
  try {
    if (navigator.canShare && navigator.canShare({ files:[file] })){
      await navigator.share({ files:[file], title:'Poze', text: hint });
    } else {
      const a = document.createElement('a'); a.href = URL.createObjectURL(file); a.download = file.name || 'photo.jpg';
      document.body.appendChild(a); a.click(); a.remove();
      toast('Sharing not supported — photo downloaded.');
    }
  } catch (_) {}
  el.shareSheet.hidden = true; el.faceSheet.hidden = true;
}

// ---------- Identification par tap sur les visages ----------
function getMatch(id){ return state.friendMatches.find(x => x.id === id); }
function imgFromURL(url){ return new Promise((res, rej) => { const i = new Image(); i.onload = () => res(i); i.onerror = rej; i.src = url; }); }

function openFaceTag(id){
  const m = getMatch(id); if (!m) return;
  state.faceTarget = id;
  const boxes = (m.faces || []).map((f, i) => {
    const blurred = m.blurred.has(i);
    const cls = f.name ? 'known' : 'unknown';
    return `<button class="facebox ${cls} ${blurred ? 'blur' : ''}" data-i="${i}"
      style="left:${f.x*100}%;top:${f.y*100}%;width:${f.w*100}%;height:${f.h*100}%">
      <span class="tag">${f.name ? escapeHtml(f.name) : '?'}</span></button>`;
  }).join('');
  el.facePhoto.innerHTML = `<div class="facewrap"><img src="${m.url}" alt="">${boxes}</div>`;
  el.faceActions.innerHTML = (m.faces && m.faces.length)
    ? '<p class="hint" style="text-align:center">Tap a face to share, invite or blur.</p>'
    : '<p class="hint" style="text-align:center">No face detected — you can still share the whole photo.</p>';
  el.facePhoto.querySelectorAll('.facebox').forEach(bx => bx.addEventListener('click', () => selectFace(id, +bx.dataset.i)));
  el.faceSheet.hidden = false;
}

function selectFace(id, i){
  const m = getMatch(id); if (!m) return;
  const f = m.faces[i]; const blurred = m.blurred.has(i);
  const isYou = f.name === 'You';
  let html = '';
  if (f.name && !isYou) html += `<button class="btn btn-primary" data-act="share">📤 Share with ${escapeHtml(f.name)}</button>`;
  else if (!f.name) html += `<button class="btn btn-primary" data-act="invite">➕ Invite this person</button>`;
  html += `<button class="btn btn-bordered" data-act="blur">${blurred ? '👁️ Unblur this face' : '🙈 Blur this face'}</button>`;
  const note = isYou ? 'This is you.'
    : (f.name ? `Recognized: ${escapeHtml(f.name)}`
             : 'Unknown face — you can invite them or blur them (we never look up who they are).');
  el.faceActions.innerHTML = `<p class="hint" style="text-align:center;margin:2px 0 8px">${note}</p>` + html;
  el.faceActions.querySelectorAll('button').forEach(btn => btn.addEventListener('click', () => {
    const a = btn.dataset.act;
    if (a === 'blur'){ if (blurred) m.blurred.delete(i); else m.blurred.add(i); openFaceTag(id); selectFace(id, i); }
    else if (a === 'share'){ sharePhoto(m, f.name); }
    else if (a === 'invite'){ el.faceSheet.hidden = true; openInvite(); }
  }));
}

// Génère un fichier avec les visages floutés (si besoin), sinon renvoie l'original.
async function fileFor(m){
  if (!m.blurred || m.blurred.size === 0) return m.file;
  try {
    const img = await imgFromURL(m.url);
    const w = img.naturalWidth || img.width, h = img.naturalHeight || img.height;
    const c = document.createElement('canvas'); c.width = w; c.height = h;
    const ctx = c.getContext('2d'); ctx.drawImage(img, 0, 0, w, h);
    for (const i of m.blurred){
      const f = m.faces[i]; if (!f) continue;
      const pad = f.w * w * 0.15;
      ctx.save();
      ctx.beginPath(); ctx.rect(f.x*w - pad, f.y*h - pad, f.w*w + 2*pad, f.h*h + 2*pad); ctx.clip();
      ctx.filter = `blur(${Math.max(8, f.w*w*0.25)}px)`;
      ctx.drawImage(img, 0, 0, w, h);
      ctx.restore();
    }
    const blob = await new Promise(r => c.toBlob(r, 'image/jpeg', 0.9));
    return new File([blob], (m.file.name || 'photo') + '-blurred.jpg', { type:'image/jpeg' });
  } catch (_) { return m.file; }
}

// ---------- Invitation (boucle virale) ----------
function ensureRefCode(){
  if (!store.data.refCode){ store.data.refCode = Math.random().toString(36).slice(2, 8).toUpperCase(); store.save(); }
}
function refLink(){ return `${location.origin}${location.pathname}?ref=${store.data.refCode}`; }
function inviteMsg(){ return `Join me on Poze 📸 — find your party photos. With my link you get ${INVITE_WELCOME} free reveals: ${refLink()}`; }
function openInvite(){ ensureRefCode(); el.inviteLink.textContent = refLink(); el.inviteSheet.hidden = false; }

// ---------- Confettis ----------
function confetti(){
  let c = document.getElementById('confettiCanvas');
  if (!c){ c = document.createElement('canvas'); c.id = 'confettiCanvas'; document.body.appendChild(c); }
  const dpr = Math.min(2, window.devicePixelRatio || 1);
  c.width = innerWidth * dpr; c.height = innerHeight * dpr;
  c.style.width = innerWidth + 'px'; c.style.height = innerHeight + 'px';
  const ctx = c.getContext('2d'); ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  const colors = ['#7c5cff', '#22d3ee', '#ff5da2', '#2fdd9b', '#ffffff'];
  const parts = Array.from({ length: 90 }, (_, i) => ({
    x: innerWidth / 2, y: innerHeight * 0.42,
    vx: (Math.random() - 0.5) * 11, vy: Math.random() * -9 - 3,
    s: 4 + Math.random() * 6, c: colors[i % colors.length], r: Math.random() * 6, vr: (Math.random() - 0.5) * 0.5, life: 1,
  }));
  let start = null;
  function frame(t){
    if (!start) start = t;
    ctx.clearRect(0, 0, innerWidth, innerHeight);
    let alive = false;
    for (const p of parts){
      p.vy += 0.28; p.x += p.vx; p.y += p.vy; p.r += p.vr; p.life -= 0.012;
      if (p.life > 0 && p.y < innerHeight + 30){
        alive = true;
        ctx.save(); ctx.globalAlpha = Math.max(0, p.life); ctx.translate(p.x, p.y); ctx.rotate(p.r);
        ctx.fillStyle = p.c; ctx.fillRect(-p.s / 2, -p.s / 2, p.s, p.s * 0.6); ctx.restore();
      }
    }
    if (alive && t - start < 2600) requestAnimationFrame(frame);
    else ctx.clearRect(0, 0, innerWidth, innerHeight);
  }
  requestAnimationFrame(frame);
}

// ---------- Story partageable (9:16) — le moteur viral ----------
function roundRect(ctx, x, y, w, h, r){
  ctx.beginPath(); ctx.moveTo(x + r, y);
  ctx.arcTo(x + w, y, x + w, y + h, r); ctx.arcTo(x + w, y + h, x, y + h, r);
  ctx.arcTo(x, y + h, x, y, r); ctx.arcTo(x, y, x + w, y, r); ctx.closePath();
}
function drawCover(ctx, im, x, y, w, h){
  const ir = im.width / im.height, tr = w / h; let dw, dh;
  if (ir > tr){ dh = h; dw = h * ir; } else { dw = w; dh = w / ir; }
  ctx.drawImage(im, x + (w - dw) / 2, y + (h - dh) / 2, dw, dh);
}
async function buildStoryCanvas(){
  const pool = (state.matches && state.matches.length ? state.matches : state.friendMatches) || [];
  const shots = pool.slice(0, 4);
  const W = 1080, H = 1920;
  const c = document.createElement('canvas'); c.width = W; c.height = H;
  const ctx = c.getContext('2d');
  ctx.fillStyle = '#0a0a14'; ctx.fillRect(0, 0, W, H);
  for (const [x, y, col] of [[0.2, 0.14, 'rgba(124,92,255,.85)'], [0.85, 0.12, 'rgba(34,211,238,.7)'], [0.62, 0.9, 'rgba(255,93,162,.6)'], [0.1, 0.86, 'rgba(124,92,255,.5)']]){
    const g = ctx.createRadialGradient(x * W, y * H, 0, x * W, y * H, W * 0.62);
    g.addColorStop(0, col); g.addColorStop(1, 'rgba(10,10,20,0)');
    ctx.fillStyle = g; ctx.fillRect(0, 0, W, H);
  }
  ctx.textAlign = 'center'; ctx.fillStyle = '#fff';
  ctx.font = '800 62px -apple-system,"Segoe UI",Roboto,sans-serif'; ctx.fillText('Poze', W / 2, 150);
  ctx.font = '850 96px -apple-system,"Segoe UI",Roboto,sans-serif'; ctx.fillText('My night', W / 2, 300);
  const ev = state.currentEvent ? state.currentEvent.name : '';
  if (ev){ ctx.font = '500 46px -apple-system,"Segoe UI",Roboto,sans-serif'; ctx.fillStyle = 'rgba(255,255,255,.82)'; ctx.fillText(ev, W / 2, 372); }
  const imgs = await Promise.all(shots.map(m => imgFromURL(m.thumb).catch(() => null)));
  const gx = 90, gy = 470, gap = 40, cell = (W - gx * 2 - gap) / 2;
  imgs.forEach((im, i) => {
    if (!im) return;
    const x = gx + (i % 2) * (cell + gap), y = gy + Math.floor(i / 2) * (cell + gap);
    ctx.save(); roundRect(ctx, x, y, cell, cell, 36); ctx.clip(); drawCover(ctx, im, x, y, cell, cell); ctx.restore();
    ctx.lineWidth = 2; ctx.strokeStyle = 'rgba(255,255,255,.16)'; roundRect(ctx, x, y, cell, cell, 36); ctx.stroke();
  });
  ctx.textAlign = 'center'; ctx.fillStyle = '#fff';
  ctx.font = '700 48px -apple-system,"Segoe UI",Roboto,sans-serif'; ctx.fillText('Find your photos on Poze', W / 2, H - 180);
  ctx.font = '500 40px -apple-system,"Segoe UI",Roboto,sans-serif'; ctx.fillStyle = 'rgba(255,255,255,.72)'; ctx.fillText('📸  poze.app', W / 2, H - 108);
  return c;
}
async function shareStory(){
  try {
    const c = await buildStoryCanvas();
    const blob = await new Promise(r => c.toBlob(r, 'image/jpeg', 0.92));
    const file = new File([blob], 'poze-story.jpg', { type: 'image/jpeg' });
    if (navigator.canShare && navigator.canShare({ files: [file] })){
      await navigator.share({ files: [file], title: 'Poze', text: 'My night 📸' });
    } else {
      const a = document.createElement('a'); a.href = URL.createObjectURL(file); a.download = 'poze-story.jpg'; a.click();
      toast('Story saved 📥');
    }
    addPoints(SHARE_REWARD, 'Story share'); confetti();
  } catch (_) { toast('Could not build the story.'); }
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
  el.evProgressTxt.textContent = `Analyzing ${done}/${total} — ${state.matches.length} found`;
}
const raf = () => new Promise(r => requestAnimationFrame(() => r()));
function registerSW(){ if ('serviceWorker' in navigator) navigator.serviceWorker.register('./service-worker.js').catch(()=>{}); }

// Exposé pour tests/déboguage
window.__pp = { store, state, showScreen, renderGrid, renderPoints, openUnlock, renderFriendsRow, renderFriendsGrid, openShareFriend, buildStoryCanvas, confetti };

init();
