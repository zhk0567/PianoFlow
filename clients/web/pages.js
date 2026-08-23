/** Sub-pages: login, constellation, sandbox, pitch-test */
import { getAuth, login, enterGuest, logout, getStats } from "./storage.js";
import { playMidi, setMasterVolume, getMasterVolume } from "./audio.js";
import { initPitchEngine, processPitchPcm16, getPitchEngineLabel } from "./pitch-engine.js";

let micStop = null;

export function bindSubPages({ onAuthChange, getSongs, onOpenPractice }) {
  const loginDlg = document.getElementById("login-dlg");
  const constDlg = document.getElementById("constellation-dlg");
  const sandDlg = document.getElementById("sandbox-dlg");
  const pitchDlg = document.getElementById("pitch-dlg");

  document.getElementById("btn-login")?.addEventListener("click", () => {
    loginDlg.showModal();
  });
  document.getElementById("btn-logout")?.addEventListener("click", () => {
    logout();
    onAuthChange();
  });
  document.getElementById("login-guest")?.addEventListener("click", () => {
    enterGuest();
    loginDlg.close();
    onAuthChange();
  });
  document.getElementById("login-submit")?.addEventListener("click", () => {
    const email = document.getElementById("login-email").value;
    const pass = document.getElementById("login-pass").value;
    const name = document.getElementById("login-name").value;
    const err = login(email, pass, name);
    const el = document.getElementById("login-err");
    if (err) {
      el.textContent = err;
      el.hidden = false;
      return;
    }
    el.hidden = true;
    loginDlg.close();
    onAuthChange();
  });

  document.getElementById("btn-constellation")?.addEventListener("click", () => {
    renderConstellation(getSongs());
    constDlg.showModal();
  });
  document.getElementById("btn-sandbox")?.addEventListener("click", () => {
    sandDlg.showModal();
    bindSandboxKeys();
  });
  document.getElementById("btn-pitch-test")?.addEventListener("click", () => {
    pitchDlg.showModal();
    startPitchTest();
  });

  [constDlg, sandDlg, pitchDlg].forEach((d) => {
    d?.addEventListener("close", () => stopPitchTest());
  });
}

export function refreshAuthUi() {
  const a = getAuth();
  const name = a.guest ? "访客" : a.name || a.email || "用户";
  const sub = a.guest ? "点击登录保存本地账号" : a.email || "";
  document.getElementById("profile-name").textContent = name;
  document.getElementById("profile-sub").textContent = sub;
  document.querySelector(".avatar").textContent = name.charAt(0) || "访";
  document.getElementById("btn-login").hidden = !a.guest;
  document.getElementById("btn-logout").hidden = a.guest;
}

function renderConstellation(songs) {
  const stats = getStats();
  const byId = Object.fromEntries(songs.map((s) => [s.id, s]));
  const lit = Object.entries(stats.bySong || {}).filter(([, v]) => v.lit || v.sessions > 0);
  const grid = document.getElementById("constellation-grid");
  grid.innerHTML = "";
  if (!lit.length) {
    grid.innerHTML = "<p class='page-sub'>还没有点亮的曲子，去练一首吧</p>";
    return;
  }
  for (const [id] of lit) {
    const s = byId[id];
    if (!s) continue;
    const star = document.createElement("button");
    star.type = "button";
    star.className = "star-tile";
    star.textContent = s.title;
    star.onclick = () => {
      document.getElementById("constellation-dlg").close();
      onOpenPractice?.(s);
    };
    grid.appendChild(star);
  }
}

let onOpenPractice;

export function setPracticeOpener(fn) {
  onOpenPractice = fn;
}

function bindSandboxKeys() {
  const canvas = document.getElementById("sandbox-keys");
  if (!canvas._bound) {
    canvas._bound = true;
    canvas.addEventListener("click", (ev) => {
      const rect = canvas.getBoundingClientRect();
      const x = ((ev.clientX - rect.left) / rect.width) * 88;
      const midi = 21 + Math.max(0, Math.min(87, Math.round(x)));
      playMidi(midi);
    });
  }
  document.getElementById("sandbox-metro")?.addEventListener("click", () => playMidi(60, 0, 0.4));
  const vol = document.getElementById("sandbox-volume");
  vol.value = String(Math.round(getMasterVolume() * 100));
  vol.oninput = () => setMasterVolume(Number(vol.value) / 100);
}

function startPitchTest() {
  stopPitchTest();
  const label = document.getElementById("pitch-label");
  label.textContent = "初始化音高引擎…";
  initPitchEngine().then((engine) => {
    label.textContent = `对着麦克风演奏（${getPitchEngineLabel()}）`;
    return navigator.mediaDevices.getUserMedia({ audio: true });
  }).then((stream) => {
    const ac = new AudioContext({ sampleRate: 22050 });
    const src = ac.createMediaStreamSource(stream);
    const proc = ac.createScriptProcessor(2048, 1, 1);
    proc.onaudioprocess = (ev) => {
      const f32 = ev.inputBuffer.getChannelData(0);
      const pcm = new Int16Array(f32.length);
      for (let i = 0; i < f32.length; i++) {
        const s = Math.max(-1, Math.min(1, f32[i]));
        pcm[i] = (s * 32767) | 0;
      }
      processPitchPcm16(pcm, ac.sampleRate || 22050).then((midis) => {
        if (midis.size) label.textContent = `识别 MIDI: ${[...midis].join(", ")}`;
      }).catch(() => {});
    };
    src.connect(proc);
    proc.connect(ac.destination);
    micStop = () => {
      try { proc.disconnect(); } catch (_) {}
      try { ac.close(); } catch (_) {}
      stream.getTracks().forEach((t) => t.stop());
      micStop = null;
    };
  }).catch(() => {
    label.textContent = "需要麦克风权限";
  });
}

function stopPitchTest() {
  micStop?.();
  const label = document.getElementById("pitch-label");
  if (label) label.textContent = "对着麦克风演奏";
}
