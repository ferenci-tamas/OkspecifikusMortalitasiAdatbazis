## Part A
td <- tempdir()

unzip("./inputdata/morticd10_part1.zip", exdir = td)
unzip("./inputdata/morticd10_part2.zip", exdir = td)
unzip("./inputdata/morticd10_part3.zip", exdir = td)
unzip("./inputdata/morticd10_part4.zip", exdir = td)
unzip("./inputdata/morticd10_part5.zip", exdir = td)
unzip("./inputdata/morticd10_part6.zip", exdir = td)

unzip("./inputdata/morticd09.zip", exdir = td)

unzip("./inputdata/morticd08.zip", exdir = td)

unzip("./inputdata/morticd07.zip", exdir = td)
# A WHO a 7. revíziót "MortIcd7" néven adja (nagy I betűvel!), míg az összes többi
# fájl "Morticd..." (kis i); a lenti list.files() mintázat (kis i) csak az utóbbit
# fogja meg, ezért a beolvasás előtt egységes névre kereszteljük.
file.rename(file.path(td, "MortIcd7"), file.path(td, "Morticd7"))

RawData <- rbindlist(lapply(list.files(td, pattern = "Morticd*",
                                       full.names = TRUE), fread))

# CountryCodes <- fread(
#   "https://apps.who.int/gho/athena/data/xmart.csv?target=COUNTRY&profile=xmart")
CountryCodes <- fread("xmart.csv")

unique(merge(RawData,
             CountryCodes[, .(Country = MORT, CountryName = DisplayString,
                              iso3c = ISO, Region = WHO_REGION_CODE)],
             by = "Country", all.x = TRUE)[is.na(iso3c)]$Country)

CountryCodes[DisplayString == "Mayotte"]$MORT <- 1303
CountryCodes[DisplayString == "occupied Palestinian territory, including east Jerusalem"]$MORT <- 3283

RawData <- merge(RawData,
                 CountryCodes[, .(Country = MORT, CountryName = DisplayString,
                                  iso3c = ISO, Region = WHO_REGION_CODE)],
                 by = "Country")

RawData[iso3c == "CYM" & Year == 2014]$Frmat <- 2
RawData[iso3c == "IRL" & Year %in% c(2016, 2017, 2019, 2020)]$Frmat <- 2

RawData <- RawData[Frmat %in% c(0, 1, 2)]

RawData <- RawData[!iso3c %in% RawData[
  , .(sum(Deaths26, na.rm = TRUE)/sum(Deaths1) > 0.005),
  .(iso3c)][V1 == TRUE]$iso3c]

RawData <- RawData[Sex != 9]

RawData$Deaths232425 <- ifelse(RawData$Frmat == 0, NA, RawData$Deaths23)
RawData$Deaths23 <- ifelse(RawData$Frmat == 0, RawData$Deaths23, NA)

RawData$Deaths3456 <- ifelse(
  RawData$Frmat == 2, RawData$Deaths3,
  RawData$Deaths3 + RawData$Deaths4 + RawData$Deaths5 + RawData$Deaths6)
RawData$Deaths3 <- ifelse(RawData$Frmat == 2, NA, RawData$Deaths3)

RawData <- melt(RawData[
  , c("iso3c", "Year", "List", "Cause", "Sex", "Frmat",
      paste0("Deaths", 2:25), "Deaths3456", "Deaths232425")],
  id.vars = c("iso3c", "Year", "List", "Cause", "Sex", "Frmat"),
  variable.name = "Age")

RawData <- RawData[!is.na(value)]

RawData[List == "104" & substring(Cause, 1, 1) == "W",
        Cause := substring(Cause, 1, 3)]
RawData[List == "104" & substring(Cause, 1, 1) == "X",
        Cause := substring(Cause, 1, 3)]
RawData[List == "104" & substring(Cause, 1, 3) %in%
          paste0("Y", sprintf("%02d", setdiff(0:34, 6:7))),
        Cause := substring(Cause, 1, 3)]

RawData <- RawData[, .(value = sum(value)),
                   .(iso3c, Year, List, Cause, Sex, Frmat, Age)]

RawData[List == "104" & nchar(Cause) == 3,
        Cause := paste0(Cause, "H0")]
RawData[List == "104" & nchar(Cause) == 4,
        Cause := paste0(Cause, "0")]

RawData$iso3c <- as.factor(RawData$iso3c)
RawData$List <- as.factor(RawData$List)
RawData$Cause <- as.factor(RawData$Cause)
RawData$Sex <- factor(RawData$Sex, levels = 1:2, labels = c("Férfi", "Nő"))
RawData$Frmat <- as.factor(RawData$Frmat)

RawDataAll <- unique(RawData[, .(iso3c, Year, List, Age, Frmat)])
RawDataAll[, .N, .(iso3c, Year, List, Age, Frmat)][N > 1]
RawDataAll <- rbind(cbind(RawDataAll, Sex = "Férfi"),
                    cbind(RawDataAll, Sex = "Nő"))
setkey(RawDataAll, iso3c, Year, Sex, Age)
saveRDS(RawDataAll, "./procdata/RawDataAll.rds")

setkey(RawData, iso3c, Year, Sex, Age)

saveRDS(RawData[value > 0], "./procdata/WHO-MDB.rds")

arrow::write_feather(RawData[value > 0], "./procdata/WHO-MDB.feather")
## Part B
ICDData <- data.table(foreign::read.dbf("./inputdata/BNOTORZS.DBF", as.is = TRUE))
ICDData$NEV <- stringi::stri_encode(ICDData$NEV, "windows-852", "UTF-8")

ICDData <- ICDData[ERV_VEGE == "29991231"]

unique(merge(RawData[List == 104], ICDData[, .(Cause = KOD10, Nev = NEV)],
             by = "Cause", all.x = TRUE)[is.na(Nev)]$Cause)

ICDData <- rbind(ICDData, data.table(
  KOD10 = unique(merge(RawData[List == 104],
                       ICDData[, .(Cause = KOD10, Nev = NEV)], by = "Cause",
                       all.x = TRUE)[is.na(Nev)]$Cause),
  JEL = NA, NEV = unique(merge(RawData[List == 104],
                               ICDData[, .(Cause = KOD10, Nev = NEV)],
                               by = "Cause", all.x = TRUE)[is.na(Nev)]$Cause),
  NEM = 0, KOR_A = 0, KOR_F = 99, ERV_KEZD = "19950101",
  ERV_VEGE = "29991231"))

ICDData <- ICDData[KOD10 != "AAAH0"]

ICDData$Kod1 <- substring(ICDData$KOD10, 1, 1)
ICDData$Kod23 <- as.numeric(substring(ICDData$KOD10, 2, 3))

