import { playMidi, unlockAudio, setMasterVolume, getMasterVolume } from "./audio.js";
import { initShell, kindLabel } from "./shell.js";
import { recordSession, pushRecent, toggleFavorite, getFavorites, getVisualFxEnabled, setVisualFxEnabled } from "./storage.js";
import { bindSubPages, setPracticeOpener } from "./pages.js";
import { initPitchEngine, processPitchPcm16, getPitchEngineLabel, setScorePriorMidis, clearScorePriorMidis } from "./pitch-engine.js";
import { matchNoteOn, isForgivableWrongPitch, priorBins } from "./pitch-match.js";
import { CueBleedGuard } from "./cue-bleed-guard.js";
import { PracticeFx } from "./practice-fx.js";
import { ExamPcmRecorder } from "./exam-pcm.js";
import {
  bindCanvas,
  drawWaterfallBackground,
  drawLaneGuides,
  drawFallingNote,
  drawHitLineGlow,
  drawKeyboard,
  hitLineY,
  phaseFromBeats,
} from "./practice-stage.js";
import {
  PracticeConsts,
  parseScoreJson,
  filterHand,
  expectedAt,
  shouldFreeze,
  nudgePast,
  gradeDelta,
  buildGeo,
  contentWidthFor,
  isMobilePractice,
} from "./practice-core.js";

const el = {
  shell: document.getElementById("app-shell"),
  practice: document.getElementById("practice"),
  title: document.getElementById("practice-title"),
  meta: document.getElementById("practice-meta"),
  status: document.getElementById("status"),
  grade: document.getElementById("grade"),
  frame: document.getElementById("staff-frame"),
  back: document.getElementById("btn-back"),
  auto: document.getElementById("btn-auto"),
  follow: document.getElementById("btn-follow"),
  play: document.getElementById("btn-play"),
  restart: document.getElementById("btn-restart"),
  handBoth: document.getElementById("btn-hand-both"),
  handLeft: document.getElementById("btn-hand-left"),
  handRight: document.getElementById("btn-hand-right"),
  fx: document.getElementById("btn-fx"),
  practiceSettings: document.getElementById("btn-practice-settings"),
  speed: document.getElementById("speed"),
  speedLabel: document.getElementById("speed-label"),
  seek: document.getElementById("seek"),
  fall: document.getElementById("fall"),
  keys: document.getElementById("keys"),
  practice: document.getElementById("practice"),
  stageScroll: document.getElementById("stage-scroll"),
  stageInner: document.getElementById("stage-inner"),
  staffPanel: document.querySelector(".staff-panel"),
  staffScrub: document.getElementById("staff-scrub"),
  settleDlg: document.getElementById("settle-dlg"),
  settleMsg: document.getElementById("settle-msg"),
  settleWeak: document.getElementById("settle-weak"),
  settleAgain: document.getElementById("settle-again"),
  settleLib: document.getElementById("settle-lib"),
  fav: document.getElementById("btn-fav"),
  volume: document.getElementById("volume"),
  hitFlash: document.getElementById("hit-flash"),
  comboBadge: document.getElementById("combo-badge"),
  settleListen: document.getElementById("settle-listen"),
};

const practiceFx = new PracticeFx();
const examPcm = new ExamPcmRecorder();
practiceFx.setEnabled(practiceVisualEnabled());

const state = {
  song: null,
  allNotes: [],
  notes: [],
  mode: "auto",
  exam: false,
  examRecord: true,
  examRecordAudio: false,
  hasSessionActivity: false,
  playing: false,
  positionBeats: -PracticeConsts.playbackLeadInBeats,
  pressed: new Set(),
  waitingFor: new Set(),
  bpm: 72,
  durationBeats: 1,
  lastAutoFire: -1,
  staffReady: false,
  raf: 0,
  lastTs: 0,
  micStream: null,
  micProc: null,
  micCtx: null,
  speed: 1,
  hand: "both",
  guideAudio: true,
  metronome: false,
  lastMetroBeat: -1,
  satisfied: new Set(),
  attackSpent: new Set(),
  /** midi → performance.now() when consumed (onset refractory). */
  attackSpentAt: new Map(),
  /** midi → consecutive quiet hops while spent. */
  attackQuietHops: new Map(),
  echoUntil: 0,
  cueBleed: new CueBleedGuard(),
  lastCueChord: -1,
  frozenMissLogged: false,
  missBeats: [],
  perfects: 0,
  goods: 0,
  combo: 0,
  lastGrade: null,
  settlementArmed: false,
  geo: null,
  focusMidi: null,
  seekDragging: false,
  weakPending: null,
  sessionStartedAt: 0,
  lastAutoPos: null,
  recentTimer: 0,
};

let shellApi = null;

function setStatus(msg) {
  el.status.textContent = msg;
  console.log("[PianoFlow/Web]", msg);
}

