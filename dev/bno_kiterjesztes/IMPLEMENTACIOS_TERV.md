## ICD-7 (07A) back-extension — implementation plan

### Scope & honest bounds
- **Delivers:** Hungary harmonized series extended from 1969 back to **1955** (+14 yrs) for the broad chapters and major cancer/CVD cause groups, via WHO ICD-7 List **07A**. Count, crude rate, AND ESP2013 age-standardized rate all computable (HUN 07A years are Frmat 2/1, which pass the `Frmat %in% c(0,1,2)` filter — verified in the dossier from the raw `morticd07.zip`).
- **Does NOT deliver the 1940s.** WHO MDB floor = 1950; 1940s = ICD-5 (1938), absent from every `morticd*` file. The true-1940s path is a *separate* future national-source (KSH) module (`List="05A"`), gated on Ferenci providing OCR'd, age-detailed, territorially-reconciled input data. Left as a documented stub, mechanism-compatible (same List-keyed join), not built here.
- **Other countries:** 07A also covers other countries 1950-1972, but coverage is country-dependent on their Frmat. This plan scopes the *crosswalk curation* to Hungary's reality; non-HUN 07A rows light up automatically wherever a group is mapped and that country's Frmat passes the filter.

### Architecture (recap)
Edition-registry-lite for ingestion + inline 07A rows in his existing Groups blocks + coverage metadata. **No change to how app.R consumes ICDGroups.** Graceful degradation is already free via the two List-keyed inner joins in `dataInputFun` (app.R:639 skeleton-on-`List`; app.R:641 deaths-on-`(List,Cause)`): a group with no `07A` row produces zero skeleton rows for 07A country-years → empty 1955-1968 instead of an error.

---

### Phase 0 — Acquire & verify input data (effort: S, risk: L)
1. Download `morticd07.zip` (~5 MB, 281,749 rows; URL in dataToObtain) → `inputdata/morticd07.zip`. Commit alongside existing `morticd08/09/10` zips (repo convention: inputs committed).
2. Download WHO MDB **Documentation** PDF (Table 1 = ICD7 A-List) → working copy only (not committed). This is the source of truth for the 07A "A0xx" code→cause map.
3. Sanity-read in R (no repo change yet): confirm `fread` of the extracted `MortIcd7` gives 39 cols identical to `morticd08`; `table(List)` = {07A, 07B}; for `Country==4150` (Hungary): years 1955-1968, all 07A, `table(Frmat)` ⊆ {1,2}. **Gate:** if any HUN 07A year has Frmat ∉ {0,1,2}, that year will be silently dropped at line 418 — re-scope expectations before proceeding.

### Phase 1 — Ingestion registry (effort: S, risk: L)
README.Rmd chunk at ~357-372:
- Add, just before the unzips, an edition registry table `ICDEditions` (see scaffold) and a `morticd_files` vector derived from it (or list directly).
- Replace the 9 literal `unzip(...)` lines with one `invisible(lapply(morticd_files, function(f) unzip(file.path("./inputdata", f), exdir = td)))`.
- Leave `RawData <- rbindlist(lapply(list.files(td, "Morticd*", full.names=TRUE), fread))` and everything below it (418 filter, 442-453 age reshaping, 458 melt, 474-499 104-gated cleanups) **unchanged**.
- **Validation in-chunk:** after RawData is built, assert `RawData[List=="07A" & iso3c=="HUN", range(Year)] == c(1955,1968)`.

### Phase 2 — ICD-7 (07A) crosswalk rows, inline (effort: M, risk: M — the hand-curation)
README.Rmd ICDGroups$Groups blocks (666-1227). For each **broad/unambiguous** group the ~150-cause A-list can faithfully fill, append ONE row `data.table(Cause = c(<07A codes>), List = "07A")` inside its `rbind(...)`, directly under the `List="08A"` row. Target set (start here; each is a single A-code or clean union per WHO Table 1):
- Összes halálok (total) ; Fertőző és parazitás (A,B chapter) ; Gümőkór (TB) ; Daganatok (C00-D48) ; Rosszindulatú daganatok (C00-C97) ; ajak/szájüreg/garat (C00-C14) ; nyelőcső (C15) ; **gyomor C16 ← A046** ; vastagbél/végbél (C18-C21 ← A047) ; gégefő/légcső/tüdő ; emlő ; Keringési rendszer (I00-I99) ; arterioscleroticus szívbetegség (← A081) ; Légzőrendszer (J) ; Emésztőrendszer (K) ; Külső okok (V01-Y89).
- **CRITICAL:** transcribe every 07A code from WHO Documentation Table 1. Do **not** copy the 08A `A0xx` values — ICD-7 List-A numbering differs (e.g. stomach is A046 in ICD-7 vs A047 in ICD-8). Spot-check 2-3 codes against a known WHO total.
- **Weight:** new rows inherit `Weight=1` from the cbind at 1303 — no edit there. If and only if one 07A code provably straddles two modern groups, set `Weight=0.5` on those two rows in a post-hoc block mirroring 1307-1321 (sourcing the split from NCHS ICD-7↔ICDA-8 comparability ratios). If the split is unknown, prefer mapping the code whole to the common parent chapter at Weight=1 (correctness over coverage). Add an invariant check: for each `(List,Cause)`, sum of Weights across groups it appears in == 1.
- **Leave Individual (1228) and Avoidable (1231) List="104"-only**, with a one-line comment that this is intentional (per-ICD-10-code / avoidable-definition granularity does not exist pre-ICD-10) — extends his own note at line 1326.