ICDGroups <- list(
  Groups =
    list(
      ###### Összes ######
      data.table(rbind(data.table(Cause = ICDData[Kod1!="Z"&(Kod1!="Y"|Kod23<=89)]$KOD10, List = "104"),
                       data.table(Cause = "A000", List = "08A"),
                       data.table(Cause = "B000", List = "08B"),
                       data.table(Cause = "B00", List = "09A"),
                       data.table(Cause = "B00", List = "09B"),
                       data.table(Cause = "C001", List = "09C"),
                       data.table(Cause = "B00", List = "09N")),
                 EurostatCode = "A-R_V-Y", CauseGroup = "Összes halálok (A00-Y89)"),
      ###### A, B ######
      data.table(rbind(data.table(Cause = ICDData[Kod1%in%c("A", "B")]$KOD10, List = "104"),
                       data.table(Cause = paste0("A", sprintf("%03d", 1:44)), List = "08A"),
                       data.table(Cause = paste0("B", sprintf("%03d", 1:18)), List = "08B"),
                       data.table(Cause = c("B01", "B02", "B03", "B04", "B05", "B06", "B07"), List = "09A"),
                       data.table(Cause = c("B01", "B02", "B03", "B04", "B05", "B06", "B07"), List = "09B"),
                       data.table(Cause = "C002", List = "09C"),
                       data.table(Cause = "CH01", List = "09N")),
                 EurostatCode = "A_B", CauseGroup = "Fertőző és parazitás betegségek (A00-B99)"),
      data.table(rbind(data.table(Cause = ICDData[(Kod1=="A"&Kod23>=15&Kod23<=19)|(Kod1=="B"&Kod23==90)]$KOD10,
                                  List = "104"),
                       data.table(Cause = c("A006", "A007", "A008", "A009", "A010"), List = "08A"),
                       data.table(Cause = c("B005", "B006"), List = "08B"),
                       data.table(Cause = c("B02", "B077"), List = "09A"),
                       data.table(Cause = c("B02", "B077"), List = "09B")),
                 EurostatCode = "A15-A19_B90", CauseGroup = "Gümőkór (A15-A19, B90)"),
      data.table(rbind(data.table(Cause = ICDData[KOD10 %in% c("B1800", "B1810", "B1820")]$KOD10, List = "104")),
                 EurostatCode = "B180-B182",
                 CauseGroup = "Idült vírusos B- és C-típusú hepatitis (B180-B182)"),
      data.table(rbind(data.table(Cause = ICDData[Kod1=="B"&Kod23>=20&Kod23<=24]$KOD10, List = "104"),
                       data.table(Cause = c("B184", "B185"), List = "09B")),
                 EurostatCode = "B20-B24",
                 CauseGroup = "Humán immunodeficiencia vírus (HIV) betegség (B20-B24)"),
      data.table(rbind(data.table(Cause = ICDData[(Kod1=="B"&Kod23>=15&Kod23<=19)|KOD10=="B9420"]$KOD10, List = "104"),
                       data.table(Cause = "A028", List = "08A"),
                       data.table(Cause = "B046", List = "09A"),
                       data.table(Cause = "B046", List = "09B"),
                       data.table(Cause = "C016", List = "09C")),
                 EurostatCode = "B15-B19_B942", CauseGroup = "Vírusos májgyulladás (B15-B19, B94.2)"),
      data.table(rbind(data.table(Cause = ICDData[(Kod1=="A"&(Kod23<=9|Kod23>=20))|
                                                    (Kod1=="B"&(Kod23<=9|
                                                                  (Kod23>=25&Kod23<=89)|
                                                                  (Kod23>=91&Kod23<=93)|
                                                                  (Kod23>=95&Kod23<=99)|
                                                                  (KOD10%in%c("B940", "B941", "B948",
                                                                              "B949", "B9481"))))]$KOD10,
                                  List = "104")),
                 EurostatCode = "A_B_OTH",
                 CauseGroup = paste0("Egyéb fertőző és parazitás betegségek (A00-A09, A20-B09, B25-B89, ",
                                     "B91-B94.1, B94.8-B99)")),
      ###### C, D ######
      data.table(rbind(data.table(Cause = ICDData[Kod1=="C"|(Kod1=="D"&Kod23<=48)]$KOD10, List = "104"),
                       data.table(Cause = paste0("A", sprintf("%03d", 45:61)), List = "08A"),
                       data.table(Cause = c("B019", "B020"), List = "08B"),
                       data.table(Cause = c("B08", "B09", "B10", "B11", "B12", "B13", "B14", "B15", "B16", "B17"),
                                  List = "09A"),
                       data.table(Cause = c("B08", "B09", "B10", "B11", "B12", "B13", "B14", "B15", "B16", "B17"),
                                  List = "09B"),
                       data.table(Cause = "C021", List = "09C"),
                       data.table(Cause = "CH02", List = "09N")),
                 EurostatCode = "C00-D48", CauseGroup = "Daganatok (C00-D48)"),
      data.table(rbind(data.table(Cause = ICDData[Kod1=="C"]$KOD10, List = "104"),
                       data.table(Cause = paste0("A", sprintf("%03d", 45:60)), List = "08A"),
                       data.table(Cause = "B019", List = "08B"),
                       data.table(Cause = c("B08", "B09", "B10", "B11", "B12", "B13", "B14"), List = "09A"),
                       data.table(Cause = c("B08", "B09", "B10", "B11", "B12", "B13", "B14"), List = "09B"),
                       data.table(Cause = "S08", List = "09N")),
                 EurostatCode = "C", CauseGroup = "Rosszindulatú daganatok (C00-C97)"),
      data.table(rbind(data.table(Cause = ICDData[Kod1=="C"&(Kod23>=0&Kod23<=14)]$KOD10, List = "104"),
                       data.table(Cause = "A045", List = "08A"),
                       data.table(Cause = "B08", List = "09A"),
                       data.table(Cause = "B08", List = "09B"),
                       data.table(Cause = "B08", List = "09N")),
                 EurostatCode = "C00-C14",
                 CauseGroup = "Az ajak, a szájüreg és garat rosszindulatú daganatai (C00-C14)"),
      data.table(rbind(data.table(Cause = ICDData[Kod1=="C"&Kod23==15]$KOD10, List = "104"),
                       data.table(Cause = "A046", List = "08A"),
                       data.table(Cause = "B090", List = "09A"),
                       data.table(Cause = "B090", List = "09B"),
                       data.table(Cause = "B090", List = "09N")),
                 EurostatCode = "C15", CauseGroup = "A nyelőcső rosszindulatú daganata (C15)"),
      data.table(rbind(data.table(Cause = ICDData[Kod1=="C"&Kod23==16]$KOD10, List = "104"),
                       data.table(Cause = "A047", List = "08A"),
                       data.table(Cause = "B091", List = "09A"),
                       data.table(Cause = "B091", List = "09B"),
                       data.table(Cause = "B091", List = "09N")),
                 EurostatCode = "C16", CauseGroup = "A gyomor rosszindulatú daganata (C16)"),
      data.table(rbind(data.table(Cause = ICDData[Kod1=="C"&Kod23>=18&Kod23<=21]$KOD10, List = "104"),
                       data.table(Cause = c("153", "A049"), List = "08A"),
                       data.table(Cause = c("B093", "B094"), List = "09A"),
                       data.table(Cause = c("B093", "B094"), List = "09B"),
                       data.table(Cause = c("B093", "B094"), List = "09N")),
                 EurostatCode = "C18-C21",
                 CauseGroup = "A vastagbél, végbél és a végbélnyílás rosszindulatú daganatai (C18-C21)"),
      data.table(rbind(data.table(Cause = ICDData[Kod1=="C"&Kod23==22]$KOD10, List = "104"),
                       data.table(Cause = c("155", "1978"), List = "08A"),
                       data.table(Cause = c("B095", "1551", "1552"), List = "09A"),
                       data.table(Cause = c("B095", "1551", "1552"), List = "09B")),
                 EurostatCode = "C22",
                 CauseGroup = "A máj és intrahepaticus epeutak rosszindulatú daganata (C22)"),
      data.table(rbind(data.table(Cause = ICDData[Kod1=="C"&Kod23==25]$KOD10, List = "104"),
                       data.table(Cause = "157", List = "08A"),
                       data.table(Cause = "B096", List = "09A"),
                       data.table(Cause = "B096", List = "09B")),
                 EurostatCode = "C25", CauseGroup = "A hasnyálmirigy rosszindulatú daganata (C25)"),
      data.table(rbind(data.table(Cause = ICDData[Kod1=="C"&Kod23==32]$KOD10, List = "104"),
                       data.table(Cause = "A050", List = "08A"),
                       data.table(Cause = "B100", List = "09A"),
                       data.table(Cause = "B100", List = "09B"),
                       data.table(Cause = "B100", List = "09N")),
                 EurostatCode = "C32", CauseGroup = "A gége rosszindulatú daganata (C32)"),
      data.table(rbind(data.table(Cause = ICDData[Kod1=="C"&Kod23>=33&Kod23<=34]$KOD10, List = "104"),
                       data.table(Cause = "A051", List = "08A"),
                       data.table(Cause = "B101", List = "09A"),
                       data.table(Cause = "B101", List = "09B"),
                       data.table(Cause = "B101", List = "09N")),
                 EurostatCode = "C33_C34",
                 CauseGroup = "A légcső, a hörgő és a tüdő rosszindulatú daganatai (C33-C34)"),
      data.table(rbind(data.table(Cause = ICDData[Kod1=="C"&Kod23==43]$KOD10, List = "104"),
                       data.table(Cause = "172", List = "08A"),
                       data.table(Cause = "B111", List = "09A"),
                       data.table(Cause = "B111", List = "09B")),
                 EurostatCode = "C43", CauseGroup = "A bőr rosszindulatú melanomája (C43)"),
      data.table(rbind(data.table(Cause = ICDData[Kod1=="C"&Kod23==50]$KOD10, List = "104"),
                       data.table(Cause = "A054", List = "08A"),
                       data.table(Cause = c("B113", "175"), List = "09A"),
                       data.table(Cause = c("B113", "175"), List = "09B")),
                 EurostatCode = "C50", CauseGroup = "Az emlő rosszindulatú daganata (C50)"),
      data.table(rbind(data.table(Cause = ICDData[Kod1=="C"&Kod23==53]$KOD10, List = "104"),
                       data.table(Cause = "A055", List = "08A"),
                       data.table(Cause = "B120", List = "09A"),
                       data.table(Cause = "B120", List = "09B"),
                       data.table(Cause = "B120", List = "09N")),
                 EurostatCode = "C53", CauseGroup = "A méhnyak rosszindulatú daganata (C53)"),
      data.table(rbind(data.table(Cause = ICDData[Kod1=="C"&Kod23>=54&Kod23<=55]$KOD10, List = "104"),
                       data.table(Cause = "182", List = "08A"),
                       data.table(Cause = "B122", List = "09A"),
                       data.table(Cause = "B122", List = "09B"),
                       data.table(Cause = "B122", List = "09N")),
                 EurostatCode = "C54_C55",
                 CauseGroup = paste0("A méhtest és a méh nem meghatározott részének rosszindulatú ",
                                     "daganatai (C54-55)")),
      data.table(rbind(data.table(Cause = ICDData[Kod1=="C"&Kod23==56]$KOD10, List = "104"),
                       data.table(Cause = "1830", List = "09A"),
                       data.table(Cause = "1830", List = "09B")),
                 EurostatCode = "C56", CauseGroup = "A petefészek rosszindulatú daganata (C56)"),
      data.table(rbind(data.table(Cause = ICDData[Kod1=="C"&Kod23==61]$KOD10, List = "104"),
                       data.table(Cause = "A057", List = "08A"),
                       data.table(Cause = "B124", List = "09A"),
                       data.table(Cause = "B124", List = "09B"),
                       data.table(Cause = "B124", List = "09N")),
                 EurostatCode = "C61", CauseGroup = "A prostata rosszindulatú daganata (C61)"),
      data.table(rbind(data.table(Cause = ICDData[Kod1=="C"&Kod23==64]$KOD10, List = "104"),
                       data.table(Cause = "1890", List = "08A"),
                       data.table(Cause = "1890", List = "09A"),
                       data.table(Cause = "1890", List = "09B")),
                 EurostatCode = "C64",
                 CauseGroup = "A vese rosszindulatú daganata, kivéve a vesemedencét (C64)"),
      data.table(rbind(data.table(Cause = ICDData[Kod1=="C"&Kod23==67]$KOD10, List = "104"),
                       data.table(Cause = "188", List = "08A"),
                       data.table(Cause = "B126", List = "09A"),
                       data.table(Cause = "B126", List = "09B")),
                 EurostatCode = "C67", CauseGroup = "A húgyhólyag rosszindulatú daganata (C67)"),
      data.table(rbind(data.table(Cause = ICDData[Kod1=="C"&Kod23>=70&Kod23<=72]$KOD10, List = "104"),
                       data.table(Cause = c("191", "192"), List = "08A"),
                       data.table(Cause = c("B130", "192"), List = "09A"),
                       data.table(Cause = c("B130", "192"), List = "09B")),
                 EurostatCode = "C70-C72",
                 CauseGroup = paste0("Az agyburkok, az agy, a gerincvelő, az agyidegek és a központi ",
                                     "idegrendszer egyéb részeinek rosszindulatú daganatai (C70-C72)")),
      data.table(rbind(data.table(Cause = ICDData[Kod1=="C"&Kod23==73]$KOD10, List = "104"),
                       data.table(Cause = "193", List = "08A"),
                       data.table(Cause = "193", List = "09A"),
                       data.table(Cause = "193", List = "09B")),
                 EurostatCode = "C73", CauseGroup = "A pajzsmirigy rosszindulatú daganata (C73)"),
      data.table(rbind(data.table(Cause = ICDData[Kod1=="C"&Kod23>=81&Kod23<=86]$KOD10, List = "104"),
                       data.table(Cause = c("200", "201"), List = "08A"),
                       data.table(Cause = c("200", "B140"), List = "09A"),
                       data.table(Cause = c("200", "B140"), List = "09B")),
                 EurostatCode = "C81-C86", CauseGroup = "Hodgkin kór és lymphomák (C81-C86)"),
      data.table(rbind(data.table(Cause = ICDData[Kod1=="C"&Kod23>=91&Kod23<=95]$KOD10, List = "104"),
                       data.table(Cause = c("A059", "208"), List = "08A"),
                       data.table(Cause = "B141", List = "09A"),
                       data.table(Cause = "B141", List = "09B"),
                       data.table(Cause = "B141", List = "09N"),
                       data.table(Cause = "C032", List = "09C")),
                 EurostatCode = "C91-C95", CauseGroup = "Leukémia (C91-C95)"),
      data.table(rbind(data.table(Cause = ICDData[Kod1=="C"&(Kod23==88|Kod23==90|Kod23==96)]$KOD10, List = "104"),
                       data.table(Cause = c("202", "203"), List = "08A"),
                       data.table(Cause = c("202", "203"), List = "09A"),
                       data.table(Cause = c("202", "203"), List = "09B")),
                 EurostatCode = "C88_C90_C96",
                 CauseGroup = paste0("A nyirok-, a vérképző- és kapcsolódó szövetek egyéb rosszindulatú ",
                                     "daganatai (C88, C90, C96)")),
      data.table(rbind(data.table(Cause = ICDData[Kod1=="C"&
                                                    (Kod23==17|(Kod23>=23&Kod23<=24)|(Kod23>=26&Kod23<=31)|
                                                       (Kod23>=37&Kod23<=41)|(Kod23>=44&Kod23<=49)|
                                                       (Kod23>=51&Kod23<=52)|(Kod23>=57&Kod23<=60)|
                                                       (Kod23>=62&Kod23<=63)|(Kod23>=65&Kod23<=66)|
                                                       (Kod23>=68&Kod23<=69)|(Kod23>=74&Kod23<=80)|Kod23==97)]$KOD10,
                                  List = "104")),
                 EurostatCode = "C_OTH",
                 CauseGroup = paste0("Egyéb rosszindulatú daganatok (C17, C23-C24, C26-C31, C37-C41, ",
                                     "C44-C49, C51-C52, C57-C60, C62-C63, C65-C66, C68-C69, C74-C80, ",
                                     "C97)")),
      data.table(rbind(data.table(Cause = ICDData[Kod1=="D"&Kod23>=0&Kod23<=48]$KOD10, List = "104"),
                       data.table(Cause = "A061", List = "08A"),
                       data.table(Cause = "B020", List = "08B"),
                       data.table(Cause = c("B15", "B16", "B17"), List = "09A"),
                       data.table(Cause = c("B15", "B16", "B17"), List = "09B")),
                 EurostatCode = "D00-D48",
                 CauseGroup = paste0("In situ, jóindulatú, vagy bizonytalan vagy ismeretlen viselkedésű ",
                                     "daganatok (D00-D48)")),
      data.table(rbind(data.table(Cause = ICDData[Kod1=="D"&Kod23>=50&Kod23<=89]$KOD10, List = "104"),
                       data.table(Cause = c("A067", "A068"), List = "08A"),
                       data.table(Cause = "B20", List = "09A"),
                       data.table(Cause = "B20", List = "09B"),
                       data.table(Cause = "B20", List = "09N"),
                       data.table(Cause = "C036", List = "09C")),
                 EurostatCode = "D50-D89",
                 CauseGroup = paste0("A vér és a vérképző szervek betegségei és az immunrendszert érintő ",
                                     "egyéb rendellenességek (D50-D89)")),
      ##### E #####
      data.table(rbind(data.table(Cause = ICDData[Kod1=="E"&Kod23>=0&Kod23<=89]$KOD10, List = "104"),
                       data.table(Cause = c("A062", "A063", "A064", "A065", "A066"), List = "08A"),
                       data.table(Cause = c("B18", "B19"), List = "09A"),
                       data.table(Cause = c("B18", "B19"), List = "09B"),
                       data.table(Cause = "CH03", List = "09N"),
                       data.table(Cause = "C034", List = "09C")),
                 EurostatCode = "E",
                 CauseGroup = "Endokrin, táplálkozási és anyagcsere betegségek (E00-E89)"),
      data.table(rbind(data.table(Cause = ICDData[Kod1=="E"&Kod23>=10&Kod23<=14]$KOD10, List = "104"),
                       data.table(Cause = "A064", List = "08A"),
                       data.table(Cause = "B021", List = "08B"),
                       data.table(Cause = "B181", List = "09A"),
                       data.table(Cause = "B181", List = "09B"),
                       data.table(Cause = "B181", List = "09N"),
                       data.table(Cause = "C035", List = "09C")),
                 EurostatCode = "E10-E14", CauseGroup = "Cukorbetegség (E10-E14)"),
      data.table(rbind(data.table(Cause = ICDData[Kod1=="E"&((Kod23>=0&Kod23<=7)|(Kod23>=15&Kod23<=89))]$KOD10,
                                  List = "104")),
                 EurostatCode = "E_OTH",
                 CauseGroup = "Egyéb endokrin, táplálkozási és anyagcsere betegségek (E00-E07, E15-E89)"),
      ##### F #####
      data.table(rbind(data.table(Cause = ICDData[Kod1=="F"&Kod23>=1&Kod23<=99]$KOD10, List = "104"),
                       data.table(Cause = c("A069", "A070", "A071"), List = "08A"),
                       data.table(Cause = "B21", List = "09A"),
                       data.table(Cause = "B21", List = "09B"),
                       data.table(Cause = "B21", List = "09N"),
                       data.table(Cause = "C038", List = "09C")),
                 EurostatCode = "F", CauseGroup = "Mentális- és viselkedészavarok (F01-F99)"),
      data.table(rbind(data.table(Cause = ICDData[Kod1=="F"&(Kod23==1|Kod23==3)]$KOD10, List = "104"),
                       data.table(Cause = "B210", List = "09A"),
                       data.table(Cause = "B210", List = "09B")),
                 EurostatCode = "F01_F03", CauseGroup = "Dementia (F01, F03)"),
      data.table(rbind(data.table(Cause = ICDData[Kod1=="F"&Kod23==10]$KOD10, List = "104")),
                 EurostatCode = "F10", CauseGroup = "Alkohol okozta mentális- és viselkedészavarok (F10)"),
      data.table(rbind(data.table(Cause = ICDData[Kod1=="F"&((Kod23>=11&Kod23<=16)|(Kod23>=18&Kod23<=19))]$KOD10,
                                  List = "104")),
                 EurostatCode = "TOXICO",
                 CauseGroup = paste0("Drog és pszichoaktív anyagok használata által okozott mentális- és ",
                                     "viselkedészavarok (F11-F16, F18-F19)")),
      data.table(rbind(data.table(Cause = ICDData[Kod1=="F"&((Kod23>=4&Kod23<=9)|(Kod23==17)|
                                                               (Kod23>=20&Kod23<=99))]$KOD10, List = "104")),
                 EurostatCode = "F_OTH",
                 CauseGroup = "Egyéb mentális- és viselkedészavarok (F04-F09, F17, F20-F99)"),
      ##### G, H #####
      data.table(rbind(data.table(Cause = ICDData[Kod1=="G"|Kod1=="H"]$KOD10, List = "104"),
                       data.table(Cause = c("A072", "A073", "A074", "A075", "A076", "A077", "A078", "A079"), List = "08A"),
                       data.table(Cause = c("B22", "B23", "B24"), List = "09A"),
                       data.table(Cause = c("B22", "B23", "B24"), List = "09B"),
                       data.table(Cause = "CH06", List = "09N")),
                 EurostatCode = "G_H",
                 CauseGroup = "Az idegrendszer és az érzékszervek betegségei (G00-H95)"),
      data.table(rbind(data.table(Cause = ICDData[Kod1=="G"&Kod23==20]$KOD10, List = "104")),
                 EurostatCode = "G20", CauseGroup = "Parkinson-kór (G20)"),
      data.table(rbind(data.table(Cause = ICDData[Kod1=="G"&Kod23==30]$KOD10, List = "104")),
                 EurostatCode = "G30", CauseGroup = "Alzheimer-kór (G30)"),
      data.table(rbind(data.table(Cause = ICDData[(Kod1=="G"&((Kod23>=0&Kod23<=12)|(Kod23==14)|(Kod23>=21&Kod23<=25)|
                                                                (Kod23>=31)))|Kod1=="H"]$KOD10, List = "104")),
                 EurostatCode = "G_H_OTH",
                 CauseGroup = paste0("Az idegrendszer és az érzékszervek egyéb betegségei (G00-G12, G14, ",
                                     "G21-G25, G31-H95)")),
      ##### I #####
      data.table(rbind(data.table(Cause = ICDData[Kod1=="I"]$KOD10, List = "104"),
                       data.table(Cause = c("A080", "A081", "A082", "A083", "A084", "A085", "A086", "A087", "A088"), List = "08A"),
                       data.table(Cause = c("B25", "B26", "B27", "B28", "B29", "B30"), List = "09A"),
                       data.table(Cause = c("B25", "B26", "B27", "B28", "B29", "B30"), List = "09B"),
                       data.table(Cause = c("B25", "B26", "B27", "B28", "B29", "B30"), List = "09N"),
                       data.table(Cause = "C041", List = "09C")),
                 EurostatCode = "I", CauseGroup = "A keringési rendszer betegségei (I00-I99)"),
      data.table(rbind(data.table(Cause = ICDData[Kod1=="I"&Kod23>=20&Kod23<=25]$KOD10, List = "104"),
                       data.table(Cause = "A083", List = "08A"),
                       data.table(Cause = "B028", List = "08B"),
                       data.table(Cause = "B27", List = "09A"),
                       data.table(Cause = "B27", List = "09B"),
                       data.table(Cause = "B27", List = "09N"),
                       data.table(Cause = c("C046", "C047"), List = "09N")),
                 EurostatCode = "I20-I25", CauseGroup = "Ischaemiás szívbetegségek (I20-I25)"),
      data.table(rbind(data.table(Cause = ICDData[Kod1=="I"&Kod23>=21&Kod23<=22]$KOD10, List = "104")),
                 EurostatCode = "I21_I22",
                 CauseGroup = "Heveny szívizomelhalás és ismétlődő szívizomelhalás (I21-I22)"),
      data.table(rbind(data.table(Cause = ICDData[Kod1=="I"&((Kod23==20)|(Kod23>=23&Kod23<=25))]$KOD10, List = "104")),
                 EurostatCode = "I20_I23-I25",
                 CauseGroup = "Egyéb ischaemiás szívbetegségek (I20, I23-I25)"),
      data.table(rbind(data.table(Cause = ICDData[Kod1=="I"&Kod23>=30&Kod23<=51]$KOD10, List = "104"),
                       data.table(Cause = "A084", List = "08A"),
                       data.table(Cause = "B029", List = "08B"),
                       data.table(Cause = c("420+", "B281"), List = "09A"),
                       data.table(Cause = c("420+", "B281"), List = "09B"),
                       data.table(Cause = "C049", List = "09C")),
                 EurostatCode = "I30-I51", CauseGroup = "A szívbetegség egyéb formái (I30-I51)"),
      data.table(rbind(data.table(Cause = ICDData[Kod1=="I"&Kod23>=60&Kod23<=69]$KOD10, List = "104"),
                       data.table(Cause = "A085", List = "08A"),
                       data.table(Cause = "B030", List = "08B"),
                       data.table(Cause = "B29", List = "09A"),
                       data.table(Cause = "B29", List = "09B"),
                       data.table(Cause = "B29", List = "09N"),
                       data.table(Cause = "C051", List = "09C")),
                 EurostatCode = "I60-I69", CauseGroup = "Cerebrovaszkuláris betegségek (I60-I69)"),
      data.table(rbind(data.table(Cause = ICDData[Kod1=="I"&((Kod23>=0&Kod23<=15)|(Kod23>=26&Kod23<=28)|
                                                               (Kod23>=70&Kod23<=99))]$KOD10, List = "104"),
                       data.table(Cause = c("A080", "A081", "A082", "A086", "A087", "A088"), List = "08A")),
                 EurostatCode = "I_OTH",
                 CauseGroup = "A keringési rendszer egyéb betegségei (I00-I15, I26-I28, I70-I99)"),
      ##### J #####
      data.table(rbind(data.table(Cause = ICDData[Kod1=="J"&Kod23>=0&Kod23<=99]$KOD10, List = "104"),
                       data.table(Cause = c("A089", "A090", "A091", "A092", "A093", "A094", "A095", "A096"), List = "08A"),
                       data.table(Cause = c("B31", "B32"), List = "09A"),
                       data.table(Cause = c("B31", "B32"), List = "09B"),
                       data.table(Cause = "CH08", List = "09N"),
                       data.table(Cause = "C052", List = "09C")),
                 EurostatCode = "J", CauseGroup = "A légzőrendszer betegségei (J00-J99)"),
      data.table(rbind(data.table(Cause = ICDData[Kod1=="J"&Kod23>=9&Kod23<=11]$KOD10, List = "104"),
                       data.table(Cause = "A090", List = "08A"),
                       data.table(Cause = "B031", List = "08B"),
                       data.table(Cause = "B322", List = "09A"),
                       data.table(Cause = "B322", List = "09B"),
                       data.table(Cause = "B322", List = "09N")),
                 EurostatCode = "J09-J11", CauseGroup = "Influenza (J09-J11)"),
      data.table(rbind(data.table(Cause = ICDData[Kod1=="J"&Kod23>=12&Kod23<=18]$KOD10, List = "104"),
                       data.table(Cause = c("A091", "A092"), List = "08A"),
                       data.table(Cause = "B032", List = "08B"),
                       data.table(Cause = "B321", List = "09A"),
                       data.table(Cause = "B321", List = "09B"),
                       data.table(Cause = "B321", List = "09N"),
                       data.table(Cause = "C053", List = "09C")),
                 EurostatCode = "J12-J18", CauseGroup = "Tüdőgyulladás (J12-J18)"),
      data.table(rbind(data.table(Cause = ICDData[Kod1=="J"&Kod23>=40&Kod23<=47]$KOD10, List = "104")),
                 EurostatCode = "J40-J47", CauseGroup = "Idült alsó légúti betegségek (J40-J47)"),
      data.table(rbind(data.table(Cause = ICDData[Kod1=="J"&Kod23>=45&Kod23<=46]$KOD10, List = "104")),
                 EurostatCode = "J45_J46", CauseGroup = "Asztma (J45-J46)"),
      data.table(rbind(data.table(Cause = ICDData[Kod1=="J"&((Kod23>=40&Kod23<=44)|(Kod23==47))]$KOD10, List = "104")),
                 EurostatCode = "J40-J44_J47",
                 CauseGroup = "Egyéb idült alsó légúti megbetegedések (J40-J44, J47)"),
      data.table(rbind(data.table(Cause = ICDData[Kod1=="J"&((Kod23>=0&Kod23<=6)|(Kod23>=20&Kod23<=39)|
                                                               (Kod23>=60&Kod23<=99))]$KOD10, List = "104")),
                 EurostatCode = "J_OTH",
                 CauseGroup = "A légzőrendszer egyéb betegségei (J00-J06, J20-J39, J60-J99)"),
      ##### K #####
      data.table(rbind(data.table(Cause = ICDData[Kod1=="K"&Kod23>=0&Kod23<=92]$KOD10, List = "104"),
                       data.table(Cause = c("A097", "A098", "A099", "A100", "A101", "A102", "A103", "A104"), List = "08A"),
                       data.table(Cause = c("B33", "B34"), List = "09A"),
                       data.table(Cause = c("B33", "B34"), List = "09B"),
                       data.table(Cause = "CH09", List = "09N"),
                       data.table(Cause = "C056", List = "09C")),
                 EurostatCode = "K", CauseGroup = "Az emésztőrendszer betegségei (K00-K92)"),
      data.table(rbind(data.table(Cause = ICDData[Kod1=="K"&Kod23>=25&Kod23<=28]$KOD10, List = "104")),
                 EurostatCode = "K25-K28",
                 CauseGroup = "Gyomor-, nyombél-, pepticus- és gastrojejunalis fekély (K25-K28)"),
      data.table(rbind(data.table(Cause = ICDData[Kod1=="K"&((Kod23==70)|(Kod23>=73&Kod23<=74))]$KOD10, List = "104"),
                       data.table(Cause = "A102", List = "08A"),
                       data.table(Cause = "B037", List = "08B"),
                       data.table(Cause = "B347", List = "09A"),
                       data.table(Cause = "B347", List = "09B"),
                       data.table(Cause = "C060", List = "09N")),
                 EurostatCode = "K70_K73_K74",
                 CauseGroup = paste0("Idült májgyulladás, májfibrózis és májzsugorodás, valamint ",
                                     "alkoholos májbetegség (K70, K73-K74)")),
      data.table(rbind(data.table(Cause = ICDData[Kod1=="K"&(Kod23>=72&Kod23<=75)]$KOD10, List = "104")),
                 EurostatCode = "K72-K75",
                 CauseGroup = paste0("Idült májbetegség, kivéve az alkoholos és toxikus ",
                                     "májbetegséget (K72-K75)")),
      data.table(rbind(data.table(Cause = ICDData[Kod1=="K"&((Kod23>=0&Kod23<=22)|(Kod23>=29&Kod23<=66)|
                                                               (Kod23>=71&Kod23<=72)|(Kod23>=75&Kod23<=92))]$KOD10,
                                  List = "104")),
                 EurostatCode = "K_OTH",
                 CauseGroup = "Az emésztőrendszer egyéb betegségei (K00-K22, K29-K66, K71-K72, K75-K92)"),
      ##### L #####
      data.table(rbind(data.table(Cause = ICDData[Kod1=="L"]$KOD10, List = "104"),
                       data.table(Cause = c("A119", "A120"), List = "08A"),
                       data.table(Cause = "B42", List = "09A"),
                       data.table(Cause = "B42", List = "09B"),
                       data.table(Cause = "B42", List = "09N")),
                 EurostatCode = "L", CauseGroup = "A bőr és a bőralatti szövet betegségei (L00-L99)"),
      ##### M #####
      data.table(rbind(data.table(Cause = ICDData[Kod1=="M"]$KOD10, List = "104"),
                       data.table(Cause = c("A121", "A122", "A123", "A124", "A125"), List = "08A"),
                       data.table(Cause = "B43", List = "09A"),
                       data.table(Cause = "B43", List = "09B"),
                       data.table(Cause = "B43", List = "09N"),
                       data.table(Cause = "C071", List = "09C")),
                 EurostatCode = "M",
                 CauseGroup = "A csont-izomrendszer és kötőszövet betegségei (M00-M99)"),
      data.table(rbind(data.table(Cause = ICDData[Kod1=="M"&((Kod23>=05&Kod23<=06)|(Kod23>=15&Kod23<=19))]$KOD10,
                                  List = "104")),
                 EurostatCode = "RHEUM_ARTHRO",
                 CauseGroup = "Rheumatoid arthritis és arthrosis (M05-M06, M15-M19)"),
      data.table(rbind(data.table(Cause = ICDData[Kod1=="M"&((Kod23>=0&Kod23<=2)|(Kod23>=8&Kod23<=13)|
                                                               (Kod23>=20&Kod23<=99))]$KOD10, List = "104")),
                 EurostatCode = "M_OTH",
                 CauseGroup = paste0("A csont-izomrendszer és kötőszövet egyéb betegségei (M00-M02, ",
                                     "M08-M13, M20-M99)")),
      ##### N #####
      data.table(rbind(data.table(Cause = ICDData[Kod1=="N"]$KOD10, List = "104"),
                       data.table(Cause = c("A105", "A106", "A107", "A108", "A109", "A110", "A111"), List = "08A"),
                       data.table(Cause = c("B35", "B36", "B37"), List = "09A"),
                       data.table(Cause = c("B35", "B36", "B37"), List = "09B"),
                       data.table(Cause = "CH10", List = "09N"),
                       data.table(Cause = "C061", List = "09C")),
                 EurostatCode = "N", CauseGroup = "Az urogenitális rendszer megbetegedései (N00-N99)"),
      data.table(rbind(data.table(Cause = ICDData[Kod1=="N"&Kod23>=0&Kod23<=29]$KOD10, List = "104")),
                 EurostatCode = "N00-N29", CauseGroup = "Vese és az ureter betegségei (N00-N29)"),
      data.table(rbind(data.table(Cause = ICDData[Kod1=="N"&Kod23>=30&Kod23<=99]$KOD10, List = "104")),
                 EurostatCode = "N_OTH",
                 CauseGroup = "Az urogenitális rendszer egyéb betegségei (N30-N99)"),
      ##### O #####
      data.table(rbind(data.table(Cause = ICDData[Kod1=="O"]$KOD10, List = "104"),
                       data.table(Cause = c("A112", "A113", "A114", "A115", "A116", "A117"), List = "08A"),
                       data.table(Cause = c("B040", "B041"), List = "08B"),
                       data.table(Cause = c("B38", "B39", "B40", "B41"), List = "09A"),
                       data.table(Cause = c("B38", "B39", "B40", "B41"), List = "09B"),
                       data.table(Cause = "CH11", List = "09N"),
                       data.table(Cause = "C064", List = "09C")),
                 EurostatCode = "O",
                 CauseGroup = "A terhesség, a szülés és a gyermekágy komplikációi (O00-O99)"),
      ##### P #####
      data.table(rbind(data.table(Cause = ICDData[Kod1=="P"&Kod23>=0&Kod23<=96]$KOD10, List = "104"),
                       data.table(Cause = c("A131", "A132", "A133", "A134", "A135"), List = "08A"),
                       data.table(Cause = c("B043", "B044"), List = "08B"),
                       data.table(Cause = "B45", List = "09A"),
                       data.table(Cause = "B45", List = "09B"),
                       data.table(Cause = "B45", List = "09N"),
                       data.table(Cause = "C074", List = "09C")),
                 EurostatCode = "P",
                 CauseGroup = "A perinatális szakban keletkező bizonyos állapotok (P00-P96)"),
      ##### Q #####
      data.table(rbind(data.table(Cause = ICDData[Kod1=="Q"&Kod23>=0&Kod23<=99]$KOD10, List = "104"),
                       data.table(Cause = c("A126", "A127", "A128", "A129", "A130"), List = "08A"),
                       data.table(Cause = "B042", List = "08B"),
                       data.table(Cause = "B44", List = "09A"),
                       data.table(Cause = "B44", List = "09B"),
                       data.table(Cause = "B44", List = "09N"),
                       data.table(Cause = "C072", List = "09C")),
                 EurostatCode = "Q",
                 CauseGroup = paste0("Veleszületett rendellenességek, deformitások és ",
                                     "kromoszómaabnormitások (Q00-Q99)")),
      ##### R #####
      data.table(rbind(data.table(Cause = ICDData[Kod1=="R"]$KOD10, List = "104"),
                       data.table(Cause = c("A136", "A137"), List = "08A"),
                       data.table(Cause = "B045", List = "08B"),
                       data.table(Cause = "B46", List = "09A"),
                       data.table(Cause = "B46", List = "09B"),
                       data.table(Cause = "B46", List = "09N")),
                 EurostatCode = "R",
                 CauseGroup = paste0("Máshova nem osztályozott panaszok, tünetek és kóros klinikai és ",
                                     "laboratóriumi leletek (R00-R99)")),
      data.table(rbind(data.table(Cause = ICDData[Kod1=="R"&Kod23==95]$KOD10, List = "104"),
                       data.table(Cause = "B466", List = "09A"),
                       data.table(Cause = "B466", List = "09B")),
                 EurostatCode = "R95", CauseGroup = "Hirtelen csecsemőhalál szindróma  (R95)"),
      data.table(rbind(data.table(Cause = ICDData[Kod1=="R"&Kod23>=96&Kod23<=99]$KOD10, List = "104")),
                 EurostatCode = "R96-R99",
                 CauseGroup = paste0("Egyéb hirtelen halál ismeretlen okból, halál tanú nélkül, a ",
                                     "halálozás rosszul meghatározott és külön megnevezés nélküli okai ",
                                     "(R96-R99)")),
      data.table(rbind(data.table(Cause = ICDData[Kod1=="R"&Kod23>=0&Kod23<=94]$KOD10, List = "104")),
                 EurostatCode = "R_OTH",
                 CauseGroup = paste0("Egyéb máshova nem osztályozott panaszok, tünetek és kóros klinikai ",
                                     "és laboratóriumi leletek (R00-R94)")),
      ##### U #####
      data.table(rbind(data.table(Cause = ICDData[Kod1=="U"]$KOD10, List = "104")), EurostatCode = "U",
                 CauseGroup = "Speciális kódok, beleértve a COVID-19-et (U)"),
      data.table(rbind(data.table(Cause = ICDData[KOD10 == "U0710"]$KOD10, List = "104")), EurostatCode = "U071",
                 CauseGroup = "COVID-19, kimutatott vírussal (U071)"),
      data.table(rbind(data.table(Cause = ICDData[KOD10 == "U0720"]$KOD10, List = "104")), EurostatCode = "U072",
                 CauseGroup = "COVID-19, vírus kimutatása nélkül (U072)"),
      data.table(rbind(data.table(Cause = ICDData[KOD10 %in% c("U0990", "U1090")]$KOD10, List = "104")),
                 EurostatCode = "U_COV19_OTH", CauseGroup = "COVID-19, egyéb (U099, U109)"),
      ##### V, W, X, Y #####
      data.table(rbind(data.table(Cause = ICDData[(Kod1=="V")|(Kod1=="W")|(Kod1=="X")|(Kod1=="Y"&Kod23>=0&Kod23<=89)]$KOD10,
                                  List = "104"),
                       data.table(Cause = c(paste0("A", sprintf("%03d", 138:150)), "CH17"), List = "08A"),
                       data.table(Cause = c("B047", "B048", "B049", "B050"), List = "08B"),
                       data.table(Cause = c("B47", "B48", "B49", "B50", "B51", "B52", "B53", "B54", "B55", "B56", "CH17"), List = "09A"),
                       data.table(Cause = c("B47", "B48", "B49", "B50", "B51", "B52", "B53", "B54", "B55", "B56", "CH17"), List = "09B"),
                       data.table(Cause = "CH17", List = "09N"),
                       data.table(Cause = "C089", List = "09C")),
                 EurostatCode = "V01-Y89", CauseGroup = "A morbiditás és mortalitás külső okai (V00-Y89)"),
      data.table(rbind(data.table(Cause = ICDData[(Kod1=="V")|(Kod1=="W")|(Kod1=="X"&Kod23>=0&Kod23<=59)|
                                                    (Kod1=="Y"&Kod23>=85&Kod23<=86)]$KOD10, List = "104"),
                       data.table(Cause = c("B47", "B48", "B49", "B50", "B51", "B52", "S47"), List = "09A"),
                       data.table(Cause = c("B47", "B48", "B49", "B50", "B51", "B52"), List = "09B")),
                 EurostatCode = "ACC", CauseGroup = "Balesetek (V01-X59, Y85-Y86)"),
      data.table(rbind(data.table(Cause = ICDData[Kod1=="V"|(Kod1=="Y"&Kod23==85)]$KOD10, List = "104")),
                 EurostatCode = "V_Y85", CauseGroup = "Közlekedési balesetek (V01-V99, Y85)"),
      data.table(rbind(data.table(Cause = ICDData[Kod1=="W"&Kod23>=0&Kod23<=19]$KOD10, List = "104"),
                       data.table(Cause = "A141", List = "08A"),
                       data.table(Cause = "B50", List = "09A"),
                       data.table(Cause = "B50", List = "09B"),
                       data.table(Cause = "B50", List = "09N"),
                       data.table(Cause = "C093", List = "09C")),
                 EurostatCode = "W00-W19", CauseGroup = "Esések (W00-W19)"),
      data.table(rbind(data.table(Cause = ICDData[Kod1=="W"&Kod23>=65&Kod23<=74]$KOD10, List = "104"),
                       data.table(Cause = "A143", List = "08A"),
                       data.table(Cause = "B521", List = "09A"),
                       data.table(Cause = "B521", List = "09B"),
                       data.table(Cause = "B521", List = "09N"),
                       data.table(Cause = "C096", List = "09C")),
                 EurostatCode = "W65-W74",
                 CauseGroup = "Balesetszerű vízbefulladás vagy elmerülés (W65-W74)"),
      data.table(rbind(data.table(Cause = ICDData[Kod1=="X"&Kod23>=40&Kod23<=49]$KOD10, List = "104"),
                       data.table(Cause = "A140", List = "08A"),
                       data.table(Cause = "B48", List = "09A"),
                       data.table(Cause = "B48", List = "09B"),
                       data.table(Cause = "B48", List = "09N"),
                       data.table(Cause = "C092", List = "09C")),
                 EurostatCode = "X40-X49",
                 CauseGroup = "Káros anyagok által okozott balesetszerű mérgezés (X40-X49)"),
      data.table(rbind(data.table(Cause = ICDData[(Kod1=="W"&Kod23>=20&Kod23<=64)|(Kod1=="W"&Kod23>=75)|
                                                    (Kod1=="X"&Kod23<=39)|(Kod1=="X"&Kod23>=50&Kod23<=59)|
                                                    (Kod1=="Y"&Kod23==86)]$KOD10, List = "104")),
                 EurostatCode = "ACC_OTH",
                 CauseGroup = "Egyéb balesetek (W20-W64, W75-X39, X50-X59, Y86)"),
      data.table(rbind(data.table(Cause = ICDData[(Kod1=="X"&Kod23>=60&Kod23<=84)|(KOD10=="Y8700")]$KOD10, List = "104"),
                       data.table(Cause = "A147", List = "08A"),
                       data.table(Cause = "B049", List = "08A"),
                       data.table(Cause = "B54", List = "09A"),
                       data.table(Cause = "B54", List = "09B"),
                       data.table(Cause = "B54", List = "09N"),
                       data.table(Cause = "C102", List = "09C")),
                 EurostatCode = "X60-X84_Y870", CauseGroup = "Szándékos önártalom (X60-X84, Y87.0)"),
      data.table(rbind(data.table(Cause = ICDData[(Kod1=="X"&Kod23>=85)|(Kod1=="Y"&Kod23<=9)|(KOD10=="Y8710")]$KOD10,
                                  List = "104"),
                       data.table(Cause = "B55", List = "09A"),
                       data.table(Cause = "B55", List = "09B"),
                       data.table(Cause = "B55", List = "09N"),
                       data.table(Cause = "C103", List = "09C")),
                 EurostatCode = "X85-Y09_Y871", CauseGroup = "Testi sértés (X85-Y09, Y87.1)"),
      data.table(rbind(data.table(Cause = ICDData[(Kod1=="Y"&Kod23>=10&Kod23<=34)|(KOD10=="Y8720")]$KOD10, List = "104"),
                       data.table(Cause = "A149", List = "08A"),
                       data.table(Cause = "B560", List = "09A"),
                       data.table(Cause = "B560", List = "09B")),
                 EurostatCode = "Y10-Y34_Y872",
                 CauseGroup = "Nem meghatározott szándékú esemény (Y10-Y34, Y87.2)"),
      data.table(rbind(data.table(Cause = ICDData[(Kod1=="Y"&Kod23>=35&Kod23<=84)|
                                                    (Kod1=="Y"&Kod23>=88&Kod23<=89)]$KOD10, List = "104")),
                 EurostatCode = "V01-Y89_OTH",
                 CauseGroup = paste0("Törvényes beavatkozás és háborús cselekmények, az orvosi ellátás ",
                                     "szövődményei, egyéb külső ok (Y35-Y84, Y88-Y89)"))),
  Individual = lapply(1:nrow(ICDData), function(i)
    data.table(Cause = ICDData[i]$KOD10, EurostatCode = NA,
               CauseGroup = paste0(ICDData[i]$KOD10, " - ", ICDData[i]$NEV))),
  Avoidable = list(
    "Megelőzhető halálozás" =
      data.table(Cause = ICDData[
        (Kod1=="A"&((Kod23>=0&Kod23<=9)|(Kod23>=50&Kod23<=60)|
                      (Kod23>=15&Kod23<=19)|
                      Kod23%in%c(35, 36, 80, 37, 39, 63, 64, 33, 34)|
                      KOD10%in%c("A4030", "A4130", "A4920")))|
          (Kod1=="B"&((Kod23>=15&Kod23<=19)|(Kod23>=20&Kod23<=24)|
                        (Kod23>=50&Kod23<=54)|Kod23%in%c(1, 5, 6, 90)))|
          (Kod1=="C"&((Kod23>=0&Kod23<=14)|(Kod23>=33&Kod23<=34)|
                        Kod23%in%c(15, 16, 22, 45, 43, 67, 53)))|
          (Kod1=="D"&((Kod23>=50&Kod23<=53)))|
          (Kod1=="E"&((Kod23>=10&Kod23<=14)|KOD10=="E2440"))|
          (Kod1=="F"&(Kod23==10|(Kod23>=11&Kod23<=16)|(Kod23>=18&Kod23<=19)))|
          (Kod1=="G"&(KOD10%in%c("G0000", "G0010", "G3120", "G6210", "G7210")))|
          (Kod1=="I"&((Kod23>=10&Kod23<=13)|(Kod23>=20&Kod23<=25)|
                        (Kod23>=60&Kod23<=69)|
                        Kod23%in%c(71, 15, 70)|KOD10%in%c("I7390", "I4260")))|
          (Kod1=="J"&((Kod23>=9&Kod23<=11)|(Kod23>=13&Kod23<=14)|
                        (Kod23>=40&Kod23<=44)|(Kod23>=60&Kod23<=64)|
                        (Kod23>=66&Kod23<=70)|Kod23%in%c(65, 82, 92)))|
          (Kod1=="K"&(Kod23%in%c(70, 73)|
                        KOD10%in%c("K2920", "K8520", "K8600", "K7400",
                                   "K7410", "K7420", "K7460")))|
          (Kod1=="Q"&(Kod23%in%c(0, 1, 5)|KOD10=="Q8600"))|
          (Kod1=="R"&(KOD10=="R7800"))|
          (Kod1=="U"&(KOD10%in%c("U0710", "U0720")))|
          (Kod1=="V"&((Kod23>=0&Kod23<=99)))|
          (Kod1=="W")|
          (Kod1=="X"&((Kod23<=39)|(Kod23>=46&Kod23<=59)|(Kod23>=66&Kod23<=84)|
                        (Kod23>=40&Kod23<=44)|(Kod23>=60&Kod23<=64)|(Kod23>=86)|
                        Kod23%in%c(45, 65, 85)))|
          (Kod1=="Y"&((Kod23<=9)|(Kod23>=16&Kod23<=34)|
                        (Kod23>=10&Kod23<=14)|Kod23==15))]$KOD10,
        EurostatCode = NA, CauseGroup = "Megelőzhető halálozás"),
    "Kezeléssel elkerülhető halálozás" =
      data.table(Cause = ICDData[
        (Kod1=="A"&((Kod23>=15&Kod23<=19)|Kod23%in%c(38, 46)|(Kod23==40&KOD10!="A4030")|
                      (Kod23==41&KOD10!="A4130")|KOD10%in%c("A4810", "A4910")))|
          (Kod1=="B"&(Kod23==90))|
          (Kod1=="D"&((Kod23>=10&Kod23<=36)))|
          (Kod1=="E"&(Kod23==27|(Kod23>=10&Kod23<=14)|(Kod23>=0&Kod23<=7)|
                        (Kod23>=24&Kod23<=25&KOD10!="E2440")))|
          (Kod1=="C"&(Kod23%in%c(53, 50, 54, 55, 62, 73, 81)|(Kod23>=18&Kod23<=21)|
                        KOD10%in%c("C9100", "C9101", "C9102", "C9110")))|
          (Kod1=="G"&(KOD10%in%c("G0020", "G0030", "G0080", "G0090")|Kod23%in%c(3, 40, 41)))|
          (Kod1=="I"&((Kod23%in%c(71, 15, 70, 26, 80))|(Kod23>=10&Kod23<=13)|(Kod23>=20&Kod23<=25)|
                        (Kod23>=60&Kod23<=69)|(Kod23>=0&Kod23<=9)|KOD10%in%c("I7390", "I8290")))|
          (Kod1=="J"&(Kod23%in%c(65, 12, 15, 80, 81, 85, 86, 90, 93, 94)|(Kod23>=0&Kod23<=6)|
                        (Kod23>=30&Kod23<=39)|(Kod23>=16&Kod23<=18)|(Kod23>=20&Kod23<=22)|
                        (Kod23>=45&Kod23<=47)))|
          (Kod1=="K"&((Kod23>=25&Kod23<=28)|(Kod23>=35&Kod23<=38)|(Kod23>=40&Kod23<=46)|
                        (Kod23>=80&Kod23<=81)|(Kod23>=82&Kod23<=83)|
                        KOD10%in%c("K8500", "K8510", "K8530", "K8580", "K8590",
                                   "K8610", "K8620", "K8630", "K8680", "K8681", "K8690")))|
          (Kod1=="L"&(Kod23==3))|
          (Kod1=="N"&(Kod23%in%c(13, 35, 23, 25, 40)|(Kod23>=0&Kod23<=7)|(Kod23>=20&Kod23<=21)|
                        (Kod23>=17&Kod23<=19)|(Kod23>=26&Kod23<=27)|(Kod23>=70&Kod23<=73)|
                        KOD10%in%c("N3410", "N7500", "N7510", "N7640", "N7660")))|
          (Kod1=="O"&((Kod23>=0&Kod23<=99)))|
          (Kod1=="P"&((Kod23>=0&Kod23<=96)))|
          (Kod1=="Q"&((Kod23>=20&Kod23<=28)))|
          (Kod1=="Y"&((Kod23>=40&Kod23<=59)|(Kod23>=60&Kod23<=69)|(Kod23>=83&Kod23<=84)|
                        (Kod23>=70&Kod23<=82)))]$KOD10,
        EurostatCode = NA, CauseGroup = "Kezeléssel elkerülhető halálozás")))

