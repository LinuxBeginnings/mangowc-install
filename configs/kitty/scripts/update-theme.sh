#!/bin/bash
# Detects desktop session and sets appropriate kitty theme
# Uses COSMIC theme colors directly instead of matugen

if [ -z "$KITTY_PID" ]; then
	exit 0 # Not running in kitty
fi

DESKTOP="${XDG_CURRENT_DESKTOP:-unknown}"
KITTY_DIR="$HOME/.config/kitty"
THEME_LINK="$KITTY_DIR/current-theme.conf"

if [ "$DESKTOP" = "COSMIC" ]; then
	# Parse colors from COSMIC theme files
	COSMIC_THEME="$HOME/.config/cosmic/com.system76.CosmicTheme.Dark/v1"

	if [ -f "$COSMIC_THEME/background" ] && [ -f "$COSMIC_THEME/accent" ] && [ -f "$COSMIC_THEME/palette" ]; then

		# Extract colors from COSMIC theme files
		BG_RED=$(grep -A1 'base:' "$COSMIC_THEME/background" | grep 'red:' | head -1 | sed 's/.*red: *\([0-9.]*\).*/\1/')
		BG_GREEN=$(grep -A2 'base:' "$COSMIC_THEME/background" | grep 'green:' | head -1 | sed 's/.*green: *\([0-9.]*\).*/\1/')
		BG_BLUE=$(grep -A3 'base:' "$COSMIC_THEME/background" | grep 'blue:' | head -1 | sed 's/.*blue: *\([0-9.]*\).*/\1/')

		FG_RED=$(grep -A1 'on:' "$COSMIC_THEME/background" | grep 'red:' | head -1 | sed 's/.*red: *\([0-9.]*\).*/\1/')
		FG_GREEN=$(grep -A2 'on:' "$COSMIC_THEME/background" | grep 'green:' | head -1 | sed 's/.*green: *\([0-9.]*\).*/\1/')
		FG_BLUE=$(grep -A3 'on:' "$COSMIC_THEME/background" | grep 'blue:' | head -1 | sed 's/.*blue: *\([0-9.]*\).*/\1/')

		ACC_RED=$(grep -A1 'base:' "$COSMIC_THEME/accent" | grep 'red:' | head -1 | sed 's/.*red: *\([0-9.]*\).*/\1/')
		ACC_GREEN=$(grep -A2 'base:' "$COSMIC_THEME/accent" | grep 'green:' | head -1 | sed 's/.*green: *\([0-9.]*\).*/\1/')
		ACC_BLUE=$(grep -A3 'base:' "$COSMIC_THEME/accent" | grep 'blue:' | head -1 | sed 's/.*blue: *\([0-9.]*\).*/\1/')

		# Convert to hex using python
		convert_to_hex() {
			python3 -c "r=$1; g=$2; b=$3; print('#{:02x}{:02x}{:02x}'.format(int(r*255), int(g*255), int(b*255)))" 2>/dev/null
		}

		BG=$(convert_to_hex "$BG_RED" "$BG_GREEN" "$BG_BLUE")
		FG=$(convert_to_hex "$FG_RED" "$FG_GREEN" "$FG_BLUE")
		ACCENT=$(convert_to_hex "$ACC_RED" "$ACC_GREEN" "$ACC_BLUE")

		# Extract palette colors
		get_palette_color() {
			local color_name="$1"
			local red=$(grep -A3 "$color_name:" "$COSMIC_THEME/palette" | grep 'red:' | head -1 | sed 's/.*red: *\([0-9.]*\).*/\1/')
			local green=$(grep -A4 "$color_name:" "$COSMIC_THEME/palette" | grep 'green:' | head -1 | sed 's/.*green: *\([0-9.]*\).*/\1/')
			local blue=$(grep -A5 "$color_name:" "$COSMIC_THEME/palette" | grep 'blue:' | head -1 | sed 's/.*blue: *\([0-9.]*\).*/\1/')
			convert_to_hex "$red" "$green" "$blue"
		}

		COLOR0=$(get_palette_color "neutral_0")
		COLOR1=$(get_palette_color "accent_red")
		COLOR2=$(get_palette_color "accent_green")
		COLOR3=$(get_palette_color "accent_yellow")
		COLOR4=$(get_palette_color "accent_blue")
		COLOR5=$(get_palette_color "accent_purple")
		COLOR6=$(get_palette_color "accent_indigo")
		COLOR7=$(get_palette_color "neutral_8")
		COLOR8=$(get_palette_color "neutral_2")
		COLOR9=$(get_palette_color "bright_red")
		COLOR10=$(get_palette_color "bright_green")
		COLOR11=$(get_palette_color "bright_orange")
		COLOR12=$(get_palette_color "accent_blue")
		COLOR13=$(get_palette_color "accent_pink")
		COLOR14=$(get_palette_color "accent_indigo")
		COLOR15=$(get_palette_color "neutral_10")

		# Generate kitty theme file
		cat >"$KITTY_DIR/cosmic-theme.conf" <<EOF