const recentPromoteMs = 5 * 60 * 1000;

function armRecentPromote(songId) {
  if (state.recentTimer) clearTimeout(state.recentTimer);
  state.recentTimer = setTimeout(() => {
    state.recentTimer = 0;
    if (!state.song || state.song.id !== songId) return;
    pushRecent(songId);
    console.log("[PianoFlow/Library] recent promote after 5min open:", songId);
  }, recentPromoteMs);
}

function cancelRecentPromote() {
  if (state.recentTimer) clearTimeout(state.recentTimer);
  state.recentTimer = 0;
}

function staffWin() {
  return el.frame?.contentWindow || null;
}

async function waitPfReady(timeoutMs = 20000) {
  const t0 = performance.now();
  while (performance.now() - t0 < timeoutMs) {
    const w = staffWin();
    try {
      if (w && typeof w.pfReady === "function" && w.pfReady()) return true;
    } catch (_) {}
    await new Promise((r) => setTimeout(r, 100));
  }
  return false;
}

function practiceVisualEnabled() {
  return getVisualFxEnabled() && !isMobilePractice();
}

function applyGeometry() {
  const mobile = isMobilePractice();
  const body = document.querySelector(".practice-body");
  const totalH = body?.clientHeight || 560;
  const keyH = mobile ? 108 : 120;
  const gap = mobile ? 0 : 4;
  const staffH = mobile
    ? Math.max(200, Math.floor(totalH * 0.52))
    : Math.max(180, Math.floor((totalH - keyH - gap) * 0.58));
  const fallH = mobile ? 0 : Math.max(120, totalH - keyH - gap - staffH);
  const vw = el.stageScroll?.clientWidth || window.innerWidth || 800;
  const cw = contentWidthFor(vw, { fitViewport: mobile });
  state.geo = buildGeo(cw);
  bindCanvas(el.keys, cw, keyH);
  el.keys.style.height = `${keyH}px`;
  el.stageInner.style.width = mobile ? "100%" : `${cw}px`;
  el.stageScroll.style.height = `${(mobile ? 0 : fallH) + keyH}px`;
  el.stageScroll.style.overflowX = mobile ? "hidden" : "";
  if (mobile) {
    el.fall.style.display = "none";
    el.fall.style.height = "0";
  } else {
    el.fall.style.display = "";
    el.fall.style.height = `${fallH}px`;
    bindCanvas(el.fall, cw, fallH);
  }
  if (el.staffPanel) {
    el.staffPanel.style.flex = `0 0 ${staffH}px`;
    el.staffPanel.style.height = `${staffH}px`;
  }
  resizeStaff();
}

function scrollToFocus() {
  if (isMobilePractice()) return;
  if (!state.geo || state.focusMidi == null) return;
  const cx = state.geo.midiCenterX(state.focusMidi);
  if (cx == null) return;
  const target = Math.max(0, cx - el.stageScroll.clientWidth / 2);
  el.stageScroll.scrollTo({ left: target, behavior: "smooth" });
}

function staffLayoutOpts() {
  const frame = el.frame;
  const w = Math.max(1, frame?.clientWidth || el.staffPanel?.clientWidth || 360);
  const h = Math.max(1, frame?.clientHeight || el.staffPanel?.clientHeight || 280);
  const mobile = isMobilePractice();
  // Fixed scale=60 for every score (Windows parity). Never vary by song/lane.
  return {
    cssWidth: mobile ? w : Math.max(640, w),
    cssHeight: Math.max(mobile ? 200 : 280, h),
    scale: 60,
    pageHeight: 900,
    mobile,
  };
}

function resizeStaff() {
  if (!state.staffReady) return;
  const w = staffWin();
  if (!w || typeof w.pfResize !== "function") return;
  try {
    w.pfResize(staffLayoutOpts());
  } catch (e) {
    console.warn("[PianoFlow/Web] pfResize", e);
  }
}

async function loadScoreIntoVerovio(xmlPath) {
  const ready = await waitPfReady();
  if (!ready) {
    setStatus("Verovio 未就绪");
    return;
  }
  const w = staffWin();
  const url = new URL(xmlPath, window.location.href).href;
  const opts = staffLayoutOpts();
  try {
    if (typeof w.pfLoadFromUrlAsync === "function") w.pfLoadFromUrlAsync(url, opts);
    else if (typeof w.pfLoadFromUrl === "function") w.pfLoadFromUrl(url, opts);
    state.staffReady = true;
    setStatus("谱面就绪");
  } catch (e) {
    console.error("[PianoFlow/Web]", e);
    setStatus("谱面加载失败（详情见控制台 [PianoFlow/Web]）");
  }
}

/** Align Windows VerovioTransportSync.playPushMinIntervalMs = 32 */
const STAFF_PUSH_MIN_MS = 32;
const STAFF_POS_MIN_DELTA = 0.01;
const STAFF_SEEK_SNAP = 0.35;
let _lastStaffPushAt = 0;
let _lastStaffPushBeats = NaN;