ICDGroups$Groups <- setNames(ICDGroups$Groups, sapply(ICDGroups$Groups, function(gr) gr$CauseGroup[1]))
ICDGroups$Individual <- setNames(ICDGroups$Individual, sapply(ICDGroups$Individual, function(gr) gr$CauseGroup[1]))

# --- BNO-7 (ICD-7, "A" lista, List == "07A") modul ----------------------------
# A régebbi revíziók visszafelé illesztése egyetlen, önálló blokkban: a kulcs az
# EurostatCode, így a fenti haláloki csoportok definícióját nem kell módosítani
# (új revízió hozzáadása is itt, egy helyen történik). A kódok a WHO MDB
# dokumentáció 1. táblájából (ICD7 A-List) valók -- FONTOS, hogy ezek NEM azonosak
# a 08A (BNO-8) "A0xx" kódjaival (pl. gyomor: 07A A046 vs. 08A A047)! Ahol a durva
# A-lista egy finomabb csoportot nem tud kitölteni, oda nem kerül sor: az a csoport
# az ICD-7 éveknél (Magyarországon 1955-1968) egyszerűen üresen marad (fokozatos
# degradáció), a downstream feldolgozás (app.R) változatlanul működik.
bno07a <- list(
  ## Összes
  "A-R_V-Y"      = "A000",                                # Összes halálok
  ## Fertőző és parazitás betegségek (A00-B99)
  "A_B"          = sprintf("A%03d", 1:43),               # Fertőző és parazitás betegségek
  "A15-A19_B90"  = sprintf("A%03d", 1:5),                # Gümőkór (TBC)
  "B15-B19_B942" = "A034",                               # Vírusos májgyulladás (fertőző hepatitis)
  "A_B_OTH"      = sprintf("A%03d", c(6:33, 35:43)),     # Egyéb fertőző (TBC és hepatitis nélkül)
  ## Daganatok (C00-D48). A finom lokalizációk (máj, hasnyálmirigy, petefészek,
  ## vese, hólyag, agy, pajzsmirigy) a 07A-ban az A057 "egyéb"-be vannak vonva,
  ## így külön nem bonthatók -- azok a csoportok 1955-68-ra üresek (degradáció).
  "C00-D48"      = sprintf("A%03d", 44:60),              # Daganatok (összes)
  "C"            = sprintf("A%03d", 44:59),              # Rosszindulatú daganatok
  "C00-C14"      = "A044",                               # Ajak, szájüreg, garat
  "C15"          = "A045",                               # Nyelőcső
  "C16"          = "A046",                               # Gyomor
  "C18-C21"      = c("A047", "A048"),                    # Vastagbél és végbél
  "C32"          = "A049",                               # Gége
  "C33_C34"      = "A050",                               # Légcső, hörgő, tüdő
  "C50"          = "A051",                               # Emlő
  "C53"          = "A052",                               # Méhnyak
  "C54_C55"      = "A053",                               # Méhtest és méh k.m.n.
  "C61"          = "A054",                               # Prostata
  "C81-C86"      = "A059",                               # Hodgkin-kór és lymphomák
  "C91-C95"      = "A058",                               # Leukémia
  "D00-D48"      = "A060",                               # Jó-/bizonytalan indulatú daganatok
  "D50-D89"      = "A065",                               # Vér betegségei (vérszegénységek)
  ## Endokrin, táplálkozási és anyagcsere (E00-E89)
  "E"            = sprintf("A%03d", c(61:64, 66)),       # Endokrin (vérképzőszervi A065 nélkül)
  "E10-E14"      = "A063",                               # Cukorbetegség
  "E_OTH"        = sprintf("A%03d", c(61, 62, 64, 66)),  # Egyéb endokrin (cukorbetegség nélkül)
  ## Mentális (F01-F99). Demencia/alkohol/drog 07A-ban nincs külön -> üres.
  "F"            = sprintf("A%03d", 67:69),              # Mentális- és viselkedészavarok
  "F_OTH"        = sprintf("A%03d", 67:69),              # Egyéb mentális (a kiemeltek 07A-ban nincsenek)
  ## Idegrendszer és érzékszervek (G00-H95). A070 = agyér -> a keringéshez!
  "G_H"          = sprintf("A%03d", 71:78),              # Idegrendszer és érzékszervek
  "G_H_OTH"      = sprintf("A%03d", 71:78),              # Egyéb (Parkinson/Alzheimer 07A-ban nincs)
  ## Keringési rendszer (I00-I99). Teljes felbontás A070, A079-A086.
  "I"            = c("A070", sprintf("A%03d", 79:86)),   # Keringési rendszer
  "I20-I25"      = "A081",                               # Ischaemiás szívbetegség (arterioscl. szív)
  "I30-I51"      = "A082",                               # A szívbetegség egyéb formái
  "I60-I69"      = "A070",                               # Cerebrovaszkuláris betegségek
  "I_OTH"        = sprintf("A%03d", c(79, 80, 83:86)),   # Egyéb keringési (reuma, hypertonia, artériák)
  ## Légzőrendszer (J00-J99). Teljes felbontás A087-A097.
  "J"            = sprintf("A%03d", 87:97),              # Légzőrendszer
  "J09-J11"      = "A088",                               # Influenza
  "J12-J18"      = sprintf("A%03d", 89:91),              # Tüdőgyulladás
  "J40-J47"      = "A093",                               # Idült alsó légúti (idült hörghurut)
  "J40-J44_J47"  = "A093",                               # Egyéb idült alsó légúti
  "J_OTH"        = sprintf("A%03d", c(87, 92, 94:97)),   # Egyéb légzőrendszeri
  ## Emésztőrendszer (K00-K92). Teljes felbontás A098-A107.
  "K"            = sprintf("A%03d", 98:107),             # Emésztőrendszer
  "K25-K28"      = c("A099", "A100"),                    # Gyomor- és nyombélfekély
  "K70_K73_K74"  = "A105",                               # Idült májbetegség / májzsugor
  "K_OTH"        = sprintf("A%03d", c(98, 101:104, 106, 107)), # Egyéb emésztőrendszeri
  ## Bőr (csak a bőrfertőzések; az "egyéb bőr" 07A-ban a csont-izommal közös)
  "L"            = "A121",                               # Bőr és bőralatti szövet
  ## Csont-izomrendszer (M00-M99). 07A: A122-A125 (A121 itt a BŐR!).
  "M"            = sprintf("A%03d", 122:125),            # Csont-izomrendszer
  "RHEUM_ARTHRO" = "A122",                               # Rheumatoid arthritis és arthrosis
  "M_OTH"        = sprintf("A%03d", 123:125),            # Egyéb csont-izom
  ## Urogenitális (N00-N99). Teljes felbontás A108-A114.
  "N"            = sprintf("A%03d", 108:114),            # Urogenitális rendszer
  "N00-N29"      = sprintf("A%03d", 108:111),            # Vese és ureter
  "N_OTH"        = sprintf("A%03d", 112:114),            # Egyéb urogenitális
  ## Terhesség, szülés, gyermekágy (O00-O99). 07A: A115-A120.
  "O"            = sprintf("A%03d", 115:120),            # Terhesség, szülés, gyermekágy
  ## Perinatális állapotok (P00-P96). 07A: A130-A135.
  "P"            = sprintf("A%03d", 130:135),            # Perinatális állapotok
  ## Veleszületett rendellenességek (Q00-Q99). 07A: A127-A129.
  "Q"            = sprintf("A%03d", 127:129),            # Veleszületett rendellenességek
  ## Tünetek, kórosan meghatározott (R00-R99). 07A: A136 (aggkor), A137 (k.m.n.).
  "R"            = c("A136", "A137"),                    # Tünetek és kóros leletek
  "R_OTH"        = c("A136", "A137"),                    # (R95 SIDS és R96-99 07A-ban nincs)
  ## Külső okok (V00-Y89). Teljes felbontás A138-A150.
  "V01-Y89"      = sprintf("A%03d", 138:150),            # Külső okok (összes)
  "ACC"          = sprintf("A%03d", 138:147),            # Balesetek
  "V_Y85"        = c("A138", "A139"),                    # Közlekedési balesetek
  "W00-W19"      = "A141",                               # Esések
  "W65-W74"      = "A146",                               # Vízbefulladás
  "X40-X49"      = "A140",                               # Balesetszerű mérgezés
  "ACC_OTH"      = sprintf("A%03d", c(142:145, 147)),    # Egyéb balesetek
  "X60-X84_Y870" = "A148",                               # Szándékos önártalom (öngyilkosság)
  "X85-Y09_Y871" = "A149"                                # Testi sértés (emberölés)
)
# Szándékosan kihagyva (07A-ban nincs megfelelő, vagy csak durvább kategória):
# HIV (B20-B24), idült vírusos hepatitis (B180-B182), a finom daganat-lokalizációk
# (C22, C25, C43, C56, C64, C67, C70-C72, C73, C88_C90_C96, C_OTH), demencia
# (F01_F03), alkohol/drog (F10, TOXICO), Parkinson (G20), Alzheimer (G30),
# asztma (J45_J46), egyes máj- és vesecsoportok (K72-K75), SIDS (R95), R96-R99,
# COVID (U...), bizonytalan szándék (Y10-Y34). Ezek 1955-1968-ra üresen maradnak.

