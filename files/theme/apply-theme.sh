#!/usr/bin/env bash
#
# Uso:
#   apply-theme.sh
#   apply-theme.sh [PALETA]
#   apply-theme.sh --list
#   apply-theme.sh --help
#
# Sem argumentos:
#   - mostra as paletas disponíveis
#   - permite escolher uma paleta
#   - permite sair sem alterar nada
#
# Com uma paleta:
#   - aplica diretamente a paleta informada
#
# --list:
#   - lista as paletas disponíveis
#
# --help:
#   - mostra esta ajuda

set -Eeuo pipefail

# ---------------------------------------------------------------------------
# Erros
# ---------------------------------------------------------------------------

if [[ -t 1 ]]; then
  RED=$'\033[31m'
  GREEN=$'\033[32m'
  YELLOW=$'\033[33m'
  BLUE=$'\033[34m'
  CYAN=$'\033[36m'
  BOLD=$'\033[1m'
  RESET=$'\033[0m'
else
  RED=''
  GREEN=''
  YELLOW=''
  BLUE=''
  CYAN=''
  BOLD=''
  RESET=''
fi

sucess() {
  printf '✓%s ' "$GREEN"
  printf "$@"
  printf '%s' "$RESET"
}

info() {
  printf '%s ' "$BLUE"
  printf "$@"
  printf '%s' "$RESET"
}

error() {
  printf '✗%s ' "$RED"
  printf "$@"
  printf '%s' "$RESET"
  # printf 'Erro: %s\n' "$*" >&2
  exit 1
}

warning() {
  printf '!%s ' "$YELLOW"
  printf "$@"
  printf '%s' "$RESET"
  # printf 'Aviso: %s\n' "$*" >&2
}

# ---------------------------------------------------------------------------
# Diretórios e arquivos
# ---------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
I3_CONFIG_DIR="$(dirname "$SCRIPT_DIR")"
PALETTES_DIR="$SCRIPT_DIR/palettes"

ROFI_COLORS="$SCRIPT_DIR/rofi/shared/colors.rasi"
POLYBAR_COLORS="$SCRIPT_DIR/polybar/colors.ini"
ALACRITTY_COLORS="$I3_CONFIG_DIR/alacritty/colors.toml"
KITTY_COLORS="$I3_CONFIG_DIR/kitty/colors.conf"
I3_COLORS="$I3_CONFIG_DIR/config.d/00-colors.conf"
DUNST_COLORS="$I3_CONFIG_DIR/dunstrc.d/colors.conf"

# ---------------------------------------------------------------------------
# Variáveis exigidas pelas paletas
# ---------------------------------------------------------------------------

REQUIRED_VARS=(
  BG
  BG_ALT
  FG
  FG_ALT
  ACCENT

  RED_N
  GREEN_N
  YELLOW_N
  BLUE_N
  MAGENTA_N
  CYAN_N
  WHITE_N

  RED_B
  GREEN_B
  YELLOW_B
  BLUE_B
  MAGENTA_B
  CYAN_B
  WHITE_B

  GRAY
)

# ---------------------------------------------------------------------------
# Temporários
# ---------------------------------------------------------------------------

TMP_FILES=()

cleanup() {
  local tmp_file

  for tmp_file in "${TMP_FILES[@]}"; do
    [[ -e "$tmp_file" ]] && rm -f -- "$tmp_file"
  done
}

trap cleanup EXIT

create_temp_file() {
  local target="$1"
  local tmp_file

  tmp_file="$(mktemp "$(dirname "$target")/.theme.XXXXXX")"

  TMP_FILES+=("$tmp_file")

  if [[ -e "$target" ]]; then
    chmod --reference="$target" "$tmp_file"
  fi

  printf '%s\n' "$tmp_file"
}

# ---------------------------------------------------------------------------
# Ajuda
# ---------------------------------------------------------------------------

usage() {
  cat <<EOF
Uso:
  $(basename "$0")
  $(basename "$0") [PALETA]
  $(basename "$0") --list
  $(basename "$0") --help

Opções:
  -l, --list       Lista as paletas disponíveis
  -h, --help       Mostra esta ajuda

Sem argumentos:
  Mostra as paletas disponíveis e permite escolher uma.

Com uma paleta:
  Aplica diretamente a paleta informada.

Exemplos:
  $(basename "$0")
  $(basename "$0") gruvbox
  $(basename "$0") nord
  $(basename "$0") --list
EOF
}

# ---------------------------------------------------------------------------
# Lista de paletas
# ---------------------------------------------------------------------------

list_palettes() {
  local palette_file
  local palette_name

  printf 'Paletas disponíveis:\n'

  while IFS= read -r palette_file; do
    palette_name="$(basename "$palette_file" .sh)"
    printf '  %s\n' "$palette_name"
  done < <(
    find "$PALETTES_DIR" \
      -maxdepth 1 \
      -type f \
      -name '*.sh' \
      -print |
      sort
  )
}

