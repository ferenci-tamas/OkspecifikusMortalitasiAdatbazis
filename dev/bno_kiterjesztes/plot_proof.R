# Visual proof v2: Hungary age-STANDARDIZED death rates (ESP2013) now reach 1955.
# Direct standardization computed manually: ASR = sum(d_i/n_i * w_i) / sum(w_i).
proj <- "C:/Users/mrkma/OneDrive/DKM/Stats_R/R/FerenciTamas/OkspecifikusMortalitasiAdatbazis"
setwd(proj)
suppressMessages({ library(data.table); library(arrow); library(ggplot2) })

RD      <- as.data.table(arrow::read_feather("./procdata/WHO-MDB.feather"))
allG    <- rbindlist(readRDS("./procdata/ICDGroups.rds")$Groups, fill = TRUE)
Pop     <- as.data.table(readRDS("./procdata/WHO-MDB-Population.rds"))
StdPopT <- fread("./inputdata/ESP2013.csv", dec = ",")
for (d in list(RD, Pop, StdPopT)) d[, `:=`(Frmat = as.character(Frmat), Age = as.character(Age))]

HU <- "HUN"
yrfmt <- unique(RD[iso3c == HU, .(Year, Frmat)])
popHU <- merge(Pop[iso3c == HU], yrfmt, by = c("Year", "Frmat"))[Age != "Deaths3456",
              .(Pop = sum(Pop)), .(Year, Age, Frmat)]   # sexes combined, as the app does

asr <- function(ec, label) {
  icd <- allG[EurostatCode == ec, .(List, Cause = as.character(Cause))]
  dg  <- RD[iso3c == HU][icd, on = .(List, Cause), nomatch = NULL][, .(value = sum(value)), .(Year, Age, Frmat)]
  ms  <- merge(merge(popHU, dg, by = c("Year", "Age", "Frmat"), all.x = TRUE),
               StdPopT, by = c("Frmat", "Age"))
  ms[is.na(value), value := 0]
  r <- ms[Pop > 0, .(rate = sum(value / Pop * StdPop) / sum(StdPop) * 1e5), by = Year]
  r[, grp := label][]
}

groups <- list(c("A-R_V-Y", "Összes halálok"), c("C", "Rosszindulatú daganatok"),
               c("I", "Keringési rendszer"), c("J", "Légzőrendszer"),
               c("V01-Y89", "Külső okok"))
dat <- rbindlist(lapply(groups, function(g) asr(g[1], g[2])))
dat[, grp := factor(grp, levels = sapply(groups, `[`, 2))]

cat("All-cause standardized rate (ESP2013, /100k):\n")
print(dat[grp == "Összes halálok" & Year %in% c(1955, 1968, 1969, 1990, 2020)])

p <- ggplot(dat, aes(Year, rate, colour = grp)) +
  annotate("rect", xmin = 1954.5, xmax = 1968.5, ymin = 0, ymax = Inf, fill = "#ffd24d", alpha = 0.18) +
  annotate("text", x = 1961.5, y = max(dat$rate) * 0.97, label = "ÚJ: BNO-7 (1955–1968)", size = 3.1, colour = "#a06800") +
  geom_vline(xintercept = 1968.5, linetype = "dashed", colour = "grey55") +
  geom_line(linewidth = 0.7) + geom_point(size = 0.5) +
  scale_x_continuous(breaks = seq(1955, 2020, 10)) +
  scale_colour_manual(values = c("#1f3b73", "#c0392b", "#16846b", "#8e44ad", "#d97706")) +
  labs(title = "Magyarország – standardizált halálozási ráták, BNO-7 modullal 1955-ig",
       subtitle = "Korösszetételre standardizált ráta (ESP2013), /100 000 fő. Korábbi adathatár: 1969 (szaggatott).",
       x = NULL, y = "Standardizált ráta / 100 000 fő", colour = NULL,
       caption = "Forrás: WHO MDB (morticd07–10) + ENSZ WPP népességadat. 64/93 haláloki csoport leképezve BNO-7-re.") +
  theme_minimal(base_size = 12) +
  theme(legend.position = "bottom", plot.title = element_text(face = "bold", size = 12),
        plot.caption = element_text(colour = "grey45", size = 8))

out <- file.path(proj, "dev", "bno_kiterjesztes", "HU_bno7_standardizalt_rata.png")
ok <- tryCatch({ ggsave(out, p, width = 9.5, height = 5.6, dpi = 130, device = ragg::agg_png); TRUE },
               error = function(e) FALSE)
if (!ok) ggsave(out, p, width = 9.5, height = 5.6, dpi = 130)
cat("saved:", out, "\n")
