/** Exam PCM → WAV (tee from mic path). Port of lib/features/practice/exam_pcm_recorder.dart */

function wavHeader(dataBytes, sampleRate = 22050, channels = 1, bits = 16) {
  const byteRate = (sampleRate * channels * bits) / 8;
  const blockAlign = (channels * bits) / 8;
  const buf = new ArrayBuffer(44);
  const v = new DataView(buf);
  const w = (o, s) => { for (let i = 0; i < s.length; i++) v.setUint8(o + i, s.charCodeAt(i)); };
  w(0, "RIFF");
  v.setUint32(4, 36 + dataBytes, true);
  w(8, "WAVE");
  w(12, "fmt ");
  v.setUint32(16, 16, true);
  v.setUint16(20, 1, true);
  v.setUint16(22, channels, true);
  v.setUint32(24, sampleRate, true);
  v.setUint32(28, byteRate, true);
  v.setUint16(32, blockAlign, true);
  v.setUint16(34, bits, true);
  w(36, "data");
  v.setUint32(40, dataBytes, true);
  return new Uint8Array(buf);
}

export class ExamPcmRecorder {
  constructor() {
    this._chunks = [];
    this._bytes = 0;
    this._active = false;
    this._url = null;
    this._audio = null;
  }

  get active() { return this._active; }
  get url() { return this._url; }

  start(songId) {
    this.stop();
    this._chunks = [];
    this._bytes = 0;
    this._active = true;
    console.log("[PianoFlow/Web/ExamPcm] record start", songId);
  }

  addPcm16(pcm) {
    if (!this._active || !pcm?.length) return;
    this._chunks.push(pcm.slice ? pcm.slice() : new Int16Array(pcm));
    this._bytes += pcm.length * 2;
  }

  stop() {
    if (!this._active) return null;
    this._active = false;
    if (this._url) {
      URL.revokeObjectURL(this._url);
      this._url = null;
    }
    if (this._bytes <= 0) {
      this._chunks = [];
      return null;
    }
    const pcm = new Int16Array(this._bytes / 2);
    let o = 0;
    for (const c of this._chunks) {
      pcm.set(c, o);
      o += c.length;
    }
    const header = wavHeader(pcm.byteLength);
    const blob = new Blob([header, pcm], { type: "audio/wav" });
    this._url = URL.createObjectURL(blob);
    console.log("[PianoFlow/Web/ExamPcm] saved", this._bytes, "B");
    this._chunks = [];
    return this._url;
  }

  play() {
    if (!this._url) return false;
    try {
      this._audio?.pause();
      this._audio = new Audio(this._url);
      this._audio.play();
      return true;
    } catch (e) {
      console.error("[PianoFlow/Web/ExamPcm]", e);
      return false;
    }
  }

  dispose() {
    this.stop();
    if (this._url) URL.revokeObjectURL(this._url);
    this._url = null;
  }
}
