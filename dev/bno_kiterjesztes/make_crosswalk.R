# Deliverables for Marci:
#   1) BNO_kereszttabla.xlsx  — the ICD-7/8/9/10 code crosswalk per cause group
#                               (wide overview + a long, directly-mergeable sheet)
#   2) BNO_sankey_revaltas.png — alluvial/Sankey of ~12 example causes flowing
#                               across ICD-7 -> ICD-8 -> ICD-9 -> ICD-10
proj <- "C:/Users/mrkma/OneDrive/DKM/Stats_R/R/FerenciTamas/OkspecifikusMortalitasiAdatbazis"
setwd(proj)
options(repos = c(CRAN = "https://cloud.r-project.org"))
if (!requireNamespace("ggalluvial", quietly = TRUE)) install.packages("ggalluvial")
suppressMessages({ library(data.table); library(arrow); library(writexl); library(ggplot2); library(ggalluvial) })

allG <- rbindlist(readRDS("./procdata/ICDGroups.rds")$Groups, fill = TRUE)
allG[, Cause := as.character(Cause)]
outdir <- file.path(proj, "dev", "bno_kiterjesztes")

## ---------------- 1) XLSX crosswalk ----------------
listcols <- c("07A", "08A", "08B", "09A", "09B", "09C", "09N")     # older revisions (hand-mapped)
byList <- allG[, .(codes = paste(sort(unique(Cause)), collapse = ", ")), by = .(EurostatCode, CauseGroup, List)]
wide <- dcast(byList, EurostatCode + CauseGroup ~ List, value.var = "codes")
if ("104" %in% names(wide)) wide[, ("104") := NULL]   # ICD-10 = the group itself; keep only a count
for (L in setdiff(listcols, names(wide))) wide[, (L) := NA_character_]
n104 <- allG[List == "104", .(`ICD-10 kódok (db)` = uniqueN(Cause)), by = EurostatCode]
wide <- merge(wide, n104, by = "EurostatCode", all.x = TRUE)
setcolorder(wide, c("EurostatCode", "CauseGroup", listcols, "ICD-10 kódok (db)"))
setnames(wide, listcols, c("ICD-7 (07A)", "ICD-8 (08A)", "ICD-8 (08B)",
                           "ICD-9 (09A)", "ICD-9 (09B)", "ICD-9 (09C)", "ICD-9 (09N)"))

long <- allG[List %in% listcols, .(Revizio = fcase(List == "07A", "ICD-7", List %in% c("08A","08B"), "ICD-8",
                                                    default = "ICD-9"),
                                    List, Cause, EurostatCode, CauseGroup, Weight)][order(EurostatCode, List, Cause)]

write_xlsx(list(Attekintes_csoportok = as.data.frame(wide),
                Merge_tabla_regi_revak = as.data.frame(long)),
           path = file.path(outdir, "BNO_kereszttabla.xlsx"))
cat("xlsx written:", nrow(wide), "groups (wide),", nrow(long), "old-revision mappings (long)\n")

## ---------------- 2) Sankey / alluvial ----------------
# representative (first) code per group for each revision; prefer the main list
rep1 <- function(ec, lists) { for (L in lists) { cc <- sort(allG[EurostatCode == ec & List == L]$Cause); if (length(cc)) return(cc[1]) }; "(nincs)" }
pick <- c("A15-A19_B90"="Gümőkór", "C16"="Gyomorrák", "C33_C34"="Tüdőrák", "C50"="Emlőrák",
          "C53"="Méhnyakrák", "E10-E14"="Cukorbetegség", "I20-I25"="Ischaemiás szívbetegség",
          "I60-I69"="Agyérbetegség", "J12-J18"="Tüdőgyulladás", "K70_K73_K74"="Májzsugor",
          "V_Y85"="Közlekedési baleset", "X60-X84_Y870"="Öngyilkosság")
df <- rbindlist(lapply(names(pick), function(ec) data.table(
  Betegseg = pick[[ec]],
  `ICD-7`  = rep1(ec, "07A"),
  `ICD-8`  = rep1(ec, c("08A", "08B")),
  `ICD-9`  = rep1(ec, c("09A", "09B")),
  `ICD-10` = ec)))

p <- ggplot(df, aes(axis1 = `ICD-7`, axis2 = `ICD-8`, axis3 = `ICD-9`, axis4 = `ICD-10`, y = 1)) +
  geom_alluvium(aes(fill = Betegseg), width = 0.28, alpha = 0.75) +
  geom_stratum(width = 0.28, fill = "grey95", colour = "grey55") +
  geom_text(stat = "stratum", aes(label = after_stat(stratum)), size = 3) +
  scale_x_discrete(limits = c("ICD-7\n(07A)", "ICD-8\n(08A/B)", "ICD-9\n(09A/B)", "ICD-10\n(104)"),
                   expand = c(0.06, 0.06)) +
  labs(title = "Ugyanazon halálok kódja a BNO-revíziókban (12 példa)",
       subtitle = "A WHO 'List' kódrendszerei közötti megfeleltetés — minden szalag egy haláloki csoport útja",
       y = NULL, fill = NULL,
       caption = "A teljes leképezés: BNO_kereszttabla.xlsx. Reprezentatív (első) kód csoportonként.") +
  theme_minimal(base_size = 12) +
  theme(legend.position = "right", panel.grid = element_blank(),
        axis.text.y = element_blank(), plot.title = element_text(face = "bold"))

out <- file.path(outdir, "BNO_sankey_revaltas.png")
ok <- tryCatch({ ggsave(out, p, width = 11, height = 6.5, dpi = 130, device = ragg::agg_png); TRUE }, error = function(e) FALSE)
if (!ok) ggsave(out, p, width = 11, height = 6.5, dpi = 130)
cat("sankey written:", out, "\n\nExample rows:\n"); print(df)
