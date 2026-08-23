/** Midnight stage skin + waterfall/keyboard paint — parity with Windows, Web can go richer. */

export const HIT_LINE_INSET = 3;
export const STAGE = {
  waterfallTop: "#01060f",
  waterfallMid: "#0a2038",
  waterfallNear: "rgba(255,208,120,0.33)",
  waterfallHitGlow: "rgba(255,208,120,0.47)",
  auroraWarm: "#ffd078",
  auroraCool: "#4ae0f2",
  accent: "#ffd078",
  accentSoft: "rgba(255,208,120,0.4)",
  leftHand: "#f2a06d",
  rightHand: "#4eb6c8",
  success: "#5cbf8a",
  keyWhite: "#f7f3ea",
  keyWhiteLit: "#ffe8b8",
  keyBlack: "#141820",
  keyBlackLit: "#e8a849",
  panelBg: "#0e2438",
};

export function hitLineY(h) {
  return h - HIT_LINE_INSET;
}

export function phaseFromBeats(beats) {
  return Math.abs((beats * 2.2) % 1);
}

/** CSS-pixel canvas with devicePixelRatio scaling for crisp lines. */
export function bindCanvas(canvas, cssW, cssH) {
  const dpr = Math.min(window.devicePixelRatio || 1, 2.5);
  canvas.width = Math.max(1, Math.floor(cssW * dpr));
  canvas.height = Math.max(1, Math.floor(cssH * dpr));
  canvas.style.width = `${cssW}px`;
  canvas.style.height = `${cssH}px`;
  const ctx = canvas.getContext("2d");
  ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  return { ctx, w: cssW, h: cssH, dpr };
}

function roundRectPath(ctx, x, y, w, h, r) {
  const rr = Math.min(r, w / 2, h / 2);
  ctx.beginPath();
  ctx.moveTo(x + rr, y);
  ctx.arcTo(x + w, y, x + w, y + h, rr);
  ctx.arcTo(x + w, y + h, x, y + h, rr);
  ctx.arcTo(x, y + h, x, y, rr);
  ctx.arcTo(x, y, x + w, y, rr);
  ctx.closePath();
}

export function drawWaterfallBackground(ctx, w, h, { fx, phase }) {
  if (!fx) {
    const g = ctx.createLinearGradient(0, 0, 0, h);
    g.addColorStop(0, "#080c14");
    g.addColorStop(1, "#141920");
    ctx.fillStyle = g;
    ctx.fillRect(0, 0, w, h);
    return hitLineY(h);
  }

  const hitY = hitLineY(h);
  const bg = ctx.createLinearGradient(0, 0, 0, h);
  bg.addColorStop(0, STAGE.waterfallTop);
  bg.addColorStop(0.55, STAGE.waterfallMid);
  bg.addColorStop(0.88, STAGE.waterfallNear);
  bg.addColorStop(1, STAGE.waterfallHitGlow);
  ctx.fillStyle = bg;
  ctx.fillRect(0, 0, w, h);

  const side = ctx.createLinearGradient(0, 0, w, 0);
  side.addColorStop(0, "rgba(74,224,242,0.14)");
  side.addColorStop(0.16, "rgba(0,0,0,0)");
  side.addColorStop(0.84, "rgba(0,0,0,0)");
  side.addColorStop(1, "rgba(74,224,242,0.14)");
  ctx.fillStyle = side;
  ctx.fillRect(0, 0, w, h);

  const aurora = 0.12 + 0.1 * 0.4;
  const top = ctx.createLinearGradient(0, 0, 0, h * 0.5);
  top.addColorStop(0, `rgba(255,208,120,${aurora})`);
  top.addColorStop(0.55, `rgba(74,224,242,${aurora * 0.55})`);
  top.addColorStop(1, "rgba(0,0,0,0)");
  ctx.fillStyle = top;
  ctx.fillRect(0, 0, w, h * 0.5);

  const bottom = ctx.createLinearGradient(0, hitY - 70, 0, h);
  bottom.addColorStop(0, "rgba(0,0,0,0)");
  bottom.addColorStop(1, `rgba(255,208,120,${0.16 + 0.1 * 0.4})`);
  ctx.fillStyle = bottom;
  ctx.fillRect(0, hitY - 70, w, h - hitY + 70);

  return hitY;
}

export function drawLaneGuides(ctx, geo, hitY, { fx, phase }) {
  if (!geo) return;
  ctx.strokeStyle = fx
    ? `rgba(255,208,120,${0.10 + 0.04 * phase})`
    : "rgba(255,255,255,0.08)";
  ctx.lineWidth = fx ? 1.2 : 1;
  for (let i = 1; i < geo.whiteMidis.length; i++) {
    const x = geo.lefts[i];
    ctx.beginPath();
    ctx.moveTo(x, 0);
    ctx.lineTo(x, hitY);
    ctx.stroke();
  }
  if (!fx) {
    for (let i = 0; i < geo.whiteMidis.length; i++) {
      if (geo.whiteMidis[i] % 12 === 0) {
        const x = geo.lefts[i];
        ctx.beginPath();
        ctx.moveTo(x, 0);
        ctx.lineTo(x, hitY);
        ctx.stroke();
      }
    }
  }
}

