# Reproduce the FULL RENDER's in-memory state up to Ferenci's failing HMD dcast,
# to find why the '+' column vanishes there but not against the saved data.
# Read-only: builds RawData in memory, stops BEFORE any procdata write.
proj <- "C:/Users/mrkma/OneDrive/DKM/Stats_R/R/FerenciTamas/OkspecifikusMortalitasiAdatbazis"
setwd(proj)
suppressMessages({ library(knitr); library(data.table); library(arrow) })

tmp <- tempfile(fileext = ".R"); knitr::purl("README.Rmd", output = tmp, documentation = 0, quiet = TRUE)
code <- readLines(tmp, warn = FALSE)
f1 <- function(p) grep(p, code, fixed = TRUE)[1]

a0    <- f1("td <- tempdir()")
asave <- f1('saveRDS(RawDataAll, "./procdata/RawDataAll.rds")')   # stop just before first write
cat("Building in-memory RawData exactly as the render does (no procdata writes)...\n")
eval(parse(text = paste(code[a0:(asave - 1)], collapse = "\n")), envir = .GlobalEnv)

cat("class(RawData$Year) =", class(RawData$Year),
    "| #years =", length(unique(RawData$Year)),
    "| #iso3c =", length(unique(RawData$iso3c)), "\n")

# Run the HMD chunk up to (not including) the failing dcast/plot
h0  <- f1('unzip("./inputdata/population.zip"')
hdc <- grep('dcast(PopDataHMD[YearSign!=""]', code, fixed = TRUE)[1]
eval(parse(text = paste(code[h0:(hdc - 1)], collapse = "\n")), envir = .GlobalEnv)

cat("\n--- reproduced HMD state ---\n")
cat("YearSign value counts:\n"); print(table(PopDataHMD$YearSign, useNA = "ifany"))
sub <- PopDataHMD[YearSign != ""]
cat("rows with YearSign != '' :", nrow(sub), "\n")
if (nrow(sub)) {
  cat("distinct (iso3c, Year, YearSign):\n"); print(unique(sub[, .(iso3c, Year, YearSign)]))
  d <- dcast(sub, iso3c + Age + Year ~ YearSign, value.var = "Total")
  cat("\ndcast columns:", paste(sprintf("'%s'", names(d)), collapse = ", "), "\n")
  cat("has '+'?", "+" %in% names(d), " | has '-'?", "-" %in% names(d),
      "  <-- if '+' is FALSE, the render failure is reproduced.\n")
}