for (ec in names(bno07a)) {
  idx <- which(sapply(ICDGroups$Groups, function(gr) gr$EurostatCode[1] == ec))
  if (length(idx) == 1) {
    gr <- ICDGroups$Groups[[idx]]
    ICDGroups$Groups[[idx]] <- rbind(gr, data.table(
      Cause = bno07a[[ec]], List = "07A",
      EurostatCode = ec, CauseGroup = gr$CauseGroup[1]))
  }
}
# --- BNO-7 modul vége ---------------------------------------------------------

ICDGroups$Individual <- lapply(ICDGroups$Individual, function(l) cbind(l, List = "104"))
ICDGroups$Avoidable <- lapply(ICDGroups$Avoidable, function(l) cbind(l, List = "104"))

ICDGroups$Groups <- lapply(ICDGroups$Groups, function(l) cbind(l, Weight = 1))
ICDGroups$Individual <- lapply(ICDGroups$Individual, function(l) cbind(l, Weight = 1))
ICDGroups$Avoidable <- lapply(ICDGroups$Avoidable, function(l) cbind(l, Weight = 1))

ICDGroups$Avoidable$`Megelőzhető halálozás`[
  Cause %in% ICDData[
    (Kod1=="A"&((Kod23>=15&Kod23<=19)))|(Kod1=="B"&(Kod23==90))|(Kod1=="J"&(Kod23==65))|
      (Kod1=="C"&(Kod23==53))|(Kod1=="E"&((Kod23>=10&Kod23<=14)))|
      (Kod1=="I"&(Kod23%in%c(71, 15, 70)|(Kod23>=10&Kod23<=13)|(Kod23>=20&Kod23<=25)|
                    (Kod23>=60&Kod23<=69)|(KOD10=="I7390")))]$KOD10
]$Weight <- 0.5