function pushPosition(force = false) {
  if (!state.staffReady) return;
  const w = staffWin();
  if (!w || typeof w.pfSetPosition !== "function") return;
  const beats = Math.max(0, state.positionBeats);
  const now = performance.now();
  const posDelta = Number.isNaN(_lastStaffPushBeats)
    ? 1
    : Math.abs(beats - _lastStaffPushBeats);
  const forceImmediate = force || !!state.seekDragging;
  if (
    !forceImmediate &&
    posDelta <= STAFF_SEEK_SNAP &&
    now - _lastStaffPushAt < STAFF_PUSH_MIN_MS &&
    (state.playing || posDelta <= STAFF_POS_MIN_DELTA)
  ) {
    return;
  }
  let rate = 0;
  if (state.playing && state.mode === "auto") rate = (state.bpm * state.speed) / 60;
  else if (state.playing && state.mode === "follow" && state.waitingFor.size === 0) {
    rate = (state.bpm * state.speed) / 60;
  }
  try {
    w.pfSetPosition(beats, forceImmediate, rate);
    _lastStaffPushAt = now;
    _lastStaffPushBeats = beats;
  } catch (_) {}
}

function drawFall() {
  if (isMobilePractice()) return;
  const cssH = el.fall.clientHeight || 220;
  const cssW = state.geo?.contentWidth || el.fall.clientWidth || 800;
  const { ctx, w, h } = bindCanvas(el.fall, cssW, cssH);
  const g = state.geo;
  if (!g) return;
  const fx = practiceVisualEnabled();
  const phase = phaseFromBeats(state.positionBeats);
  const hitY = drawWaterfallBackground(ctx, w, h, { fx, phase });
  drawLaneGuides(ctx, g, hitY, { fx, phase });

  const lookAhead = 4;
  const laneSpan = h * 0.82;
  const pos = state.positionBeats;
  for (const n of state.notes) {
    const dy = (n.start - pos) / lookAhead;
    if (dy < -0.35 || dy > 1.3) continue;
    const bottom = hitY - dy * laneSpan;
    const nh = Math.min(h * 0.45, Math.max(14, (n.duration / lookAhead) * laneSpan * 0.55));
    const top = bottom - nh;
    if (bottom < -12 || top > h + 12) continue;
    const cx = g.midiCenterX(n.midi);
    if (cx == null) continue;
    const nw = g.isBlack(n.midi) ? g.blackWidth * 0.85 : g.whiteWidth * 0.72;
    const delta = n.start - pos;
    const waiting = state.waitingFor.has(n.midi)
      && delta <= PracticeConsts.waitEarlyHitBeats
      && delta >= -0.12;
    drawFallingNote(ctx, {
      cx, top, bottom, nw, hand: n.hand, waiting, fx, phase,
    });
  }

  drawHitLineGlow(ctx, w, hitY, { fx });
  practiceFx.draw(ctx, w, h, hitY);
}

function drawKeys() {
  const cssH = el.keys.clientHeight || 120;
  const cssW = state.geo?.contentWidth || el.keys.clientWidth || 800;
  const { ctx, h } = bindCanvas(el.keys, cssW, cssH);
  const g = state.geo;
  if (!g) return;
  const lit = state.pressed.size ? state.pressed : state.waitingFor;
  drawKeyboard(ctx, g, h, lit, { fx: practiceVisualEnabled() });
}

function updateFocus() {
  const pos = Math.max(0, state.positionBeats);
  const n = state.notes.find((x) => x.start >= pos - 0.02) || state.notes[state.notes.length - 1];
  if (n) state.focusMidi = n.midi;
}

function render() {
  const mobile = isMobilePractice();
  const fx = practiceVisualEnabled();
  el.practice?.classList.toggle("practice--fx", fx);
  el.practice?.classList.toggle("practice--mobile", mobile);
  if (!mobile) drawFall();
  drawKeys();
  pushPosition();
  scrollToFocus();
  el.play.textContent = state.playing ? "⏸" : "▶";
  el.play.setAttribute("aria-label", state.playing ? "暂停" : "播放");
  el.seek.disabled = state.exam;
  el.auto.classList.toggle("active", state.mode === "auto");
  el.follow.classList.toggle("active", state.mode === "follow");
  el.handBoth.classList.toggle("active", state.hand === "both");
  el.handLeft.classList.toggle("active", state.hand === "left");
  el.handRight.classList.toggle("active", state.hand === "right");
  el.fx?.classList.toggle("active", practiceVisualEnabled());
  if (el.speedLabel) {
    el.speedLabel.textContent = `${Math.round(state.speed * 100)}%`;
  }
  // 段末日常结算不弹窗；命中浮字由 flashHit 负责。
  el.grade.textContent = "";
  if (!state.seekDragging && state.durationBeats > 0) {
    el.seek.value = String(
      Math.round((Math.max(0, state.positionBeats) / state.durationBeats) * 1000),
    );
  }
}

