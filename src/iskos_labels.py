"""Helpers to convert ÍSKOS variable codes (incl. one-hot derivatives) into
human-readable Icelandic labels.

All label content is read **directly from the SPSS .sav file** via
``pyreadstat.read_sav(..., metadataonly=True)``. The .sav was produced in
Iceland, so its native ``column_names_to_labels`` (variable questions) and
``variable_value_labels`` (numeric code → text label) are already Icelandic.

The only hand-curated piece is ``SHORT_QUESTION_LABELS_IS`` — 1–3 word
axis-tick labels that are authorial judgement, not data.

Usage from a notebook:

    >>> import sys
    >>> sys.path.insert(0, "../src")
    >>> from iskos_labels import IskosLabels
    >>> labels = IskosLabels.from_sav(
    ...     "Kjósendakönnun/ÍSKOS kjósenda 2024/ISKOS2024_med_aukabreytum_20260318.sav",
    ...     feature_groups_path="data/processed/feature_groups.json",
    ... )
    >>> labels.readable("educationflo_80")
    'Menntun: MA, MSc eða sambærilegt'
    >>> labels.readable("lrscale")
    'Hægri-vinstri staðsetning svarenda'
    >>> labels.short_question("educationflo")
    'Menntun'
"""

from __future__ import annotations

import json
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Iterable

# Hand-curated short forms for variable headers that appear on plot axes.
# The full SPSS question text is too long for a y-tick — we want a 1–3 word
# label that a reader can scan. Falls back to the first sentence of the
# question text when a code is missing here.
SHORT_QUESTION_LABELS_IS: dict[str, str] = {
    "gender": "Kyn",
    "age": "Aldur",
    "yob": "Fæðingarár",
    "educationflo": "Menntun",
    "elecdist": "Kjördæmi",
    "area": "Búseta (svæði)",
    "urban": "Búseta (þéttbýli)",
    "emplstatus": "Atvinnustaða",
    "incomecate": "Heimilistekjur",
    "manadartekjur": "Mánaðartekjur",
    "arstekjur": "Árstekjur",
    "rentown": "Húsnæði",
    "maritals": "Hjúskaparstaða",
    "hhmmb": "Heimilisstærð",
    "childs": "Börn á heimili",
    "languagecat": "Tungumál heima",
    "church": "Trúfélag",
    "rlgatnd": "Trúarlegar athafnir",
    "lrscale": "Hægri–vinstri",
    "polintr": "Áhugi á stjórnmálum",
    "pltrust": "Traust til stjórnmálamanna",
    "envirimp": "Umhverfismál > hagvöxtur",
    "gincdif": "Jöfnun tekna",
    "taxreduc": "Lægri skattar",
    "capicntry": "Höfuðborg vs. landsbyggð",
    "ceqvote": "Jöfn vægi atkvæða",
    "privhealth": "Einkarekstur í heilbrigði",
    "imueclt": "Innflytjendur ógna þjóðareinkenni",
    "essfull": "EES ógnar fullveldi",
    "femfight": "Femínistabarátta gengin of langt",
    "banks": "Einkavæða banka",
    "immrght": "Innflytjendur og félagshúsnæði",
    "genconsind": "Áhersla á stóriðju",
    "acrproimp": "Innflutningur landbúnaðarvara",
    "drugpol": "Afglæpavæðing fíkniefna",
    "gndequ": "Jafnrétti kynjanna",
    "EUmship": "Aðild að ESB",
    "govprfm": "Frammistaða ríkisstjórnar",
    "ecobettwors_1": "Efnahagur sl. 12 mán.",
    "bprteco": "Besti flokkur: efnahagur",
    "bprtimm": "Besti flokkur: innflytjendur",
    "bprteurope": "Besti flokkur: Evrópa",
    "bprtfamily": "Besti flokkur: fjölskyldur",
    "bprtisencit": "Besti flokkur: eldri borgarar",
    "bprthealth": "Besti flokkur: heilbrigði",
    "bprtenvir": "Besti flokkur: umhverfi",
    "bprtregpol": "Besti flokkur: byggðamál",
    "bprtedu": "Besti flokkur: menntun",
    "bprtequal": "Besti flokkur: jafnrétti",
    "bprthouse": "Besti flokkur: húsnæði",
}


def _normalize_code(code: Any) -> str:
    """Convert a pyreadstat value-label key (usually a float) to an integer-string
    where possible, to match the existing lookup convention.

    pyreadstat stores keys as ``1.0, 2.0, ...``; we want ``"1", "2"``.
    Non-integer numerics and plain strings pass through via ``str()``.
    """
    try:
        return str(int(float(code)))
    except (ValueError, TypeError):
        return str(code)


