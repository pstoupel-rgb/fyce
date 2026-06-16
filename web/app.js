import * as faceapi from 'https://cdn.jsdelivr.net/npm/@vladmandic/face-api/dist/face-api.esm.js';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const MODEL_URL = 'https://cdn.jsdelivr.net/npm/@vladmandic/face-api/model';
const cfg = window.SUPABASE_CONFIG || {};
const supabaseReady = !!(cfg.url && cfg.anonKey && !String(cfg.url).includes('YOUR-') && !String(cfg.anonKey).includes('YOUR-'));
const sb = supabaseReady ? createClient(cfg.url, cfg.anonKey) : null;

const state = {
  referenceDescriptor: null,
  threshold: 0.55,
  matches: [],            // { id, file, thumb, distance, selected, status, remotePath }
  uploadedPaths: [],
};

const $ = (id) => document.getElementById(id);
const els = {
  loader: $('loader'), loaderText: $('loaderText'),
  refInput: $('refInput'), refAvatar: $('refAvatar'), refLabel: $('refLabel'), refStatus: $('refStatus'),
  pickBtn: $('pickBtn'), photosInput: $('photosInput'),
  shareBtn: $('shareBtn'),
  progressBox: $('progressBox'), progressBar: $('progressBar'), progressText: $('progressText'),
  selbar: $('selbar'), selCount: $('selCount'), selectAll: $('selectAll'), selectNone: $('selectNone'),
  results: $('results'), empty: $('empty'),
  settingsBtn: $('settingsBtn'), settingsSheet: $('settingsSheet'), settingsClose: $('settingsClose'),
  threshold: $('threshold'), threshVal: $('threshVal'), sbStatus: $('sbStatus'), sbFoot: $('sbFoot'),
  recap: $('recap'), recapSeal: $('recapSeal'), recapTitle: $('recapTitle'),
  recapOk: $('recapOk'), recapFail: $('recapFail'), copyLinks: $('copyLinks'), recapClose: $('recapClose'),
};

// ---------- Initialisation ----------
async function init() {
  registerServiceWorker();
  try {
    await Promise.all([
      faceapi.nets.ssdMobilenetv1.loadFromUri(MODEL_URL),
      faceapi.nets.faceLandmark68Net.loadFromUri(MODEL_URL),
      faceapi.nets.faceRecognitionNet.loadFromUri(MODEL_URL),
    ]);
  } catch (e) {
    els.loaderText.textContent = "Échec du chargement du modèle (vérifie ta connexion).";
    return;
  }
  els.loader.classList.add('hidden');
  wireEvents();
  refreshSupabaseStatus();
}

function wireEvents() {
  els.refInput.addEventListener('change', (e) => onReference(e.target.files[0]));
  els.photosInput.addEventListener('change', (e) => onPhotos([...e.target.files]));
  els.shareBtn.addEventListener('click', uploadSelected);
  els.selectAll.addEventListener('click', () => { setAllSelected(true); });
  els.selectNone.addEventListener('click', () => { setAllSelected(false); });
  els.settingsBtn.addEventListener('click', () => els.settingsSheet.classList.remove('hidden'));
  els.settingsClose.addEventListener('click', () => els.settingsSheet.classList.add('hidden'));
  els.threshold.addEventListener('input', (e) => {
    state.threshold = parseFloat(e.target.value);
    els.threshVal.textContent = state.threshold.toFixed(2);
  });
  els.recapClose.addEventListener('click', () => els.recap.classList.add('hidden'));
  els.copyLinks.addEventListener('click', copyShareLinks);
}

// ---------- Visage de référence ----------
async function onReference(file) {
  if (!file) return;
  els.refStatus.textContent = "Analyse du visage…";
  const img = await loadImage(file);
  els.refAvatar.style.backgroundImage = `url(${img.src})`;
  els.refAvatar.querySelector('span')?.remove();

  const det = await faceapi
    .detectSingleFace(toCanvas(img, 512))
    .withFaceLandmarks().withFaceDescriptor();

  if (!det) {
    els.refStatus.textContent = "Aucun visage détecté. Essaie une autre photo.";
    els.refAvatar.classList.remove('ok');
    return;
  }
  state.referenceDescriptor = det.descriptor;
  els.refAvatar.classList.add('ok');
  els.refLabel.textContent = "Changer mon visage de référence";
  els.refStatus.textContent = "Visage de référence prêt ✓";
  els.pickBtn.setAttribute('aria-disabled', 'false');
}

