/** Practice stage rendering — Web midnight theme, richer than Windows canvas path. */

export const STAGE = {
  waterfallTop: "#01060F",
  waterfallMid: "#0A2038",
  waterfallNear: "rgba(255,208,120,0.33)",
  waterfallHitGlow: "rgba(255,208,120,0.47)",
  auroraWarm: "#FFD078",
  auroraCool: "#4AE0F2",
  accent: "#FFD078",
  leftHand: "#F2A06D",
  rightHand: "#4EB6C8",
  keyWhite: "#F7F3EA",
  keyWhiteLit: "#FFE8B8",
  keyBlack: "#141820",
  keyBlackLit: "#E8A849",
  guide: "rgba(61,122,154,0.35)",
};

const LOOK_AHEAD = 4;
const HIT_FRAC = 0.92;

let bgCache = null;

function cacheKey(w, h, fx) {
  return `${w}x${h}:${fx ? 1 : 0}`;
}

function ensureBg(ctx, w, h, fx) {
  const k = cacheKey(w, h, fx);
  if (bgCache?.key === k) return bgCache;
  const g = ctx.createLinearGradient(0, 0, 0, h);
  if (fx) {
    g.addColorStop(0, STAGE.waterfallTop);
    g.addColorStop(0.55, STAGE.waterfallMid);
    g.addColorStop(0.88, STAGE.waterfallNear);
    g.addColorStop(1, STAGE.waterfallHitGlow);
  } else {
    g.addColorStop(0, "#080c14");
    g.addColorStop(1, "#141920");
  }
  const aurora = fx
    ? ctx.createLinearGradient(0, 0, w, 0)
    : null;
  if (aurora) {
    aurora.addColorStop(0, "rgba(74,224,242,0.14)");
    aurora.addColorStop(0.16, "rgba(0,0,0,0)");
    aurora.addColorStop(0.84, "rgba(0,0,0,0)");
    aurora.addColorStop(1, "rgba(74,224,242,0.14)");
  }
  bgCache = { key: k, g, aurora };
  return bgCache;
}

function roundRect(ctx, x, y, rw, rh, r) {
  const rr = Math.min(r, rw / 2, rh / 2);
  ctx.beginPath();
  ctx.moveTo(x + rr, y);
  ctx.arcTo(x + rw, y, x + rw, y + rh, rr);
  ctx.arcTo(x + rw, y + rh, x, y + rh, rr);
  ctx.arcTo(x, y + rh, x, y, rr);
  ctx.arcTo(x, y, x + rw, y, rr);
  ctx.closePath();
}

function noteColor(n, waiting, fx) {
  const base = n.hand === "left" ? STAGE.leftHand : STAGE.rightHand;
  if (waiting && fx) return STAGE.accent;
  return base;
}

export function hitLineY(h) {
  return h * HIT_FRAC;
}

