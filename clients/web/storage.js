/** Local persistence — mirrors Windows SharedPreferences + UserImportStore (IndexedDB). */
const DB_NAME = "pianoflow_web";
const DB_VER = 1;
const LS = {
  auth: "pf_auth_v1",
  favorites: "pf_fav_v1",
  recent: "pf_recent_v1",
  stats: "pf_stats_v1",
  prefs: "pf_prefs_v1",
};

let dbPromise;

function openDb() {
  if (!dbPromise) {
    dbPromise = new Promise((resolve, reject) => {
      const req = indexedDB.open(DB_NAME, DB_VER);
      req.onupgradeneeded = () => {
        const db = req.result;
        if (!db.objectStoreNames.contains("userScores")) {
          db.createObjectStore("userScores", { keyPath: "id" });
        }
        if (!db.objectStoreNames.contains("userXml")) {
          db.createObjectStore("userXml", { keyPath: "id" });
        }
      };
      req.onsuccess = () => resolve(req.result);
      req.onerror = () => reject(req.error);
    });
  }
  return dbPromise;
}

function lsGet(key, fallback) {
  try {
    const raw = localStorage.getItem(key);
    return raw ? JSON.parse(raw) : fallback;
  } catch {
    return fallback;
  }
}

function lsSet(key, val) {
  localStorage.setItem(key, JSON.stringify(val));
}

export function getAuth() {
  return lsGet(LS.auth, { email: null, name: null, guest: true });
}

export function login(email, password, name) {
  const trimmed = (email || "").trim();
  if (!trimmed.includes("@")) return "请输入有效邮箱";
  if ((password || "").length < 4) return "密码至少 4 位";
  const display = (name || trimmed.split("@")[0]).trim();
  lsSet(LS.auth, { email: trimmed, name: display, guest: false });
  return null;
}

export function enterGuest() {
  lsSet(LS.auth, { email: null, name: "访客", guest: true });
}

export function logout() {
  lsSet(LS.auth, { email: null, name: null, guest: true });
}

export function getFavorites() {
  return new Set(lsGet(LS.favorites, []));
}

export function toggleFavorite(id) {
  const f = getFavorites();
  if (f.has(id)) f.delete(id);
  else f.add(id);
  lsSet(LS.favorites, [...f]);
  return f.has(id);
}

export function getRecent() {
  return lsGet(LS.recent, []);
}

export function pushRecent(id) {
  const r = [id, ...getRecent().filter((x) => x !== id)].slice(0, 12);
  lsSet(LS.recent, r);
}

export function getStats() {
  return lsGet(LS.stats, {
    totalSessions: 0,
    totalSeconds: 0,
    today: { day: "", seconds: 0 },
    bySong: {},
    examHistory: [],
  });
}

export function recordSession(songId, seconds, { exam = false, perfects = 0, goods = 0, combo = 0, recordExam = true } = {}) {
  const s = getStats();
  const day = new Date().toISOString().slice(0, 10);
  s.totalSessions = (s.totalSessions || 0) + 1;
  s.totalSeconds = (s.totalSeconds || 0) + Math.max(0, seconds | 0);
  if (!s.today || s.today.day !== day) s.today = { day, seconds: 0 };
  s.today.seconds += Math.max(0, seconds | 0);
  s.bySong = s.bySong || {};
  const cur = s.bySong[songId] || { sessions: 0, seconds: 0, lit: false, examSessions: 0 };
  cur.sessions += 1;
  cur.seconds += Math.max(0, seconds | 0);
  cur.lit = true;
  if (exam && recordExam) {
    cur.examSessions = (cur.examSessions || 0) + 1;
    s.examHistory = s.examHistory || [];
    s.examHistory.unshift({
      songId,
      at: Date.now(),
      perfects,
      goods,
      combo,
    });
    s.examHistory = s.examHistory.slice(0, 50);
  }
  s.bySong[songId] = cur;
  lsSet(LS.stats, s);
  pushRecent(songId);
}

export async function loadUserSongs() {
  const db = await openDb();
  return new Promise((resolve, reject) => {
    const tx = db.transaction("userScores", "readonly");
    const req = tx.objectStore("userScores").getAll();
    req.onsuccess = () => resolve(req.result || []);
    req.onerror = () => reject(req.error);
  });
}

export async function getUserScoreJson(id) {
  const db = await openDb();
  return new Promise((resolve, reject) => {
    const tx = db.transaction("userScores", "readonly");
    const req = tx.objectStore("userScores").get(id);
    req.onsuccess = () => resolve(req.result?.json || null);
    req.onerror = () => reject(req.error);
  });
}

export async function getUserMusicXml(id) {
  const db = await openDb();
  return new Promise((resolve, reject) => {
    const tx = db.transaction("userXml", "readonly");
    const req = tx.objectStore("userXml").get(id);
    req.onsuccess = () => resolve(req.result?.xml || null);
    req.onerror = () => reject(req.error);
  });
}

export async function saveUserImport({ id, catalogEntry, scoreJson, musicXml }) {
  const db = await openDb();
  await new Promise((resolve, reject) => {
    const tx = db.transaction(["userScores", "userXml"], "readwrite");
    tx.objectStore("userScores").put({ id, json: scoreJson, meta: catalogEntry });
    tx.objectStore("userXml").put({ id, xml: musicXml });
    tx.oncomplete = () => resolve();
    tx.onerror = () => reject(tx.error);
  });
}

export async function deleteUserImport(id) {
  const db = await openDb();
  await new Promise((resolve, reject) => {
    const tx = db.transaction(["userScores", "userXml"], "readwrite");
    tx.objectStore("userScores").delete(id);
    tx.objectStore("userXml").delete(id);
    tx.oncomplete = () => resolve();
    tx.onerror = () => reject(tx.error);
  });
  const fav = getFavorites();
  if (fav.delete(id)) lsSet(LS.favorites, [...fav]);
}

export function getVisualFxEnabled() {
  return lsGet(LS.prefs, { visualFx: true }).visualFx !== false;
}

export function setVisualFxEnabled(on) {
  const p = lsGet(LS.prefs, { visualFx: true });
  p.visualFx = !!on;
  lsSet(LS.prefs, p);
}

export async function mergeCatalog(bundled) {
  const user = await loadUserSongs();
  const userEntries = user.map((u) => u.meta).filter(Boolean);
  const byId = Object.fromEntries(bundled.map((s) => [s.id, s]));
  for (const u of userEntries) byId[u.id] = u;
  const out = [...bundled];
  for (const u of userEntries) {
    if (!bundled.some((b) => b.id === u.id)) out.push(u);
  }
  return out;
}