// ---------- Scan des photos ----------
async function onPhotos(files) {
  if (!state.referenceDescriptor) { alert("Choisis d'abord un visage de référence."); return; }
  if (!files.length) return;

  state.matches = [];
  state.uploadedPaths = [];
  els.results.innerHTML = '';
  els.empty.classList.add('hidden');
  els.shareBtn.classList.add('hidden');
  els.selbar.classList.add('hidden');
  els.progressBox.classList.remove('hidden');

  for (let i = 0; i < files.length; i++) {
    const file = files[i];
    setProgress(i + 1, files.length);
    try {
      const match = await analyze(file);
      if (match) { state.matches.push(match); renderResults(); }
    } catch (_) { /* image illisible : ignorée */ }
    await nextFrame();
  }

  els.progressBox.classList.add('hidden');
  if (!state.matches.length) {
    els.empty.classList.remove('hidden');
    els.empty.querySelector('h2').textContent = "Aucune photo avec ton visage";
    els.empty.querySelector('p').textContent = "Essaie d'ajuster la sensibilité dans les réglages.";
  } else {
    els.shareBtn.classList.remove('hidden');
    els.selbar.classList.remove('hidden');
    updateSelectionUI();
  }
}

async function analyze(file) {
  const img = await loadImage(file);
  const canvas = toCanvas(img, 640);
  const results = await faceapi.detectAllFaces(canvas).withFaceLandmarks().withFaceDescriptors();
  if (!results.length) { URL.revokeObjectURL(img.src); return null; }

  let best = Infinity;
  for (const r of results) {
    const d = faceapi.euclideanDistance(state.referenceDescriptor, r.descriptor);
    if (d < best) best = d;
  }
  if (best > state.threshold) { URL.revokeObjectURL(img.src); return null; }

  const thumb = toCanvas(img, 220).toDataURL('image/jpeg', 0.7);
  URL.revokeObjectURL(img.src);
  return {
    id: `${file.name}-${file.size}-${file.lastModified}`,
    file, thumb, distance: best, date: new Date(file.lastModified || Date.now()),
    selected: true, status: 'pending', remotePath: null,
  };
}

// ---------- Rendu ----------
function renderResults() {
  const sections = groupByMonth(state.matches);
  els.results.innerHTML = sections.map(sec => `
    <div class="month">${sec.title}</div>
    <div class="grid">
      ${sec.items.map(thumbHTML).join('')}
    </div>`).join('');
  els.results.querySelectorAll('.thumb').forEach(node => {
    node.addEventListener('click', () => toggleSelect(node.dataset.id));
  });
  updateSelectionUI();
}

function thumbHTML(m) {
  const badge = { pending: '', uploading: '⏳', uploaded: '☁️✓', failed: '⚠️' }[m.status] || '';
  return `<div class="thumb ${m.selected ? 'sel' : 'off'}" data-id="${m.id}">
      <img src="${m.thumb}" alt="">
      <span class="selbadge">${m.selected ? '✓' : '○'}</span>
      ${badge ? `<span class="up">${badge}</span>` : ''}
    </div>`;
}

function toggleSelect(id) {
  const m = state.matches.find(x => x.id === id);
  if (!m || m.status === 'uploaded' || m.status === 'uploading') return;
  m.selected = !m.selected;
  renderResults();
}

function setAllSelected(v) {
  for (const m of state.matches) if (m.status !== 'uploaded' && m.status !== 'uploading') m.selected = v;
  renderResults();
}

function updateSelectionUI() {
  const sel = state.matches.filter(m => m.selected).length;
  els.selCount.textContent = `${sel} sélectionnée(s) sur ${state.matches.length}`;
  els.shareBtn.textContent = `☁️ Partager la sélection (${sel})`;
  els.shareBtn.disabled = sel === 0 || !supabaseReady;
}

