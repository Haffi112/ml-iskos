# ÍSKOS sjónræn samræming fyrir R-vinnubækurnar (speglar rsetup.R úr aðalverkefninu).
# Hér höldum við litum og þema á EINUM stað svo allar myndir í 01–03 noti sama útlit.
# Notkun í Rmd:  source("iskos_style.R")  →  theme_iskos(), party_colors, iskos_color_main …

library(ggplot2)

# ---- Grunnlitir (sjá iskos_color_* í rsetup.R) ----
iskos_color_background <- "#F9F9F9"
iskos_color_main       <- "#02529c"              # einn meginlitur (súlurit)
iskos_color_main2      <- c("#cc3e2a", "#3d6dba") # rauður / blár (t.d. SHAP +/-)
iskos_text_dark        <- "#222222"
iskos_text_mid         <- "#333333"

# ---- Flokkalitir (nýja paletta úr endurgjöfinni), lyklað á nefnifallsheiti ----
party_colors <- c(
  "Sósíalistar"           = "#c0392b",
  "VG"                    = "#5da832",
  "Samfylkingin"          = "#e8000d",
  "Píratar"               = "#6c3fa0",
  "Flokkur fólksins"      = "#e6c300",
  "Framsókn"              = "#1a6b2f",
  "Viðreisn"              = "#d4600a",
  "Sjálfstæðisflokkurinn" = "#4a90d9",
  "Miðflokkurinn"         = "#0d2d6e"
)

# Brú frá sameinuðu 7-flokka heitunum (þolfall, eins og í `flokkur`) yfir í litina.
# "Vinstri (sameinað)" fær Pírata-fjólubláan svo hann skerist ekki á við dökkgræna Framsókn.
class_colors <- c(
  "Samfylkinguna (S)"       = unname(party_colors["Samfylkingin"]),
  "Sjálfstæðisflokkinn (D)" = unname(party_colors["Sjálfstæðisflokkurinn"]),
  "Viðreisn (C)"            = unname(party_colors["Viðreisn"]),
  "Framsóknarflokkinn (B)"  = unname(party_colors["Framsókn"]),
  "Miðflokkinn (M)"         = unname(party_colors["Miðflokkurinn"]),
  "Flokk fólksins (F)"      = unname(party_colors["Flokkur fólksins"]),
  "Vinstri (sameinað)"      = unname(party_colors["Píratar"])
)

# Velja svartan eða hvítan texta eftir birtu bakgrunnslitar (WCAG-relative luminance).
# Notað fyrir ákvarðanatökutréð: mettaðir flokkslitir þurfa hvítan texta, ljósir svartan.
iskos_text_on <- function(hex_color) {
  rgb <- grDevices::col2rgb(hex_color) / 255
  lin <- function(c) ifelse(c <= 0.03928, c / 12.92, ((c + 0.055) / 1.055) ^ 2.4)
  lum <- 0.2126 * lin(rgb[1, ]) + 0.7152 * lin(rgb[2, ]) + 0.0722 * lin(rgb[3, ])
  ifelse(lum > 0.5, "#111111", "#ffffff")
}

# theme_iskos — ljós bakgrunnur, vinstristillaður titill, engin skýring (legend).
# Léttvæg útgáfa af theme_iskos() í rsetup.R (án hrbrthemes-háðar svo vinnubækurnar séu sjálfstæðar).
theme_iskos <- function(base_size = 11) {
  theme_minimal(base_size = base_size) +
    theme(
      plot.background  = element_rect(fill = iskos_color_background, colour = iskos_color_background),
      panel.background = element_rect(fill = iskos_color_background, colour = NA),
      panel.grid.minor = element_blank(),
      panel.grid.major = element_line(colour = "#e6e6e6", linewidth = 0.3),
      axis.ticks       = element_blank(),
      axis.text        = element_text(colour = iskos_text_mid),
      # ggplot2:: forskeyti því randomForest skyggir á margin() þegar sá pakki er hlaðinn.
      plot.title       = element_text(hjust = 0, colour = iskos_text_dark,
                                      size = base_size + 1, margin = ggplot2::margin(b = 8)),
      legend.position  = "none",
      plot.margin      = ggplot2::margin(5, 5, 5, 5)
    )
}

