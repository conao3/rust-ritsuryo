import Ritsuryo
import Ritsuryo.Cli.Commands
import Ritsuryo.Cli.Render

/-!
# The functions the Rust crate exports

lean-rust compiles this module, with everything it calls in `ritsuryo`, to one Rust module in
`crates/ritsuryo/src/generated/`.

- `invoke` runs a subcommand of the `ritsuryo` CLI on parameters given as a JSON object, through
  the same command table, value checks and computations as the CLI, without IO.
- `describe` gives the command table as JSON, from which the web page builds its forms.
- `isHoliday`, `holidays` and `incomeTax` call the library functions directly, with Rust types.
-/

namespace RitsuryoRs.Api

open Ritsuryo Ritsuryo.Cli

/-- A failed `invoke`: the exit code of the CLI (252, 254 or 255) and its message. -/
structure Failure where
  code : UInt32
  message : String

/-- A row of the holiday table of a year. `kind` is `national`, `treated-as-national`,
`special-law` or `rest`. -/
structure HolidayEntry where
  month : Nat
  day : Nat
  name : String
  kind : String

private def failureOf (e : CliError) : Failure := ⟨e.code, e.message⟩

private def outputFormatOf : String → Except CliError OutputFormat
  | "json" => pure .json
  | "text" => pure .text
  | "table" => pure .table
  | v => throw (usageError s!"--output には json | text | table を渡す（{v} は使えない）")

private def renderOutput (fmt : OutputFormat) (title : String) (j : Json) : String :=
  match fmt with
  | .json => Json.pretty j ++ "\n"
  | .text => renderText j
  | .table => renderTable title j

/-- Checks the fields of `params` (keys in PascalCase, as the CLI's JSON output names them)
against the parameters of `sub`, the same way the CLI checks its command line. -/
private def bindJson (sub : Subcommand) (params : Json) : Except CliError Args := do
  let fields ← match params with
    | .obj fields => pure fields
    | .null => pure #[]
    | _ => throw (usageError "パラメータには JSON のオブジェクトを渡す")
  let mut values : Array (String × Json) := #[]
  for (key, v) in fields do
    match sub.params.find? (·.key == key) with
    | none => throw (usageError s!"{key} は {sub.name} のパラメータではない")
    | some p => values := (values.filter (·.1 != key)).push (key, ← checkValue p v)
  for p in sub.params do
    if p.required && !(values.any (·.1 == p.key)) then
      throw (usageError s!"{p.key} は必須")
  return ⟨values⟩

private def invokeCore (command subcommand paramsJson output : String) : Except CliError String := do
  let fmt ← outputFormatOf output
  let cmd ← match commands.find? (·.name == command) with
    | some c => pure c
    | none => throw (usageError s!"コマンド {command} はない")
  let sub ← match cmd.subcommands.find? (·.name == subcommand) with
    | some s => pure s
    | none => throw (usageError s!"サブコマンド {subcommand} はない")
  let params ← match Json.parse paramsJson with
    | .ok j => pure j
    | .error e => throw (usageError s!"パラメータの JSON を解析できない: {e}")
  let args ← bindJson sub params
  let j ← sub.run args
  return renderOutput fmt (pascalCase sub.name) j

/-- Runs `ritsuryo <command> <subcommand>` with the parameters in `paramsJson` (a JSON object
with PascalCase keys, such as `{"TaxYear": 2025, "TaxableIncome": 5000000}`), and renders the
result as `output` (`json`, `text` or `table`), as the CLI prints it. -/
def invoke (command subcommand paramsJson output : String) : Except Failure String :=
  (invokeCore command subcommand paramsJson output).mapError failureOf

private def paramTypeJson : ParamType → Json
  | .date => .obj #[("Kind", .str "date")]
  | .nat => .obj #[("Kind", .str "nat")]
  | .flag => .obj #[("Kind", .str "flag")]
  | .decimal => .obj #[("Kind", .str "decimal")]
  | .enum vs => .obj #[("Kind", .str "enum"), ("Values", .arr (vs.toArray.map .str))]
  | .enumList vs => .obj #[("Kind", .str "enum-list"), ("Values", .arr (vs.toArray.map .str))]
  | .structList fields =>
    .obj #[("Kind", .str "struct-list"),
      ("Fields", .arr (fields.toArray.map fun (k, t) =>
        .obj #[("Name", .str k), ("Type", match t with
          | .nat => .obj #[("Kind", .str "nat")]
          | .decimal => .obj #[("Kind", .str "decimal")]
          | .date => .obj #[("Kind", .str "date")]
          | .enum vs => .obj #[("Kind", .str "enum"), ("Values", .arr (vs.toArray.map .str))]
          | _ => .obj #[("Kind", .str "string")])]))]

private def paramJson (p : Param) : Json :=
  .obj #[("Name", .str p.name), ("Key", .str p.key), ("Help", .str p.help),
    ("Required", .bool p.required), ("Type", paramTypeJson p.type)]

/-- The command table of the CLI as JSON: the commands, their subcommands and parameters. -/
def describe : String :=
  Json.pretty (.arr (commands.toArray.map fun c =>
    .obj #[("Name", .str c.name), ("Help", .str c.help),
      ("Subcommands", .arr (c.subcommands.toArray.map fun s =>
        .obj #[("Name", .str s.name), ("Help", .str s.help),
          ("Params", .arr (s.params.toArray.map paramJson))]))]))

/-- Whether the day is a holiday under 国民の祝日に関する法律 (a row of the holiday table). -/
def isHoliday (year : Int) (month day : Nat) : Bool :=
  Holiday.isHoliday ⟨year, month, day⟩

/-- Whether the year is in the range of the holiday table. -/
def holidayYearInRange (year : Int) : Bool :=
  Holiday.inRange ⟨year, 1, 1⟩

private def kindText : Holiday.EntryKind → String
  | .national => "national"
  | .treatedAsNational => "treated-as-national"
  | .specialLaw => "special-law"
  | .rest => "rest"

/-- The rows of the holiday table of the year (empty outside the range of the table). -/
def holidays (year : Int) : List HolidayEntry :=
  (Holiday.entriesOf year).map fun e => ⟨e.month, e.day, e.name, kindText e.kind⟩

/-- 所得税法 第89条 with 復興特別所得税 and 防衛特別所得税, on the taxable incomes in yen. -/
def incomeTax (year ordinary retirement timber : Nat) : Tax.Income.Result :=
  Tax.Income.compute year ordinary retirement timber

end RitsuryoRs.Api