# COSMIC Theme Colors (auto-generated from system theme)
foreground              $FG
background              $BG
selection_foreground    $BG
selection_background    $ACCENT
cursor                  $ACCENT
cursor_text_color       $BG

# URL underline color when hovering with mouse
url_color               $ACCENT

# Kitty window border colors
active_border_color     $ACCENT
inactive_border_color   $COLOR8
bell_border_color       $COLOR11

# Tab bar colors
active_tab_foreground   $BG
active_tab_background   $ACCENT
inactive_tab_foreground $FG
inactive_tab_background $COLOR8
tab_bar_background      $BG

# The 16 terminal colors

# black
color0 $COLOR0
color8 $COLOR8

# red
color1 $COLOR1
color9 $COLOR9

# green
color2  $COLOR2
color10 $COLOR10

# yellow
color3  $COLOR3
color11 $COLOR11

# blue
color4  $COLOR4
color12 $COLOR12

# magenta
color5  $COLOR5
color13 $COLOR13

# cyan
color6  $COLOR6
color14 $COLOR14

# white
color7  $COLOR7
color15 $COLOR15
EOF

		# Update symlink
		ln -sf "$KITTY_DIR/cosmic-theme.conf" "$THEME_LINK"

		# Signal kitty to reload config
		kill -SIGUSR1 "$KITTY_PID" 2>/dev/null
	fi
else
	# For bspwm: get theme from current rice and apply it
	if [ -f "$HOME/.config/bspwm/.rice" ]; then
		RICE=$(cat "$HOME/.config/bspwm/.rice")
		if [ -f "$HOME/.config/bspwm/rices/$RICE/theme-config.bash" ]; then
			# Source the theme config to get KITTY_THEME
			KITTY_THEME=$(grep "^KITTY_THEME=" "$HOME/.config/bspwm/rices/$RICE/theme-config.bash" | cut -d'"' -f2)

			# Map theme names to theme files (same as 14-kitty.sh)
			case "${KITTY_THEME}" in
			"Catppuccin-Mocha") theme_file="daniela.conf" ;;
			"Tokyo Night") theme_file="emilia.conf" ;;
			"Everforest") theme_file="brenda.conf" ;;
			"Nord") theme_file="melissa.conf" ;;
			"Rosé Pine") theme_file="aline.conf" ;;
			"Rosé Pine Moon") theme_file="cristina.conf" ;;
			"OneDark") theme_file="isabel.conf" ;;
			"Monokai Remastered") theme_file="jan.conf" ;;
			"Oxocarbon") theme_file="yael.conf" ;;
			"Varinka") theme_file="varinka.conf" ;;
			"Kanagawa Dragon") theme_file="cynthia.conf" ;;
			"Dracula") theme_file="marisol.conf" ;;
			*) theme_file="" ;;
			esac

			if [ -n "$theme_file" ] && [ -f "$HOME/.config/kitty/themes/$theme_file" ]; then
				ln -sf "$HOME/.config/kitty/themes/$theme_file" "$THEME_LINK"
				# Signal kitty to reload config
				kill -SIGUSR1 "$KITTY_PID" 2>/dev/null
			fi
		fi
	fi
fi
