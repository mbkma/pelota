## Pelota's retro color palette (assets/pelota_color_palette.gpl) and the shades derived from
## it. The UI theme (resources/themes/pelota.tres) and the UI scenes use the same colors.
class_name Palette

const TEAL := Color("#007f94")
const PURPLE := Color("#4b385e")
const RED := Color("#c22b26")
const CREAM := Color("#eed78d")
const AMBER := Color("#ffb632")

## Darkest purple: page backgrounds, borders and the hard retro drop shadows
const INK := Color("#241a30")
## Dark purple between INK and PURPLE: fields, popups and unselected tabs
const DEEP := Color("#31243f")
## Lighter teal and red, readable as text on the dark purples
const TEAL_LIGHT := Color("#59acb9")
const RED_LIGHT := Color("#d77572")

## Colors that tell the two players apart (names, charts, stats)
const PLAYER_1 := TEAL_LIGHT
const PLAYER_2 := RED_LIGHT
