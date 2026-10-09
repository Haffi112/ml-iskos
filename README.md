# ÍSKOS 2024 — Vote-choice prediction with machine learning

Companion code for the book chapter *"Getur gervigreindin spáð fyrir um hvaða flokk ég kýs?"*.

Five Jupyter notebooks explore the data, train a sequence of classifiers to predict 2024 Alþingi vote choice from the Icelandic Election Study (ÍSKOS 2024) survey, interpret the best model with SHAP, and let the reader feed their own answers into the trained models.

## Setup

Requires [`uv`](https://docs.astral.sh/uv/) and Python 3.12.

```bash
uv sync
```

First `uv sync` takes several minutes because AutoGluon pulls in PyTorch, LightGBM, XGBoost, and CatBoost.

## Running the notebooks

```bash
uv run jupyter lab
```

Run the notebooks in order:

1. **`notebooks/00_data_exploration.ipynb`** — surveys the raw .sav: shape, variable-naming scheme, target distribution vs. official 2024 election results, missingness by module, and a per-column plot gallery.
2. **`notebooks/01_data_prep.ipynb`** — loads `Kjósendakönnun/ÍSKOS kjósenda 2024/ISKOS2024_med_aukabreytum_20260318.sav`, collapses the target to 7 classes (6 seated parties + merged Sósíalistar/Píratar/VG), selects features across four groups (social status, issue attitudes, government performance, issue ownership), splits 80/20 stratified, and writes cleaned data to `data/processed/`.
3. **`notebooks/02_models.ipynb`** — trains a uniform baseline, a modal baseline, a decision tree, random forest (base + enriched), `HistGradientBoostingClassifier` (base + enriched), and AutoGluon (base + enriched). Runs both a naive pass and a class-weighted pass for imbalance correction. Saves models to `models/` and an accuracy table to `figures/accuracy_table.csv`. **Takes ~50 minutes** because AutoGluon runs for 15 minutes per feature set × both passes.
4. **`notebooks/03_shap.ipynb`** — computes SHAP values for `rf_base`, `rf_enriched`, and the class-weighted variants, produces summary and per-class plots, and writes the top-features tables.
5. **`notebooks/04_my_predictions.ipynb`** — interactive: fill in your own survey responses and see what each trained model predicts, with a SHAP waterfall per model.

To execute them non-interactively:

```bash
uv run jupyter nbconvert --to notebook --execute --inplace notebooks/00_data_exploration.ipynb
uv run jupyter nbconvert --to notebook --execute --inplace notebooks/01_data_prep.ipynb
uv run jupyter nbconvert --to notebook --execute --inplace notebooks/02_models.ipynb
uv run jupyter nbconvert --to notebook --execute --inplace notebooks/03_shap.ipynb
uv run jupyter nbconvert --to notebook --execute --inplace notebooks/04_my_predictions.ipynb
```

### Variable and value labels

All Icelandic labels (question text, categorical value labels) are loaded directly from the `.sav` file's SPSS metadata via `pyreadstat.read_sav(..., metadataonly=True)`. Short axis-tick labels (1–3 words) are curated in `src/iskos_labels.py` — see `SHORT_QUESTION_LABELS_IS`.

## Output layout

```
data/processed/   # intermediate artifacts shared between notebooks
models/           # trained classifiers (.pkl + autogluon_* directories)
figures/          # PNG figures + CSV tables for the chapter
```

Key outputs referenced in the chapter:

- `figures/decision_tree.png` — Mynd 1
- `figures/confusion_matrix_rf_base.png` — Mynd 2 (ruglingsyfirlit)
- `figures/shap_summary.png` — Mynd 3 (SHAP global)
- `figures/chapter_numbers.csv` — accuracy numbers to fill the XX,X% placeholders

## Simplified chain (`notebooks_simplified/`)

A pared-down version of the analysis aimed at students. Restricted to the ÍSKOS module
(`module == 2`, n ≈ 1193), only `DecisionTreeClassifier` + `RandomForestClassifier`, and an
interactive "predict yourself" notebook at the end. End-to-end runtime: under one minute.

1. **`notebooks_simplified/00_preprocess.ipynb`** — reads the `.sav` with
   `pyreadstat.read_sav(..., user_missing=True)`, filters `module == 2`, builds the 7-class
   `flokkur` target (6 seated parties + merged V+P+J), recodes SPSS user-missing codes
   995–999 to a single sentinel per dtype, and writes `data/iskos_clean.csv` +
   `data/feature_meta.csv`.
2. **`notebooks_simplified/01_eda.ipynb`** — class balance, per-feature distribution gallery,
   and per-feature × `flokkur` gallery (stacked bars for nominals, jitter strip plots with
   per-class mean for ordinals). One worked example per pattern, then a loop.
3. **`notebooks_simplified/02_models.ipynb`** — drops near-target groups 4 (málefnaeign)
   and 5 (flokkshollusta) with an explicit one-line opt-in for students who want to see
   leakage, one-hots, splits stratified 80/20, and trains four classifiers: a
   most-frequent baseline, a depth-3 decision tree (rendered with graphviz, node labels
   show *rule + majority party + n=…*), a deep tree to demonstrate overfitting, and a
   300-tree random forest. Saves `models/rf.pkl` + `models/feature_columns.json`.
4. **`notebooks_simplified/03_predict_yourself.ipynb`** — student fills in a `my_answers`
   Python dict; the trained RF returns class probabilities, a SHAP waterfall for the
   predicted class, and a global SHAP summary on all 1012 respondents.

The notebooks are generated from one-shot `nbformat` scripts under
`scripts/build_simplified/`. Edit the script, re-run it, then re-execute the notebook —
the script is the source of truth.

**System dependency:** `graphviz` (for the decision-tree PNG). On macOS:
`brew install graphviz`.

```bash
uv run jupyter nbconvert --to notebook --execute --inplace notebooks_simplified/00_preprocess.ipynb
uv run jupyter nbconvert --to notebook --execute --inplace notebooks_simplified/01_eda.ipynb
uv run jupyter nbconvert --to notebook --execute --inplace notebooks_simplified/02_models.ipynb
uv run jupyter nbconvert --to notebook --execute --inplace notebooks_simplified/03_predict_yourself.ipynb
```

## R Markdown chain (`notebooks_simplified_r/`)

A parallel port of the simplified chain in R Markdown for students who prefer R. Same four
steps, same data, same model story.

Requires R ≥ 4.3 and the following packages: `haven`, `dplyr`, `tidyr`, `readr`,
`ggplot2`, `forcats`, `rpart`, `rpart.plot`, `randomForest`, `fastshap`, `shapviz`,
`rmarkdown`, `knitr`.

```r
install.packages(c(
  "haven", "dplyr", "tidyr", "readr", "ggplot2", "forcats",
  "rpart", "rpart.plot", "randomForest", "fastshap", "shapviz",
  "rmarkdown", "knitr"
))
```

Render each notebook from the command line:

```bash
cd notebooks_simplified_r
Rscript -e 'rmarkdown::render("00_preprocess.Rmd")'
Rscript -e 'rmarkdown::render("01_eda.Rmd")'
Rscript -e 'rmarkdown::render("02_models.Rmd")'
Rscript -e 'rmarkdown::render("03_predict_yourself.Rmd")'
```

Each notebook produces a self-contained `*.html` (gitignored — regenerable). The
shared artifacts in `data/` and `models/` are the same as for the Python chain,
so you can mix-and-match: run the R preprocessing then the Python EDA, or vice
versa.

Differences from the Python version:

- R `rpart` / `randomForest` accept categorical predictors directly, so the
  one-hot encoding step in NB02 is **not needed**. Factor levels saved alongside
  the model let NB03 align the user's row at prediction time.
- The decision-tree figure uses `rpart.plot` instead of `graphviz`.
- SHAP values are computed with `fastshap` (Monte Carlo, model-agnostic) since
  `treeshap` doesn't support `randomForest`. The waterfall and beeswarm plots
  come from `shapviz`.

## Reproducibility

- `random_state=42` on every split and estimator
- `uv.lock` committed
- Notebooks use deterministic file names everywhere

## Data note

The raw `.sav` file lives inside `Kjósendakönnun/` and is **not shareable** per the ÍSKOS data-use agreement. The repository's `.gitignore` excludes that directory along with all generated artifacts; commit the notebooks themselves, not the outputs.
