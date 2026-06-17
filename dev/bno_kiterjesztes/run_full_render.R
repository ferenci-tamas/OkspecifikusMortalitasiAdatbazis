# Full render driver (run in BACKGROUND): install the 5 missing CRAN deps, then
# rmarkdown::render the edited README.Rmd. This refreshes README.md + ALL procdata
# (incl. dimredvizData via t-SNE) + runs the validation section. The user has
# accepted the resulting binary churn beyond the ICD-7 changes.
proj <- "C:/Users/mrkma/OneDrive/DKM/Stats_R/R/FerenciTamas/OkspecifikusMortalitasiAdatbazis"
setwd(proj)
options(repos = c(CRAN = "https://cloud.r-project.org"), timeout = 1800)
log <- function(...) cat(format(Sys.time(), "%H:%M:%S"), "-", ..., "\n")

need <- c("eurostat", "countrycode", "countries", "epitools", "Rtsne", "highcharter")
miss <- need[!vapply(need, requireNamespace, logical(1), quietly = TRUE)]
if (length(miss)) { log("Installing CRAN binaries:", paste(miss, collapse = ", ")); install.packages(miss) }
ok <- vapply(need, requireNamespace, logical(1), quietly = TRUE)
log("deps:", paste(sprintf("%s=%s", need, ok), collapse = " "))
if (!all(ok)) { log("ABORT: still missing", paste(need[!ok], collapse = ", ")); quit(status = 1) }

# pandoc (rmarkdown needs it; RStudio bundles it, usually on PATH)
if (!rmarkdown::pandoc_available()) {
  for (cc in c("C:/Program Files/RStudio/resources/app/bin/quarto/bin/tools",
               "C:/Program Files/RStudio/resources/app/bin/quarto/bin/tools/x86_64",
               "C:/Program Files/RStudio/resources/app/bin/quarto/bin",
               "C:/Program Files/RStudio/resources/app/bin/pandoc"))
    if (file.exists(file.path(cc, "pandoc.exe"))) { Sys.setenv(RSTUDIO_PANDOC = cc); break }
}
if (!rmarkdown::pandoc_available()) { log("ABORT: pandoc not found"); quit(status = 1) }
log("pandoc", as.character(rmarkdown::pandoc_version()))

if (file.exists("dev/bno_kiterjesztes/render_OK.txt")) file.remove("dev/bno_kiterjesztes/render_OK.txt")
log("Rendering README.Rmd (this is the long, networked part) ...")
t0 <- Sys.time()
err <- tryCatch({ rmarkdown::render("README.Rmd", quiet = FALSE); NULL },
                error = function(e) conditionMessage(e))
if (is.null(err)) {
  log("RENDER DONE in", round(as.numeric(difftime(Sys.time(), t0, units = "mins")), 1), "min")
  writeLines(format(Sys.time()), "dev/bno_kiterjesztes/render_OK.txt")
} else {
  log("RENDER FAILED after", round(as.numeric(difftime(Sys.time(), t0, units = "mins")), 1),
      "min:", err)
  quit(status = 1)
}