/** @param {{ geo, notes, positionBeats, waitingFor, visualFx, w, h, phase }} p */
export function drawWaterfallLane(ctx, p) {
  const { geo, notes, positionBeats, waitingFor, visualFx, w, h } = p;
  const phase = p.phase ?? 0;
  const hitY = hitLineY(h);
  const bg = ensureBg(ctx, w, h, visualFx);
  ctx.fillStyle = bg.g;
  ctx.fillRect(0, 0, w, h);
  if (bg.aurora) {
    ctx.fillStyle = bg.aurora;
    ctx.fillRect(0, 0, w, h);
  }

  if (visualFx) {
    const scanY = ((phase * 0.35) % 1) * h;
    const sg = ctx.createLinearGradient(0, scanY - 40, 0, scanY + 40);
    sg.addColorStop(0, "rgba(255,255,255,0)");
    sg.addColorStop(0.5, "rgba(255,208,120,0.04)");
    sg.addColorStop(1, "rgba(255,255,255,0)");
    ctx.fillStyle = sg;
    ctx.fillRect(0, 0, w, h);
  }

  ctx.strokeStyle = visualFx
    ? `rgba(255,208,120,${0.08 + 0.04 * phase})`
    : "rgba(255,255,255,0.08)";
  ctx.lineWidth = visualFx ? 1.2 : 1;
  for (let i = 1; i < geo.whiteMidis.length; i++) {
    const x = geo.lefts[i];
    ctx.beginPath();
    ctx.moveTo(x, 0);
    ctx.lineTo(x, hitY);
    ctx.stroke();
  }

  for (const n of notes) {
    const dy = (n.start - positionBeats) / LOOK_AHEAD;
    if (dy < -0.3 || dy > 1.3) continue;
    const cx = geo.midiCenterX(n.midi);
    if (cx == null) continue;
    const nw = geo.isBlack(n.midi) ? geo.blackWidth * 0.88 : geo.whiteWidth * 0.74;
    const nh = Math.min(h * 0.5, Math.max(16, (n.duration / LOOK_AHEAD) * h * 0.58));
    const y = hitY - dy * h * 0.82;
    const beatDist = n.start - positionBeats;
    const waiting = waitingFor.has(n.midi) && beatDist <= 0.35 && beatDist >= -0.12;

    if (visualFx && waiting) {
      ctx.save();
      ctx.shadowColor = STAGE.accent;
      ctx.shadowBlur = 14 + 6 * phase;
      roundRect(ctx, cx - nw / 2 - 2, y - nh - 2, nw + 4, nh + 4, 6);
      ctx.fillStyle = `rgba(255,208,120,${0.18 + 0.08 * phase})`;
      ctx.fill();
      ctx.restore();
    }

    const fill = noteColor(n, waiting, visualFx);
    const grad = ctx.createLinearGradient(cx, y - nh, cx, y);
    grad.addColorStop(0, lighten(fill, 0.22));
    grad.addColorStop(0.45, fill);
    grad.addColorStop(1, darken(fill, 0.18));
    roundRect(ctx, cx - nw / 2, y - nh, nw, nh, Math.min(12, nw * 0.45));
    ctx.fillStyle = grad;
    if (visualFx) {
      ctx.shadowColor = fill;
      ctx.shadowBlur = waiting ? 10 : 4;
    }
    ctx.fill();
    ctx.shadowBlur = 0;

    ctx.strokeStyle = `rgba(255,255,255,${waiting ? (visualFx ? 0.72 : 0.85) : (visualFx ? 0.28 : 0.18)})`;
    ctx.lineWidth = waiting ? (visualFx ? 1.35 : 1.8) : (visualFx ? 0.9 : 1);
    ctx.stroke();

    if (visualFx && nh > 20) {
      const tg = ctx.createLinearGradient(cx, y - nh, cx, y - nh * 0.55);
      tg.addColorStop(0, "rgba(255,255,255,0.22)");
      tg.addColorStop(1, "rgba(255,255,255,0)");
      roundRect(ctx, cx - nw / 2 + 1, y - nh + 1, nw - 2, nh * 0.45, 4);
      ctx.fillStyle = tg;
      ctx.fill();
    }
  }

  if (visualFx) {
    ctx.strokeStyle = `rgba(255,208,120,${0.12 + 0.05 * phase})`;
    ctx.lineWidth = 28;
    ctx.lineCap = "round";
    ctx.beginPath();
    ctx.moveTo(0, hitY);
    ctx.lineTo(w, hitY);
    ctx.stroke();
    ctx.lineWidth = 14;
    ctx.strokeStyle = `rgba(255,208,120,${0.22 + 0.06 * phase})`;
    ctx.stroke();
  }
  ctx.lineWidth = 2.5;
  ctx.strokeStyle = visualFx ? "rgba(255,208,120,0.95)" : "rgba(232,168,73,0.9)";
  ctx.lineCap = "butt";
  ctx.beginPath();
  ctx.moveTo(0, hitY);
  ctx.lineTo(w, hitY);
  ctx.stroke();
}

function lighten(hex, amt) {
  const c = parseHex(hex);
  return rgb(
    c.r + (255 - c.r) * amt,
    c.g + (255 - c.g) * amt,
    c.b + (255 - c.b) * amt,
  );
}

