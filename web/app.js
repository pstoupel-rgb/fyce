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
};

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
 'friendsCard','friendsRow','friendPhotoInput','importFriendsBtn','friendsPhotosInput','manualShareBtn','manualInput',
 'fProgress','fBar','fProgressTxt','fEmpty','fHead','fCount','friendsGrid',
 'shareSheet','shImg','shWho','shBtns','shClose',
 'inviteBtn','inviteSheet','inviteLink','inviteWa','inviteMail','inviteShare','inviteClose',
 'fSelect','selShare'
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
  el.recapShare.addEventListener('click', shareRecap);
  el.unlockClose.addEventListener('click', () => close('unlockSheet'));
  el.contribBtn.addEventListener('click', () => addPoints(SHARE_REWARD, 'Contribution: shared the event'));
  el.simEarn.addEventListener('click', () => addPoints(EARN_ON_DOWNLOAD, 'Someone developed your photo'));
  el.wipeBtn.addEventListener('click', wipe);
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
  el.eventList.innerHTML = EVENTS.map(ev => `
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
  openUnlock(m.id); // rebascule en mode "télécharger"
  toast('Developed! 🎉');
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
  if (!present.has('You')){ URL.revokeObjectURL(img.src); return null; }

  const thumb = toCanvas(img, 300).toDataURL('image/jpeg', 0.72);
  const url = img.src; state.friendUrls.push(url);
  return { id:`${file.name}-${file.size}-${file.lastModified}`, file, url, thumb, who:[...present] };
}

function renderFriendsGrid(){
  el.friendsGrid.innerHTML = state.friendMatches.map(m => {
    const sel = state.selected.has(m.id);
    return `<div class="tile ${state.selectMode && sel ? 'sel' : ''}" data-id="${m.id}"><img src="${m.thumb}" alt="">
      ${state.selectMode ? `<span class="pick">${sel ? '✓' : ''}</span>` : ''}
      <div class="whos">${m.who.map(personChip).join('')}</div></div>`;
  }).join('');
  el.friendsGrid.querySelectorAll('.tile').forEach(t => t.addEventListener('click', () => {
    if (state.selectMode) togglePick(t.dataset.id); else openShareFriend(t.dataset.id);
  }));
}

function togglePick(id){
  if (state.selected.has(id)) state.selected.delete(id); else state.selected.add(id);
  renderFriendsGrid();
  el.selShare.hidden = state.selected.size === 0;
  el.selShare.textContent = `📤 Share selection (${state.selected.size})`;
}

async function shareSelection(){
  const files = state.friendMatches.filter(m => state.selected.has(m.id)).map(m => m.file);
  if (!files.length) return;
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
      state.friendMatches.unshift({ id:`m-${file.name}-${file.size}-${file.lastModified}`, file, url:img.src, thumb, who:[] });
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
  try {
    if (navigator.canShare && navigator.canShare({ files:[m.file] })){
      await navigator.share({ files:[m.file], title:'Poze', text: hint });
    } else {
      const a = document.createElement('a'); a.href = m.url; a.download = m.file.name || 'photo.jpg';
      document.body.appendChild(a); a.click(); a.remove();
      toast('Sharing not supported — photo downloaded.');
    }
  } catch (_) {}
  el.shareSheet.hidden = true;
}

// ---------- Invitation (boucle virale) ----------
function ensureRefCode(){
  if (!store.data.refCode){ store.data.refCode = Math.random().toString(36).slice(2, 8).toUpperCase(); store.save(); }
}
function refLink(){ return `${location.origin}${location.pathname}?ref=${store.data.refCode}`; }
function inviteMsg(){ return `Join me on Poze 📸 — find your party photos. With my link you get ${INVITE_WELCOME} free reveals: ${refLink()}`; }
function openInvite(){ ensureRefCode(); el.inviteLink.textContent = refLink(); el.inviteSheet.hidden = false; }

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
window.__pp = { store, state, showScreen, renderGrid, renderPoints, openUnlock, renderFriendsRow, renderFriendsGrid, openShareFriend };

init();
