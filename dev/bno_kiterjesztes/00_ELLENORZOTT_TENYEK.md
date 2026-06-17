# Verified facts — ICD/BNO back-extension (2026-06-16)

Working notes (git-excluded `dev/`). Companion to `IMPLEMENTACIOS_TERV.md` and
`edition_registry_scaffold.R` (the workflow synthesis). These are the points I checked against the actual
data/files, so trust these over any claim in the generated plan that conflicts.

## Empirically verified (ran against the real data)

- **Hungary IS in WHO `morticd07` (ICD-7).** Hungary's WHO MDB country code = **4150** (from the repo's own
  `xmart.csv`, `MORT` column — *not* 3300). `MortIcd7` has **4088 Hungarian rows, years 1955–1968, List
  `07A`** only (never `07B`). All-cause `A000` ≈ 49.8k→59.7k deaths/yr per sex (~110k total) = correct
  Hungarian magnitude.
- **Age format survives the pipeline.** Hungary's 07A years are `Frmat 2` (1955–1964) then `Frmat 1`
  (1965–1968); both pass the existing `Frmat %in% c(0,1,2)` filter → **ESP2013-standardized rates are
  computable** for the whole 1955–1968 extension.
- **Current shipped floor is 1969.** `procdata/WHO-MDB.rds` HUN range = 1969–2023 (List 08A/09B/104). The
  1969 floor is just because Tamás never ingested `morticd07`, *not* a WHO availability limit.
- **Net win: Hungary gains a verified +14 years → 1955.**
- **`morticd07` overall:** 281,749 rows, years 1950–1972, Lists `07A`+`07B`. Downloaded to
  `C:/Users/mrkma/AppData/Local/Temp/wf_icd7/` — **not yet committed** to `inputdata/`.

## Corrections to earlier assumptions (caught by the workflow's verify phase + my checks)

- **`Weight` is NOT used to redistribute old-edition codes.** In shipped `ICDGroups.rds`, every `Groups`
  and `Individual` mapping has `Weight=1`; the only `0.5` weights live in `Avoidable`, all on ICD-10
  (`List=104`) codes. So any cross-edition split would be the *first* such use — handle with care
  (invariant: per `(List,Cause)`, Σ Weight should = 1). CLAUDE.md has been corrected.
- **There are 93 cause groups, not ~95.**
- **ICD-10 isn't only `104`** in the data: `101`, `103`, `10M` variants also appear (all post-1996).
- **ICD-7 List-A codes ≠ ICD-8 List-A codes** despite the shared `A0xx` shape (e.g. stomach cancer = `A046`
  in ICD-7 vs `A047` in ICD-8). The 07A crosswalk must be **transcribed fresh** from WHO Documentation
  Table 1 — copying the existing `08A` rows would compile and produce plausible-but-wrong numbers.

## Out of reach / blocked

- **The 1940s is not obtainable from WHO MDB** (oldest data 1950, oldest edition ICD-7). True 1940s =
  ICD-5 (1938), available only as scanned-image KSH yearbook PDFs → would need OCR + post-Trianon
  territorial reconciliation + a bespoke crosswalk. Out of scope until Tamás supplies a digitized,
  age/sex-detailed pre-1950 series.
- **Pre-1970 caveat:** HMD starts Hungary at 1950 due to Trianon/WWII border changes, and pre-1970
  Hungarian vital stats used a de-facto (not resident) population basis. The 1955–1968 points sit on a
  slightly different footing than the modern series → warrants a Hungarian-language footnote, not a silent
  splice.