@dataclass(frozen=True)
class IskosLabels:
    """Read-only mapping from ÍSKOS variable codes to Icelandic labels."""

    variable_labels: dict[str, str]
    value_labels: dict[str, dict[str, str]]
    nominal_columns: frozenset[str]

    # ------------------------------------------------------------------ loaders
    @classmethod
    def from_meta(
        cls,
        meta: Any,
        nominal_columns: Iterable[str] | None = None,
    ) -> "IskosLabels":
        """Build from a ``pyreadstat`` metadata object.

        Uses ``meta.column_names_to_labels`` for variable questions and
        ``meta.variable_value_labels`` for value labels. Filters out variables
        with empty / None labels so ``question()`` falls back to the raw code.
        """
        variable_labels: dict[str, str] = {
            var: lbl
            for var, lbl in getattr(meta, "column_names_to_labels", {}).items()
            if lbl  # drop None / empty strings
        }
        value_labels: dict[str, dict[str, str]] = {}
        for var, code_map in getattr(meta, "variable_value_labels", {}).items():
            value_labels[var] = {_normalize_code(k): str(v) for k, v in code_map.items()}
        nominal = frozenset(nominal_columns or ())
        return cls(
            variable_labels=variable_labels,
            value_labels=value_labels,
            nominal_columns=nominal,
        )

    @classmethod
    def from_sav(
        cls,
        sav_path: str | Path,
        feature_groups_path: str | Path | None = None,
    ) -> "IskosLabels":
        """Read metadata only (no data!) from the .sav file and build labels.

        ``feature_groups_path`` (optional) points to ``feature_groups.json``
        so that one-hot column splits know which variables are nominal.
        """
        import pyreadstat  # imported lazily to keep module-import cheap

        _, meta = pyreadstat.read_sav(str(sav_path), metadataonly=True)
        nominal: Iterable[str] | None = None
        if feature_groups_path is not None:
            fg_path = Path(feature_groups_path)
            if fg_path.exists():
                with fg_path.open(encoding="utf-8") as f:
                    fg = json.load(f)
                nominal = fg.get("nominal_columns", [])
        return cls.from_meta(meta, nominal_columns=nominal)

    # -------------------------------------------------------------- public API
    def question(self, var: str) -> str:
        """Full question text for a survey variable, or the variable code if unknown."""
        return self.variable_labels.get(var, var)

    def short_question(self, var: str) -> str:
        """Short (1–3 word) label suitable for an axis tick."""
        if var in SHORT_QUESTION_LABELS_IS:
            return SHORT_QUESTION_LABELS_IS[var]
        # Fallback: take the first clause of the question text
        full = self.question(var)
        first = re.split(r"[?,()\-–]| – | - ", full, maxsplit=1)[0].strip()
        return first[:35] or var

    def value_label(self, var: str, code: str | int | float) -> str:
        """Look up the label for a numeric code under a variable.

        Returns the original code (as string) if the variable or code is unknown.
        """
        if var not in self.value_labels:
            return str(code)
        # The JSON stores codes as strings (e.g. "10"); incoming codes can be
        # ints or floats — normalise to a string of the integer form when possible.
        try:
            code_key = str(int(float(code)))
        except (ValueError, TypeError):
            code_key = str(code)
        return self.value_labels[var].get(code_key, code_key)

    # ---------------------------------------------------- one-hot column splits
    def _split_one_hot(self, column: str) -> tuple[str, str | None]:
        """Split ``educationflo_80`` into ``("educationflo", "80")``.

        Only splits when the prefix matches a known nominal column. Otherwise
        treats the whole string as the variable name (no value suffix).
        """
        if "_" not in column:
            return column, None
        # Try every possible split point from longest prefix down (handles names
        # with underscores like ``ecobettwors_1`` — we want the whole thing as
        # the variable, not "ecobettwors" + value "1", because ecobettwors_1
        # IS the variable and is numeric (not nominal).
        # Strategy: only split if the prefix is in the known nominal_columns set.
        idx = column.rfind("_")
        while idx > 0:
            prefix, suffix = column[:idx], column[idx + 1:]
            if prefix in self.nominal_columns:
                return prefix, suffix
            idx = column.rfind("_", 0, idx)
        return column, None

    # --------------------------------------------------------- readable strings
    def readable(self, column: str, *, short: bool = True) -> str:
        """Convert a (possibly one-hot) feature column to a human-readable label.

        Examples (with ``short=True`` — the default):
          ``educationflo_80`` → ``"Menntun: MA, MSc eða sambærilegt"``
          ``urban_4``         → ``"Búseta (þéttbýli): Í stórri borg ..."``
          ``lrscale``         → ``"Hægri–vinstri"``
          ``ecobettwors_1``   → ``"Efnahagur sl. 12 mán."``  (numeric var)
        """
        var, value = self._split_one_hot(column)
        head = self.short_question(var) if short else self.question(var)
        if value is None:
            return head
        if value == "Missing":
            return f"{head}: (vantar)"
        val_text = self.value_label(var, value)
        return f"{head}: {val_text}"

    def readable_many(self, columns: Iterable[str], *, short: bool = True) -> list[str]:
        return [self.readable(c, short=short) for c in columns]
