import Assay
import RitsuryoRs.Api

deriving instance Inhabited, DecidableEq for Ritsuryo.Tax.Income.Result

open Plausible

instance (priority := high) : Arbitrary Int where
  arbitrary := do
    let offset ← Gen.choose Nat 0 80 (by decide)
    return 1951 + Int.ofNat offset.val

instance (priority := high) : Arbitrary Nat where
  arbitrary := do
    let branch ← Gen.choose Nat 0 2 (by decide)
    if branch.val = 0 then
      return (← Gen.choose Nat 0 32 (by decide)).val
    else if branch.val = 1 then
      return (← Gen.choose Nat 0 50000000 (by decide)).val
    else
      let values := #[0, 999, 1000, 1001, 2012, 2013, 2026, 2027, 2047, 2048,
        1949999, 1950000, 1950001, 3300000, 6950000, 9000000, 18000000, 40000000]
      return values[(← Gen.choose Nat 0 (values.size - 1) (by decide)).val]!

#assay RitsuryoRs.Api.invoke
#assay RitsuryoRs.Api.isHoliday
#assay RitsuryoRs.Api.holidayYearInRange
#assay RitsuryoRs.Api.holidays
#assay RitsuryoRs.Api.incomeTax
