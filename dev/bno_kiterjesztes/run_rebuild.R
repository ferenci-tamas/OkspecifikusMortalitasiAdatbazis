# Full rebuild for the ICD-7 (07A) extension:
#   Part A  RawData (+ morticd07 ingestion)        -> WHO-MDB.{feather,rds}, RawDataAll.rds
#   Part B  ICDGroups (+ full 07A module)          -> ICDGroups.rds
#   Part C  Population (WPP; auto-extends to 1955)  -> WHO-MDB-Population.rds
# Reuses Ferenci's exact pipeline code via knitr::purl (no duplication). Skips the
# intro Eurostat figures, the country/maps section, the HMD/Eurostat population
# comparison, the dim-reduction t-SNE, and the validation section.

proj <- "C:/Users/mrkma/OneDrive/DKM/Stats_R/R/FerenciTamas/OkspecifikusMortalitasiAdatbazis"
setwd(proj)
suppressMessages({ library(knitr); library(data.table); library(arrow) })

tmp <- tempfile(fileext = ".R")
knitr::purl("README.Rmd", output = tmp, documentation = 0, quiet = TRUE)
code <- readLines(tmp, warn = FALSE)
f1 <- function(p) { i <- grep(p, code, fixed = TRUE); if (length(i)) i[1] else NA_integer_ }

a0 <- f1("td <- tempdir()")
a1 <- f1('write_feather(RawData[value > 0], "./procdata/WHO-MDB.feather")')
b0 <- f1('read.dbf("./inputdata/BNOTORZS.DBF"')
b1 <- f1('saveRDS(ICDGroups, "./procdata/ICDGroups.rds")')
c0 <- f1("PopDataUN <- fread(paste0(")
c1 <- f1('names(PopDataUN)[names(PopDataUN) == "value"] <- "PopUN"')
d0 <- f1("PopData <- PopDataUN")
d1 <- f1('saveRDS(PopData, "./procdata/WHO-MDB-Population.rds")')
cat("markers:", a0, a1, "|", b0, b1, "|", c0, c1, "|", d0, d1, "\n")
stopifnot(!anyNA(c(a0, a1, b0, b1, c0, c1, d0, d1)), a0 < a1, b0 < b1, c0 < c1, d0 < d1)

slice <- c("## Part A", code[a0:a1],
           "## Part B", code[b0:b1],
           "## Part C", code[c0:c1], code[d0:d1])
sf <- file.path(proj, "dev", "bno_kiterjesztes", "_rebuild_slice.R")
writeLines(slice, sf)
cat("Running", length(slice), "lines (this re-ingests morticd07..10 and downloads WPP)...\n")

t0 <- Sys.time()
err <- tryCatch({ source(sf, echo = FALSE); NULL }, error = function(e) conditionMessage(e))
cat("Elapsed:", round(as.numeric(difftime(Sys.time(), t0, units = "secs"))), "s\n")
if (!is.null(err)) cat("*** source stopped with:", err, "\n(outputs saved before the error still persist)\n")

## ------------------------------- verify ------------------------------------
RD <- as.data.table(arrow::read_feather("./procdata/WHO-MDB.feather"))
cat("\n=== RawData ===  HUN years:", paste(range(RD[iso3c == "HUN"]$Year), collapse = "-"),
    "| HUN 07A rows:", nrow(RD[iso3c == "HUN" & List == "07A"]), "\n")

ICDG <- readRDS("./procdata/ICDGroups.rds")
allG <- rbindlist(ICDG$Groups, fill = TRUE)
cat("=== ICDGroups === groups with 07A:", length(unique(allG[List == "07A"]$EurostatCode)),
    "of", length(ICDG$Groups), "| Weight set in Groups:", paste(sort(unique(allG$Weight)), collapse = ","), "\n")

Pop <- as.data.table(readRDS("./procdata/WHO-MDB-Population.rds"))
cat("=== Population === HUN years:", paste(range(Pop[iso3c == "HUN"]$Year), collapse = "-"), "\n")
tot <- Pop[iso3c == "HUN" & Frmat == 0 & Age != "Deaths3456", .(pop = sum(Pop)), Year][order(Year)]
cat("HUN total pop sanity:", tot[Year == min(Year), paste0(Year, "=", round(pop/1e6, 2), "M")],
    "->", tot[Year == 2020, paste0("2020=", round(pop/1e6, 2), "M")], "\n")

## seam continuity (counts) across 1968->1969 for a spread of groups
ecs <- c("A-R_V-Y", "C", "C16", "I", "I20-I25", "I60-I69", "J", "K", "V01-Y89", "X60-X84_Y870")
seam <- rbindlist(lapply(ecs, function(ec) {
  m <- allG[EurostatCode == ec, .(List, Cause)]
  RD[iso3c == "HUN"][m, on = .(List, Cause), nomatch = NULL][
    Year %in% 1967:1970, .(ec = ec, deaths = sum(value)), by = Year]
}))
cat("\n=== Seam continuity 1967-1970 (counts) ===\n")
print(dcast(seam, ec ~ Year, value.var = "deaths"))
