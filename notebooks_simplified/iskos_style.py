"""ÍSKOS sjónræn samræming fyrir Python-vinnubækurnar (speglar rsetup.R úr aðalverkefninu).

Hér höldum við litum og þema á **einum stað** svo allar myndir í 01–03 noti sama útlit.
Notkun í vinnubók::

    import iskos_style as ik
    ik.apply_rc()                     # stillir bakgrunn/letur fyrir allar myndir
    ax = ik.style_iskos(ax, title=…)  # snyrtir staka mynd (theme_iskos jafngildi)
"""

import matplotlib as mpl

# ---- Grunnlitir (sjá iskos_color_* í rsetup.R) ----
ISKOS_BG    = "#F9F9F9"                  # iskos_color_background
ISKOS_MAIN  = "#02529c"                  # iskos_color_main  — einn meginlitur (súlurit)
ISKOS_MAIN2 = ["#cc3e2a", "#3d6dba"]     # iskos_color_main2 — rauður / blár (t.d. SHAP +/-)
ISKOS_TEXT  = "#222222"
ISKOS_TEXT_MID = "#333333"

# ---- Flokkalitir (nýja paletta úr endurgjöfinni) ----
# Lyklað á íslensk flokksheiti í nefnifalli.
PARTY_COLORS = {
    "Sósíalistar":           "#c0392b",
    "VG":                    "#5da832",
    "Samfylkingin":          "#e8000d",
    "Píratar":               "#6c3fa0",
    "Flokkur fólksins":      "#e6c300",
    "Framsókn":              "#1a6b2f",
    "Viðreisn":              "#d4600a",
    "Sjálfstæðisflokkurinn": "#4a90d9",
    "Miðflokkurinn":         "#0d2d6e",
}

# Brú frá sameinuðu 7-flokka heitunum (þolfall, eins og í `flokkur`-dálkinum) yfir í litina.
# "Vinstri (sameinað)" á sér ekki staka færslu í paletunni — fær Pírata-fjólubláan svo hann
# skerist ekki á við dökkgræna Framsókn.
CLASS_COLORS = {
    "Samfylkinguna (S)":       PARTY_COLORS["Samfylkingin"],
    "Sjálfstæðisflokkinn (D)": PARTY_COLORS["Sjálfstæðisflokkurinn"],
    "Viðreisn (C)":            PARTY_COLORS["Viðreisn"],
    "Framsóknarflokkinn (B)":  PARTY_COLORS["Framsókn"],
    "Miðflokkinn (M)":         PARTY_COLORS["Miðflokkurinn"],
    "Flokk fólksins (F)":      PARTY_COLORS["Flokkur fólksins"],
    "Vinstri (sameinað)":      PARTY_COLORS["Píratar"],
}


def class_colors(order):
    """Skila lista af litum í sömu röð og `order` (flokksheitin)."""
    return [CLASS_COLORS.get(c, "#999999") for c in order]


def text_on(hex_color: str) -> str:
    """Velja svartan eða hvítan texta eftir birtu bakgrunnslitar (WCAG-relative luminance).

    Notað fyrir ákvarðanatökutréð: mettaðir flokkslitir þurfa hvítan texta, ljósir svartan."""
    h = hex_color.lstrip("#")
    r, g, b = (int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))

    def lin(c):
        return c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4

    lum = 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)
    return "#111111" if lum > 0.5 else "#ffffff"


def apply_rc():
    """Stilla bakgrunn og letur fyrir allar myndir (jafngildi plot.background í theme_iskos)."""
    mpl.rcParams.update({
        "figure.facecolor":  ISKOS_BG,
        "axes.facecolor":    ISKOS_BG,
        "savefig.facecolor": ISKOS_BG,
        "font.family":       "sans-serif",
        "font.sans-serif":   ["Arial", "Helvetica", "DejaVu Sans"],
    })


def style_iskos(ax, title=None, title_pad=12, grid=False):
    """Bera theme_iskos-útlitið á staka Axes: ljós bakgrunnur, engar efri/hægri rammalínur,
    vinstristillaður titill, mjúkir ásmerkingar. Speglar theme_iskos() í rsetup.R."""
    ax.set_facecolor(ISKOS_BG)
    for side in ("top", "right"):
        ax.spines[side].set_visible(False)
    for side in ("left", "bottom"):
        ax.spines[side].set_color("#cccccc")
    ax.tick_params(length=0, colors=ISKOS_TEXT_MID)
    ax.grid(grid)
    if title is not None:
        ax.set_title(title, loc="left", color=ISKOS_TEXT, fontsize=11, pad=title_pad)
    return ax