ICDGroups$Avoidable$`Kezeléssel elkerülhető halálozás`[
  Cause %in% ICDData[
    (Kod1=="A"&((Kod23>=15&Kod23<=19)))|(Kod1=="B"&(Kod23==90))|(Kod1=="J"&(Kod23==65))|
      (Kod1=="C"&(Kod23==53))|(Kod1=="E"&((Kod23>=10&Kod23<=14)))|
      (Kod1=="I"&(Kod23%in%c(71, 15, 70)|(Kod23>=10&Kod23<=13)|(Kod23>=20&Kod23<=25)|
                    (Kod23>=60&Kod23<=69)|(KOD10=="I7390")))]$KOD10
]$Weight <- 0.5

saveRDS(ICDGroups, "./procdata/ICDGroups.rds")
## Part C
PopDataUN <- fread(paste0(
  "https://population.un.org/wpp/assets/Excel%20Files/",
  "1_Indicator%20(Standard)/CSV_FILES/",
  "WPP2024_PopulationBySingleAgeSex_Medium_1950-2023.csv.gz"))

table(PopDataUN$AgeGrpSpan) # csak 1 és -1
table(PopDataUN[AgeGrpSpan == -1]$AgeGrpStart) # a -1 az csak a 100+ kategória
# tökéletes a megfeleltetés AgeGrp és AgeGrpStart között
table(apply(table(PopDataUN$AgeGrp, PopDataUN$AgeGrpStart), 1, function(x) sum(x>0)))
table(apply(table(PopDataUN$AgeGrp, PopDataUN$AgeGrpStart), 2, function(x) sum(x>0)))