# theme_iskos_legend — eins og að ofan en með skýringu neðst (fyrir myndir með mörgum flokkum).
theme_iskos_legend <- function(base_size = 11) {
  theme_iskos(base_size = base_size) +
    theme(
      legend.position  = "bottom",
      legend.direction = "horizontal",
      legend.title     = element_text(size = base_size - 2),
      legend.text      = element_text(size = base_size - 3)
    )
}

# ---- Útgáfumyndir (kafli 8 í bókinni) ----
# Flokkaheitin í gögnunum eru í þolfalli („Hvern kaust þú?“). Á myndum notum við nefnifall.
class_names_nom <- c(
  "Samfylkinguna (S)"       = "Samfylkingin",
  "Sjálfstæðisflokkinn (D)" = "Sjálfstæðisflokkurinn",
  "Viðreisn (C)"            = "Viðreisn",
  "Framsóknarflokkinn (B)"  = "Framsóknarflokkurinn",
  "Miðflokkinn (M)"         = "Miðflokkurinn",
  "Flokk fólksins (F)"      = "Flokkur fólksins",
  "Vinstri (sameinað)"      = "Vinstri (sameinað)"
)

# Ljós blær af lit (blandað við hvítt). Ljósir reitir með dökkum texta eru læsilegri en
# mettaðir flokkslitir og halda sér líka í svarthvítri prentun.
iskos_tint <- function(hex_color, amount = 0.62) {
  colorspace::lighten(hex_color, amount = amount, space = "HLS")
}

# Litir fyrir breytuhópa (Okabe–Ito: greinanlegir fyrir fólk með litblindu).
group_colors <- c(
  "Félagsleg staða"              = "#E69F00",
  "Málefnaviðhorf"               = "#0072B2",
  "Frammistaða stjórnvalda"      = "#009E73",
  "Stjórnmálaviðhorf og -hegðun" = "#CC79A7",
  "Miðlanotkun"                  = "#56B4E9",
  "Vinstri-hægri staða"          = "#D55E00"
)
group_short <- c(
  "1 – Félagsleg staða"         = "Félagsleg staða",
  "2 – Málefnaviðhorf"          = "Málefnaviðhorf",
  "3 – Frammistaða stjórnvalda" = "Frammistaða stjórnvalda",
  "6 - Viðhorf og hegðun"       = "Stjórnmálaviðhorf og -hegðun",
  "7 - Miðlar"                  = "Miðlanotkun",
  "8 - Hægri/Vinstri"           = "Vinstri-hægri staða"
)

# Vistar mynd bæði sem PNG (300 dpi, til birtingar í Word) og SVG (vigurmynd fyrir umbrot).
# `p` er annaðhvort ggplot-hlutur eða fall sem teiknar mynd með grunngrafík (t.d. rpart.plot).
# (SVG í stað PDF: cairo_pdf er ekki alltaf tiltækt og pdf() styður ekki alla Unicode-stafi.)
iskos_save <- function(p, name, width, height, dir = FIGS) {
  png_path <- file.path(dir, paste0(name, ".png"))
  svg_path <- file.path(dir, paste0(name, ".svg"))
  if (inherits(p, "ggplot") || inherits(p, "patchwork")) {
    ggplot2::ggsave(png_path, p, width = width, height = height, dpi = 300,
                    device = ragg::agg_png, bg = iskos_color_background)
    ggplot2::ggsave(svg_path, p, width = width, height = height,
                    device = svglite::svglite, bg = iskos_color_background)
  } else {
    ragg::agg_png(png_path, width = width, height = height, units = "in", res = 300,
                  background = iskos_color_background)
    p(); invisible(grDevices::dev.off())
    svglite::svglite(svg_path, width = width, height = height, bg = iskos_color_background)
    p(); invisible(grDevices::dev.off())
  }
  invisible(c(png_path, svg_path))
}
