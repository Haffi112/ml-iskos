# Getur gervigreindin spáð fyrir um hvaða flokk ég kýs?

Kóði og vinnubækur sem fylgja kafla 8 í ritrýndri bók Háskólaútgáfunnar um alþingiskosningarnar 2024.
Höfundar kaflans eru Hafsteinn Birgir Einarsson og Hafsteinn Einarsson.

Í kaflanum er vélnámi beitt á kjósendakönnun Íslensku kosningarannsóknarinnar (ÍSKOS) 2024 til að
giska á hvaða flokk svarendur kusu út frá öðrum svörum þeirra í sömu könnun. Byrjað er á einföldum
grunnlíkönum, síðan er þjálfað ákvörðunartré og loks slembiskógur (e. random forest). Til að skilja
hvaða upplýsingar líkanið nýtir eru notaðir tveir mælikvarðar á mikilvægi breyta (Gini-mikilvægi og
umröðunarmikilvægi) og SHAP-gildi fyrir einstakar spár.

Vinnubækurnar eru skrifaðar með lesendur bókarinnar í huga: skýringar eru á íslensku og hvert skref er
útskýrt. Þú getur líka sett inn eigin svör og séð hvaða flokk líkanið telur líklegast að þú hafir kosið.

## Gögnin

**Gögn ÍSKOS fylgja ekki þessari geymslu.** Skilmálar um notkun gagnanna heimila ekki að þeim sé
dreift, og það á líka við um gögn á svarendastigi sem unnin eru úr þeim. Upplýsingar um ÍSKOS og aðgang
að gögnunum eru á [iskos.hi.is](https://iskos.hi.is/).

Greiningin notar skrána `ISKOS2024_med_aukabreytum_20260318.sav` (kjósendakönnun ÍSKOS 2024 ásamt
aukabreytum). Settu hana hér:

```
Kjósendakönnun/ÍSKOS kjósenda 2024/ISKOS2024_med_aukabreytum_20260318.sav
```

Í geymslunni eru aðeins lýsigögn: flokkun breyta í breytuhópa (`iskos24_breytuflokkun.csv`) og
breytuheiti og gildismerki (`data/feature_meta.csv`, `data/value_labels.json`).

## Uppsetning

**Python** (3.12) með [`uv`](https://docs.astral.sh/uv/):

```bash
uv sync
```

Ákvörðunartréð í Python-útgáfunni er teiknað með `graphviz` (á macOS: `brew install graphviz`).

**R** (4.3 eða nýrra):

```r
install.packages(c(
  "haven", "dplyr", "tidyr", "readr", "ggplot2", "forcats", "jsonlite",
  "rpart", "rpart.plot", "randomForest", "nnet", "fastshap", "shapviz",
  "patchwork", "ragg", "svglite", "colorspace", "rmarkdown", "knitr"
))
```

## Vinnubækurnar

Kaflinn byggir á einfölduðu keðjunni, sem er til bæði í Python og R. Keyrðu vinnubækurnar í þessari röð.

| Skref | Python (`notebooks_simplified/`) | R (`notebooks_simplified_r/`) | Hvað gerist |
|---|---|---|---|
| 0 | `00_preprocess.ipynb` | `00_preprocess.Rmd` | Les SPSS-skrána, velur svarendur ÍSKOS-hlutans, býr til markbreytuna og skrifar `data/iskos_clean.csv` |
| 1 | `01_eda.ipynb` | `01_eda.Rmd` | Lýsandi myndir af hverri breytu og tengslum hennar við flokksval |
| 2 | `02_models.ipynb` | `02_models.Rmd` | Grunnlíkön, ákvörðunartré, slembiskógur, ruglingsfylki og mikilvægi breyta |
| 3 | `03_predict_yourself.ipynb` | `03_predict_yourself.Rmd` | Settu inn eigin svör og sjáðu spá líkansins með SHAP-fossariti |

Úr rót verkefnisins:

```bash
# Python
uv run jupyter nbconvert --to notebook --execute --inplace notebooks_simplified/00_preprocess.ipynb
uv run jupyter nbconvert --to notebook --execute --inplace notebooks_simplified/01_eda.ipynb
uv run jupyter nbconvert --to notebook --execute --inplace notebooks_simplified/02_models.ipynb
uv run jupyter nbconvert --to notebook --execute --inplace notebooks_simplified/03_predict_yourself.ipynb

# R
cd notebooks_simplified_r
Rscript -e 'rmarkdown::render("00_preprocess.Rmd")'
Rscript -e 'rmarkdown::render("01_eda.Rmd")'
Rscript -e 'rmarkdown::render("02_models.Rmd")'
Rscript -e 'rmarkdown::render("03_predict_yourself.Rmd")'
```

Báðar forvinnsluvinnubækurnar skrifa sömu skrár í `data/`, svo það skiptir ekki máli hvor er keyrð.
Keyrsla hvorrar keðju tekur fáeinar mínútur.

### Hvað fer inn í líkanið

- **Svarendur:** þeir sem fengu ÍSKOS-hluta spurningalistans (n = 1.193) og sögðust hafa kosið einn
  af flokkunum sjö hér að neðan (n = 1.012).
- **Markbreyta:** flokksval í alþingiskosningunum 2024 í sjö flokkum: þingflokkarnir sex auk
  „Vinstri (sameinað)“, þar sem Sósíalistaflokkurinn, Píratar og Vinstri græn eru sameinuð. Þeir sem
  kusu ekki, skiluðu auðu, vildu ekki segja hvað þeir kusu eða kusu Lýðræðisflokkinn eru ekki með.
- **Breytur:** 38 spurningar um félagslega stöðu (þar á meðal aldur og menntun), málefnaviðhorf, mat
  á efnahagsástandi, stjórnmálaviðhorf og -hegðun, miðlanotkun og sjálfsstaðsetningu á vinstri-hægri
  kvarða.
- **Breytur sem er sleppt:** málefnaeign (hvaða flokkur er talinn bestur í tilteknum málaflokki),
  flokkshollusta (þar á meðal hversu vel svaranda líkar við hvern flokk) og mat á frammistöðu
  ríkisstjórnarinnar 2021–2024. Allar eru þær svo nátengdar flokksvalinu að þær segja lítið annað en
  hvaða flokk svarandinn kaus. Breyttu `LEAK_GROUPS` og `EXCLUDE_VARS` í 02-vinnubókinni til að sjá
  áhrifin af því að taka þær með.
- **Vantandi svör** eru sérstakt gildi: „Ekki svarað“ í flokkabreytum og −1 í raðbreytum. Enginn
  svarandi er felldur út vegna þeirra.
- **Skipting:** lagskipt 80/20 skipting í þjálfunar- og prófunarmengi (806/206) með slembifræi 42.

### Myndir kaflans

| Mynd í bókinni | Skrá í `figures/` | Vinnubók |
|---|---|---|
| Mynd 8.1, ákvörðunartré | `mynd_8_1_akvordunartre.png` / `.svg` | `notebooks_simplified_r/02_models.Rmd` |
| Mynd 8.2, ruglingsfylki | `mynd_8_2_ruglingsfylki.png` / `.svg` | `notebooks_simplified_r/02_models.Rmd` |
| Mynd 8.3, mikilvægi breyta | `mynd_8_3_mikilvaegi.png` / `.svg` | `notebooks_simplified_r/02_models.Rmd` |
| Mynd 8.4, SHAP-fossarit | `mynd_8_4_fossarit.png` / `.svg` | `notebooks_simplified/03_predict_yourself.ipynb` |

Myndirnar eru vistaðar sem PNG (300 dpi) og SVG (vigurmynd). Möppurnar `figures/` og `models/` eru búnar
til við keyrslu og fylgja ekki geymslunni.

### Stöðugleikagreiningar

`scripts/robustness/robustness.R` endurtekur líkönin úr `02_models.Rmd` og skilar tölunum sem vísað er
til í kaflanum: sömu skiptingu og í kaflanum, 50 endurteknar skiptingar, samanburð við fjölkosta
lógistíska aðhvarfsgreiningu, líkön sem byggja aðeins á tveimur eða þremur spurningum og
umröðunarmikilvægi. Keyrt úr rót verkefnisins eftir forvinnslu:

```bash
Rscript scripts/robustness/robustness.R            # líkanið í kaflanum
Rscript scripts/robustness/robustness.R with_gov   # með mati á frammistöðu ríkisstjórnarinnar
Rscript scripts/robustness/robustness.R all        # allar breytur, líka málefnaeign og flokkshollusta
```

### Um endurtakanleika

- Öll slembiskref nota fast slembifræ (`random_state=42` í Python, `set.seed(42)` í R) og
  `uv.lock` festir útgáfur Python-pakka.
- R- og Python-útgáfurnar skila svipuðum en ekki nákvæmlega sömu tölum, því slembiskipting gagnanna
  og meðhöndlun flokkabreyta er ólík milli `randomForest` og scikit-learn. Tölurnar í kaflanum eru úr
  R-útgáfunni nema SHAP-fossaritið (Mynd 8.4), sem er gert í Python.
- `predict()` í `randomForest` brýtur jafntefli í atkvæðum trjánna af handahófi. Þess vegna spáir
  02-vinnubókin fyrst fyrir þjálfunargögnin og svo prófunargögnin, og stöðugleikaforritið gerir það sama.

## Úttak vinnubóka

Úttak vinnubóka getur innihaldið einstök svör úr könnuninni og er því fjarlægt áður en vinnubók fer í
geymsluna. Það sér git-sía um (`scripts/strip_notebook_outputs.py`), en úttakið helst í þínu eintaki.
Settu síuna upp einu sinni eftir að þú klónar geymsluna:

```bash
git config filter.nbstrip.clean "python3 scripts/strip_notebook_outputs.py"
git config filter.nbstrip.smudge cat
git config filter.nbstrip.required true
```

## Upphaflega greiningarkeðjan

Í `notebooks/` er fyrsta og umfangsmeiri útgáfa greiningarinnar, með fleiri líkönum (meðal annars
stigulsmögnuðum trjám og AutoGluon) og fleiri afbrigðum. Kaflinn byggir ekki á henni, en hún er höfð með
fyrir þá sem vilja ganga lengra. Keyrsla hennar tekur um 50 mínútur.