// ---------- Upload Supabase ----------
async function uploadSelected() {
  if (!supabaseReady) { alert("Supabase n'est pas configuré (web/config.js)."); return; }
  const targets = state.matches.filter(m => m.selected && m.status !== 'uploaded' && m.status !== 'uploading');
  if (!targets.length) return;

  let ok = 0, fail = 0;
  for (const m of targets) {
    m.status = 'uploading'; renderResults();
    const path = `${safeName(m.id)}.${ext(m.file)}`;
    const { error } = await sb.storage.from(cfg.bucket).upload(path, m.file, {
      upsert: true, contentType: m.file.type || 'image/jpeg',
    });
    if (error) { m.status = 'failed'; fail++; }
    else { m.status = 'uploaded'; m.remotePath = path; state.uploadedPaths.push(path); ok++; }
    renderResults();
  }
  showRecap(ok, fail);
}

async function copyShareLinks() {
  const links = [];
  for (const path of state.uploadedPaths) {
    const { data } = await sb.storage.from(cfg.bucket).createSignedUrl(path, 60 * 60 * 24 * 7);
    if (data?.signedUrl) links.push(data.signedUrl);
  }
  if (links.length) {
    await navigator.clipboard?.writeText(links.join('\n')).catch(() => {});
    els.copyLinks.textContent = `✓ ${links.length} lien(s) copié(s)`;
  }
}

function showRecap(ok, fail) {
  els.recapSeal.textContent = fail ? '⚠️' : '✅';
  els.recapTitle.textContent = fail ? 'Partage terminé avec des erreurs' : 'Partage réussi';
  els.recapOk.textContent = `✔ ${ok} photo(s) partagée(s)`;
  els.recapFail.classList.toggle('hidden', !fail);
  els.recapFail.textContent = `✕ ${fail} échec(s)`;
  els.copyLinks.classList.toggle('hidden', state.uploadedPaths.length === 0);
  els.copyLinks.textContent = '🔗 Copier les liens de partage';
  els.recap.classList.remove('hidden');
}

// ---------- Helpers ----------
function loadImage(file) {
  return new Promise((resolve, reject) => {
    const img = new Image();
    img.onload = () => resolve(img);
    img.onerror = reject;
    img.src = URL.createObjectURL(file);
  });
}

function toCanvas(img, maxSide) {
  const scale = Math.min(1, maxSide / Math.max(img.width, img.height));
  const c = document.createElement('canvas');
  c.width = Math.round(img.width * scale);
  c.height = Math.round(img.height * scale);
  c.getContext('2d').drawImage(img, 0, 0, c.width, c.height);
  return c;
}

function groupByMonth(items) {
  const fmt = new Intl.DateTimeFormat('fr-FR', { month: 'long', year: 'numeric' });
  const map = new Map();
  for (const it of items) {
    const key = `${it.date.getFullYear()}-${it.date.getMonth()}`;
    if (!map.has(key)) map.set(key, { key, date: new Date(it.date.getFullYear(), it.date.getMonth(), 1), items: [] });
    map.get(key).items.push(it);
  }
  return [...map.values()]
    .sort((a, b) => b.date - a.date)
    .map(s => ({ title: fmt.format(s.date), items: s.items.sort((a, b) => b.date - a.date) }));
}

function setProgress(done, total) {
  els.progressBar.style.width = `${(done / total) * 100}%`;
  els.progressText.textContent = `Analyse ${done}/${total} — ${state.matches.length} match(s)`;
}

const nextFrame = () => new Promise(r => requestAnimationFrame(() => r()));
const safeName = (s) => s.replace(/[^a-zA-Z0-9._-]/g, '_');
const ext = (file) => (file.name.split('.').pop() || 'jpg').toLowerCase();

function refreshSupabaseStatus() {
  els.sbStatus.textContent = supabaseReady ? 'Configuré ✓' : 'Non configuré';
  els.sbFoot.textContent = supabaseReady
    ? `Bucket : ${cfg.bucket}`
    : "Renseigne web/config.js (URL + clé anon) pour activer l'upload. Le scan fonctionne sans.";
}

function registerServiceWorker() {
  if ('serviceWorker' in navigator) {
    navigator.serviceWorker.register('./service-worker.js').catch(() => {});
  }
}

init();
