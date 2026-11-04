import {
  mergeCatalog,
  getFavorites,
  toggleFavorite,
  getRecent,
  getStats,
  recordSession,
  getUserScoreJson,
  getUserMusicXml,
  deleteUserImport,
} from "./storage.js";
import { importMusicXmlText, importMidiBytes, readFileAsText, readFileAsArrayBuffer } from "./workshop-import.js";
import { importAudioFile } from "./audio-workshop.js";
import { stagePdfFile, listStagedPdfs } from "./pdf-workshop.js";
import { refreshAuthUi } from "./pages.js";

const CATALOG_URL = "./scores/catalog.json";
const INK = [
  // [topWash, bottom] — Echo warm paper, deep enough to separate from page bg
  ["#b5cfa0", "#e8f0dc"],
  ["#d4b090", "#f0e4d4"],
  ["#e0b090", "#f2e2d4"],
  ["#9cbcbc", "#dce8e8"],
  ["#c0c890", "#e8ead8"],
  ["#d0a890", "#f0e0d4"],
  ["#d0bc90", "#f0e8d4"],
  ["#a0bc9c", "#dce8d8"],
];

export function kindLabel(k) {
  return ({ formal: "正式谱", omrDraft: "OMR草稿", simplified: "简化谱", userImport: "用户导入" }[k] || k);
}

function difficultyLabel(d) {
  return ({ 1: "入门", 2: "初级", 3: "中级", 4: "高级" }[d] || `${d}`);
}

function inkFor(id) {
  let h = 0;
  for (let i = 0; i < id.length; i++) h = (h * 31 + id.charCodeAt(i)) | 0;
  return INK[Math.abs(h) % INK.length];
}

export { recordSession };