# ---------------------------------------------------------------------------
# Escolha interativa da paleta
# ---------------------------------------------------------------------------

choose_palette() {
  local palette_file
  local palette_name
  local palettes=()
  local choice

  [[ -t 0 ]] ||
    error "nenhuma paleta foi informada e não existe um terminal interativo. Use: $(basename "$0") <paleta>"

  while IFS= read -r palette_file; do
    palette_name="$(basename "$palette_file" .sh)"
    palettes+=("$palette_name")
  done < <(
    find "$PALETTES_DIR" \
      -maxdepth 1 \
      -type f \
      -name '*.sh' \
      -print |
      sort
  )

  ((${#palettes[@]} > 0)) ||
    error "nenhuma paleta encontrada em: $PALETTES_DIR"

  printf 'Paletas disponíveis:\n'

  for ((i = 0; i < ${#palettes[@]}; i++)); do
    printf '  %d) %s\n' "$((i + 1))" "${palettes[i]}"
  done

  printf '\n  0) Sair\n\n'

  while true; do
    read -r -p "Escolha uma opção [0-${#palettes[@]}]: " choice

    if [[ "$choice" == "0" ]]; then
      printf 'Nenhuma alteração foi feita.\n'
      exit 0
    fi

    if [[ "$choice" =~ ^[0-9]+$ ]] &&
      ((choice >= 1 && choice <= ${#palettes[@]})); then
      PALETTE="${palettes[choice - 1]}"
      return 0
    fi

    printf 'Opção inválida. Escolha um número entre 0 e %d.\n\n' \
      "${#palettes[@]}"
  done
}

# ---------------------------------------------------------------------------
# Argumentos
# ---------------------------------------------------------------------------

[[ -d "$PALETTES_DIR" ]] ||
  error "diretório de paletas não encontrado: $PALETTES_DIR"

case "${1:-}" in
-h | --help)
  usage
  exit 0
  ;;

-l | --list)
  list_palettes
  exit 0
  ;;

--)
  shift
  ;;

--*)
  error "opção desconhecida: $1"
  ;;
esac

if (($# > 1)); then
  error "apenas uma paleta pode ser informada"
fi

if (($# == 1)); then
  PALETTE="$1"

  PALETTE_FILE="$PALETTES_DIR/$PALETTE.sh"

  if [[ ! -f "$PALETTE_FILE" ]]; then
    printf "Erro: paleta '%s' não encontrada.\n\n" "$PALETTE" >&2
    choose_palette
    PALETTE_FILE="$PALETTES_DIR/$PALETTE.sh"
  fi
else
  choose_palette
  PALETTE_FILE="$PALETTES_DIR/$PALETTE.sh"
fi

# ---------------------------------------------------------------------------
# Validação inicial
# ---------------------------------------------------------------------------

[[ -f "$PALETTE_FILE" ]] ||
  error "paleta não encontrada: $PALETTE_FILE"

for required_dir in \
  "$(dirname "$DUNST_COLORS")" \
  "$(dirname "$ROFI_COLORS")" \
  "$(dirname "$POLYBAR_COLORS")" \
  "$(dirname "$ALACRITTY_COLORS")" \
  "$(dirname "$KITTY_COLORS")" \
  "$(dirname "$I3_COLORS")"; do

  [[ -d "$required_dir" ]] ||
    error "diretório necessário não encontrado: $required_dir"
done

# ---------------------------------------------------------------------------
# Carrega a paleta
# ---------------------------------------------------------------------------

# shellcheck disable=SC1090
source "$PALETTE_FILE"

# ---------------------------------------------------------------------------
# Valida todas as variáveis antes de modificar qualquer arquivo
# ---------------------------------------------------------------------------

missing_vars=()

for variable in "${REQUIRED_VARS[@]}"; do
  if [[ -z "${!variable:-}" ]]; then
    missing_vars+=("$variable")
  fi
done

if ((${#missing_vars[@]} > 0)); then
  printf 'Erro: a paleta "%s" não define as seguintes variáveis:\n' \
    "$PALETTE" >&2

  printf '  %s\n' "${missing_vars[@]}" >&2

  exit 1
fi

# ---------------------------------------------------------------------------
# Geração dos arquivos temporários
# ---------------------------------------------------------------------------

ROFI_TMP="$(create_temp_file "$ROFI_COLORS")"

cat >"$ROFI_TMP" <<EOF
* {
    background:     $BG;
    background-alt: $BG_ALT;
    foreground:     $FG;
    selected:       $ACCENT;
    active:         $GREEN_B;
    urgent:         $RED_B;
}
EOF

POLYBAR_TMP="$(create_temp_file "$POLYBAR_COLORS")"

cat >"$POLYBAR_TMP" <<EOF
[color]

BACKGROUND = $BG
FOREGROUND = $FG
ALTBACKGROUND = $BG_ALT
ALTFOREGROUND = $FG_ALT
ACCENT = $ACCENT

BLACK = $BG
RED = $RED_B
GREEN = $GREEN_B
YELLOW = $YELLOW_B
BLUE = $BLUE_B
MAGENTA = $MAGENTA_B
CYAN = $CYAN_B
WHITE = $WHITE_N
ALTBLACK = $GRAY
ALTRED = $RED_B
ALTGREEN = $GREEN_B
ALTYELLOW = $YELLOW_B
ALTBLUE = $BLUE_B
ALTMAGENTA = $MAGENTA_B
ALTCYAN = $CYAN_B
ALTWHITE = $FG
EOF

ALACRITTY_TMP="$(create_temp_file "$ALACRITTY_COLORS")"

cat >"$ALACRITTY_TMP" <<EOF
[colors.primary]
background = "$BG"
foreground = "$FG"

[colors.normal]
black   = "$BG"
red     = "$RED_N"
green   = "$GREEN_N"
yellow  = "$YELLOW_N"
blue    = "$BLUE_N"
magenta = "$MAGENTA_N"
cyan    = "$CYAN_N"
white   = "$WHITE_N"

[colors.bright]
black   = "$GRAY"
red     = "$RED_B"
green   = "$GREEN_B"
yellow  = "$YELLOW_B"
blue    = "$BLUE_B"
magenta = "$MAGENTA_B"
cyan    = "$CYAN_B"
white   = "$WHITE_B"
EOF

KITTY_TMP="$(create_temp_file "$KITTY_COLORS")"

cat >"$KITTY_TMP" <<EOF
background $BG
foreground $FG
selection_background $FG
selection_foreground $BG
cursor $FG

color0 $BG
color8 $GRAY
color1 $RED_N
color9 $RED_B
color2 $GREEN_N
color10 $GREEN_B
color3 $YELLOW_N
color11 $YELLOW_B
color4 $BLUE_N
color12 $BLUE_B
color5 $MAGENTA_N
color13 $MAGENTA_B
color6 $CYAN_N
color14 $CYAN_B
color7 $WHITE_N
color15 $WHITE_B
EOF

I3_TMP="$(create_temp_file "$I3_COLORS")"

cat >"$I3_TMP" <<EOF
set \$i3_cl_col_bg $BG
set \$i3_cl_col_fg $FG
set \$i3_cl_col_in $GREEN_B
set \$i3_cl_col_afoc $ACCENT
set \$i3_cl_col_ifoc $BLUE_N
set \$i3_cl_col_ufoc $BG_ALT
set \$i3_cl_col_urgt $MAGENTA_N
set \$i3_cl_col_phol $BG
EOF

DUNST_TMP="$(create_temp_file "$DUNST_COLORS")"

cat >"$DUNST_TMP" <<EOF
[urgency_low]
  timeout = 2
  background = "$BG"
  foreground = "$FG"
  frame_color = "$ACCENT"

[urgency_normal]
  timeout = 5
  background = "$BG"
  foreground = "$FG"
  frame_color = "$ACCENT"

[urgency_critical]
  timeout = 0
  background = "$BG"
  foreground = "$RED_B"
  frame_color = "$RED_B"
EOF

# ---------------------------------------------------------------------------
# Aplicação
#
# Todos os arquivos já foram gerados com sucesso.
# Os mv acontecem somente depois dessa etapa.
# ---------------------------------------------------------------------------

mv -f -- "$ROFI_TMP" "$ROFI_COLORS"
mv -f -- "$POLYBAR_TMP" "$POLYBAR_COLORS"
mv -f -- "$ALACRITTY_TMP" "$ALACRITTY_COLORS"
mv -f -- "$KITTY_TMP" "$KITTY_COLORS"
mv -f -- "$I3_TMP" "$I3_COLORS"
mv -f -- "$DUNST_TMP" "$DUNST_COLORS"

# ---------------------------------------------------------------------------
# Recarregar componentes
# ---------------------------------------------------------------------------

# if ! i3-msg reload >/dev/null 2>&1; then
#   warning "não foi possível recarregar o i3"
# fi
#
# "$I3_CONFIG_DIR/scripts/i3_dunst" >/dev/null 2>&1 &
# # FIXME: Cria arquivos .system e .module quando chama a bar pelo script. Ou entao não está limpando os arquivos temporários quando chama esse script. Avaliar
# "$I3_CONFIG_DIR/scripts/i3_bar" >/dev/null 2>&1 &

# ---------------------------------------------------------------------------
# Resultado
# ---------------------------------------------------------------------------

sucess "Tema '%s' aplicado com sucesso.\n" "$PALETTE"
info "Faça logoff para o tema ser aplicado corretamente ou recarregue o i3 'i3-msg restart'\n\n"