function darken(hex, amt) {
  const c = parseHex(hex);
  return rgb(c.r * (1 - amt), c.g * (1 - amt), c.b * (1 - amt));
}

function parseHex(hex) {
  const h = hex.replace("#", "");
  if (h.length === 3) {
    return {
      r: parseInt(h[0] + h[0], 16),
      g: parseInt(h[1] + h[1], 16),
      b: parseInt(h[2] + h[2], 16),
    };
  }
  return {
    r: parseInt(h.slice(0, 2), 16),
    g: parseInt(h.slice(2, 4), 16),
    b: parseInt(h.slice(4, 6), 16),
  };
}

function rgb(r, g, b) {
  return `rgb(${r | 0},${g | 0},${b | 0})`;
}

/** @param {{ geo, pressed, waitingFor, visualFx, w, h, phase }} p */
export function drawKeyboard(ctx, p) {
  const { geo, pressed, waitingFor, visualFx, w, h } = p;
  const phase = p.phase ?? 0;
  const lit = pressed.size ? pressed : waitingFor;

  if (visualFx) {
    const kg = ctx.createLinearGradient(0, 0, 0, h);
    kg.addColorStop(0, "#0E2438");
    kg.addColorStop(1, "#16344C");
    ctx.fillStyle = kg;
    ctx.fillRect(0, 0, w, h);
  } else {
    ctx.fillStyle = "#1a2030";
    ctx.fillRect(0, 0, w, 4);
  }

  for (let i = 0; i < geo.whiteMidis.length; i++) {
    const midi = geo.whiteMidis[i];
    const l = geo.lefts[i];
    const ww = geo.widths[i] - 1.4;
    const on = lit.has(midi);
    const wait = waitingFor.has(midi);
    const grad = ctx.createLinearGradient(l, 0, l, h);
    if (on) {
      grad.addColorStop(0, "#FFF0C8");
      grad.addColorStop(0.55, STAGE.keyWhiteLit);
      grad.addColorStop(1, "#E8C878");
    } else {
      grad.addColorStop(0, "#FFFFFF");
      grad.addColorStop(0.4, STAGE.keyWhite);
      grad.addColorStop(1, "#DDD6C8");
    }
    ctx.fillStyle = grad;
    if (visualFx && (on || wait)) {
      ctx.shadowColor = STAGE.accent;
      ctx.shadowBlur = on ? 12 : 6;
    }
    ctx.fillRect(l, 0, ww, h);
    ctx.shadowBlur = 0;
    ctx.strokeStyle = on ? STAGE.accent : "#9AA3AD";
    ctx.lineWidth = on ? 1.5 : 1;
    ctx.strokeRect(l, 0.5, ww, h - 0.5);
    if (visualFx && wait && !on) {
      ctx.fillStyle = `rgba(255,208,120,${0.12 + 0.06 * phase})`;
      ctx.fillRect(l + 1, 1, ww - 2, h - 2);
    }
  }

  for (const midi of geo.blackMidis) {
    const l = geo.blackLeft(midi);
    if (l == null) continue;
    const on = lit.has(midi);
    const bw = geo.blackWidth;
    const bh = h * 0.62;
    const grad = ctx.createLinearGradient(l, 0, l, bh);
    if (on) {
      grad.addColorStop(0, "#FFE090");
      grad.addColorStop(1, STAGE.keyBlackLit);
    } else {
      grad.addColorStop(0, "#2A3040");
      grad.addColorStop(1, STAGE.keyBlack);
    }
    if (visualFx) {
      ctx.shadowColor = on ? STAGE.accent : "rgba(0,0,0,0.5)";
      ctx.shadowBlur = on ? 10 : 4;
      ctx.shadowOffsetY = 2;
    }
    ctx.fillStyle = grad;
    roundRect(ctx, l, 0, bw, bh, 3);
    ctx.fill();
    ctx.shadowBlur = 0;
    ctx.shadowOffsetY = 0;
  }
}