function fireAutoNotes() {
  const pos = state.positionBeats;
  const window = state.notes.filter(
    (n) => n.start > state.lastAutoFire + 1e-6 && n.start <= pos + 1e-4,
  );
  if (!window.length) return;
  state.lastAutoFire = Math.max(...window.map((n) => n.start));
  const midis = [...new Set(window.map((n) => n.midi))];
  state.pressed = new Set(midis);
  midis.forEach((m) => playMidi(m));
}

function tickMetro() {
  if (!state.metronome || !state.playing) return;
  if (state.mode === "follow" && state.waitingFor.size) return;
  const beat = Math.floor(state.positionBeats);
  if (beat >= 0 && beat !== state.lastMetroBeat) {
    state.lastMetroBeat = beat;
    playMidi(60, 0, 0.35);
  }
}

function nextOnset(expected) {
  for (const n of state.notes) {
    if (expected.has(n.midi)) return n.start;
  }
  return null;
}

function tickFollow(dt, beatsPerSec) {
  const pos = state.positionBeats;
  const expected = expectedAt(state.notes, pos);
  state.waitingFor = new Set([...expected].filter((m) => !state.satisfied.has(m)));
  const chordStart = nextOnset(expected);
  const freeze = chordStart != null && expected.size > 0 && shouldFreeze(pos, chordStart);
  if (freeze) {
    if (state.guideAudio && chordStart !== state.lastCueChord) {
      state.lastCueChord = chordStart;
      const toCue = [...state.waitingFor];
      if (toCue.length) {
        toCue.forEach((m) => playMidi(m));
        state.echoUntil = performance.now() + PracticeConsts.echoSuppressGuideMs;
        state.cueBleed.arm(toCue);
      }
    }
    state.pressed = new Set(state.waitingFor);
  } else {
    state.positionBeats = Math.min(state.durationBeats, state.positionBeats + dt * beatsPerSec);
    if (expected.size === 0) {
      state.satisfied.clear();
      state.attackSpent.clear();
      state.attackSpentAt.clear();
      state.attackQuietHops.clear();
      state.lastCueChord = -1;
      state.frozenMissLogged = false;
    }
    state.pressed = expected;
    tickMetro();
  }
  updateFocus();
  if (state.positionBeats >= state.durationBeats) finishRun();
}

function tick(ts) {
  if (!state.playing) {
    state.raf = 0;
    return;
  }
  if (!state.lastTs) state.lastTs = ts;
  const dt = (ts - state.lastTs) / 1000;
  state.lastTs = ts;
  const beatsPerSec = (state.bpm * state.speed) / 60;
  if (state.mode === "auto") {
    state.positionBeats = Math.min(state.durationBeats, state.positionBeats + dt * beatsPerSec);
    const prev = state.lastAutoPos;
    if (practiceVisualEnabled() && state.geo) {
      const fh = el.fall.clientHeight || 200;
      practiceFx.autoplayAt(
        state.notes,
        state.positionBeats,
        prev,
        state.geo,
        hitLineY(fh),
        state.geo.contentWidth,
      );
    }
    state.lastAutoPos = state.positionBeats;
    fireAutoNotes();
    tickMetro();
    updateFocus();
    if (state.positionBeats >= state.durationBeats) finishRun();
  } else {
    tickFollow(dt, beatsPerSec);
  }
  render();
  state.raf = requestAnimationFrame(tick);
}

function play() {
  unlockAudio();
  if (!state.notes.length) {
    setStatus("无音符可播放");
    return;
  }
  state.playing = true;
  state.settlementArmed = true;
  if (!state.sessionStartedAt) state.sessionStartedAt = performance.now();
  if (state.exam && state.examRecordAudio && !examPcm.active) {
    examPcm.start(state.song?.id || "exam");
  }
  state.lastTs = 0;
  setStatus(state.mode === "follow" ? (state.exam ? "考试跟弹中" : "跟弹中") : "自动播放");
  if (state.mode === "follow") startMic();
  if (!state.raf) state.raf = requestAnimationFrame(tick);
  render();
}

function pause() {
  state.playing = false;
  stopMic();
  if (state.raf) cancelAnimationFrame(state.raf);
  state.raf = 0;
  render();
}

function restartTransport(clearStats) {
  state.positionBeats = -PracticeConsts.playbackLeadInBeats;
  state.lastAutoFire = -1;
  state.lastMetroBeat = -1;
  state.pressed = new Set();
  state.waitingFor = new Set();
  state.satisfied.clear();
  state.attackSpent.clear();
  state.attackSpentAt.clear();
  state.attackQuietHops.clear();
  state.cueBleed.clear();
  state.frozenMissLogged = false;
  state.lastCueChord = -1;
  if (clearStats) {
    state.perfects = 0;
    state.goods = 0;
    state.combo = 0;
    state.lastGrade = null;
    state.missBeats = [];
    state.sessionStartedAt = 0;
    state.lastAutoPos = null;
  }
  updateFocus();
}

