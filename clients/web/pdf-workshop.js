/** PDF staging for Web — OMR still requires Windows; store + honest guide. */

const DB_NAME = "pianoflow_pdf";
const STORE = "pdfs";

function openDb() {
  return new Promise((resolve, reject) => {
    const req = indexedDB.open(DB_NAME, 1);
    req.onupgradeneeded = () => req.result.createObjectStore(STORE);
    req.onsuccess = () => resolve(req.result);
    req.onerror = () => reject(req.error);
  });
}

export async function stagePdfFile(file) {
  const id = `user_pdf_${file.name.replace(/[^a-zA-Z0-9\u4e00-\u9fff]+/g, "_").slice(0, 30)}_${Date.now().toString(36).slice(-4)}`;
  const buf = await file.arrayBuffer();
  const db = await openDb();
  await new Promise((resolve, reject) => {
    const tx = db.transaction(STORE, "readwrite");
    tx.objectStore(STORE).put({ id, name: file.name, at: Date.now(), blob: buf }, id);
    tx.oncomplete = () => resolve();
    tx.onerror = () => reject(tx.error);
  });
  console.log("[PianoFlow/Web/Workshop] PDF staged", id, file.name);
  return {
    id,
    name: file.name,
    guide:
      "PDF 已暂存到本浏览器。完整 OMR 一键流水线需 Windows 桌面版：将 PDF 复制到仓库 user_import/pdf_inbox 后运行 scripts/omr-from-pdf.ps1。Web 端无法本机 Audiveris。",
  };
}

export async function listStagedPdfs() {
  const db = await openDb();
  return new Promise((resolve, reject) => {
    const tx = db.transaction(STORE, "readonly");
    const req = tx.objectStore(STORE).getAll();
    req.onsuccess = () => resolve(req.result || []);
    req.onerror = () => reject(req.error);
  });
}
