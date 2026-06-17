## ============================================================================
## ICD-7 (07A) back-extension — runnable scaffold (Ferenci data.table idiom)
## Drop the registry chunk into README.Rmd ~357; the 07A rows go INLINE into the
## existing ICDGroups$Groups blocks. Downstream (app.R) consumes ICDGroups UNCHANGED:
## columns Cause / List / EurostatCode / CauseGroup / Weight are preserved.
## ============================================================================

library(data.table)

## ---------------------------------------------------------------------------
## (1) EDITION REGISTRY  — single source of truth for which editions exist.
##     Drives the unzip loop; adding an edition = add a row + drop the zip in.
## ---------------------------------------------------------------------------
ICDEditions <- data.table(
  File        = c(paste0("morticd10_part", 1:6, ".zip"),
                  "morticd09.zip", "morticd08.zip", "morticd07.zip"),
  List        = c(rep("104", 6), "09x", "08x", "07A"),   # informative only
  Edition     = c(rep("BNO-10", 6), "BNO-9", "BNO-8", "BNO-7"),
  Granularity = c(rep("részletes", 6), "BTL", "A/B lista", "A lista (~150 ok)"),
  Status      = "supported"
)
## NOTE: morticd07.zip must be present in ./inputdata (committed). 07B is omitted
## (Hungary never reports List B; it is a trivial future add for other countries).

td <- tempdir()
invisible(lapply(ICDEditions[Status == "supported"]$File,
                 function(f) unzip(file.path("./inputdata", f), exdir = td)))

## --- everything below is the EXISTING pipeline, unchanged ------------------
RawData <- rbindlist(lapply(list.files(td, pattern = "Morticd*",
                                       full.names = TRUE), fread))
## ... (country-code merge, Frmat %in% c(0,1,2) filter, melt, 104-gated padding,
##      factor coercion, saveRDS WHO-MDB.{rds,feather}) all UNCHANGED ...

## Sanity gate (add near the validation section): ICD-7 ingested for Hungary?
stopifnot(identical(
  RawData[List == "07A" & iso3c == "HUN", range(as.integer(as.character(Year)))],
  c(1955L, 1968L)))


## ---------------------------------------------------------------------------
## (2) ONE FULLY WORKED OLDER-EDITION EXAMPLE — ICD-7 List 07A inline rows.
##     This is how each chosen Groups block gains a 07A sibling row. Codes are
##     ICD-7 List-A "A0xx" from WHO Documentation Table 1 (NOT the ICD-8 A-codes;
##     numbering differs — e.g. stomach = A046 in ICD-7 vs A047 in ICD-8).
##     Below are illustrative placements for a few top-level Groups exactly in
##     Ferenci's rbind() style. (ICDData is his BNO-10 master, already in scope.)
## ---------------------------------------------------------------------------

## ---- Összes halálok (total): ICD-7 A-list total = A000 ----
g_ossz <- data.table(rbind(
  data.table(Cause = ICDData[Kod1!="Z"&(Kod1!="Y"|Kod23<=89)]$KOD10, List = "104"),
  data.table(Cause = "A000", List = "08A"),
  data.table(Cause = "B000", List = "08B"),
  data.table(Cause = "B00",  List = "09A"),
  data.table(Cause = "B00",  List = "09B"),
  data.table(Cause = "C001", List = "09C"),
  data.table(Cause = "B00",  List = "09N"),
  data.table(Cause = "A000", List = "07A")),          # <-- ADDED (07A total)
  EurostatCode = "A-R_V-Y", CauseGroup = "Összes halálok (A00-Y89)")

## ---- A gyomor rosszindulatú daganata (C16): ICD-7 stomach = A046 ----
g_c16 <- data.table(rbind(
  data.table(Cause = ICDData[Kod1=="C"&Kod23==16]$KOD10, List = "104"),
  data.table(Cause = "A047", List = "08A"),
  data.table(Cause = "B091", List = "09A"),
  data.table(Cause = "B091", List = "09B"),
  data.table(Cause = "B091", List = "09N"),
  data.table(Cause = "A046", List = "07A")),          # <-- ADDED (07A stomach; A046 != 08A A047)
  EurostatCode = "C16", CauseGroup = "A gyomor rosszindulatú daganata (C16)")

