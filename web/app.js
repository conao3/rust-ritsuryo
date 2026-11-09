import init, { describe, invoke } from "./pkg/ritsuryo_wasm.js";

const $ = (id) => document.getElementById(id);

const commandSelect = $("command");
const subcommandSelect = $("subcommand");
const paramsBox = $("params");
const helpText = $("help");
const form = $("form");
const runButton = $("run");
const statusText = $("status");
const resultBox = $("result");
const cliText = $("cli");

let commands = [];

function el(tag, attrs = {}, children = []) {
  const e = document.createElement(tag);
  for (const [k, v] of Object.entries(attrs)) {
    if (k === "class") e.className = v;
    else if (k === "text") e.textContent = v;
    else if (v === true) e.setAttribute(k, "");
    else if (v !== false && v !== undefined) e.setAttribute(k, v);
  }
  for (const c of children) e.append(c);
  return e;
}

function today() {
  const d = new Date();
  const p = (n) => String(n).padStart(2, "0");
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}`;
}

function currentCommand() {
  return commands.find((c) => c.Name === commandSelect.value);
}

function currentSubcommand() {
  return currentCommand()?.Subcommands.find((s) => s.Name === subcommandSelect.value);
}

function scalarInput(type, name, required) {
  switch (type.Kind) {
    case "date":
      return el("input", { type: "date", name, required, value: required ? today() : undefined });
    case "nat":
      return el("input", { type: "number", name, min: "0", step: "1", inputmode: "numeric", required });
    case "decimal":
      return el("input", { type: "text", name, inputmode: "decimal", pattern: "\\d+(\\.\\d)?", required });
    case "enum": {
      const s = el("select", { name, required });
      if (!required) s.append(el("option", { value: "", text: "（指定しない）" }));
      for (const v of type.Values) s.append(el("option", { value: v, text: v }));
      return s;
    }
    default:
      return el("input", { type: "text", name, required });
  }
}

function structRow(fields) {
  const row = el("div", { class: "struct-row" });
  for (const f of fields) {
    const input = scalarInput(f.Type, f.Name, true);
    row.append(el("label", {}, [el("span", { text: f.Name }), input]));
  }
  const remove = el("button", { type: "button", class: "ghost", text: "削除", "aria-label": "この行を削除" });
  remove.addEventListener("click", () => row.remove());
  row.append(remove);
  return row;
}

function paramField(p) {
  const id = `p-${p.Name}`;
  const label = el("span", { class: "param-name" }, [
    el("code", { text: `--${p.Name}` }),
    p.Required ? el("span", { class: "required", text: "必須" }) : "",
  ]);
  const help = el("small", { class: "param-help", text: p.Help });
  const wrap = el("div", { class: "param", "data-key": p.Key, "data-kind": p.Type.Kind });

  switch (p.Type.Kind) {
    case "flag": {
      const input = el("input", { type: "checkbox", id });
      wrap.append(el("label", { class: "check", for: id }, [input, label]), help);
      return wrap;
    }
    case "enum-list": {
      const box = el("div", { class: "choices" });
      for (const v of p.Type.Values) {
        box.append(el("label", { class: "check" }, [el("input", { type: "checkbox", value: v }), v]));
      }
      wrap.append(el("div", { class: "label" }, [label]), box, help);
      return wrap;
    }
    case "struct-list": {
      const rows = el("div", { class: "struct-rows" });
      const add = el("button", { type: "button", class: "ghost", text: "行を足す" });
      add.addEventListener("click", () => rows.append(structRow(p.Type.Fields)));
      if (p.Required) rows.append(structRow(p.Type.Fields));
      wrap.append(el("div", { class: "label" }, [label]), rows, add, help);
      return wrap;
    }
    default: {
      const input = scalarInput(p.Type, p.Key, p.Required);
      input.id = id;
      wrap.append(el("label", { for: id, class: "label" }, [label]), input, help);
      return wrap;
    }
  }
}

function scalarValue(kind, raw) {
  if (raw === "") return undefined;
  return kind === "nat" ? Number(raw) : raw;
}

function collect() {
  const params = {};
  const argv = [commandSelect.value, subcommandSelect.value];
  for (const wrap of paramsBox.querySelectorAll(".param")) {
    const key = wrap.dataset.key;
    const kind = wrap.dataset.kind;
    const p = currentSubcommand().Params.find((x) => x.Key === key);
    if (kind === "flag") {
      const checked = wrap.querySelector("input").checked;
      if (checked) {
        params[key] = true;
        argv.push(`--${p.Name}`);
      }
    } else if (kind === "enum-list") {
      const vs = [...wrap.querySelectorAll("input:checked")].map((i) => i.value);
      if (vs.length) {
        params[key] = vs;
        argv.push(`--${p.Name}`, ...vs);
      }
    } else if (kind === "struct-list") {
      const rows = [...wrap.querySelectorAll(".struct-row")].map((row) => {
        const obj = {};
        for (const f of p.Type.Fields) {
          obj[f.Name] = row.querySelector(`[name="${f.Name}"]`).value;
        }
        return obj;
      });
      if (rows.length) {
        params[key] = rows;
        argv.push(
          `--${p.Name}`,
          ...rows.map((r) => Object.entries(r).map(([k, v]) => `${k}=${v}`).join(",")),
        );
      }
    } else {
      const v = scalarValue(kind, wrap.querySelector("input, select").value.trim());
      if (v !== undefined) {
        params[key] = v;
        argv.push(`--${p.Name}`, String(v));
      }
    }
  }
  return { params, argv };
}

function showCli() {
  const { argv } = collect();
  cliText.textContent = `ritsuryo ${argv.join(" ")}`;
}

function renderParams() {
  const sub = currentSubcommand();
  helpText.textContent = sub.Help;
  paramsBox.replaceChildren(...sub.Params.map(paramField));
  showCli();
}

function renderSubcommands() {
  const cmd = currentCommand();
  subcommandSelect.replaceChildren(
    ...cmd.Subcommands.map((s) => el("option", { value: s.Name, text: s.Name })),
  );
  renderParams();
}

function run() {
  const { params } = collect();
  const output = form.elements.output.value;
  resultBox.hidden = false;
  try {
    const started = performance.now();
    const out = invoke(commandSelect.value, subcommandSelect.value, JSON.stringify(params), output);
    const ms = (performance.now() - started).toFixed(1);
    resultBox.textContent = out;
    resultBox.classList.remove("error");
    statusText.textContent = `計算しました（${ms} ms）`;
  } catch (e) {
    let failure = { Code: 255, Message: String(e) };
    try {
      failure = JSON.parse(e);
    } catch {}
    resultBox.textContent = failure.Message;
    resultBox.classList.add("error");
    statusText.textContent = `計算できませんでした（終了コード ${failure.Code}）`;
  }
}

commandSelect.addEventListener("change", renderSubcommands);
subcommandSelect.addEventListener("change", renderParams);
form.addEventListener("input", showCli);
form.addEventListener("click", () => queueMicrotask(showCli));
form.addEventListener("submit", (ev) => {
  ev.preventDefault();
  run();
});

try {
  await init();
  commands = JSON.parse(describe());
  commandSelect.replaceChildren(
    ...commands.map((c) => el("option", { value: c.Name, text: `${c.Name} — ${c.Help}` })),
  );
  renderSubcommands();
  runButton.disabled = false;
  statusText.textContent = "パラメータを入れて「計算する」を押してください";
} catch (e) {
  statusText.textContent = `WebAssembly を読み込めませんでした: ${e}`;
}