PopDataUN <- melt(
  PopDataUN[ISO3_code != "", .(iso3c = ISO3_code, Year = Time,
                               Age = AgeGrpStart, PopMale, PopFemale)],
  id.vars = c("iso3c", "Year", "Age"), variable.name = "Sex", variable.factor = FALSE)
PopDataUN$Sex <- factor(PopDataUN$Sex, levels = c("PopMale", "PopFemale"), labels = c("Férfi", "Nő"))
PopDataUN$value <- PopDataUN$value * 1000

PopDataUN <- PopDataUN[iso3c %in% unique(RawData$iso3c)]
PopDataUN <- PopDataUN[Year %in% unique(RawData$Year)]

PopDataUN[Age %in% 95:100]$Age <- 95
PopDataUN <- PopDataUN[, .(value = sum(value)), .(iso3c, Year, Sex, Age)]

names(PopDataUN)[names(PopDataUN) == "value"] <- "PopUN"
PopData <- PopDataUN
names(PopData)[names(PopData) == "PopUN"] <- "Pop"

PopData$Age <- cut(PopData$Age, c(0:5, seq(10, 95, 5), Inf), right = FALSE,
                   labels = paste0("Deaths", 2:25))
PopData <- PopData[, .(Pop = sum(Pop)), .(iso3c, Year, Age, Sex)]

PopData <- rbind(PopData, PopData[Age %in% paste0("Deaths", 3:6),
                                  .(Pop = sum(Pop), Age = "Deaths3456") , .(iso3c, Year, Sex)])

PopData <- rbind(
  cbind(PopData, Frmat = 0),
  cbind(rbind(PopData[!Age %in% paste0("Deaths", 23:25)],
              PopData[Age %in% paste0("Deaths", 23:25),
                      .(Pop = sum(Pop), Age = "Deaths232425"), .(iso3c, Year, Sex)]), Frmat = 1),
  cbind(rbind(PopData[!Age %in% paste0("Deaths", 23:25) & !Age %in% paste0("Deaths", 3:6)],
              PopData[Age %in% paste0("Deaths", 23:25),
                      .(Pop = sum(Pop), Age = "Deaths232425"), .(iso3c, Year, Sex)]), Frmat = 2)
)

PopData$Aggregated <- ifelse(PopData$Frmat == 2, FALSE, PopData$Age == "Deaths3456")

PopData$iso3c <- as.factor(PopData$iso3c)
PopData$Frmat <- as.factor(PopData$Frmat)
PopData$Age <- as.factor(PopData$Age)

saveRDS(PopData, "./procdata/WHO-MDB-Population.rds")
