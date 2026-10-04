#!/usr/bin/env bash
#
# Uso:
#   apply-theme.sh [PALeta]
#   apply-theme.sh --list
#   apply-theme.sh --help
#
# Com uma paleta:
#   - aplica a paleta informada
#   - atualiza theme/current
#
# Sem uma paleta:
#   - lê theme/current
#   - aplica a paleta armazenada
#   - não altera theme/current
#
set -Eeuo pipefail

# ---------------------------------------------------------------------------
# Erros
# ---------------------------------------------------------------------------

error() {
  printf 'Erro: %s\n' "$*" >&2
  exit 1
}

warning() {
  printf 'Aviso: %s\n' "$*" >&2
}

# ---------------------------------------------------------------------------
# Diretórios e arquivos
# ---------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
I3_CONFIG_DIR="$(dirname "$SCRIPT_DIR")"
PALETTES_DIR="$SCRIPT_DIR/palettes"
CURRENT_THEME="$SCRIPT_DIR/current"

ROFI_COLORS="$SCRIPT_DIR/rofi/shared/colors.rasi"
POLYBAR_COLORS="$SCRIPT_DIR/polybar/colors.ini"
ALACRITTY_COLORS="$I3_CONFIG_DIR/alacritty/colors.toml"
I3_COLORS="$I3_CONFIG_DIR/config.d/00-colors.conf"
DUNST_CONFIG="$I3_CONFIG_DIR/dunstrc"

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
  $(basename "$0") [PALETA]
  $(basename "$0") --list
  $(basename "$0") --help

Opções:
  -l, --list       Lista as paletas disponíveis
  -h, --help       Mostra esta ajuda

Com uma paleta:
  Aplica a paleta informada e atualiza o tema atual.

Sem uma paleta:
  Aplica a paleta definida em:
    $CURRENT_THEME

Exemplos:
  $(basename "$0") gruvbox
  $(basename "$0") nord
  $(basename "$0")
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
# Argumentos
# ---------------------------------------------------------------------------

EXPLICIT_PALETTE=false

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
  EXPLICIT_PALETTE=true
else
  [[ -f "$CURRENT_THEME" ]] ||
    error "nenhuma paleta foi informada e o arquivo 'current' não existe. Use: $(basename "$0") <paleta>"

  PALETTE="$(<"$CURRENT_THEME")"

  [[ -n "$PALETTE" ]] ||
    error "o arquivo 'current' está vazio. Use: $(basename "$0") <paleta>"
fi

# Remove espaços em branco acidentais.
PALETTE="${PALETTE#"${PALETTE%%[![:space:]]*}"}"
PALETTE="${PALETTE%"${PALETTE##*[![:space:]]}"}"

[[ -n "$PALETTE" ]] ||
  error "nome de paleta vazio"

PALETTE_FILE="$PALETTES_DIR/$PALETTE.sh"

# ---------------------------------------------------------------------------
# Validação inicial
# ---------------------------------------------------------------------------

[[ -d "$PALETTES_DIR" ]] ||
  error "diretório de paletas não encontrado: $PALETTES_DIR"

[[ -f "$PALETTE_FILE" ]] ||
  error "paleta não encontrada: $PALETTE_FILE"

[[ -f "$DUNST_CONFIG" ]] ||
  error "arquivo do Dunst não encontrado: $DUNST_CONFIG"

for required_dir in \
  "$(dirname "$ROFI_COLORS")" \
  "$(dirname "$POLYBAR_COLORS")" \
  "$(dirname "$ALACRITTY_COLORS")" \
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

I3_TMP="$(create_temp_file "$I3_COLORS")"

cat >"$I3_TMP" <<EOF
set \$i3_cl_col_bg $BG
set \$i3_cl_col_fg $FG
set \$i3_cl_col_in $GREEN_B
set \$i3_cl_col_afoc $ACCENT
set \$i3_cl_col_ifoc $BLUE_N
set \$i3_cl_col_ufoc $BG_ALT
set \$i3_cl_col_urgt $RED_N
set \$i3_cl_col_phol $BG
EOF

# ---------------------------------------------------------------------------
# Dunst
# ---------------------------------------------------------------------------

DUNST_TMP="$(create_temp_file "$DUNST_CONFIG")"

awk \
  -v bg="$BG" \
  -v fg="$FG" \
  -v accent="$ACCENT" \
  -v red="$RED_B" '
    /^\[/ {
        sec = $0
        sub(/[ \t]+$/, "", sec)
    }

    sec == "[urgency_low]" || sec == "[urgency_normal]" {
        if ($0 ~ /^[ \t]*background[ \t]*=/) {
            print "background = \"" bg "\""
            next
        }

        if ($0 ~ /^[ \t]*foreground[ \t]*=/) {
            print "foreground = \"" fg "\""
            next
        }

        if ($0 ~ /^[ \t]*frame_color[ \t]*=/) {
            print "frame_color = \"" accent "\""
            next
        }
    }

    sec == "[urgency_critical]" {
        if ($0 ~ /^[ \t]*background[ \t]*=/) {
            print "background = \"" bg "\""
            next
        }

        if ($0 ~ /^[ \t]*foreground[ \t]*=/) {
            print "foreground = \"" red "\""
            next
        }

        if ($0 ~ /^[ \t]*frame_color[ \t]*=/) {
            print "frame_color = \"" red "\""
            next
        }
    }

    { print }
' "$DUNST_CONFIG" >"$DUNST_TMP"

# ---------------------------------------------------------------------------
# Atualiza "current" somente quando a paleta foi informada explicitamente.
#
# Também é feito de forma atômica.
# ---------------------------------------------------------------------------

CURRENT_TMP=""

if [[ "$EXPLICIT_PALETTE" == true ]]; then
  CURRENT_TMP="$(create_temp_file "$CURRENT_THEME")"

  printf '%s\n' "$PALETTE" >"$CURRENT_TMP"
fi

# ---------------------------------------------------------------------------
# Aplicação
#
# Todos os arquivos já foram gerados com sucesso.
# Os mv acontecem somente depois dessa etapa.
# ---------------------------------------------------------------------------

mv -f -- "$ROFI_TMP" "$ROFI_COLORS"
mv -f -- "$POLYBAR_TMP" "$POLYBAR_COLORS"
mv -f -- "$ALACRITTY_TMP" "$ALACRITTY_COLORS"
mv -f -- "$I3_TMP" "$I3_COLORS"
mv -f -- "$DUNST_TMP" "$DUNST_CONFIG"

if [[ "$EXPLICIT_PALETTE" == true ]]; then
  mv -f -- "$CURRENT_TMP" "$CURRENT_THEME"
fi

# ---------------------------------------------------------------------------
# Recarregar componentes
# ---------------------------------------------------------------------------

if ! i3-msg reload >/dev/null 2>&1; then
  warning "não foi possível recarregar o i3"
fi

if [[ -x "$SCRIPT_DIR/polybar/launch.sh" ]]; then
  "$SCRIPT_DIR/polybar/launch.sh" >/dev/null 2>&1 &
else
  warning "launch.sh do Polybar não encontrado ou não é executável"
fi

pkill -x dunst 2>/dev/null || true

if ! setsid dunst -conf "$DUNST_CONFIG" >/dev/null 2>&1 & then
  warning "não foi possível iniciar o Dunst"
fi

# ---------------------------------------------------------------------------
# Resultado
# ---------------------------------------------------------------------------

if [[ "$EXPLICIT_PALETTE" == true ]]; then
  printf "Tema '%s' aplicado e definido como atual.\n" "$PALETTE"
else
  printf "Tema atual '%s' aplicado.\n" "$PALETTE"
fi