export function drawFallingNote(ctx, { cx, top, bottom, nw, hand, waiting, fx, phase }) {
  const h = Math.max(10, bottom - top);
  const y = top;
  const base = hand === "left" ? STAGE.leftHand : STAGE.rightHand;
  const fill = waiting && fx ? STAGE.accent : base;
  const r = Math.min(14, Math.max(3, nw * 0.45));

  if (fx && waiting) {
    ctx.fillStyle = `rgba(255,208,120,${0.22 + 0.08 * phase})`;
    roundRectPath(ctx, cx - nw / 2 - 2, y - 2, nw + 4, h + 4, r);
    ctx.fill();
  }

  const body = ctx.createLinearGradient(cx, y, cx, y + h);
  if (fx) {
    body.addColorStop(0, fill);
    body.addColorStop(1, hand === "left" ? "#c87848" : "#3a9aaa");
  } else {
    body.addColorStop(0, fill);
    body.addColorStop(1, fill);
  }
  ctx.fillStyle = body;
  roundRectPath(ctx, cx - nw / 2, y, nw, h, r);
  ctx.fill();

  ctx.strokeStyle = waiting
    ? `rgba(255,255,255,${fx ? 0.72 : 0.85})`
    : `rgba(255,255,255,${fx ? 0.28 : 0.18})`;
  ctx.lineWidth = waiting ? (fx ? 1.35 : 1.8) : (fx ? 0.9 : 1);
  roundRectPath(ctx, cx - nw / 2, y, nw, h, r);
  ctx.stroke();

  if (fx) {
    ctx.save();
    ctx.globalCompositeOperation = "lighter";
    ctx.fillStyle = `rgba(255,255,255,${waiting ? 0.18 : 0.08})`;
    roundRectPath(ctx, cx - nw / 2 + 1, y + 1, Math.max(2, nw - 2), Math.min(6, h * 0.35), 2);
    ctx.fill();
    ctx.restore();
  }
}

export function drawHitLineGlow(ctx, w, hitY, { fx }) {
  if (!fx) {
    ctx.fillStyle = "rgba(232,168,73,0.15)";
    ctx.fillRect(0, hitY - 6, w, 12);
    ctx.strokeStyle = "rgba(232,168,73,0.9)";
    ctx.lineWidth = 3;
    ctx.beginPath();
    ctx.moveTo(0, hitY);
    ctx.lineTo(w, hitY);
    ctx.stroke();
    return;
  }
  const layers = [
    { a: 0.02, w: 96 },
    { a: 0.05, w: 24 },
    { a: 0.04, w: 8 },
  ];
  ctx.lineCap = "round";
  for (const L of layers) {
    ctx.strokeStyle = `rgba(255,208,120,${L.a})`;
    ctx.lineWidth = L.w;
    ctx.beginPath();
    ctx.moveTo(0, hitY);
    ctx.lineTo(w, hitY);
    ctx.stroke();
  }
  ctx.strokeStyle = "rgba(255,255,255,0.04)";
  ctx.lineWidth = 2;
  ctx.beginPath();
  ctx.moveTo(0, hitY);
  ctx.lineTo(w, hitY);
  ctx.stroke();
}

export function drawKeyboard(ctx, geo, h, lit, { fx }) {
  if (!geo) return;
  if (fx) {
    const bg = ctx.createLinearGradient(0, 0, 0, h);
    bg.addColorStop(0, STAGE.panelBg);
    bg.addColorStop(1, "#0a1828");
    ctx.fillStyle = bg;
    ctx.fillRect(0, 0, geo.contentWidth, h);
    ctx.strokeStyle = "rgba(61,122,154,0.55)";
    ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.moveTo(0, 0);
    ctx.lineTo(geo.contentWidth, 0);
    ctx.stroke();
  }

  for (let i = 0; i < geo.whiteMidis.length; i++) {
    const midi = geo.whiteMidis[i];
    const l = geo.lefts[i];
    const ww = geo.widths[i];
    const on = lit.has(midi);
    if (fx && on) {
      const g = ctx.createLinearGradient(l, 0, l, h);
      g.addColorStop(0, STAGE.keyWhiteLit);
      g.addColorStop(1, STAGE.accent);
      ctx.fillStyle = g;
      ctx.shadowColor = STAGE.accentSoft;
      ctx.shadowBlur = 14;
    } else {
      ctx.fillStyle = on ? STAGE.keyWhiteLit : STAGE.keyWhite;
      ctx.shadowBlur = 0;
    }
    ctx.fillRect(l, 0, ww - 1.2, h);
    ctx.shadowBlur = 0;
    ctx.strokeStyle = fx ? "rgba(61,122,154,0.45)" : "#9aa3ad";
    ctx.strokeRect(l, 0, ww - 1.2, h);
  }

  for (const midi of geo.blackMidis) {
    const l = geo.blackLeft(midi);
    if (l == null) continue;
    const on = lit.has(midi);
    const bh = h * 0.62;
    if (fx && on) {
      const g = ctx.createLinearGradient(l, 0, l, bh);
      g.addColorStop(0, STAGE.keyBlackLit);
      g.addColorStop(1, "#8a6020");
      ctx.fillStyle = g;
      ctx.shadowColor = STAGE.accentSoft;
      ctx.shadowBlur = 10;
    } else {
      ctx.fillStyle = on ? STAGE.keyBlackLit : STAGE.keyBlack;
      ctx.shadowBlur = 0;
    }
    ctx.fillRect(l, 0, geo.blackWidth, bh);
    ctx.shadowBlur = 0;
  }
}