## ---- Vastagbél, végbél, végbélnyílás (C18-C21): ICD-7 intestine exc. rectum = A047 ----
g_c18_21 <- data.table(rbind(
  data.table(Cause = ICDData[Kod1=="C"&Kod23>=18&Kod23<=21]$KOD10, List = "104"),
  data.table(Cause = c("153", "A049"), List = "08A"),
  data.table(Cause = c("B093", "B094"), List = "09A"),
  data.table(Cause = c("B093", "B094"), List = "09B"),
  data.table(Cause = c("B093", "B094"), List = "09N"),
  data.table(Cause = "A047", List = "07A")),          # <-- ADDED (07A intestine exc. rectum)
  EurostatCode = "C18-C21",
  CauseGroup = "A vastagbél, végbél és a végbélnyílás rosszindulatú daganatai (C18-C21)")

## ---- Rosszindulatú daganatok (C00-C97): ICD-7 all malignant = A044-A060 union ----
g_malig <- data.table(rbind(
  data.table(Cause = ICDData[Kod1=="C"]$KOD10, List = "104"),
  data.table(Cause = paste0("A", sprintf("%03d", 45:60)), List = "08A"),
  data.table(Cause = "B019", List = "08B"),
  data.table(Cause = c("B08","B09","B10","B11","B12","B13","B14"), List = "09A"),
  data.table(Cause = c("B08","B09","B10","B11","B12","B13","B14"), List = "09B"),
  data.table(Cause = "S08", List = "09N"),
  data.table(Cause = paste0("A", sprintf("%03d", 44:60)), List = "07A")), # <-- ADDED (verify exact A-range vs Table 1)
  EurostatCode = "C", CauseGroup = "Rosszindulatú daganatok (C00-C97)")

## ---- Arterioscleroticus szívbetegség (CVD subgroup): ICD-7 = A081 ----
## (placement shown schematically; goes into the matching I-chapter heart block)
## data.table(rbind( ...104..., data.table(Cause = "A081", List = "07A")), EurostatCode = "...", CauseGroup = "...")

## ===> Groups NOT given a 07A row (fine sub-sites, B180-B182 hepatitis, HIV, etc.)
##      get NO 1955-1968 data BY CONSTRUCTION. That is the graceful-degradation
##      behaviour: dataInputFun's skeleton join on List (app.R:639) yields zero
##      07A rows for them, so the series simply starts in 1969. No code change.


## ---------------------------------------------------------------------------
## (3) DOWNSTREAM-INVARIANT TAIL — unchanged from README.Rmd:1297-1331.
##     New 07A rows inherit Weight = 1 here automatically.
## ---------------------------------------------------------------------------
## ICDGroups$Groups    <- setNames(ICDGroups$Groups, sapply(ICDGroups$Groups, \(g) g$CauseGroup[1]))
## ICDGroups$Groups    <- lapply(ICDGroups$Groups, \(l) cbind(l, Weight = 1))
## ... (Individual & Avoidable stay List="104"-only; Avoidable 0.5 splits unchanged) ...
## saveRDS(ICDGroups, "./procdata/ICDGroups.rds")

## ---- OPTIONAL: first cross-edition Weight=0.5 split (only if a 07A code
##      straddles two modern groups; mirrors the Avoidable 0.5 pattern). Default
##      to parent-mapping at Weight=1 if the split fraction is unknown. ----
# ICDGroups$Groups$`<group A>`[Cause == "A0xx" & List == "07A"]$Weight <- 0.5
# ICDGroups$Groups$`<group B>`[Cause == "A0xx" & List == "07A"]$Weight <- 0.5

## ---- INVARIANT CHECK (add to validation section): per (List,Cause) weights sum to 1 ----
# chk <- rbindlist(lapply(ICDGroups$Groups, \(g) g[, .(Cause, List, Weight)]))
# stopifnot(nrow(chk[, .(w = sum(Weight)), .(List, Cause)][abs(w - 1) > 1e-9]) == 0)

## ---- COVERAGE METADATA (Phase 3): earliest resolvable year per group×country ----
# GroupCoverage <- merge(
#   rbindlist(lapply(names(ICDGroups$Groups), \(nm)
#     ICDGroups$Groups[[nm]][, .(CauseGroup = nm, List)]), use.names = TRUE),
#   unique(RawData[, .(List = as.character(List), iso3c,
#                      Year = as.integer(as.character(Year)))]),
#   by = "List", allow.cartesian = TRUE
# )[, .(FirstYear = min(Year)), .(CauseGroup, iso3c)]
# saveRDS(GroupCoverage, "./procdata/GroupCoverage.rds")
