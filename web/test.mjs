// Runs the WebAssembly module under Node and compares it with values the Lean CLI prints.
import { readFile } from "node:fs/promises";
import assert from "node:assert/strict";
import { initSync, describe, invoke, isHoliday } from "./pkg/ritsuryo_wasm.js";

initSync({ module: await readFile(new URL("./pkg/ritsuryo_wasm_bg.wasm", import.meta.url)) });

const commands = JSON.parse(describe());
assert.ok(commands.some((c) => c.Name === "income-tax"));

const tax = JSON.parse(
  invoke("income-tax", "compute-tax", JSON.stringify({ TaxYear: 2025, TaxableIncome: 5000000 }), "json"),
);
assert.equal(tax.Result.IncomeTax, 572500);
assert.equal(tax.Result.Payable, 584500);

const holiday = JSON.parse(invoke("holiday", "check-holiday", JSON.stringify({ Date: "2026-11-23" }), "json"));
assert.equal(holiday.Result.NationalHoliday.Name, "勤労感謝の日");
assert.equal(isHoliday(2026, 11, 23), true);
assert.equal(isHoliday(2026, 11, 24), false);

assert.throws(
  () => invoke("income-tax", "compute-tax", "{}", "json"),
  (e) => JSON.parse(e).Code === 252,
);
assert.throws(
  () => invoke("holiday", "check-holiday", JSON.stringify({ Date: "2026-02-30" }), "json"),
  (e) => JSON.parse(e).Code === 254,
);

console.log("wasm: ok");
