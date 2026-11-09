//! The `ritsuryo` crate for JavaScript, through wasm-bindgen.

use wasm_bindgen::prelude::*;

fn escape(s: &str) -> String {
    let mut out = String::with_capacity(s.len() + 2);
    out.push('"');
    for c in s.chars() {
        match c {
            '"' => out.push_str("\\\""),
            '\\' => out.push_str("\\\\"),
            '\n' => out.push_str("\\n"),
            '\r' => out.push_str("\\r"),
            '\t' => out.push_str("\\t"),
            c if (c as u32) < 0x20 => out.push_str(&format!("\\u{:04x}", c as u32)),
            c => out.push(c),
        }
    }
    out.push('"');
    out
}

/// Runs `ritsuryo <command> <subcommand>` on the parameters in `params_json` (a JSON object with
/// PascalCase keys) and returns the output rendered as `output` (`json`, `text` or `table`).
/// On failure it throws a string with the JSON `{"Code": <exit code>, "Message": <message>}`.
#[wasm_bindgen]
pub fn invoke(
    command: &str,
    subcommand: &str,
    params_json: &str,
    output: &str,
) -> Result<String, JsValue> {
    let output = match output {
        "json" => ritsuryo::Output::Json,
        "text" => ritsuryo::Output::Text,
        "table" => ritsuryo::Output::Table,
        _ => {
            return Err(JsValue::from_str(&format!(
                "{{\"Code\": 252, \"Message\": {}}}",
                escape("output には json | text | table を渡す")
            )));
        }
    };
    ritsuryo::invoke_rendered(command, subcommand, params_json, output).map_err(|e| {
        JsValue::from_str(&format!(
            "{{\"Code\": {}, \"Message\": {}}}",
            e.code,
            escape(&e.message)
        ))
    })
}

/// The command table of the CLI as JSON text.
#[wasm_bindgen]
pub fn describe() -> String {
    ritsuryo::describe()
}

/// Whether the day is a holiday under 国民の祝日に関する法律.
#[wasm_bindgen(js_name = isHoliday)]
pub fn is_holiday(year: i32, month: u32, day: u32) -> bool {
    ritsuryo::holiday::is_holiday(year.into(), month, day)
}