function restart() {
  pause();
  restartTransport(true);
  setStatus("已重来");
  render();
}

function seek(beats) {
  // Slider / staff scrub while playing → pause; no auto-resume on release.
  if (state.playing) pause();
  const b = Math.max(0, Math.min(state.durationBeats, beats));
  state.positionBeats = b <= 0.05 ? -PracticeConsts.playbackLeadInBeats : b;
  state.lastAutoFire = state.positionBeats - 1e-3;
  state.satisfied.clear();
  state.attackSpent.clear();
  state.attackSpentAt.clear();
  state.attackQuietHops.clear();
  state.waitingFor = new Set();
  state.pressed = new Set();
  state.frozenMissLogged = false;
  state.lastCueChord = -1;
  updateFocus();
  render();
}

function recomputeNotes() {
  state.notes = filterHand(state.allNotes, state.hand);
  state.durationBeats = Math.max(1, ...state.notes.map((n) => n.start + n.duration), 1);
}

function flashHit() {
  if (el.hitFlash) {
    el.hitFlash.hidden = false;
    el.hitFlash.offsetHeight;
    el.hitFlash.hidden = true;
  }
  // Windows HitFeedbackOverlay parity: 完美 / 不错 floating grade.
  if (el.grade && state.lastGrade) {
    el.grade.textContent = state.lastGrade === "perfect" ? "完美" : "不错";
    el.grade.classList.remove("grade-flash");
    void el.grade.offsetWidth;
    el.grade.classList.add("grade-flash");
    clearTimeout(flashHit._gradeT);
    flashHit._gradeT = setTimeout(() => {
      el.grade.textContent = "";
      el.grade.classList.remove("grade-flash");
    }, 420);
  }
  if (el.comboBadge && state.combo >= 3) {
    el.comboBadge.textContent = `连击 ${state.combo}`;
    el.comboBadge.hidden = false;
    el.comboBadge.offsetHeight;
    clearTimeout(flashHit._t);
    flashHit._t = setTimeout(() => { el.comboBadge.hidden = true; }, 450);
  }
}

function setMode(mode) {
  if (state.exam && mode === "auto") return;
  pause();
  state.mode = mode;
  setStatus(mode === "follow" ? "跟弹模式" : "自动模式");
  render();
}

function finishRun() {
  state.playing = false;
  if (state.exam && state.examRecordAudio) examPcm.stop();
  stopMic();
  if (state.raf) cancelAnimationFrame(state.raf);
  state.raf = 0;
  setStatus("本段结束");
  const followOrExam = state.mode === "follow" || state.exam;
  const activity = state.perfects > 0 || state.goods > 0 || state.missBeats.length > 0;
  if (state.song && followOrExam && activity) {
    recordSession(state.song.id, {
      exam: state.exam,
      recordExam: state.examRecord,
      perfects: state.perfects,
      goods: state.goods,
      combo: state.combo,
    });
    shellApi?.refreshProfile();
  }
  render();
  // 平时跟弹：recordSession 已写入；仅考试弹结算（含得分/再考）。
  if (state.settlementArmed && state.exam) {
    state.settlementArmed = false;
    showSettlement();
  } else if (state.settlementArmed) {
    state.settlementArmed = false;
  }
}

function showSettlement() {
  // 仅考试调用；不再提供「练薄弱段」入口。
  state.weakPending = null;
  el.settleMsg.textContent = `完美 ${state.perfects} · 不错 ${state.goods} · 连击 ${state.combo}`;
  el.settleWeak.hidden = true;
  if (el.settleListen) {
    el.settleListen.hidden = !examPcm.url;
  }
  el.settleDlg.showModal();
}

