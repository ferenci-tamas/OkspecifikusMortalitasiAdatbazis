library(shiny)
library(data.table)
library(highcharter)

hcoptslang <- getOption("highcharter.lang")
hcoptslang$contextButtonTitle <- "Helyi menü"
hcoptslang$exitFullscreen <- "Kilépés a teljes képernyős módból"
hcoptslang$hideData <- "Adatok elrejtése"
hcoptslang$loading <- "Betöltés..."
hcoptslang$mainBreadcrumb <- "Fő ábra"
hcoptslang$noData <- "Nincs megjeleníthető adat"
hcoptslang$printChart <- "Ábra nyomtatása"
hcoptslang$viewData <- "Adatok megtekintése"
hcoptslang$viewFullscreen <- "Teljes képernyős nézet"
hcoptslang$months <- c("január", "február", "március", "április", "május","június", "július",
                       "augusztus", "szeptember", "október", "november", "december")
hcoptslang$shortMonths <- c("jan", "febr", "márc", "ápr", "máj", "jún", "júl", "aug", "szept",
                            "okt", "nov", "dec")
hcoptslang$weekdays <- c("vasárnap", "hétfő", "kedd", "szerda", "csütörtök", "péntek",
                         "szombat")
hcoptslang$shortWeekdays <- c("Vas", "Hét", "Ked", "Sze", "Csü", "Pén", "Szo", "Vas")
hcoptslang$exportButtonTitle <- "Exportál"
hcoptslang$printButtonTitle <- "Importál"
hcoptslang$rangeSelectorFrom <- "ettől"
hcoptslang$rangeSelectorTo <- "eddig"
hcoptslang$rangeSelectorZoom <- "mutat:"
hcoptslang$downloadPNG <- "Letöltés PNG képként"
hcoptslang$downloadJPEG <- "Letöltés JPEG képként"
hcoptslang$downloadPDF <- "Letöltés PDF dokumentumként"
hcoptslang$downloadSVG <- "Letöltés SVG formátumban"
hcoptslang$downloadCSV <- "Letöltés CSV formátumú táblázatként"
hcoptslang$downloadXLS <- "Letöltés XLS formátumú táblázatként"
hcoptslang$resetZoom <- "Nagyítás alaphelyzetbe állítása"
hcoptslang$resetZoomTitle <- "Nagyítás alaphelyzetbe állítása"
hcoptslang$thousandsSep <- " "
hcoptslang$decimalPoint <- ","
hcoptslang$numericSymbols <- NA
options(highcharter.lang = hcoptslang)
options(highcharter.download_map_data = FALSE)

RawData <- arrow::read_feather("WHO-MDB.feather")

RawDataAll <- readRDS("RawDataAll.rds")

PopData <- readRDS("WHO-MDB-Population.rds")

AgeTable <- data.table(Age = c(NA, paste0("Deaths", 2:25), "Deaths3456", "Deaths232425"),
                       AgeNum = c(NA, (0:4) + 0.5, seq(5, 90, 5) + 2.5, 100, 3, 95),
                       AgeLabel = c(NA, c(0:4, paste0(seq(5, 95, 5), "-",
                                                      c(seq(9, 94, 5), "")), "1-4", "85-")))

PopData <- merge(PopData, AgeTable, by = "Age")

ICDGroups <- readRDS("ICDGroups.rds")
stratsel <- c("Nincs" = "None", "Nem szerint" = "Sex", "Életkor szerint" = "AgeLabel")
StdPop <- fread("ESP2013.csv", dec = ",")
StdPop$Frmat <- as.factor(StdPop$Frmat)

CountryCodes <- readRDS("CountryCodes.rds")
CountryCodes <- CountryCodes[order(names(CountryCodes))]

EUCountries <- list(
  "EU27" = countrycode::countrycode(eurostat::eu_countries$code, "eurostat", "iso3c"),
  "EU15" = c("AUT", "BEL", "DNK", "FIN", "FRA", "DEU", "GRC", "IRL", "ITA", "LUX", "NLD", "PRT",
             "ESP", "SWE", "GBR"),
  "EU11" = c("CZE", "EST", "HUN", "LVA", "LTU", "POL", "SVK", "SVN", "BGR", "ROU", "HRV"),
  "V4" = c("SVK", "CZE", "HUN", "POL")
)

dimredvizData <- readRDS("dimredvizData.rds")

desctext <- paste0("Hazai és nemzetközi halálozási adatok, halálokok vizsgálatát,",
                   "összehasonlítását lehetővé tevő alkalmazás. Írta: Ferenci Tamás.")
urlpre <- "https://research.physcon.uni-obuda.hu/"

# ICDlabel <- div("Kiválasztott betegség(ek)", bslib::tooltip(
#   bsicons::bs_icon("question-circle"),
#   "Backspace-szel, Del-lel törölhető a kiválasztott, gépelve név szerint kereshető.",
#   placement = "right"))

pickeropts <- shinyWidgets::pickerOptions(
  actionsBox = TRUE,
  liveSearch = TRUE,
  noneSelectedText = "Válasszon!",
  noneResultsText = "Nincs találat {0}",
  countSelectedText = "{0} elem kiválasztva",
  maxOptionsText ="Legfeljebb {n} elem választható",
  selectAllText = "Mindegyik",
  deselectAllText = "Egyik sem",
  multipleSeparator = ", ",
  style = "btn btn-outline-dark"
)

pickeroptsWOSearch <- shinyWidgets::pickerOptions(
  actionsBox = TRUE,
  liveSearch = FALSE,
  noneSelectedText = "Válasszon!",
  noneResultsText = "Nincs találat {0}",
  countSelectedText = "{0} elem kiválasztva",
  maxOptionsText ="Legfeljebb {n} elem választható",
  selectAllText = "Mindegyik",
  deselectAllText = "Egyik sem",
  multipleSeparator = ", ",
  style = "btn btn-outline-dark"
)

metrictext <- HTML(paste0(
  "Az <b>abszolút szám</b> a vizsgált adat főben, így országok közötti összehasonlításra ",
  "nem alkalmas. A <b>nyers ráta</b> az abszolút szám osztva az ország lélekszámával, így ",
  "jobban összehasonlítható, de az eltérő korfát ez sem veszi figyelembe. A ",
  "<b>standardizált ráta</b> korrigál az eltérő korösszetételre."))

