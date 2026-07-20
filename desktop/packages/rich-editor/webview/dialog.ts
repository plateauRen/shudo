/** In-page dialogs — WKWebView does not support window.prompt / confirm. */

function ensureStyles() {
  if (document.getElementById("wk-rich-dialog-style")) return;
  const style = document.createElement("style");
  style.id = "wk-rich-dialog-style";
  style.textContent = `
.wk-rich-dialog-mask {
  position: fixed; inset: 0; z-index: 10000;
  background: rgba(0,0,0,.35);
  display: flex; align-items: center; justify-content: center;
  padding: 16px;
}
.wk-rich-dialog {
  width: min(340px, 100%);
  background: var(--re-toolbar-bg, #fff); color: var(--re-fg, #111);
  border-radius: 12px;
  box-shadow: 0 12px 40px rgba(0,0,0,.22);
  padding: 16px;
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
}
.wk-rich-dialog h3 {
  margin: 0 0 10px; font-size: 16px; font-weight: 600;
}
.wk-rich-dialog p {
  margin: 0 0 12px; font-size: 13px; color: var(--re-placeholder, #666); line-height: 1.4;
}
.wk-rich-dialog input[type="text"],
.wk-rich-dialog input[type="number"],
.wk-rich-dialog input[type="url"] {
  width: 100%; box-sizing: border-box;
  height: 40px; padding: 0 10px;
  border: 1px solid var(--re-border, rgba(0,0,0,.15)); border-radius: 8px;
  background: var(--re-bg, #fff); color: var(--re-fg, #111);
  font-size: 15px; margin-bottom: 10px;
}
.wk-rich-dialog .wk-rich-dialog-row {
  display: flex; gap: 8px; margin-bottom: 10px;
}
.wk-rich-dialog .wk-rich-dialog-row label {
  flex: 1; font-size: 12px; color: #666;
  display: flex; flex-direction: column; gap: 4px;
}
.wk-rich-dialog .wk-rich-dialog-presets {
  display: flex; flex-wrap: wrap; gap: 6px; margin-bottom: 12px;
}
.wk-rich-dialog .wk-rich-dialog-presets button {
  height: 32px; padding: 0 10px;
  border: 1px solid var(--re-border, rgba(0,0,0,.12)); border-radius: 6px;
  background: var(--re-btn-bg, #f5f5f5); color: var(--re-fg, #111);
  font-size: 13px; font-weight: 600;
}
.wk-rich-dialog .wk-rich-dialog-actions {
  display: flex; justify-content: flex-end; gap: 8px; margin-top: 4px;
}
.wk-rich-dialog .wk-rich-dialog-actions button {
  height: 36px; padding: 0 14px; border-radius: 8px;
  border: 1px solid var(--re-border, rgba(0,0,0,.12));
  background: var(--re-btn-bg, #f7f7f7); color: var(--re-fg, #111);
  font-size: 14px;
}
.wk-rich-dialog .wk-rich-dialog-actions button.primary {
  background: var(--re-accent, #FF4500); border-color: var(--re-accent, #FF4500); color: #fff;
}
`;
  document.head.appendChild(style);
}

function openMask(): HTMLDivElement {
  ensureStyles();
  const mask = document.createElement("div");
  mask.className = "wk-rich-dialog-mask";
  document.body.appendChild(mask);
  return mask;
}

export function promptText(
  title: string,
  defaultValue = "",
  placeholder = ""
): Promise<string | null> {
  return new Promise((resolve) => {
    const mask = openMask();
    const box = document.createElement("div");
    box.className = "wk-rich-dialog";
    box.innerHTML = `<h3></h3><input type="text" /><div class="wk-rich-dialog-actions"><button type="button" data-act="cancel">取消</button><button type="button" class="primary" data-act="ok">确定</button></div>`;
    box.querySelector("h3")!.textContent = title;
    const input = box.querySelector("input") as HTMLInputElement;
    input.value = defaultValue;
    input.placeholder = placeholder;
    mask.appendChild(box);

    const done = (v: string | null) => {
      mask.remove();
      resolve(v);
    };
    box.querySelector('[data-act="cancel"]')!.addEventListener("click", () =>
      done(null)
    );
    box.querySelector('[data-act="ok"]')!.addEventListener("click", () =>
      done(input.value)
    );
    mask.addEventListener("click", (e) => {
      if (e.target === mask) done(null);
    });
    setTimeout(() => input.focus(), 50);
  });
}