### Phase 3 — Coverage metadata + optional UI (effort: S, risk: L)
- After the crosswalk builds, compute `GroupCoverage <- ` earliest resolvable Year per (CauseGroup × iso3c) given the assembled crosswalk AND the post-Frmat-filter RawData; `saveRDS(..., "./procdata/GroupCoverage.rds")`.
- README prose: a short table listing which broad groups received 07A and which fine groups are intentionally coarse-dropped for 1955-1968 (documented graceful degradation).
- (Optional, additive) app.R: read GroupCoverage.rds and render an "Elérhető: {év}-tól" hint near the cause picker (`ownpanel()` ~app.R:115); optionally annotate the year-slider left edge. **No change to `dataInputFun`.** Skippable without affecting the core deliverable.

### Phase 4 — Re-render & validate (effort: S, risk: M — build is long, has network deps)
- `Rscript -e "rmarkdown::render('README.Rmd')"` regenerates `procdata/WHO-MDB.{rds,feather}`, `RawDataAll.rds`, `ICDGroups.rds` (+ `GroupCoverage.rds`). Commit the regenerated `procdata/` **in the same change** as the input zip and code (never hand-edit procdata).
- **Smoke tests:** (a) a top-level group (Összes halálok, Rosszindulatú daganatok) returns non-empty count/cruderate/adjrate for HUN 1955-1968; (b) a deliberately-unmapped fine group (a specific C-site given no 07A row) returns empty for 1955-1968 and non-empty from 1969 — proving degradation end-to-end; (c) level-continuity check: the 1968(08A) vs 1969 and 1955-1968 totals are plausibly continuous (catches mis-transcribed A-codes).
- **Schema guard:** `identical(names(readRDS('procdata/ICDGroups.rds')$Groups[[1]]), c("Cause","List","EurostatCode","CauseGroup","Weight"))` must hold.

### Phased rollout / de-risking
- **Stage A (de-risk data):** Phases 0-1 only — ingest 07A, re-render, confirm RawData has HUN 1955-1968 — before writing any crosswalk row. Proves the file & filter assumptions cheaply.
- **Stage B (value):** Phase 2 for ~6 chapter-level groups first (Összes, Daganatok, Rosszindulatú daganatok, Keringési, Légzőrendszer, Külső okok), render, eyeball charts.
- **Stage C (breadth):** add the per-site cancer/CVD groups (C15, C16, C18-C21, lung, breast, arteriosclerotic heart).
- **Stage D (polish):** Phase 3 metadata + optional UI hint; README prose; CLAUDE.md note ("ICD-7 / 07A added; older editions = registry row + inline crosswalk rows; 1940s needs national ICD-5 data").

### Effort/risk summary
| Phase | Effort | Risk | Main risk |
|---|---|---|---|
| 0 Acquire/verify | S | Low | HUN Frmat — mitigated, verified |
| 1 Ingestion registry | S | Low | glob already generic |
| 2 07A crosswalk (curate) | M | **Med** | hand-transcribing A-codes ≠ 08A |
| 3 Coverage metadata/UI | S | Low | optional |
| 4 Render/validate | S | Med | long build, network deps; must re-commit procdata |

### What remains hand-curated (unavoidable)
- Per-group ICD-7 List-A code transcription from WHO Table 1 (bounded to ~12-25 broad groups).
- Any Weight=0.5 cross-edition split decisions (only where a code straddles two groups; sourced from NCHS ratios).
- The 1940s/ICD-5 module is NOT hand-curation-deferrable — it is **data-blocked** until KSH-sourced, OCR'd, age-detailed, territorially-reconciled input exists.