ownpanel <- function(idPrefix, singleICD = FALSE, map = FALSE, indicators = TRUE,
                     defaultLogY = FALSE, strat = stratsel, hconv = FALSE) {
  c(
    list(shinyWidgets::pickerInput(paste0(idPrefix, "Category"), "Kategória",
                                   c("Főbb haláloki csoportok" = "Groups",
                                     "Egyedi betegségek" = "Individual",
                                     "Elkerülhető halálozás" = "Avoidable"),
                                   multiple = FALSE, options = pickeroptsWOSearch)),
    if(singleICD) {
      lapply(1:length(ICDGroups), function(i)
        conditionalPanel(paste0("input.", idPrefix, "Category == '", names(ICDGroups)[i], "'"),
                         shinyWidgets::pickerInput(paste0(idPrefix, names(ICDGroups)[i], "ICDSingle"), "Kiválasztott halálok",
                                                   sapply(ICDGroups[[i]], `[[`, "Name"), multiple = FALSE,
                                                   options = pickeropts)))
    } else {
      c(
        lapply(1:length(ICDGroups), function(i)
          conditionalPanel(paste0("input.", idPrefix, "Category == '", names(ICDGroups)[i],
                                  "'& input.", idPrefix, "MultipleICD == 'Single'"),
                           shinyWidgets::pickerInput(paste0(idPrefix, names(ICDGroups)[i], "ICDSingle"),
                                                     "Kiválasztott halálok",
                                                     sapply(ICDGroups[[i]], `[[`, "Name"),
                                                     multiple = FALSE,
                                                     options = pickeropts))),
        lapply(1:length(ICDGroups), function(i)
          conditionalPanel(paste0("input.", idPrefix, "Category == '", names(ICDGroups)[i],
                                  "'& input.", idPrefix, "MultipleICD != 'Single'"),
                           shinyWidgets::pickerInput(paste0(idPrefix, names(ICDGroups)[i], "ICDMultiple"),
                                                     "Kiválasztott halálokok",
                                                     sapply(ICDGroups[[i]], `[[`, "Name"),
                                                     multiple = TRUE,
                                                     options = pickeropts))),
        list(
          radioButtons(paste0(idPrefix, "MultipleICD"), "Ábrázolt betegségek száma",
                       c("Egy betegség" = "Single",
                         "Több betegség, külön-külön ábrázolva" = "MultiIndiv",
                         "Több betegség, az összegük ábrázolva" = "MultiSum")),
          conditionalPanel(paste0("input.", idPrefix, "MultipleICD != 'MultiIndiv'"),
                           radioButtons(paste0(idPrefix, "MultipleCountry"), "Ábrázolt országok száma",
                                        c("Egy ország" = "Single", "Több ország" = "Multiple"))),
          conditionalPanel(paste0("(input.", idPrefix, "MultipleICD == 'MultiIndiv')|(input.", idPrefix, "MultipleCountry == 'Single')"),
                           shinyWidgets::pickerInput(paste0(idPrefix, "CountrySingle"), "Ország",
                                                     CountryCodes, "HUN", FALSE,
                                                     options = pickeropts)),
          conditionalPanel(paste0("(input.", idPrefix, "MultipleICD != 'MultiIndiv')&(input.", idPrefix, "MultipleCountry == 'Multiple')"),
                           shinyWidgets::pickerInput(paste0(idPrefix, "CountryMultiple"), "Ország",
                                                     CountryCodes, "HUN", TRUE,
                                                     options = pickeropts)))
      )
    },
    if(indicators) {
      list(
        shinyWidgets::pickerInput(paste0(idPrefix, "Indicator"), "Ábrázolt mutató",
                                  c("Halálozás" = "death", "Elvesztett életévek száma" = "yll"),
                                  options = pickeroptsWOSearch),
        conditionalPanel(paste0("input.", idPrefix, "Indicator == 'yll'"),
                         shinyWidgets::pickerInput(paste0(idPrefix, "YllMethod"), "Módszer",
                                                   c("Fix cél-életkor (PYLL)" = "pyll"),
                                                   options = pickeroptsWOSearch)),
        conditionalPanel(paste0("input.", idPrefix, "Indicator == 'yll' & input.", idPrefix, "YllMethod == 'pyll'"),
                         numericInput(paste0(idPrefix, "YllPyllTarget"), "Cél-életkor", 75, 0, 100, 1)),
        shinyWidgets::pickerInput(paste0(idPrefix, "Metric"), div("Mérőszám", bslib::tooltip(
          bsicons::bs_icon("question-circle"), metrictext, placement = "right")),
          c("Abszolút szám" = "count", "Nyers ráta" = "cruderate",
            "Standardizált ráta" = "adjrate"), "adjrate", options = pickeroptsWOSearch)
      )
    },
    if(map) {
      list(
        radioButtons(paste0(idPrefix, "Type"), "Ábrázolás módja",
                     c("Térkép" = "Map", "Oszlopdiagram" = "Bar")),
        conditionalPanel(paste0("input.", idPrefix, "Type == 'Map'"),
                         shinyWidgets::pickerInput(paste0(idPrefix, "Map"), "Térkép",
                                                   c("Európa" = "europe", "Világ" = "world"),
                                                   options = pickeroptsWOSearch)),
        shinyWidgets::pickerInput(paste0(idPrefix, "Sex"), "Ábrázolt nem", c("Összesen", "Férfi", "Nő"),
                                  options = pickeroptsWOSearch),
        conditionalPanel(paste0("input.", idPrefix, "Metric != 'adjrate'"),
                         shinyWidgets::pickerInput(paste0(idPrefix, "Age"), "Ábrázolt életkor",
                                                   setNames(c("Összesen", AgeTable[!is.na(Age)][order(AgeNum)]$Age),
                                                            c("Összesen", AgeTable[!is.na(Age)][order(AgeNum)]$AgeLabel)),
                                                   options = pickeroptsWOSearch)),
        conditionalPanel(paste0("input.", idPrefix, "Type == 'Bar'"),
                         checkboxInput(paste0(idPrefix, "BarOrder"), "Nagyság szerint sorbarendezve"),
                         checkboxInput(paste0(idPrefix, "BarHorizontal"), "Vízszintes diagram"))
      )
    } else if(!hconv) {
      list(
        conditionalPanel(paste0("input.", idPrefix, "MultipleICD != 'MultiIndiv' & input.", idPrefix, "MultipleCountry == 'Single'"),
                         radioButtons(paste0(idPrefix, "Stratification"), "Lebontás", strat)),
        checkboxInput(paste0(idPrefix, "LogY"), "A függőleges tengely logaritmikus",
                      value = defaultLogY),
        checkboxInput(paste0(idPrefix, "YFromZero"), "A függőleges tengely nullától indul")
      )
    }
  )
}