export async function initShell({ onOpenPractice }) {
  const state = {
    songs: [],
    query: "",
    scoreKind: null,
    difficulty: null,
    genre: null,
    favoritesOnly: false,
    examId: null,
    examRecord: true,
    examRecordAudio: false,
  };

  async function loadCatalog() {
    const err = document.getElementById("lib-error");
    try {
      const res = await fetch(CATALOG_URL);
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const data = await res.json();
      const bundled = (data.songs || []).filter((s) => s.id);
      state.songs = await mergeCatalog(bundled);
      console.log("[PianoFlow/Web]", `曲库 ${state.songs.length} 首`);
      if (err) err.hidden = true;
    } catch (e) {
      console.error("[PianoFlow/Web]", e);
      if (err) {
        err.hidden = false;
        err.textContent = "曲库加载失败：请运行 serve.ps1，勿用 file://。" + String(e.message || e);
      }
    }
    renderAll();
  }

  function filtered() {
    const q = state.query.trim().toLowerCase();
    const favs = getFavorites();
    return state.songs.filter((s) => {
      if (state.favoritesOnly && !favs.has(s.id)) return false;
      if (state.scoreKind && s.scoreKind !== state.scoreKind) return false;
      if (state.difficulty && s.difficulty !== state.difficulty) return false;
      if (state.genre && s.genre !== state.genre) return false;
      if (!q) return true;
      return `${s.title} ${s.artist || ""} ${s.genre || ""} ${kindLabel(s.scoreKind)}`.toLowerCase().includes(q);
    });
  }

  function openSong(song, exam = false) {
    onOpenPractice(song, {
      exam,
      examRecord: state.examRecord,
      examRecordAudio: exam && state.examRecordAudio,
    });
  }

  function renderHome() {
    const recent = getRecent().map((id) => state.songs.find((s) => s.id === id)).filter(Boolean);
    const ul = document.getElementById("home-recent");
    ul.innerHTML = "";
    if (!recent.length) ul.innerHTML = "<li class='page-sub'>暂无 · 去曲库开练</li>";
    else recent.slice(0, 6).forEach((s) => {
      const li = document.createElement("li");
      li.textContent = `${s.title} · ${s.artist || ""}`;
      li.onclick = () => openSong(s);
      ul.appendChild(li);
    });
    const favUl = document.getElementById("home-favorites");
    if (favUl) {
      const favSongs = [...getFavorites()]
        .map((id) => state.songs.find((s) => s.id === id))
        .filter(Boolean);
      favUl.innerHTML = "";
      const openFavLibrary = () => {
        state.favoritesOnly = favSongs.length > 0;
        showTab("library");
      };
      const favBox = favUl.closest(".surface-box");
      const favTitle = favBox?.querySelector("h3");
      if (favTitle) {
        favTitle.style.cursor = "pointer";
        favTitle.title = "查看曲库收藏";
        favTitle.onclick = openFavLibrary;
      }
      if (!favSongs.length) {
        const li = document.createElement("li");
        li.className = "page-sub";
        li.textContent = "暂无 · 曲库点 ☆ 收藏";
        li.style.cursor = "pointer";
        li.onclick = openFavLibrary;
        favUl.appendChild(li);
      } else {
        favSongs.slice(0, 6).forEach((s) => {
          const li = document.createElement("li");
          li.textContent = `★ ${s.title} · ${s.artist || ""}`;
          li.onclick = () => openSong(s);
          favUl.appendChild(li);
        });
      }
    }
    const practiced = new Set(Object.keys(getStats().bySong || {}));
    const today = state.songs.find((s) => !practiced.has(s.id)) || state.songs[0];
    const box = document.getElementById("home-today");
    if (!today) box.textContent = "无曲目";
    else {
      box.innerHTML = `<strong>${today.title}</strong><br/><span class="page-sub">${today.artist || ""}</span>`;
      box.onclick = () => openSong(today);
      box.style.cursor = "pointer";
    }
    const cta = document.getElementById("home-cta");
    const cont = recent[0];
    const beginner = state.songs.find((s) => s.difficulty === 1) || state.songs[0];
    if (cont) {
      cta.textContent = `继续：${cont.title}`;
      cta.onclick = () => openSong(cont);
    } else if (beginner) {
      cta.textContent = "从入门曲开始";
      cta.onclick = () => openSong(beginner);
    } else {
      cta.textContent = "去曲库看看";
      cta.onclick = () => showTab("library");
    }
  }

  function renderLibrary() {
    const genres = [...new Set(state.songs.map((s) => s.genre).filter(Boolean))].sort();
    const filters = document.getElementById("lib-filters");
    filters.innerHTML = "";
    const favs = getFavorites();
    const add = (label, active, onClick) => {
      const b = document.createElement("button");
      b.type = "button";
      b.className = "chip-filter" + (active ? " active" : "");
      b.textContent = label;
      b.onclick = () => { onClick(); renderLibrary(); };
      filters.appendChild(b);
    };
    add("全部", !state.scoreKind && !state.difficulty && !state.genre && !state.favoritesOnly, () => {
      state.scoreKind = null;
      state.difficulty = null;
      state.genre = null;
      state.favoritesOnly = false;
    });
    add(favs.size ? `★ 收藏 (${favs.size})` : "★ 收藏", state.favoritesOnly, () => {
      state.favoritesOnly = !state.favoritesOnly;
    });
    for (const k of ["formal", "omrDraft", "simplified", "userImport"]) {
      if (!state.songs.some((s) => s.scoreKind === k)) continue;
      add(kindLabel(k), state.scoreKind === k, () => { state.scoreKind = k; });
    }
    for (const d of [1, 2, 3, 4]) add(difficultyLabel(d), state.difficulty === d, () => {
      state.difficulty = state.difficulty === d ? null : d;
    });
    for (const g of genres) add(g, state.genre === g, () => { state.genre = state.genre === g ? null : g; });

    const list = filtered();
    const countEl = document.getElementById("lib-count");
    if (!list.length) {
      countEl.textContent = state.favoritesOnly ? "暂无收藏" : "无匹配曲目";
    } else {
      countEl.textContent = state.favoritesOnly
        ? `${list.length} 首收藏`
        : `${list.length} 张唱片`;
    }
    if (state.scoreKind === "omrDraft") {
      document.getElementById("omr-hint").hidden = false;
    } else {
      document.getElementById("omr-hint").hidden = true;
    }
    const grid = document.getElementById("song-grid");
    grid.innerHTML = "";
    if (!list.length && state.favoritesOnly) {
      const empty = document.createElement("p");
      empty.className = "page-sub";
      empty.textContent = "还没有收藏。点封面右上角 ☆ 即可收藏。";
      grid.appendChild(empty);
      return;
    }
    for (const s of list) {
      const [hue, deep] = inkFor(s.id);
      const card = document.createElement("div");
      card.className = "album-card-wrap";
      const fav = favs.has(s.id);
      card.innerHTML = `
        <button type="button" class="album-card${fav ? " is-fav" : ""}" style="background:linear-gradient(135deg,${hue},${deep} 50%,#fff9f0)">
          <span class="kind">${kindLabel(s.scoreKind)}</span>
          ${fav ? '<span class="fav-badge">已收藏</span>' : ""}
          <strong>${s.title}</strong>
          <small>${s.artist || ""}</small>
        </button>
        <button type="button" class="fav-btn${fav ? " is-on" : ""}" title="${fav ? "取消收藏" : "收藏"}">${fav ? "★" : "☆"}</button>
        ${s.scoreKind === "userImport" ? '<button type="button" class="del-btn" title="删除">删</button>' : ""}
      `;
      card.querySelector(".album-card").onclick = () => openSong(s);
      card.querySelector(".fav-btn").onclick = (e) => {
        e.stopPropagation();
        toggleFavorite(s.id);
        renderLibrary();
        renderHome();
      };
      const del = card.querySelector(".del-btn");
      if (del) del.onclick = async (e) => {
        e.stopPropagation();
        if (!confirm(`删除自导入「${s.title}」？`)) return;
        await deleteUserImport(s.id);
        await loadCatalog();
      };
      grid.appendChild(card);
    }
  }

  function renderExam() {
    const q = (document.getElementById("exam-search").value || "").trim().toLowerCase();
    const list = state.songs.filter((s) => {
      if (!q) return true;
      return `${s.title} ${s.artist || ""}`.toLowerCase().includes(q);
    }).sort((a, b) => (a.difficulty || 99) - (b.difficulty || 99));
    const ul = document.getElementById("exam-list");
    ul.innerHTML = "";
    for (const s of list) {
      const li = document.createElement("li");
      li.textContent = `${s.title} · ${kindLabel(s.scoreKind)}`;
      if (s.id === state.examId) li.classList.add("active");
      li.onclick = () => { state.examId = s.id; renderExam(); };
      ul.appendChild(li);
    }
    const song = list.find((s) => s.id === state.examId);
    if (!song && list.length) state.examId = list[0].id;
    const sel = list.find((s) => s.id === state.examId);
    document.getElementById("exam-title").textContent = sel ? sel.title : "选择曲目";
    document.getElementById("exam-meta").textContent = sel
      ? `${sel.artist || ""} · ${kindLabel(sel.scoreKind)} · ${sel.bpm || "—"} BPM`
      : "";
    const hist = getStats().examHistory || [];
    document.getElementById("exam-history").textContent = hist.length
      ? `最近考试 ${hist.length} 次 · 上次 ${new Date(hist[0].at).toLocaleString()}`
      : "暂无考试记录";
    const histUl = document.getElementById("exam-history-list");
    if (histUl) {
      histUl.innerHTML = "";
      if (!hist.length) histUl.hidden = true;
      else {
        histUl.hidden = false;
        for (const h of hist.slice(0, 5)) {
          const s = state.songs.find((x) => x.id === h.songId);
          const li = document.createElement("li");
          li.className = "page-sub";
          li.textContent = `${s?.title || h.songId} · 完美 ${h.perfects} · 不错 ${h.goods} · ${new Date(h.at).toLocaleString()}`;
          li.onclick = () => {
            if (s) { state.examId = s.id; renderExam(); }
          };
          histUl.appendChild(li);
        }
      }
    }
    const start = document.getElementById("exam-start");
    start.disabled = !sel;
    start.onclick = () => sel && openSong(sel, true);
  }

  async function renderWorkshop() {
    const list = document.getElementById("user-import-list");
    const imports = state.songs.filter((s) => s.scoreKind === "userImport");
    list.innerHTML = imports.length
      ? imports.map((s) => `<li>${s.title}
        <button type="button" data-open="${s.id}" class="chip">练习</button>
        <button type="button" data-del="${s.id}" class="chip del-chip">删除</button></li>`).join("")
      : "<li class='page-sub'>暂无自导入</li>";
    list.querySelectorAll("button[data-open]").forEach((b) => {
      b.onclick = () => {
        const s = state.songs.find((x) => x.id === b.dataset.open);
        if (s) openSong(s);
      };
    });
    list.querySelectorAll("button[data-del]").forEach((b) => {
      b.onclick = async () => {
        const s = state.songs.find((x) => x.id === b.dataset.del);
        if (!s || !confirm(`删除自导入「${s.title}」？`)) return;
        await deleteUserImport(s.id);
        await loadCatalog();
      };
    });
    const pdfHint = document.getElementById("pdf-stage-hint");
    if (pdfHint) {
      try {
        const pdfs = await listStagedPdfs();
        pdfHint.textContent = pdfs.length
          ? `已暂存 ${pdfs.length} 个 PDF（最近：${pdfs[pdfs.length - 1].name}）`
          : "暂无暂存 PDF";
      } catch (e) {
        pdfHint.textContent = "";
      }
    }
  }

  function refreshProfile() {
    const s = getStats();
    document.getElementById("stat-sessions").textContent = String(s.totalSessions || 0);
    document.getElementById("stat-songs").textContent = String(Object.keys(s.bySong || {}).length);
    refreshAuthUi();
  }

  function renderAll() {
    renderHome();
    renderLibrary();
    renderExam();
    renderWorkshop();
    refreshProfile();
  }

  function showTab(tab) {
    document.querySelectorAll(".tab-pane").forEach((p) => p.classList.remove("active"));
    document.getElementById(`tab-${tab}`)?.classList.add("active");
    document.querySelectorAll("[data-tab]").forEach((b) => {
      b.classList.toggle("active", b.dataset.tab === tab);
    });
    location.hash = tab;
    if (tab === "home") renderHome();
    if (tab === "library") renderLibrary();
    if (tab === "exam") renderExam();
    if (tab === "workshop") renderWorkshop();
    if (tab === "profile") refreshProfile();
  }

  document.querySelectorAll("[data-tab]").forEach((b) => {
    b.addEventListener("click", () => showTab(b.dataset.tab));
  });
  document.querySelectorAll("[data-goto]").forEach((b) => {
    b.addEventListener("click", () => showTab(b.dataset.goto));
  });
  document.getElementById("lib-search").oninput = (e) => {
    state.query = e.target.value;
    renderLibrary();
  };
  document.getElementById("exam-search").oninput = () => renderExam();
  document.getElementById("exam-record").onchange = (e) => {
    state.examRecord = e.target.checked;
  };
  document.getElementById("exam-record-audio")?.addEventListener("change", (e) => {
    state.examRecordAudio = e.target.checked;
  });
  document.getElementById("import-mxml").onchange = async (e) => {
    const f = e.target.files?.[0];
    if (!f) return;
    const status = document.getElementById("workshop-status");
    try {
      status.textContent = "导入中…";
      const xml = await readFileAsText(f);
      await importMusicXmlText(xml, f.name);
      status.textContent = `已导入：${f.name}`;
      await loadCatalog();
      showTab("library");
    } catch (err) {
      console.error("[PianoFlow/Web/Workshop]", err);
      status.textContent = "导入失败：" + (err.message || err);
    }
    e.target.value = "";
  };
  document.getElementById("import-midi")?.addEventListener("change", async (e) => {
    const f = e.target.files?.[0];
    if (!f) return;
    const status = document.getElementById("workshop-status");
    try {
      status.textContent = "MIDI 导入中…";
      const buf = await readFileAsArrayBuffer(f);
      await importMidiBytes(buf, f.name);
      status.textContent = `MIDI 已导入：${f.name}`;
      await loadCatalog();
      showTab("library");
    } catch (err) {
      console.error("[PianoFlow/Web/Workshop]", err);
      status.textContent = "MIDI 导入失败：" + (err.message || err);
    }
    e.target.value = "";
  });
  document.getElementById("import-audio")?.addEventListener("change", async (e) => {
    const f = e.target.files?.[0];
    if (!f) return;
    const status = document.getElementById("workshop-status");
    try {
      status.textContent = "音频转录中（草稿）…";
      await importAudioFile(f);
      status.textContent = `音频已导入：${f.name}`;
      await loadCatalog();
      showTab("library");
    } catch (err) {
      console.error("[PianoFlow/Web/Workshop]", err);
      status.textContent = "音频导入失败：" + (err.message || err);
    }
    e.target.value = "";
  });
  document.getElementById("import-pdf")?.addEventListener("change", async (e) => {
    const f = e.target.files?.[0];
    if (!f) return;
    const status = document.getElementById("workshop-status");
    const pdfHint = document.getElementById("pdf-stage-hint");
    try {
      status.textContent = "PDF 暂存中…";
      const staged = await stagePdfFile(f);
      status.textContent = staged.guide;
      if (pdfHint) pdfHint.textContent = `已暂存：${staged.name}`;
    } catch (err) {
      console.error("[PianoFlow/Web/Workshop]", err);
      status.textContent = "PDF 暂存失败：" + (err.message || err);
    }
    e.target.value = "";
  });
  document.getElementById("btn-settings")?.addEventListener("click", () => {
    document.getElementById("settings-dlg").showModal();
  });
  document.getElementById("settings-close")?.addEventListener("click", () => {
    document.getElementById("settings-dlg").close();
  });

  const hash = (location.hash || "#home").slice(1);
  await loadCatalog();
  showTab(["home", "library", "exam", "workshop", "profile"].includes(hash) ? hash : "home");

  return {
    showTab,
    getSongs: () => state.songs,
    refreshProfile,
    getUserScoreJson,
    getUserMusicXml,
    reload: loadCatalog,
  };
}
