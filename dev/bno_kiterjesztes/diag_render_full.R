# FAITHFUL reproduction of the render's in-memory state at the failing HMD dcast.
# Unlike the earlier (flawed) version, this runs the WHOLE sequence in order —
# RawData build + country/maps + the bno07a loop + population — exactly as the
# render does, so any side effect of my additions is present. Writes stripped so
# procdata is NOT clobbered.
proj <- "C:/Users/mrkma/OneDrive/DKM/Stats_R/R/FerenciTamas/OkspecifikusMortalitasiAdatbazis"
setwd(proj)
suppressMessages({
  library(knitr); library(data.table); library(arrow); library(eurostat)
  library(countrycode); library(countries); library(highcharter)
  library(foreign); library(stringi); library(lubridate); library(ggplot2)
})

tmp <- tempfile(fileext = ".R"); knitr::purl("README.Rmd", output = tmp, documentation = 0, quiet = TRUE)
code <- readLines(tmp, warn = FALSE)
a0     <- grep("td <- tempdir()", code, fixed = TRUE)[1]
hstop  <- grep('unique(PopDataHMD[YearSign != "", .(Year, iso3c)])', code, fixed = TRUE)[1]
slice <- code[a0:hstop]   # builds PopDataHMD fully; stops just before the guarded plots
n0 <- length(slice)
slice <- slice[!grepl("saveRDS|write_feather|save\\.image", slice)]   # no procdata writes
cat("Running", length(slice), "lines (stripped", n0 - length(slice),
    "saves): RawData + country/maps + bno07a + HMD, in order...\n")

t0 <- Sys.time()
eval(parse(text = paste(slice, collapse = "\n")), envir = .GlobalEnv)
cat("ran in", round(as.numeric(difftime(Sys.time(), t0, units = "secs"))), "s\n")

cat("\nDid bno07a run here? 07A present in",
    length(unique(rbindlist(ICDGroups$Groups, fill = TRUE)[List == "07A"]$EurostatCode)), "groups\n")
cat("Leftover globals from my loop:",
    paste(intersect(c("bno07a", "ec", "idx", "gr"), ls(.GlobalEnv)), collapse = ", "), "\n")

sub <- PopDataHMD[YearSign != ""]
cat("\nYearSign counts:\n"); print(table(sub$YearSign))
d <- dcast(sub, iso3c + Age + Year ~ YearSign, value.var = "Total")
cat("dcast columns:", paste(sprintf("'%s'", names(d)), collapse = ", "),
    "\nhas '+'?", "+" %in% names(d), " | has '-'?", "-" %in% names(d), "\n")