ui <- navbarPage(
  theme = bslib::bs_theme(bootswatch = "default"),
  title = "Okspecifikus Mortalitási Adatbázis",
  # title = h4(HTML("Okspecifikus Mortalitási Adatbázis<br>Ferenci Tamás, medstat.hu")),
  # title = div(p("test title", br(), "kettp"), class = "test"),
  header = list(
    tags$head(
      tags$meta(name = "description", content = desctext),
      tags$meta(property = "og:title", content = "Okspecifikus Mortalitási Adatbázis"),
      tags$meta(property = "og:type", content = "website"),
      tags$meta(property = "og:locale", content = "hu_HU"),
      tags$meta(property = "og:url",
                content = paste0(urlpre, "OkspecifikusMortalitasiAdatbazis/")),
      tags$meta(property = "og:image",
                content = paste0(urlpre, "OkspecifikusMortalitasiAdatbazis-Pelda.png")),
      tags$meta(property = "og:image:width", content = 1200),
      tags$meta(property = "og:image:height", content = 630),
      tags$meta(property = "og:description", content = desctext),
      tags$meta(name = "DC.Title", content = "Okspecifikus Mortalitási Adatbázis"),
      tags$meta(name = "DC.Creator", content = "Ferenci Tamás"),
      tags$meta(name = "DC.Subject", content = "népegészségtan"),
      tags$meta(name = "DC.Description", content = desctext),
      tags$meta(name = "DC.Publisher",
                content = paste0(urlpre, "OkspecifikusMortalitasiAdatbazis/")),
      tags$meta(name = "DC.Contributor", content = "Ferenci Tamás"),
      tags$meta(name = "DC.Language", content = "hu_HU"),
      tags$meta(name = "twitter:card", content = "summary_large_image"),
      tags$meta(name = "twitter:title", content = "Okspecifikus Mortalitási Adatbázis"),
      tags$meta(name = "twitter:description", content = desctext),
      tags$meta(name = "twitter:image",
                content = paste0(urlpre, "OkspecifikusMortalitasiAdatbazis-Pelda.png"))
    ),
    
    tags$script(src = "https://code.highcharts.com/mapdata/custom/world.js"),
    tags$script(src = "https://code.highcharts.com/mapdata/custom/europe.js"),
    
    tags$div(id = "fb-root"),
    tags$script(async = NA, defer = NA, crossorigin = "anonymous",
                src = "https://connect.facebook.net/hu_HU/sdk.js#xfbml=1&version=v19.0",
                nonce = "mr8Yvh3Y"),
    
    p("A program használatát részletesen bemutató súgó, valamint a technikai részletek",
      a("itt", href = "https://github.com/tamas-ferenci/OkspecifikusMortalitasiAdatbazis",
        target = "_blank" ), "olvashatóak el."),
    
    div(style = "line-height: 13px;",
        div(class = "fb-share-button",
            "data-href" = paste0("https://research.physcon.uni-obuda.hu/",
                                 "OkspecifikusMortalitasiAdatbazis"),
            "data-layout" = "button_count", "data-size" = "small",
            a("Megosztás", target = "_blank",
              href = paste0("https://www.facebook.com/sharer/sharer.php?u=",
                            "https%3A%2F%2Fresearch.physcon.uni-obuda.hu%2FOkspecifikus",
                            "MortalitasiAdatbazis&amp;src=sdkpreparse"),
              class = "fb-xfbml-parse-ignore")),
        
        a("Tweet", href = "https://twitter.com/share?ref_src=twsrc%5Etfw",
          class = "twitter-share-button", "data-show-count" = "true"),
        includeScript("http://platform.twitter.com/widgets.js", async = NA,
                      charset = "utf-8"))),
  footer = list(
    hr(),
    p("Írta: ", a("Ferenci Tamás", href = "http://www.medstat.hu/", target = "_blank",
                  .noWS = "outside"), ", v0.38"),
    
    tags$script(HTML("
      var sc_project=11601191; 
      var sc_invisible=1; 
      var sc_security=\"5a06c22d\";
                     "),
                type = "text/javascript"),
    tags$script(type = "text/javascript",
                src = "https://www.statcounter.com/counter/counter.js", async = NA),
    tags$noscript(div(class = "statcounter",
                      a(title = "ingyen webstatisztika", href = "https://www.statcounter.hu/",
                        target = "_blank",
                        img(class = "statcounter",
                            src = "https://c.statcounter.com/11601191/0/5a06c22d/1/",
                            alt = "ingyen webstatisztika",
                            referrerPolicy = "no-referrer-when-downgrade"))))
  ),
  
  tabPanel(
    title = "Időbeli trendek",
    sidebarLayout(
      sidebarPanel(
        ownpanel("time")
      ),
      mainPanel(
        shinycssloaders::withSpinner(highchartOutput("timePlot", height = "600px"))
      )
    )
  ),
  
  tabPanel(
    title = "Területi összehasonlítás",
    sidebarLayout(
      sidebarPanel(
        ownpanel("map", TRUE, TRUE)
      ),
      mainPanel(
        shinycssloaders::withSpinner(highchartOutput("mapPlot", height = "600px")),
        tags$style(type = "text/css", ".irs-grid-pol.small {height: 0px;}"),
        sliderInput("mapYear", div("Vizsgált év(tartomány)", bslib::tooltip(
          bsicons::bs_icon("question-circle"),
          paste0("Amennyiben a csúszka két vége nem esik egybe, úgy a megjelenített ",
                 "adat a tartomány összesített eredménye. A két végpont egy évre is ",
                 "összehúzható, ez esetben a kérdéses év adata fog látszódni."),
          placement = "right")), min(RawData$Year), max(RawData$Year),
          c(2020, 2022), 1, sep = "", width = "100%")
      )
    )
  ),
  
  tabPanel(
    title = "Életkor és nem hatása",
    sidebarLayout(
      sidebarPanel(
        ownpanel("agesex", indicators = FALSE, defaultLogY = TRUE,
                 strat = c("Nincs" = "None", "Nem szerint" = "Sex", "Év szerint" = "Year"))
      ),
      mainPanel(
        shinycssloaders::withSpinner(highchartOutput("agesexPlot", height = "600px")),
        tags$style(type = "text/css", ".irs-grid-pol.small {height: 0px;}"),
        sliderInput("agesexYear", div("Vizsgált év(tartomány)", bslib::tooltip(
          bsicons::bs_icon("question-circle"),
          paste0("Amennyiben a csúszka két vége nem esik egybe, úgy a megjelenített ",
                 "adat a tartomány összesített eredménye. A két végpont egy évre is ",
                 "összehúzható, ez esetben a kérdéses év adata fog látszódni."),
          placement = "right")), min(RawData$Year), max(RawData$Year),
          c(min(RawData$Year), max(RawData$Year)), 1, sep = "", width = "100%")
      )
    )
  ),
  
  navbarMenu("Speciális elemzések",
             tabPanel(
               title = "Magyarország és a világ",
               sidebarLayout(
                 sidebarPanel(
                   shinyWidgets::pickerInput("hunworldCountryInvestigated", "Vizsgált ország",
                                             CountryCodes, "HUN", FALSE, options = pickeropts),
                   shinyWidgets::pickerInput("hunworldCountryComparison",
                                             div("Összehasonlítási alapot képező országok",
                                                 bslib::tooltip(
                                                   bsicons::bs_icon("question-circle"),
                                                   paste0("Az összehasonlító országokból ",
                                                          "természetesen mindig kivételre ",
                                                          "kerül a vizsgált ország."),
                                                   placement = "right")),
                                             CountryCodes, EUCountries$EU27, TRUE,
                                             options = pickeropts),
                   actionButton("hunworldEU27", "EU27 (Európai Unió) beállítása"),
                   actionButton("hunworldEU15", "EU15 ('Nyugat') beállítása"),
                   actionButton("hunworldEU11", "EU11 ('Kelet') beállítása"),
                   actionButton("hunworldV4", "V4 (visegrádi négyek) beállítása"),
                   shinyWidgets::pickerInput("hunworldIndicator", "Ábrázolt mutató",
                                             c("Halálozás" = "death",
                                               "Elvesztett életévek száma" = "yll"),
                                             options = pickeroptsWOSearch),
                   conditionalPanel("input.hunworldIndicator == 'yll'",
                                    shinyWidgets::pickerInput("hunworldYllMethod", "Módszer",
                                                              c("Fix cél-életkor (PYLL)" = "pyll"),
                                                              options = pickeroptsWOSearch)),
                   conditionalPanel("input.hunworldIndicator == 'yll' & input.hunworldYllMethod == 'pyll'",
                                    numericInput("hunworldYllPyllTarget", "Cél-életkor", 75, 0, 100, 1)),
                   checkboxInput("hunworldPropsize",
                                 "A körök nagysága a vizsgált ország értékével arányos", FALSE),
                   checkboxInput("hunworldLog", "Logaritmikus ábra", FALSE),
                   checkboxInput("hunworldXRangeSet",
                                 "Vízszintes tengely tartományának beállítása", FALSE),
                   conditionalPanel("input.hunworldXRangeSet",
                                    sliderInput("hunworldXRange",
                                                "Vízszintes tengely tartománya",
                                                0, 2000, c(0, 100)))
                 ),
                 
                 mainPanel(
                   shinycssloaders::withSpinner(highchartOutput("hunworldPlot", height = "600px")),
                   tags$style(type = "text/css", ".irs-grid-pol.small {height: 0px;}"),
                   sliderInput("hunworldYear", div("Vizsgált év(tartomány)", bslib::tooltip(
                     bsicons::bs_icon("question-circle"),
                     paste0("Amennyiben a csúszka két vége nem esik egybe, úgy a megjelenített ",
                            "adat a tartomány összesített eredménye. A két végpont egy évre is ",
                            "összehúzható, ez esetben a kérdéses év adata fog látszódni."),
                     placement = "right")), min(RawData$Year), max(RawData$Year),
                     c(2020, 2022), 1, sep = "", width = "100%")
                 )
               )
             ),
             
             tabPanel(
               title = "Egészségkonvergencia",
               sidebarLayout(
                 sidebarPanel(
                   shinyWidgets::pickerInput("hconvCountryInvestigated", "Vizsgált ország",
                                             CountryCodes, "HUN", FALSE, options = pickeropts),
                   shinyWidgets::pickerInput("hconvCountryComparison",
                                             div("Összehasonlítási alapot képező ország(ok)",
                                                 bslib::tooltip(
                                                   bsicons::bs_icon("question-circle"),
                                                   paste0("Az összehasonlító országokból ",
                                                          "természetesen mindig kivételre ",
                                                          "kerül a vizsgált ország."),
                                                   placement = "right")),
                                             CountryCodes, EUCountries$EU27, TRUE,
                                             options = pickeropts),
                   actionButton("hconvEU27", "EU27 (Európai Unió) beállítása"),
                   actionButton("hconvEU15", "EU15 ('Nyugat') beállítása"),
                   actionButton("hconvEU11", "EU11 ('Kelet') beállítása"),
                   actionButton("hconvV4", "V4 (visegrádi négyek) beállítása"),
                   # shinyWidgets::pickerInput("hconvIndicator", "Ábrázolt mutató",
                   #                           c("Halálozás" = "death",
                   #                             "Elvesztett életévek száma" = "yll"),
                   #                           options = pickeroptsWOSearch),
                   # conditionalPanel("input.hconvIndicator == 'yll'",
                   #                  shinyWidgets::pickerInput("hconvYllMethod", "Módszer",
                   #                                            c("Fix cél-életkor (PYLL)" = "pyll"),
                   #                                            options = pickeroptsWOSearch)),
                   # conditionalPanel("input.hconvIndicator == 'yll' & input.hconvYllMethod == 'pyll'",
                   #                  numericInput("hconvYllPyllTarget", "Cél-életkor", 75, 0, 100, 1)),
                   radioButtons("hconvType", "Ábrázolás módja",
                                c("Szóródási diagram" = "scatter", "Hányados" = "ratio",
                                  "Különbség" = "difference"), "ratio"),
                   ownpanel("hconv", TRUE, hconv = TRUE)
                 ),
                 
                 mainPanel(
                   shinycssloaders::withSpinner(highchartOutput("hconvPlot", height = "600px"))
                 )
               )
             ),
             
             tabPanel(
               title = "Egészségkonvergencia dekompozíciója",
               sidebarLayout(
                 sidebarPanel(
                   shinyWidgets::pickerInput("hconvdecompCountryInvestigated", "Vizsgált ország",
                                             CountryCodes, "HUN", FALSE, options = pickeropts),
                   shinyWidgets::pickerInput("hconvdecompCountryComparison",
                                             div("Összehasonlítási alapot képező ország(ok)",
                                                 bslib::tooltip(
                                                   bsicons::bs_icon("question-circle"),
                                                   paste0("Az összehasonlító országokból ",
                                                          "természetesen mindig kivételre ",
                                                          "kerül a vizsgált ország."),
                                                   placement = "right")),
                                             CountryCodes, EUCountries$EU27, TRUE,
                                             options = pickeropts),
                   actionButton("hconvdecompEU27", "EU27 (Európai Unió) beállítása"),
                   actionButton("hconvdecompEU15", "EU15 ('Nyugat') beállítása"),
                   actionButton("hconvdecompEU11", "EU11 ('Kelet') beállítása"),
                   actionButton("hconvdecompV4", "V4 (visegrádi négyek) beállítása"),
                   # shinyWidgets::pickerInput("hconvdecompIndicator", "Ábrázolt mutató",
                   #                           c("Halálozás" = "death",
                   #                             "Elvesztett életévek száma" = "yll"),
                   #                           options = pickeroptsWOSearch),
                   # conditionalPanel("input.hconvdecompIndicator == 'yll'",
                   #                  shinyWidgets::pickerInput("hconvdecompYllMethod", "Módszer",
                   #                                            c("Fix cél-életkor (PYLL)" = "pyll"),
                   #                                            options = pickeroptsWOSearch)),
                   # conditionalPanel("input.hconvdecompIndicator == 'yll' & input.hconvdecompYllMethod == 'pyll'",
                   #                  numericInput("hconvdecompYllPyllTarget", "Cél-életkor", 75, 0, 100, 1)),
                   tags$style(type = "text/css", ".irs-grid-pol.small {height: 0px;}"),
                   sliderInput("hconvdecompYear", "Vizsgált intervallum",
                               min(RawData$Year), max(RawData$Year),
                               c(2003, 2019), 1, sep = "", width = "100%"),
                   shinyWidgets::pickerInput("hconvdecompType", "Dekompozíció módja",
                                             c("Hányados felbontása összegként" = "ratioassum"),
                                             "ratioassum" ,FALSE, options = pickeroptsWOSearch),
                   shinyWidgets::pickerInput("hconvdecompIndicator", "Ábrázolt mutató",
                                             c("Halálozás" = "death",
                                               "Elvesztett életévek száma" = "yll"),
                                             options = pickeroptsWOSearch),
                   conditionalPanel("input.hconvdecompIndicator == 'yll'",
                                    shinyWidgets::pickerInput("hconvdecompYllMethod", "Módszer",
                                                              c("Fix cél-életkor (PYLL)" = "pyll"),
                                                              options = pickeroptsWOSearch)),
                   conditionalPanel("input.hconvdecompIndicator == 'yll' & input.hconvdecompYllMethod == 'pyll'",
                                    numericInput("hconvdecompYllPyllTarget", "Cél-életkor", 75, 0, 100, 1))
                   # ownpanel("hconvdecomp", TRUE, hconv = TRUE)
                 ),
                 
                 mainPanel(
                   shinycssloaders::withSpinner(highchartOutput("hconvdecompPlot", height = "600px"))
                 )
               )
             ),
             
             tabPanel(
               title = "Vizualizáció dimenziócsökkentéssel",
               sidebarLayout(
                 sidebarPanel(
                   shinyWidgets::pickerInput("dimredvizMethod",
                                             "Alkalmazott módszer",
                                             c("PCA", "MDS", "t-SNE"), "t-SNE", FALSE,
                                             options = pickeropts),
                 ),
                 
                 mainPanel(
                   shinycssloaders::withSpinner(highchartOutput("dimredvizPlot", height = "600px"))
                 )
               )
             )
  )
)

server <- function(input, output) {
  
  observeEvent("", {
    showModal(modalDialog(
      h1("Okspecifikus Mortalitási Adatbázis"),
      p(paste0("Ez a weboldal a magyar halálozási adatokat tartalmazza halálok, nem és ",
               "életkor szerinti lebontásban, évente, 1995-ig visszamenően, valamint lehetővé ",
               "teszi ezek számos vetületben történő elemzését, vizualizálását és nemzetközi ",
               "összehasonlítását.")),
      p(paste0("Az adatok értelmezése, az adatminőség, a különféle összehasonlítások nem ",
               "nyilvánvaló problémákat vetnek fel, így érdemes bármilyen következtetés ",
               "levonása előtt tanulmányozni az oldalhoz kapcsolódó "),
        a(href = "https://github.com/tamas-ferenci/OkspecifikusMortalitasiAdatbazis",
          target = "_blank", "leírást", .noWS = "outside"),
        ", mely igyekszik közérthetően összefoglalni a legfontosabb szempontokat."),
      p(paste0("Ugyanezen a linken elérhető részletes technikai magyarázat is a weboldal ",
               "működéséhez, valamint letölthető a teljes forráskódja mind az oldalnak, mind ",
               "az adatok előkészítését végző szkriptnek, így az oldal teljesen ",
               "transzparens.")),
      p("Az adatbázist összeállította és a weboldalt készítette: ",
        a(href = "https://www.medstat.hu/", target = "_blank", "Ferenci Tamás",
          .noWS = "outside"),
        ". A weboldal és a közölt adatok, nézetek nem tekinthetőek semmilyen szerv hivatalos ",
        "álláspontjának, helyességükre garancia nincs, de a szerző örömmel vesz minden ",
        "javaslatot és kritikát (akár a Github-oldalon, akár email-ben)."),
      p(paste0("Az adatok forrása az Egészségügyi Világszervezet, a Human Mortality ",
               "Database és az Eurostat. Hivatalos deklarációk: HMD. Human Mortality ",
               "Database. Max Planck Institute for Demographic Research (Germany), University ",
               "of California, Berkeley (USA), and French Institute for Demographic Studies ",
               "(France). Available at www.mortality.org. Source of MDB data is WHO. ",
               "Analyses, interpretations and conclusions are of the author, not the WHO, ",
               "which is responsible only for the provision of the original information.")),
      easyClose = TRUE,
      footer = tagList(
        actionButton(inputId = "opening", label = "Bezárás", icon = icon("info-circle"))
      )
    ))
  })
  
  observeEvent(input$opening, {
    removeModal()
  })
  
  observeEvent(input$timeMetric,
               updateRadioButtons(inputId = "timeStratification",
                                  choices = if(input$timeMetric == "adjrate")
                                    stratsel[stratsel != "AgeLabel"] else stratsel))
  
  KitagawaDecomp <- function(di, years) {
    temp <- di[Year %in% years]
    temp$Year <- ifelse(temp$Year == years[1], 0, 1)
    
    temp <- dcast(temp, CauseGroup + EurostatCode ~ iso3c + Year, value.var = "adj.rate")[order(EurostatCode)]
    
    temp <- temp[Comparator_0 != 0 & Comparator_1 != 0]
    
    temp$V_0 <- temp$Investigated_0 / temp$Comparator_0
    temp$V_1 <- temp$Investigated_1 / temp$Comparator_1
    temp$k <- temp$V_1 - temp$V_0
    
    temp$Kp0 <- temp$Comparator_0 / sum(temp$Comparator_0) * temp$k
    temp$Kp1 <- temp$Comparator_1 / sum(temp$Comparator_1) * temp$k
    
    temp$Kpp0 <- (temp$Comparator_1 / sum(temp$Comparator_1) * temp$V_0) -
      (temp$Comparator_0 / sum(temp$Comparator_0) * temp$V_0)
    temp$Kpp1 <- (temp$Comparator_1 / sum(temp$Comparator_1) * temp$V_1) -
      (temp$Comparator_0 / sum(temp$Comparator_0) * temp$V_1)
    
    temp$Kp <- (temp$Kp0 + temp$Kp1)/2
    temp$Kpp <- (temp$Kpp0 + temp$Kpp1)/2
    
    start <- sum(temp$Investigated_0) / sum(temp$Comparator_0)
    end <- sum(temp$Investigated_1) / sum(temp$Comparator_1)
    
    tempplot <- data.table(Cause = c(paste0("Kezdő (", years[1], "): ", round(start, 2)), temp$CauseGroup, "Összetételhatás", paste0("Záró (", years[2], "): ", round(end, 2))),
                           Code = c(paste0("Kezdő (", years[1], "): ", round(start, 2)), temp$EurostatCode, "Összetételhatás", paste0("Záró (", years[2], "): ", round(end, 2))),
                           low = c(0, 0, cumsum(temp$Kp), end - start) + start,
                           high = c(0, cumsum(temp$Kp), sum(temp$Kp) + sum(temp$Kpp), end - start) + start)
    tempplot$color <- ifelse(tempplot$high > tempplot$low, "#FF0000", "#00FF00")
    tempplot$lwd <- c(3, rep(0.5, nrow(temp)), 3, 3)
    
    return(list(temp = temp, plot = tempplot, Kprime = sum(temp$Kp)))
  }
  
  dataInputFun <- function(category, multipleICD, ICDSingle, ICDMultiple,
                           multipleCountry, countrySingle, countryMultiple,
                           indicator, yllMethod, yllPyllTarget,
                           strat, metric, ordVar, byvarAdd,
                           yearFilter, sexFilter, ageFilter, comp, valid) {
    
    rd <- RawData
    rdAll <- RawDataAll
    
    icd <- if(multipleICD == "Single") ICDSingle else ICDMultiple
    if(is.null(icd)) return(NULL)
    icdtable <- rbindlist(lapply(icd, function(icdcode)
      with(ICDGroups[[category]][[icdcode]], data.table(CauseGroup = Name, Cause = ICD,
                                                        Weights, EurostatCode))))
    
    if(!is.na(multipleCountry)) {
      country <- if((multipleICD == "MultiIndiv" && is.null(comp) && !valid) || (multipleCountry == "Single"))
        countrySingle else countryMultiple
      if(is.null(country)) return(NULL)
      
      rd <- if(length(country) == 1) rd[iso3c == country] else rd[iso3c %in% country]
      rdAll <- if(length(country) == 1) rdAll[iso3c == country] else rdAll[iso3c %in% country]
    } else country <- NA
    
    if(!is.null(yearFilter)) {
      yearSel <- seq(yearFilter[1], yearFilter[2], 1)
      rd <- rd[Year %in% yearSel]
      rdAll <- rdAll[Year %in% yearSel]
    }
    if(sexFilter != "Összesen") {
      rd <- rd[Sex == sexFilter]
      rdAll <- rdAll[Sex == sexFilter]
    }
    if((ageFilter != "Összesen") && (metric != "adjrate")) {
      rd <- rd[Age == ageFilter]
      rdAll <- rdAll[Age == ageFilter]
    }
    
    rd <- merge(rd, icdtable, allow.cartesian = TRUE)
    
    if(multipleICD == "MultiSum") rd$CauseGroup <- "Összeg"
    
    rd <- rd[, .(value = round(sum(value*Weights))),
             .(iso3c, Year, Sex, Age, Frmat, CauseGroup, EurostatCode)]
    
    rd <- merge(
      data.table(base::merge.data.frame(rdAll, unique(rd[,.(CauseGroup, EurostatCode)]))),
      rd, by = c("iso3c", "Year", "Sex", "Age", "Frmat", "CauseGroup", "EurostatCode"),
      all.x = TRUE)
    rd[is.na(value)]$value <- 0
    
    rd <- merge(rd, PopData, by = c("iso3c", "Year", "Sex", "Age", "Frmat"))
    
    if(category == "Avoidable") rd <- rd[AgeNum < yllPyllTarget]
    
    if(indicator == "yll" && yllMethod == "pyll")
      rd$value <- rd$value * pmax(0, yllPyllTarget - rd$AgeNum)
    
    byvars <- c("iso3c", byvarAdd)
    if(multipleICD != "MultiIndiv" && !is.na(strat) && multipleCountry == "Single")
      byvars <- c(byvars, strat[strat != "None"])
    
    if(!is.null(comp)) rd$iso3c <- ifelse(rd$iso3c == comp, "Investigated", "Comparator")
    rd <- rd[, .(value = sum(value), Pop = sum(Pop)), setdiff(names(rd), c("value", "Pop"))]
    
    rd <- switch(metric,
                 "count" = rd[Aggregated == FALSE, .(value = sum(value)), byvars],
                 "cruderate" = rd[Aggregated == FALSE,
                                  .(value = sum(value)/sum(Pop)*1e5), byvars],
                 "adjrate" = merge(
                   rd[, .(value = sum(value), Pop = sum(Pop)),
                      c(byvars, "Frmat", "Age")],
                   StdPop, by = c("Frmat", "Age"))[
                     , as.list(epitools::ageadjust.direct(value, Pop, stdpop = StdPop)),
                     byvars][, c(.SD, .(value = adj.rate*1e5))])
    
    if(!is.na(ordVar)) rd <- rd[order(rd[[ordVar]])]
    
    if(is.null(comp)) rd <- merge(rd, data.table(iso3c = CountryCodes,
                                                 CountryName = names(CountryCodes)))
    
    return(list(rd = rd, icd = icd, country = country))
  }
  
  # countrySel <- function(multipleCountry, countrySingle, countryMultiple) {
  #   
  # }
  
  mapICDSingle <- reactive(switch(input$mapCategory, "Groups" = input$mapGroupsICDSingle,
                                  "Individual" = input$mapIndividualICDSingle,
                                  "Avoidable" = input$mapAvoidableICDSingle))
  hconvICDSingle <- reactive(switch(input$hconvCategory, "Groups" = input$hconvGroupsICDSingle,
                                    "Individual" = input$hconvIndividualICDSingle,
                                    "Avoidable" = input$hconvAvoidableICDSingle))
  
  dataInputTime <- reactive(dataInputFun(
    input$timeCategory, input$timeMultipleICD,
    switch(input$timeCategory, "Groups" = input$timeGroupsICDSingle,
           "Individual" = input$timeIndividualICDSingle,
           "Avoidable" = input$timeAvoidableICDSingle),
    switch(input$timeCategory, "Groups" = input$timeGroupsICDMultiple,
           "Individual" = input$timeIndividualICDMultiple,
           "Avoidable" = input$timeAvoidableICDMultiple),
    input$timeMultipleCountry,input$timeCountrySingle, input$timeCountryMultiple,
    input$timeIndicator, input$timeYllMethod, input$timeYllPyllTarget,
    input$timeStratification, input$timeMetric, "Year", c("Year", "CauseGroup"),
    NULL, "Összesen", "Összesen", NULL, FALSE))
  dataInputMap <- reactive(dataInputFun(
    input$mapCategory,
    "Single", mapICDSingle(), NA,
    NA, NA, NA,
    input$mapIndicator, input$mapYllMethod, input$mapYllPyllTarget,
    NA, input$mapMetric, NA, NULL,
    input$mapYear, input$mapSex, input$mapAge, NULL, FALSE))
  dataInputAgesex <- reactive(dataInputFun(
    input$agesexCategory, input$agesexMultipleICD,
    switch(input$agesexCategory, "Groups" = input$agesexGroupsICDSingle,
           "Individual" = input$agesexIndividualICDSingle,
           "Avoidable" = input$agesexAvoidableICDSingle),
    switch(input$agesexCategory, "Groups" = input$agesexGroupsICDMultiple,
           "Individual" = input$agesexIndividualICDMultiple,
           "Avoidable" = input$agesexAvoidableICDMultiple),
    input$agesexMultipleCountry,input$agesexCountrySingle, input$agesexCountryMultiple,
    "death", NA, NA, input$agesexStratification, "cruderate", "AgeNum",
    c("Age", "AgeNum", "AgeLabel", "CauseGroup"), input$agesexYear, "Összesen", "Összesen",
    NULL, FALSE))
  dataInputHunworld <- reactive(dataInputFun(
    "Groups", "MultiIndiv", NA, names(ICDGroups$Groups),
    "Multiple", NA, union(input$hunworldCountryInvestigated, input$hunworldCountryComparison),
    input$hunworldIndicator, input$hunworldYllMethod, input$hunworldYllPyllTarget,
    NA, "adjrate", NA, "CauseGroup", input$hunworldYear, "Összesen", "Összesen",
    input$hunworldCountryInvestigated, FALSE))
  dataInputHconv <- reactive(dataInputFun(
    input$hconvCategory, "Single",
    switch(input$hconvCategory, "Groups" = input$hconvGroupsICDSingle,
           "Individual" = input$hconvIndividualICDSingle,
           "Avoidable" = input$hconvAvoidableICDSingle), NA,
    "Multiple", NA, union(input$hconvCountryInvestigated, input$hconvCountryComparison),
    input$hconvIndicator, input$hconvYllMethod, input$hconvYllPyllTarget,
    NA, input$hconvMetric, NA, "Year", NULL, "Összesen", "Összesen",
    input$hconvCountryInvestigated, FALSE))
  dataInputHconvdecomp <- reactive(dataInputFun(
    "Groups",
    "MultiIndiv", NA, names(ICDGroups$Groups)[c(2, 9, 32, 33, 34, 37, 42, 46, 53, 60, 65, 66, 69, 72, 73, 74, 75, 79, 83)],
    "Multiple", NA, union(input$hconvdecompCountryInvestigated, input$hconvdecompCountryComparison),
    input$hconvdecompIndicator, input$hconvdecompYllMethod, input$hconvdecompYllPyllTarget, NA,
    "adjrate", "EurostatCode", c("Year", "CauseGroup", "EurostatCode"),
    NULL, "Összesen", "Összesen", input$hconvdecompCountryInvestigated, FALSE))
  
  output$timePlot <- renderHighchart({
    p <- highchart()
    
    di <- dataInputTime()
    mortdat <- di$rd
    gc()
    if(is.null(mortdat)) return(p)
    
    if(input$timeMultipleICD %in% c("Single", "MultiSum") && input$timeMultipleCountry == "Single" && input$timeStratification == "None")
      p <- p |> hc_add_series(mortdat, type = "line", hcaes(x = Year, y = value, group = NA),
                              name = paste0(di$icd, collapse = ", "))
    if(input$timeMultipleICD %in% c("Single", "MultiSum") && input$timeMultipleCountry == "Single" && input$timeStratification == "Sex")
      p <- p |> hc_add_series(mortdat, type = "line", hcaes(x = Year, y = value, group = Sex))
    if(input$timeMultipleICD %in% c("Single", "MultiSum") && input$timeMultipleCountry == "Single" && input$timeStratification == "AgeLabel")
      p <- p |> hc_add_series(mortdat, type = "line", hcaes(x = Year, y = value, group = AgeLabel))
    if(input$timeMultipleICD %in% c("Single", "MultiSum") && input$timeMultipleCountry == "Multiple")
      p <- p |> hc_add_series(mortdat, type = "line", hcaes(x = Year, y = value, group = CountryName))
    if(input$timeMultipleICD == "MultiIndiv") p <- p |> hc_add_series(mortdat, type = "line", hcaes(x = Year, y = value, group = CauseGroup))
    
    p <- p |>
      hc_title(text = paste0("<b>", if(input$timeIndicator == "death") "Halálozás" else
        "Elveszett életévek számának", " időbeli alakulása</b>",
        if(input$timeMultipleCountry == "Single")
          paste0("<br>", names(CountryCodes)[CountryCodes == di$country]) else
            if(input$timeMultipleCountry == "Multiple")
              if(input$timeMultipleICD %in% c("Single", "MultiSum"))
                paste0("<br>", paste0(di$icd, collapse = ", ")) else
                  paste0("<br>", names(CountryCodes)[CountryCodes == di$country]))) |>
      hc_subtitle(
        text = "Okspecifikus Mortalitási Adatbázis<br>Ferenci Tamás, medstat.hu",
        align = "left", verticalAlign = "bottom") |>
      hc_xAxis(tickInterval = 1) |>
      hc_yAxis(title = list(
        text = switch(input$timeMetric, "count" = "Abszolút szám [fő]",
                      "cruderate" = "Nyers ráta [fő/100 ezer fő/év]",
                      "adjrate" = "Standardizált ráta [fő/100 ezer fő/év]")),
        type = if(input$timeLogY) "logarithmic" else "linear",
        softMin = if(input$timeYFromZero) 0 else NULL) |>
      hc_tooltip(valueDecimals = ifelse(input$timeMetric == "count", 0, 1)) |>
      hc_add_theme(hc_theme(
        chart = list(backgroundColor = "white"))) |>
      hc_credits(enabled = TRUE) |>
      hc_exporting(enabled = TRUE, chartOptions = list(legend = TRUE),
                   sourceWidth = 1600/2, sourceHeight = 900/2)
    
    if("HUN" %in% di$country) p <- p |> hc_xAxis(plotLines = list(
      list(
        label = list(text = "Módszertani változás (HUN)"),
        dashStyle = "Dash",
        value = 2004.5
      )
    ))
    
    p
  })
  
  output$mapPlot <- renderHighchart({
    di <- dataInputMap()
    mortdat <- di$rd
    gc()
    if(is.null(mortdat)) return(p)
    
    if(input$mapType == "Map") {
      p <- hcmap(paste0("custom/", input$mapMap), data = mortdat, value = "value",
                 joinBy = c("iso-a3", "iso3c"), name = mapICDSingle(),
                 tooltip = list(pointFormat = "{point.CountryName}: {point.value}"))
      # p <- p |> hc_colorAxis(width = "100%")
      # p <- p |> hc_colorAxis(layout = "vertical", reversed = FALSE, margin = 0) |> hc_legend(align = "right", verticalAlign = "middle")
    } else {
      p <- hchart(mortdat[order(if(input$mapBarOrder) value else iso3c)],
                  type = if(input$mapBarHorizontal) "bar" else "column",
                  hcaes(x = iso3c, y = value), name = mapICDSingle())
      p <- p |> hc_tooltip(headerFormat = "{point.point.CountryName}<br>")
    }
    
    p <- p |>
      hc_title(text = paste0("<b>", if(input$mapIndicator == "death") "Halálozás" else
        "Elveszett életévek számának", " területi alakulása, ",
        if(input$mapYear[1] == input$mapYear[2]) input$mapYear[1] else
          paste0(input$mapYear, collapse = " - "),
        if(input$mapSex != "Összesen") paste0(", ", input$mapSex),
        if((input$mapAge != "Összesen")&(input$mapMetric != "adjrate"))
          paste0(", ", AgeTable[Age == input$mapAge]$AgeLabel, " év"),
        "</b><br>", mapICDSingle())) |>
      hc_subtitle(
        text = "Okspecifikus Mortalitási Adatbázis<br>Ferenci Tamás, medstat.hu",
        align = "left", verticalAlign = "bottom") |>
      hc_xAxis(title = list(text = "")) |>
      hc_yAxis(title = list(
        text = switch(input$mapMetric, "count" = "Abszolút szám [fő]",
                      "cruderate" = "Nyers ráta [fő/100 ezer fő/év]",
                      "adjrate" = "Standardizált ráta [fő/100 ezer fő/év]")),
        type = if(input$timeLogY) "logarithmic" else "linear",
        softMin = if(input$timeYFromZero) 0 else NULL) |>
      hc_tooltip(valueDecimals = ifelse(input$mapMetric == "count", 0, 1)) |>
      hc_add_theme(hc_theme(
        chart = list(backgroundColor = "white"))) |>
      hc_credits(enabled = TRUE) |>
      hc_exporting(enabled = TRUE, chartOptions = list(legend = TRUE),
                   sourceWidth = 1600/2, sourceHeight = 900/2)
  })
  
  output$agesexPlot <- renderHighchart({
    p <- highchart()
    
    di <- dataInputAgesex()
    mortdat <- di$rd
    gc()
    if(is.null(mortdat)) return(p)
    
    if(input$agesexMultipleICD %in% c("Single", "MultiSum") & input$agesexMultipleCountry == "Single" & input$agesexStratification == "None")
      p <- p |> hc_add_series(mortdat, type = "line", hcaes(x = AgeNum, y = value, group = NA),
                              name = paste0(di$icd, collapse = ", "))
    if(input$agesexMultipleICD %in% c("Single", "MultiSum") & input$agesexMultipleCountry == "Single" & input$agesexStratification == "Sex")
      p <- p |> hc_add_series(mortdat, type = "line", hcaes(x = AgeNum, y = value, group = Sex))
    if(input$agesexMultipleICD %in% c("Single", "MultiSum") & input$agesexMultipleCountry == "Single" & input$agesexStratification == "Year")
      p <- p |> hc_add_series(mortdat, type = "line", hcaes(x = AgeNum, y = value, group = Year))
    if(input$agesexMultipleICD %in% c("Single", "MultiSum") & input$agesexMultipleCountry == "Multiple")
      p <- p |> hc_add_series(mortdat, type = "line", hcaes(x = AgeNum, y = value, group = CountryName))
    if(input$agesexMultipleICD == "MultiIndiv") p <- p |> hc_add_series(mortdat, type = "line", hcaes(x = AgeNum, y = value, group = CauseGroup))
    
    p <- p |>
      hc_title(text = paste0("<b>", if(input$timeIndicator == "death") "Halálozás" else
        "Elveszett életévek számának", " életkor- és nem-függése, ",
        if(input$agesexYear[1] == input$agesexYear[2]) input$agesexYear[1] else
          paste0(input$agesexYear, collapse = " - "), "</b>",
        if(input$agesexMultipleCountry == "Single")
          paste0("<br>", names(CountryCodes)[CountryCodes == di$country]) else
            if(input$agesexMultipleCountry == "Multiple")
              if(input$agesexMultipleICD %in% c("Single", "MultiSum"))
                paste0("<br>", paste0(di$icd, collapse = ", ")) else
                  paste0("<br>", names(CountryCodes)[CountryCodes == di$country]))) |>
      hc_subtitle(
        text = "Okspecifikus Mortalitási Adatbázis<br>Ferenci Tamás, medstat.hu",
        align = "left", verticalAlign = "bottom") |>
      hc_xAxis(title = list(text = "Életkor [év]")) |>
      hc_yAxis(title = list(text = "Nyers ráta [fő/100 ezer fő/év]"),
               type = if(input$agesexLogY) "logarithmic" else "linear",
               softMin = if(input$agesexYFromZero) 0 else NULL) |>
      hc_tooltip(valueDecimals = 1, headerFormat = "{point.point.AgeLabel} év<br>") |>
      hc_add_theme(hc_theme(chart = list(backgroundColor = "white"))) |>
      hc_credits(enabled = TRUE) |>
      hc_exporting(enabled = TRUE, chartOptions = list(legend = TRUE),
                   sourceWidth = 1600/2, sourceHeight = 900/2)
    
    p
  })
  
  observeEvent(input$hunworldEU27,
               shinyWidgets::updatePickerInput(inputId = "hunworldCountryComparison",
                                               selected = EUCountries$EU27))
  observeEvent(input$hunworldEU15,
               shinyWidgets::updatePickerInput(inputId = "hunworldCountryComparison",
                                               selected = EUCountries$EU15))
  observeEvent(input$hunworldEU11,
               shinyWidgets::updatePickerInput(inputId = "hunworldCountryComparison",
                                               selected = EUCountries$EU11))
  observeEvent(input$hunworldV4,
               shinyWidgets::updatePickerInput(inputId = "hunworldCountryComparison",
                                               selected = EUCountries$V4))
  
  output$hunworldPlot <- renderHighchart({
    mortdat <- dataInputHunworld()$rd
    gc()
    mortdat <- dcast(mortdat[, .(iso3c, CauseGroup, value)], CauseGroup ~ iso3c,
                     value.var = "value")
    invcountryname <- names(CountryCodes)[CountryCodes == input$hunworldCountryInvestigated]
    
    p <- hchart(if("Comparator" %in% names(mortdat) & "Investigated" %in% names(mortdat)) mortdat else
      data.table(Investigated = numeric(), Comparator = numeric(), CauseGroup = character()), "point",
      if(input$hunworldPropsize) hcaes(x = Investigated, y = Comparator, group = CauseGroup, size = Investigated) else
        hcaes(x = Investigated, y = Comparator, group = CauseGroup))
    
    p <- p |>
      hc_title(text = paste0("<b>", invcountryname, " összehasonlítása más országokkal</b><br>",
                             "Összehasonlítási alap a következő országok átlaga: ",
                             paste0(setdiff(input$hunworldCountryComparison, input$hunworldCountryInvestigated), collapse = ", "))) |>
      hc_subtitle(
        text = "Okspecifikus Mortalitási Adatbázis<br>Ferenci Tamás, medstat.hu",
        align = "left", verticalAlign = "bottom") |>
      hc_annotations(list(draggable = FALSE,
                          shapes = list(type = "path", strokeWidth = 2,
                                        points = list(
                                          list(x = 1e-6, y = 1e-6, xAxis = 0, yAxis = 0),
                                          list(x = 1e6, y = 1e6, xAxis = 0, yAxis = 0))))) |>
      hc_xAxis(title = list(text = if(input$hunworldIndicator == "death")
        paste0(invcountryname, " standardizált mortalitási rátája [fő/100 ezer fő/év]") else
          paste0(invcountryname, " standardizált elvesztett életév rátája [fő/100 ezer fő/év]")),
        type = if(input$hunworldLog) "logarithmic" else "linear",
        min = if(input$hunworldXRangeSet) input$hunworldXRange[1],
        max = if(input$hunworldXRangeSet) input$hunworldXRange[2]) |>
      hc_yAxis(title = list(text = if(input$hunworldIndicator == "death")
        "A többi ország standardizált mortalitási rátája [fő/100 ezer fő/év]" else
          "A többi ország standardizált elvesztett életév rátája [fő/100 ezer fő/év]"),
        type = if(input$hunworldLog) "logarithmic" else "linear") |>
      hc_legend(enabled = FALSE) |>
      hc_tooltip(pointFormatter = JS(
        paste0("function() { return('", invcountryname, ": ' + this.x.toFixed(1) + '/100 ezer fő/év' +
      '<br>Összehasonlítási országok: ' + this.y.toFixed(1) + '/100 ezer fő/év<br>", invcountryname, " adata az összehasonlítási országok ' +
      (this.x / this.y * 100).toFixed(1) + '%-a (a különbség ' + (this.x - this.y).toFixed(1) + '/100 ezer fő/év)'); }"))) |>
      hc_add_theme(hc_theme(chart = list(backgroundColor = "white"))) |>
      hc_credits(enabled = TRUE) |>
      hc_exporting(enabled = TRUE, chartOptions = list(legend = TRUE),
                   sourceWidth = 1600/2, sourceHeight = 900/2)
    
    p
  })
  
  observeEvent(input$hconvEU27,
               shinyWidgets::updatePickerInput(inputId = "hconvCountryComparison",
                                               selected = EUCountries$EU27))
  observeEvent(input$hconvEU15,
               shinyWidgets::updatePickerInput(inputId = "hconvCountryComparison",
                                               selected = EUCountries$EU15))
  observeEvent(input$hconvEU11,
               shinyWidgets::updatePickerInput(inputId = "hconvCountryComparison",
                                               selected = EUCountries$EU11))
  observeEvent(input$hconvV4,
               shinyWidgets::updatePickerInput(inputId = "hconvCountryComparison",
                                               selected = EUCountries$V4))
  
  output$hconvPlot <- renderHighchart({
    mortdat <- dataInputHconv()$rd
    gc()
    
    mortdat <- dcast(mortdat[, .(iso3c, Year, value)], Year ~ iso3c, value.var = "value")
    # if(!"Comparator" %in% names(mortdat))
    #   mortdat <- data.table(HUN = numeric(), Comparator = numeric(), Year = numeric())
    mortdat$Ratio <- mortdat$Investigated / mortdat$Comparator
    mortdat$Difference <- mortdat$Investigated - mortdat$Comparator
    
    invcountryname <- names(CountryCodes)[CountryCodes == input$hconvCountryInvestigated]
    
    p <- switch(input$hconvType,
                "scatter" = hchart(mortdat, "scatter",
                                   hcaes(x = Investigated, y = Comparator, group = Year, color = Year)),
                "ratio" = hchart(mortdat, "line", hcaes(x = Year, y = Ratio),
                                 name = "Hányados"),
                "difference" = hchart(mortdat, "line", hcaes(x = Year, y = Difference),
                                      name = "Különbség"))
    
    p <- p |>
      hc_title(text = paste0("<b>", invcountryname, " konvergenciája más országokhoz</b><br>",
                             hconvICDSingle(), "<br>",
                             "Összehasonlítási alap a következő országok átlaga: ",
                             paste0(setdiff(input$hconvCountryComparison, input$hconvCountryInvestigated), collapse = ", "))) |>
      hc_subtitle(
        text = "Okspecifikus Mortalitási Adatbázis<br>Ferenci Tamás, medstat.hu",
        align = "left", verticalAlign = "bottom") |>
      hc_legend(enabled = FALSE) |>
      hc_add_theme(hc_theme(chart = list(backgroundColor = "white"))) |>
      hc_credits(enabled = TRUE) |>
      hc_exporting(enabled = TRUE, chartOptions = list(legend = TRUE),
                   sourceWidth = 1600/2, sourceHeight = 900/2)
    
    if(input$hconvType == "ratio") p <-
      p |> hc_yAxis(title = list(text = paste0("Hányados (", invcountryname, " / többi)")), softMin = 0.9, softMax = 1.1,
                    plotLines = list(list(value = 1, color = "red", width = 2)),
                    gridZIndex = 0)
    if(input$hconvType == "difference") p <-
      p |> hc_yAxis(title = list(text = paste0("Különbség (", invcountryname, " - többi)")), softMin = -10, softMax = 10,
                    plotLines = list(list(value = 0, color = "red", width = 2)),
                    gridZindex = 0)
    if(input$hconvType %in% c("ratio", "difference")) {
      p <- p |> hc_xAxis(title = list(text = "Év")) |>
        hc_tooltip(valueDecimals = ifelse(input$hconvType == "ratio", 2, 1))
    } 
    
    if(input$hconvType == "scatter") {
      if(input$hconvType == "scatter") p <-
          p |> hc_tooltip(pointFormat = ifelse(
            input$hconvMetric == "count",
            "x: <b>{point.x:.0f}</b><br>y: <b>{point.y:.0f}</b>",
            "x: <b>{point.x:.1f}</b><br>y: <b>{point.y:.1f}</b>")) |>
          hc_yAxis(title = list(text = if(input$hconvIndicator == "death")
            "A többi ország standardizált mortalitási rátája [fő/100 ezer fő/év]" else
              "A többi ország standardizált elvesztett életév rátája [fő/100 ezer fő/év]")) |>
          hc_xAxis(title = list(text = if(input$hconvIndicator == "death")
            paste0(invcountryname, " standardizált mortalitási rátája [fő/100 ezer fő/év]") else
              paste0(invcountryname, " standardizált elvesztett életév rátája [fő/100 ezer fő/év]"))) |>
          hc_annotations(list(draggable = FALSE,
                              shapes = list(type = "path", strokeWidth = 2,
                                            points = list(
                                              list(x = 1e-6, y = 1e-6, xAxis = 0, yAxis = 0),
                                              list(x = 1e6, y = 1e6, xAxis = 0, yAxis = 0)))))
    }
    
    p
  })
  
  observeEvent(input$hconvdecompEU27,
               shinyWidgets::updatePickerInput(inputId = "hconvdecompCountryComparison",
                                               selected = EUCountries$EU27))
  observeEvent(input$hconvdecompEU15,
               shinyWidgets::updatePickerInput(inputId = "hconvdecompCountryComparison",
                                               selected = EUCountries$EU15))
  observeEvent(input$hconvdecompEU11,
               shinyWidgets::updatePickerInput(inputId = "hconvdecompCountryComparison",
                                               selected = EUCountries$EU11))
  observeEvent(input$hconvdecompV4,
               shinyWidgets::updatePickerInput(inputId = "hconvdecompCountryComparison",
                                               selected = EUCountries$V4))
  
  output$hconvdecompPlot <- renderHighchart({
    mortdat <- dataInputHconvdecomp()$rd
    gc()
    
    mortdat <- KitagawaDecomp(mortdat, input$hconvdecompYear)
    tempplot <- mortdat$plot
    tempplot$CodeFormatted <- tempplot$Code
    tempplot$CodeFormatted[c(1, nrow(tempplot))] <- paste0("<span style='font-weight:900;'>", tempplot$Code[c(1, nrow(tempplot))], "</span>")
    
    invcountryname <- names(CountryCodes)[CountryCodes == input$hconvdecompCountryInvestigated]
    
    p <- highchart() |>
      hc_add_series(data = tempplot, type = "columnrange",
                    hcaes(x = Cause, low = low, high = high, color = color)) |>
      hc_xAxis(categories = tempplot$CodeFormatted, labels = list(useHTML = TRUE)) |>
      hc_yAxis(title = list(text = paste0("Hányados (", invcountryname, " / többi)"))) |>
      hc_tooltip(pointFormatter = JS("function() {return('Hozzájárulás:' + ((this.high - this.low)<=0?'':'+') + (this.high - this.low).toFixed(3))}")) |>
      hc_legend(enabled = FALSE)
    
    for(i in 1:(nrow(tempplot) - 1))
      p <- p |> hc_add_series(data = data.frame(Code = c(i - 1, i), y = rep(tempplot$high[i], 2)),
                              type = "line", hcaes(x = Code, y = y), color = "black", lineWidth = tempplot$lwd[i])
    
    p <- p |>
      hc_plotOptions(line = list(enableMouseTracking = FALSE, marker = list(enabled = FALSE),
                                 lineWidth = 0.5)) |>
      hc_title(text = paste0("<b>", invcountryname, " ", input$hconvdecompYear[1], " és ",
                             input$hconvdecompYear[2], " közötti konvergenciájának ",
                             "dekompozíciója </b><br>",
                             "Összehasonlítási alap a következő országok átlaga: ",
                             paste0(setdiff(input$hconvdecompCountryComparison, input$hconvdecompCountryInvestigated), collapse = ", "))) |>
      hc_subtitle(
        text = "Okspecifikus Mortalitási Adatbázis<br>Ferenci Tamás, medstat.hu",
        align = "left", verticalAlign = "bottom") |>
      hc_legend(enabled = FALSE) |>
      hc_add_theme(hc_theme(chart = list(backgroundColor = "white"))) |>
      hc_credits(enabled = TRUE) |>
      hc_exporting(enabled = TRUE, chartOptions = list(legend = TRUE),
                   sourceWidth = 1600/2, sourceHeight = 900/2)
    
    p
  })
  
  output$dimredvizPlot <- renderHighchart({
    hchart(dimredvizData[Method == input$dimredvizMethod], "point",
           hcaes(x = V1, y = V2, group = iso3c, color = iso3c,
                 shape = ifelse(Sex == "Férfi", "square", "circle"))) |>
      hc_chart(events = list(load = JS("function() {
        var chart = this,
          seriess = chart.series;
        seriess.forEach(function(series, index) {
          var points = series.points;
            points.forEach(function(point, index) {
              point.update({
                marker: {
                  symbol: point.shape
                }
              });
            });
        });
      }")
      )) |>
      hc_title(text = paste0("Mortalitási profilok vizualizációja dimenziócsökkentéssel",
                             " (alkalmazott módszer: ", input$dimredvizMethod, ")")) |>
      hc_subtitle(
        text = paste0("Férfi: ◼, Nő: ⚫︎<br>Okspecifikus Mortalitási Adatbázis<br>",
                      "Ferenci Tamás, medstat.hu"),
        align = "left", verticalAlign = "bottom") |>
      hc_add_theme(hc_theme(chart = list(backgroundColor = "white"))) |>
      hc_credits(enabled = TRUE) |>
      hc_exporting(enabled = TRUE, chartOptions = list(legend = TRUE),
                   sourceWidth = 1600/2, sourceHeight = 900/2) |>
      hc_xAxis(title = list(text = ""), gridLineWidth = 1, labels = list(enabled = FALSE),
               tickLength = 0, startOnTick = TRUE, endOnTick = TRUE) |>
      hc_yAxis(title = list(text = ""), labels = list(enabled = FALSE), tickLength = 0) |>
      hc_plotOptions(scatter = list(marker = list(radius = 3))) |>
      hc_tooltip(pointFormat = "",
                 headerFormat =
                   "{point.point.iso3c}, {point.point.Sex}, {point.point.Year}<br>")
  })
}

shinyApp(ui = ui, server = server)