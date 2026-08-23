const catalog = require("../../data/catalog.json");
const staffFur = require("../../data/staff/fur_elise_woo59.json");
const staffCastle = require("../../data/staff/hisaishi_castle_in_the_sky.json");

const STAFF = {
  fur_elise_woo59: staffFur,
  hisaishi_castle_in_the_sky: staffCastle,
};

const PX_PER_BEAT = 56;
const STAFF_MID_Y = 88;

Page({
  data: {
    song: { title: "", scoreKindLabel: "", honesty: "" },
    bpm: 72,
    metroOn: false,
    beatFlash: false,
    staffNotes: [],
    staffWidth: 400,
    staffDisclaimer: "",
    notePreview: "",
  },
  _timer: null,
  _flashTimer: null,
  onLoad(query) {
    const song =
      (catalog.songs || []).find((s) => s.id === query.id) || catalog.songs[0];
    const staff = STAFF[song.id] || { notes: [], disclaimer: "暂无预渲染谱" };
    const notes = (staff.notes || []).map((n, i) => ({
      id: `${n.name}_${n.onset}_${i}`,
      name: n.name,
      left: Math.round(24 + n.onset * PX_PER_BEAT),
      top: Math.round(STAFF_MID_Y + (n.y || 0)),
      w: Math.max(18, Math.round((n.dur || 0.25) * PX_PER_BEAT * 0.55)),
    }));
    const maxLeft = notes.reduce((m, n) => Math.max(m, n.left + n.w), 200);
    const preview = (staff.notes || [])
      .slice(0, 12)
      .map((n) => n.name)
      .join(" · ");
    this.setData({
      song,
      bpm: 72,
      staffNotes: notes,
      staffWidth: maxLeft + 48,
      staffDisclaimer: staff.disclaimer || "",
      notePreview: preview,
    });
    console.log(
      "[PianoFlow/WeChat] practice load",
      song.id,
      "notes=",
      notes.length
    );
  },
  onUnload() {
    this.stopMetro();
  },
  toggleMetro() {
    if (this.data.metroOn) {
      this.stopMetro();
      return;
    }
    this.setData({ metroOn: true });
    const interval = Math.round(60000 / (this.data.bpm || 72));
    const tick = () => {
      this.setData({ beatFlash: true });
      if (this._flashTimer) clearTimeout(this._flashTimer);
      this._flashTimer = setTimeout(() => {
        this.setData({ beatFlash: false });
      }, 120);
      try {
        wx.vibrateShort({ type: "medium" });
      } catch (e) {
        console.warn("[PianoFlow/WeChat] vibrate failed", e);
      }
      console.log("[PianoFlow/WeChat] metro tick bpm=", this.data.bpm);
    };
    tick();
    this._timer = setInterval(tick, interval);
  },
  stopMetro() {
    if (this._timer) {
      clearInterval(this._timer);
      this._timer = null;
    }
    if (this._flashTimer) {
      clearTimeout(this._flashTimer);
      this._flashTimer = null;
    }
    this.setData({ metroOn: false, beatFlash: false });
  },
  bumpBpm(e) {
    const delta = Number(e.currentTarget.dataset.delta || 0);
    let bpm = (this.data.bpm || 72) + delta;
    bpm = Math.max(40, Math.min(160, bpm));
    this.setData({ bpm });
    if (this.data.metroOn) {
      this.stopMetro();
      this.toggleMetro();
    }
  },
});