export function promptTableSize(
  defaultRows = 3,
  defaultCols = 3
): Promise<{ rows: number; cols: number } | null> {
  return new Promise((resolve) => {
    const mask = openMask();
    const box = document.createElement("div");
    box.className = "wk-rich-dialog";
    box.innerHTML = `
      <h3>插入表格</h3>
      <p>选择预设，或自定义行数与列数</p>
      <div class="wk-rich-dialog-presets">
        <button type="button" data-r="2" data-c="2">2×2</button>
        <button type="button" data-r="3" data-c="3">3×3</button>
        <button type="button" data-r="4" data-c="4">4×4</button>
        <button type="button" data-r="5" data-c="3">5×3</button>
      </div>
      <div class="wk-rich-dialog-row">
        <label>行数<input type="number" min="2" max="20" data-f="rows" /></label>
        <label>列数<input type="number" min="2" max="10" data-f="cols" /></label>
      </div>
      <div class="wk-rich-dialog-actions">
        <button type="button" data-act="cancel">取消</button>
        <button type="button" class="primary" data-act="ok">插入</button>
      </div>`;
    const rowsInput = box.querySelector('[data-f="rows"]') as HTMLInputElement;
    const colsInput = box.querySelector('[data-f="cols"]') as HTMLInputElement;
    rowsInput.value = String(defaultRows);
    colsInput.value = String(defaultCols);
    mask.appendChild(box);

    const done = (v: { rows: number; cols: number } | null) => {
      mask.remove();
      resolve(v);
    };
    const clamp = (n: number, min: number, max: number, fallback: number) => {
      if (!Number.isFinite(n)) return fallback;
      return Math.min(max, Math.max(min, Math.floor(n)));
    };
    const read = () => ({
      rows: clamp(Number(rowsInput.value), 2, 20, defaultRows),
      cols: clamp(Number(colsInput.value), 2, 10, defaultCols),
    });

    box.querySelectorAll("[data-r]").forEach((btn) => {
      btn.addEventListener("click", () => {
        const el = btn as HTMLElement;
        rowsInput.value = el.getAttribute("data-r") || "3";
        colsInput.value = el.getAttribute("data-c") || "3";
      });
    });
    box.querySelector('[data-act="cancel"]')!.addEventListener("click", () =>
      done(null)
    );
    box.querySelector('[data-act="ok"]')!.addEventListener("click", () =>
      done(read())
    );
    mask.addEventListener("click", (e) => {
      if (e.target === mask) done(null);
    });
  });
}

export function confirmDialog(
  title: string,
  message: string
): Promise<boolean> {
  return new Promise((resolve) => {
    const mask = openMask();
    const box = document.createElement("div");
    box.className = "wk-rich-dialog";
    box.innerHTML = `<h3></h3><p></p><div class="wk-rich-dialog-actions"><button type="button" data-act="cancel">取消</button><button type="button" class="primary" data-act="ok">确定</button></div>`;
    box.querySelector("h3")!.textContent = title;
    box.querySelector("p")!.textContent = message;
    mask.appendChild(box);
    const done = (v: boolean) => {
      mask.remove();
      resolve(v);
    };
    box.querySelector('[data-act="cancel"]')!.addEventListener("click", () =>
      done(false)
    );
    box.querySelector('[data-act="ok"]')!.addEventListener("click", () =>
      done(true)
    );
    mask.addEventListener("click", (e) => {
      if (e.target === mask) done(false);
    });
  });
}
