/** Visual FX — hit bursts, aurora, grade labels. Web targets richer than Windows. */

import { STAGE } from "./practice-stage.js";

const BURST_MS = 980;
const AMBIENT_T = 0.4;
const MAX_BURSTS = 8;

function easeOutCubic(t) {
  return 1 - (1 - t) ** 3;
}

function easeInQuad(t) {
  return t * t;
}

export class PracticeFx {
  constructor() {
    this.enabled = true;
    this.bursts = [];
    this._lastAutoFlash = new Map();
    this._lastAutoPos = null;
  }

  setEnabled(on) {
    this.enabled = !!on;
    if (!on) this.bursts = [];
  }

  hit(midi, cx, grade, combo, hitY, width) {
    if (!this.enabled || cx == null || hitY == null) return;
    this._spawn({
      cx,
      hitY,
      grade: grade || "good",
      combo: combo || 0,
      showLabel: true,
      width: width || 800,
    });
  }

  /** Auto-play visual-only flashes at note onsets. */
  autoplayAt(notes, pos, prevPos, geo, hitY, width) {
    if (!this.enabled || !geo || hitY == null) return;
    if (prevPos == null) {
      this._lastAutoPos = pos;
      return;
    }
    if (pos + 0.08 < prevPos || pos - prevPos > 1.5) {
      this._lastAutoFlash.clear();
      this._lastAutoPos = pos;
      return;
    }
    if (this.bursts.some((b) => performance.now() - b.born < BURST_MS * 0.45)) {
      this._lastAutoPos = pos;
      return;
    }
    let fired = 0;
    for (const n of notes) {
      if (fired >= 1) break;
      if (n.start <= prevPos || n.start > pos) continue;
      const last = this._lastAutoFlash.get(n.midi);
      if (last != null && pos - last < 0.25) continue;
      const cx = geo.midiCenterX(n.midi);
      if (cx == null) continue;
      this._lastAutoFlash.set(n.midi, pos);
      this._spawn({
        cx,
        hitY,
        grade: "perfect",
        combo: 0,
        showLabel: false,
        width: width || 800,
      });
      fired++;
    }
    this._lastAutoPos = pos;
  }

  _spawn({ cx, hitY, grade, combo, showLabel, width }) {
    this.bursts.push({
      cx,
      hitY,
      grade,
      combo,
      showLabel,
      width,
      born: performance.now(),
    });
    if (this.bursts.length > MAX_BURSTS) {
      this.bursts.splice(0, this.bursts.length - MAX_BURSTS);
    }
  }

  prune(now = performance.now()) {
    this.bursts = this.bursts.filter((b) => now - b.born < BURST_MS);
  }

  draw(ctx, w, h, hitY) {
    if (!this.enabled) return;
    const now = performance.now();
    this.prune(now);
    const y = hitY ?? h * 0.92;

    for (const b of this.bursts) {
      const raw = (now - b.born) / BURST_MS;
      const burstT = easeOutCubic(Math.min(1, raw));
      const life = Math.max(0, 1 - easeInQuad(Math.min(1, raw)));
      if (life <= 0) continue;

      const perfect = b.grade === "perfect";
      const color = perfect ? STAGE.accent : STAGE.success;
      const originX = b.cx;
      const originY = b.hitY ?? y;

      const pillarH = h * (perfect ? 0.55 : 0.38);
      const pw = perfect ? 18 : 12;
      const pg = ctx.createLinearGradient(originX, originY - pillarH, originX, originY);
      pg.addColorStop(0, "rgba(0,0,0,0)");
      pg.addColorStop(0.35, perfect ? `rgba(255,208,120,${0.1 * life})` : `rgba(92,191,138,${0.08 * life})`);
      pg.addColorStop(1, perfect ? `rgba(255,208,120,${0.32 * life})` : `rgba(92,191,138,${0.22 * life})`);
      ctx.fillStyle = pg;
      ctx.fillRect(originX - pw / 2, originY - pillarH, pw, pillarH);

      const rings = perfect ? [1.0, 0.62] : [1.0];
      for (const scale of rings) {
        const ringR = (8 + burstT * (perfect ? 52 : 36)) * scale;
        ctx.strokeStyle = color.replace(")", `,${0.42 * life * scale})`).replace("rgb", "rgba").replace("#ffd078", `rgba(255,208,120,${0.42 * life * scale})`);
        if (color.startsWith("#")) {
          ctx.strokeStyle = perfect
            ? `rgba(255,208,120,${0.42 * life * scale})`
            : `rgba(92,191,138,${0.42 * life * scale})`;
        }
        ctx.lineWidth = (perfect ? 2.0 : 1.5) * (1.35 - 0.25 * scale);
        ctx.beginPath();
        ctx.arc(originX, originY, ringR, 0, Math.PI * 2);
        ctx.stroke();
      }

      ctx.fillStyle = perfect ? `rgba(255,208,120,${0.16 * life})` : `rgba(92,191,138,${0.14 * life})`;
      ctx.beginPath();
      ctx.arc(originX, originY, 16 * life, 0, Math.PI * 2);
      ctx.fill();
      ctx.fillStyle = `rgba(255,255,255,${0.32 * life})`;
      ctx.beginPath();
      ctx.arc(originX, originY, 7 * life, 0, Math.PI * 2);
      ctx.fill();

      if (b.showLabel && life > 0.12) {
        const label = `${perfect ? "完美" : "不错"}${b.combo >= 3 ? `  ×${b.combo}` : ""}`;
        ctx.font = `900 ${perfect ? 26 : 20}px system-ui, "Segoe UI", sans-serif`;
        ctx.textAlign = "center";
        ctx.textBaseline = "middle";
        const tw = ctx.measureText(label).width;
        const lx = Math.max(12 + tw / 2, Math.min((b.width || w) - 12 - tw / 2, originX));
        const ly = originY - 72 - 28 * burstT;
        const padX = 12;
        const padY = 6;
        const bw = tw + padX * 2;
        const bh = (perfect ? 26 : 20) + padY * 2;
        ctx.fillStyle = perfect ? `rgba(255,208,120,${0.7 * life})` : `rgba(92,191,138,${0.65 * life})`;
        roundRect(ctx, lx - bw / 2, ly - bh / 2, bw, bh, 14);
        ctx.fill();
        ctx.fillStyle = `rgba(255,255,255,${0.95 * life})`;
        ctx.fillText(label, lx, ly);
      }
    }
    ctx.globalAlpha = 1;
  }
}

function roundRect(ctx, x, y, w, h, r) {
  const rr = Math.min(r, w / 2, h / 2);
  ctx.beginPath();
  ctx.moveTo(x + rr, y);
  ctx.arcTo(x + w, y, x + w, y + h, rr);
  ctx.arcTo(x + w, y + h, x, y + h, rr);
  ctx.arcTo(x, y + h, x, y, rr);
  ctx.arcTo(x, y, x + w, y, rr);
  ctx.closePath();
}

export { BURST_MS, AMBIENT_T };
