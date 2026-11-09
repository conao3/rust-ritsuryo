#![doc = include_str!("../README.md")]

mod generated;

use std::fmt;

use generated::ritsuryo_rs_api as api;
use lean_rust::{Int, Nat};

/// The format of the output of [`invoke_rendered`], as the CLI's `--output` takes it.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Output {
    Json,
    Text,
    Table,
}

impl Output {
    fn as_str(self) -> &'static str {
        match self {
            Output::Json => "json",
            Output::Text => "text",
            Output::Table => "table",
        }
    }
}

/// A failed computation, with the exit code the `ritsuryo` CLI gives it: 252 for a wrong
/// command or parameter, 254 for an input outside the range the computation handles (a date that
/// does not exist, a year outside the holiday table), 255 for other failures.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Error {
    pub code: u32,
    pub message: String,
}

impl fmt::Display for Error {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{} (exit code {})", self.message, self.code)
    }
}

impl std::error::Error for Error {}

/// Runs the subcommand `subcommand` of the command `command` of the `ritsuryo` CLI on `params`,
/// a JSON object with the CLI's parameter names in PascalCase, and returns the JSON the CLI
/// prints.
///
/// ```
/// let out = ritsuryo::invoke(
///     "income-tax",
///     "compute-tax",
///     &serde_json::json!({"TaxYear": 2025, "TaxableIncome": 5_000_000}),
/// )
/// .unwrap();
/// assert_eq!(out["Result"]["IncomeTax"], 572_500);
/// ```
pub fn invoke(
    command: &str,
    subcommand: &str,
    params: &serde_json::Value,
) -> Result<serde_json::Value, Error> {
    let out = invoke_rendered(command, subcommand, &params.to_string(), Output::Json)?;
    Ok(serde_json::from_str(&out).expect("the CLI's JSON output parses"))
}

/// Like [`invoke`], with the parameters as JSON text and the result rendered as `output`.
pub fn invoke_rendered(
    command: &str,
    subcommand: &str,
    params_json: &str,
    output: Output,
) -> Result<String, Error> {
    api::invoke(command, subcommand, params_json, output.as_str()).map_err(|f| Error {
        code: f.code,
        message: f.message,
    })
}

/// The command table of the CLI as JSON text: for each command its `Name`, `Help` and
/// `Subcommands`, and for each subcommand its `Params` (`Name`, `Key`, `Help`, `Required`,
/// `Type`).
pub fn describe() -> String {
    api::describe()
}

fn to_u64(n: Nat) -> u64 {
    u64::try_from(n).expect("the value fits in u64")
}

/// The holidays of 国民の祝日に関する法律, from the table of the Cabinet Office.
pub mod holiday {
    use super::*;

    /// The kind of a row of the holiday table.
    #[derive(Clone, Copy, Debug, PartialEq, Eq)]
    pub enum Kind {
        /// 国民の祝日 of 第2条.
        National,
        /// A row named 休日（祝日扱い）.
        TreatedAsNational,
        /// A holiday by a special law (結婚の儀, 大喪の礼, 即位礼正殿の儀).
        SpecialLaw,
        /// 休日 of 第3条第2項 or 第3項 (振替休日, 国民の休日).
        Rest,
    }

    /// A row of the holiday table.
    #[derive(Clone, Debug, PartialEq, Eq)]
    pub struct Holiday {
        pub month: u32,
        pub day: u32,
        pub name: String,
        pub kind: Kind,
    }

    /// Whether the day is a holiday (a row of the holiday table). Outside the range of the table
    /// ([`year_in_range`]) no day is.
    pub fn is_holiday(year: i64, month: u32, day: u32) -> bool {
        api::is_holiday(Int::from(year), Nat::from(month), Nat::from(day))
    }

    /// Whether the holiday table covers the year.
    pub fn year_in_range(year: i64) -> bool {
        api::holiday_year_in_range(Int::from(year))
    }

    /// The holidays of the year, in date order (empty outside the range of the table).
    pub fn holidays(year: i64) -> Vec<Holiday> {
        api::holidays(Int::from(year))
            .into_iter()
            .map(|e| Holiday {
                month: to_u64(e.month) as u32,
                day: to_u64(e.day) as u32,
                name: e.name,
                kind: match e.kind.as_str() {
                    "national" => Kind::National,
                    "treated-as-national" => Kind::TreatedAsNational,
                    "special-law" => Kind::SpecialLaw,
                    "rest" => Kind::Rest,
                    k => unreachable!("unknown holiday kind {k}"),
                },
            })
            .collect()
    }
}

/// 所得税法 第89条, with 復興特別所得税 and 防衛特別所得税.
pub mod income_tax {
    use super::*;

    /// The income tax on taxable incomes, in yen.
    #[derive(Clone, Debug, PartialEq, Eq)]
    pub struct IncomeTax {
        /// The taxable ordinary income, rounded down to 1,000 yen.
        pub ordinary_base: u64,
        /// The taxable retirement income, rounded down to 1,000 yen.
        pub retirement_base: u64,
        /// The taxable timber income, rounded down to 1,000 yen.
        pub timber_base: u64,
        pub ordinary_tax: u64,
        pub retirement_tax: u64,
        pub timber_tax: u64,
        /// 所得税 (第89条).
        pub income_tax: u64,
        /// 復興特別所得税.
        pub reconstruction_tax: u64,
        /// 防衛特別所得税.
        pub defense_tax: u64,
        /// The sum of the three taxes.
        pub total: u64,
        /// The total rounded down to 100 yen.
        pub payable: u64,
    }

    /// The income tax of the year `year` on the taxable ordinary, retirement and timber incomes.
    pub fn compute(year: u32, ordinary: u64, retirement: u64, timber: u64) -> IncomeTax {
        let r = api::income_tax(
            Nat::from(year),
            Nat::from(ordinary),
            Nat::from(retirement),
            Nat::from(timber),
        );
        IncomeTax {
            ordinary_base: to_u64(r.ordinary_base),
            retirement_base: to_u64(r.retirement_base),
            timber_base: to_u64(r.timber_base),
            ordinary_tax: to_u64(r.ordinary_tax),
            retirement_tax: to_u64(r.retirement_tax),
            timber_tax: to_u64(r.timber_tax),
            income_tax: to_u64(r.income_tax),
            reconstruction_tax: to_u64(r.reconstruction_tax),
            defense_tax: to_u64(r.defense_tax),
            total: to_u64(r.total),
            payable: to_u64(r.payable),
        }
    }
}