function onPitch(midi, onset = false) {
  if (state.mode !== "follow" || !state.playing) return;
  if (performance.now() < state.echoUntil) return;
  const pos = state.positionBeats;
  const expected = expectedAt(state.notes, pos);
  if (!expected.size) return;
  const chordStart = nextOnset(expected);
  if (chordStart == null) return;
  const remaining = new Set([...expected].filter((m) => !state.satisfied.has(m)));
  setScorePriorMidis(priorBins(remaining));

  const now = performance.now();
  const onsetRefractoryMs = 180;
  if (onset) {
    for (const s of [...state.attackSpent]) {
      if (Math.abs(s - midi) > 1 && Math.abs(s - midi) !== 12) continue;
      const at = state.attackSpentAt.get(s) ?? 0;
      if (now - at < onsetRefractoryMs) continue; // sustain flux — keep latch
      state.attackSpent.delete(s);
      state.attackSpentAt.delete(s);
      state.attackQuietHops.delete(s);
    }
  }

  if (
    state.cueBleed.isBleed(midi, onset, new Set([midi, ...state.pressed]))
  ) {
    console.log("[PianoFlow/Web] cue-bleed block", midi);
    return;
  }

  const freeze = shouldFreeze(pos, chordStart);
  if (freeze && remaining.size && !isForgivableWrongPitch(midi, remaining)) {
    if (!state.frozenMissLogged) {
      state.frozenMissLogged = true;
      state.missBeats.push(chordStart);
      state.combo = 0;
      console.log("[PianoFlow/Web] miss", chordStart, midi, [...remaining]);
    }
    return;
  }
  const hit = matchNoteOn(midi, remaining);
  if (hit == null) return;
  if (state.attackSpent.has(hit) || state.attackSpent.has(midi)) return;
  state.satisfied.add(hit);
  state.attackSpent.add(hit);
  state.attackSpent.add(midi);
  state.attackSpentAt.set(hit, now);
  state.attackSpentAt.set(midi, now);
  state.attackQuietHops.delete(hit);
  state.attackQuietHops.delete(midi);
  state.pressed = new Set([hit]);
  const grade = gradeDelta(pos - chordStart);
  state.lastGrade = grade;
  if (grade === "perfect") state.perfects++;
  else state.goods++;
  state.combo++;
  flashHit();
  const g = state.geo;
  const cx = g?.midiCenterX(hit);
  const fh = el.fall.clientHeight || 200;
  const hitY = hitLineY(fh);
  practiceFx.hit(hit, cx, grade, state.combo, hitY, g?.contentWidth);
  const left = new Set([...expected].filter((m) => !state.satisfied.has(m)));
  state.waitingFor = left;
  setScorePriorMidis(priorBins(left));
  if (!left.size) {
    state.positionBeats = nudgePast(state.notes, chordStart);
    state.satisfied.clear();
    // Keep attackSpent — same physical strike must not clear the next same pitch.
    state.frozenMissLogged = false;
    state.lastCueChord = -1;
    state.waitingFor = new Set();
    clearScorePriorMidis();
  }
  updateFocus();
  render();
}

/** Quiet-release spent pitches (~2 hops ≈ Flutter post-hit bar is longer; use 5). */
function tickAttackQuiet(heard) {
  if (!state.attackSpent.size) return;
  const postHitQuietHops = 5;
  for (const s of [...state.attackSpent]) {
    let still = false;
    for (const m of heard) {
      if (Math.abs(s - m) <= 1 || Math.abs(s - m) === 12) {
        still = true;
        break;
      }
    }
    if (still) {
      state.attackQuietHops.set(s, 0);
      continue;
    }
    const n = (state.attackQuietHops.get(s) || 0) + 1;
    if (n >= postHitQuietHops) {
      state.attackSpent.delete(s);
      state.attackSpentAt.delete(s);
      state.attackQuietHops.delete(s);
    } else {
      state.attackQuietHops.set(s, n);
    }
  }
}

async function startMic() {
  stopMic();
  try {
    const stream = await navigator.mediaDevices.getUserMedia({
      audio: { echoCancellation: false, noiseSuppression: false, autoGainControl: false },
    });
    state.micStream = stream;
    const ac = new (window.AudioContext || window.webkitAudioContext)({ sampleRate: 22050 });
    state.micCtx = ac;
    const src = ac.createMediaStreamSource(stream);
    const proc = ac.createScriptProcessor(2048, 1, 1);
    state.micProc = proc;
    proc.onaudioprocess = (ev) => {
      const f32 = ev.inputBuffer.getChannelData(0);
      const pcm = new Int16Array(f32.length);
      for (let i = 0; i < f32.length; i++) {
        const s = Math.max(-1, Math.min(1, f32[i]));
        pcm[i] = (s * 32767) | 0;
      }
      if (examPcm.active) examPcm.addPcm16(pcm);
      processPitchPcm16(pcm, ac.sampleRate || 22050).then(({ midis, onset }) => {
        tickAttackQuiet(midis);
        for (const midi of midis) onPitch(midi, onset);
      }).catch((e) => console.error("[PianoFlow/Web/Pitch]", e));
    };
    src.connect(proc);
    proc.connect(ac.destination);
    setStatus("跟弹：麦克风已开");
  } catch (e) {
    console.error("[PianoFlow/Web]", e);
    setStatus("跟弹需要麦克风权限。请在浏览器设置中允许后重试。");
    state.mode = "auto";
    render();
  }
}

function stopMic() {
  try { state.micProc?.disconnect(); } catch (_) {}
  try { state.micCtx?.close(); } catch (_) {}
  state.micStream?.getTracks().forEach((t) => t.stop());
  state.micProc = null;
  state.micCtx = null;
  state.micStream = null;
}

async function openPractice(song, opts = {}) {
  unlockAudio();
  pause();
  state.song = song;
  state.hasSessionActivity = true;
  armRecentPromote(song.id);
  state.exam = !!opts.exam;
  state.examRecord = opts.examRecord !== false;
  state.examRecordAudio = !!opts.examRecordAudio;
  examPcm.dispose();
  state.mode = opts.exam ? "follow" : "auto";
  state.guideAudio = !opts.exam;
  state.staffReady = false;
  el.shell.hidden = true;
  el.practice.hidden = false;
  el.title.textContent = song.title;
  el.meta.textContent = `${kindLabel(song.scoreKind)} · ${song.artist || ""}${opts.exam ? " · 考试" : ""}`;
  setStatus("加载谱面…");
  applyGeometry();
  render();

  const favs = getFavorites();
  if (el.fav) el.fav.textContent = favs.has(song.id) ? "★" : "☆";

  let scoreText;
  let xmlText;
  if (song.scoreKind === "userImport") {
    scoreText = await shellApi.getUserScoreJson(song.id);
    xmlText = await shellApi.getUserMusicXml(song.id);
    if (!scoreText) throw new Error("用户导入 JSON 缺失");
  } else {
    const jsonPath = (song.asset || `assets/scores/${song.id}.json`).replace(/^assets\//, "./");
    const res = await fetch(jsonPath.startsWith("./") ? jsonPath : `./${jsonPath}`);
    if (!res.ok) throw new Error(`JSON HTTP ${res.status}`);
    scoreText = await res.text();
    xmlText = null;
  }
  try {
    const parsed = typeof scoreText === "string" ? parseScoreJson(scoreText) : parseScoreJson(JSON.stringify(scoreText));
    const { bpm, notes } = parsed;
    state.bpm = song.bpm || bpm;
    state.allNotes = notes;
    recomputeNotes();
    restartTransport(true);
  } catch (e) {
    console.error("[PianoFlow/Web]", e);
    setStatus("乐谱 JSON 读取失败（详情见控制台 [PianoFlow/Web]）");
    return;
  }
  const xmlPath = xmlText
    ? URL.createObjectURL(new Blob([xmlText], { type: "application/xml" }))
    : new URL(`./scores/musicxml/${song.id}.musicxml`, window.location.href).href;
  await loadScoreIntoVerovio(xmlPath);
  applyGeometry();
  render();
  if (opts.exam) {
    setMode("follow");
    play();
  }
}

function leavePractice() {
  if (state.hasSessionActivity && state.playing) {
    if (!confirm("练习进行中，确定离开？")) return;
  }
  cancelRecentPromote();
  pause();
  el.practice.hidden = true;
  el.shell.hidden = false;
  state.song = null;
  state.hasSessionActivity = false;
  shellApi?.showTab("library");
}

el.back.onclick = () => {
  // 仅考试未播完离开时弹结算；平时练习直接回曲库。
  if (state.exam && state.hasSessionActivity && !state.playing) {
    showSettlement();
    return;
  }
  leavePractice();
};
el.fav?.addEventListener("click", () => {
  if (!state.song) return;
  const on = toggleFavorite(state.song.id);
  el.fav.textContent = on ? "★" : "☆";
});
el.volume?.addEventListener("input", () => {
  setMasterVolume(Number(el.volume.value) / 100);
});
el.auto.onclick = () => setMode("auto");
el.follow.onclick = async () => {
  setMode("follow");
  try {
    const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
    stream.getTracks().forEach((t) => t.stop());
    setStatus("跟弹：已获麦克风权限，点播放开始");
  } catch (e) {
    console.error("[PianoFlow/Web]", e);
    setStatus("跟弹需要麦克风权限。请在浏览器设置中允许后重试。");
    state.mode = "auto";
    render();
  }
};
el.play.onclick = () => {
  if (state.playing) {
    pause();
    setStatus("已暂停");
  } else play();
};

/** Space toggles play/pause on desktop keyboards (ignore dialogs / inputs). */
window.addEventListener("keydown", (ev) => {
  if (ev.code !== "Space" && ev.key !== " ") return;
  if (el.practice?.hidden) return;
  if (document.querySelector("dialog[open]")) return;
  const t = ev.target;
  if (
    t instanceof HTMLElement &&
    (t.tagName === "INPUT" ||
      t.tagName === "TEXTAREA" ||
      t.tagName === "SELECT" ||
      t.isContentEditable)
  ) {
    return;
  }
  ev.preventDefault();
  if (state.playing) {
    pause();
    setStatus("已暂停");
  } else {
    play();
  }
});

el.restart.onclick = () => restart();
el.handBoth.onclick = () => { state.hand = "both"; recomputeNotes(); restartTransport(false); render(); };
el.handLeft.onclick = () => { state.hand = "left"; recomputeNotes(); restartTransport(false); render(); };
el.handRight.onclick = () => { state.hand = "right"; recomputeNotes(); restartTransport(false); render(); };
el.fx?.addEventListener("click", () => {
  const next = !practiceVisualEnabled();
  setVisualFxEnabled(next);
  practiceFx.setEnabled(next);
  const settingsFx = document.getElementById("settings-visual-fx");
  if (settingsFx) settingsFx.checked = next;
  render();
});
el.practiceSettings?.addEventListener("click", () => {
  document.getElementById("settings-dlg")?.showModal();
});
el.speed?.addEventListener("input", () => {
  state.speed = Math.max(0.4, Math.min(2, Number(el.speed.value) / 100));
  render();
});
el.seek.onmousedown = () => {
  state.seekDragging = true;
  // Range input seeks on change (mouseup); pause as soon as drag starts.
  if (!state.exam && state.playing) pause();
};
el.seek.onmouseup = () => { state.seekDragging = false; };
el.seek.onchange = () => {
  if (state.exam) return;
  seek((Number(el.seek.value) / 1000) * state.durationBeats);
};

// Staff lane horizontal scrub (same seek path as bottom slider; exam blocked).
(function bindStaffScrub() {
  const target = el.staffScrub || el.staffPanel;
  if (!target) return;
  let scrubbing = false;
  let originX = 0;
  let originBeats = 0;
  let pxPerBeat = 40;

  function fallbackPx(w) {
    return Math.max(12, Math.min(200, (w || 360) / 12));
  }

  function refreshMetrics() {
    try {
      const w = el.frame?.contentWindow;
      const raw = w?.pfScrubMetrics?.();
      if (!raw) return;
      const m = typeof raw === "string" ? JSON.parse(raw) : raw;
      const contentW = Number(m.contentW) || 0;
      const endQ = Number(m.endQ) || 0;
      const dur = state.durationBeats > 0.5 ? state.durationBeats : endQ;
      if (contentW > 32 && dur > 0.5) {
        pxPerBeat = Math.max(12, Math.min(400, contentW / dur));
      }
    } catch (_) { /* keep fallback */ }
  }

  target.addEventListener("pointerdown", (ev) => {
    if (state.exam || ev.button !== 0) return;
    scrubbing = true;
    state.seekDragging = true;
    if (state.playing) pause();
    originX = ev.clientX;
    originBeats = state.positionBeats;
    pxPerBeat = fallbackPx(target.clientWidth);
    refreshMetrics();
    try { target.setPointerCapture(ev.pointerId); } catch (_) {}
  });
  target.addEventListener("pointermove", (ev) => {
    if (!scrubbing || state.exam) return;
    const dx = ev.clientX - originX;
    const next = originBeats - dx / Math.max(1, pxPerBeat);
    seek(next);
  });
  const endScrub = (ev) => {
    if (!scrubbing) return;
    scrubbing = false;
    state.seekDragging = false;
    try { target.releasePointerCapture(ev.pointerId); } catch (_) {}
  };
  target.addEventListener("pointerup", endScrub);
  target.addEventListener("pointercancel", endScrub);
})();

el.settleAgain.onclick = () => {
  el.settleDlg.close();
  restart();
  play();
};
el.settleLib.onclick = () => {
  el.settleDlg.close();
  leavePractice();
};
el.settleWeak.onclick = () => {
  el.settleDlg.close();
  const w = state.weakPending;
  if (!w) return;
  seek(w.start);
  setStatus(`练薄弱段（约 ${Math.ceil(w.start)}–${Math.ceil(w.end)} 拍）`);
  play();
};
el.settleListen?.addEventListener("click", () => {
  if (examPcm.play()) setStatus("播放考试录音…");
  else setStatus("暂无录音可播放");
});

const settingsFx = document.getElementById("settings-visual-fx");
if (settingsFx) {
  settingsFx.checked = getVisualFxEnabled();
  settingsFx.addEventListener("change", () => {
    setVisualFxEnabled(settingsFx.checked);
    practiceFx.setEnabled(practiceVisualEnabled());
    render();
  });
}

shellApi = await initShell({ onOpenPractice: openPractice });
await initPitchEngine();
const pitchLbl = document.getElementById("settings-pitch-engine");
if (pitchLbl) pitchLbl.textContent = `音高引擎：${getPitchEngineLabel()}（主路径 Basic Pitch；无模型时回退 Poly-YIN/YIN）`;
if (el.volume) el.volume.value = String(Math.round(getMasterVolume() * 100));
if (el.speed) el.speed.value = String(Math.round(state.speed * 100));
setPracticeOpener(openPractice);
bindSubPages({
  onAuthChange: () => shellApi.refreshProfile(),
  getSongs: () => shellApi.getSongs(),
  onOpenPractice: openPractice,
});

window.addEventListener("resize", () => {
  if (!el.practice.hidden) {
    applyGeometry();
    render();
  }
});
