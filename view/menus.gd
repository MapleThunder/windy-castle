class_name Menus
extends RefCounted
## Every item in the original's menus (data/menus.json) mapped to a remake action,
## or to "n/a: <reason>" for menu items that don't apply.

const ITEMS := {
	# File
	"New Game": "menu_new", "Load...": "menu_load", "Save": "menu_save", "Save As...": "menu_save_as",
	"Options...": "menu_options", "Review Story...": "menu_story", "Exit": "menu_quit",
	# Character, Inventory, Map, Activate (top-level commands)
	"Character": "menu_character", "Inventory": "menu_inventory", "Map": "menu_map", "Activate": "menu_activate",
	# Spells
	"Spellbook...": "menu_spellbook", "Customize Spell Menu...": "menu_spellbook",
	# Verbs
	"Get": "pickup", "Examine": "examine", "Free Hand": "free_hand", "Search": "search",
	"Disarm Trap": "disarm", "Rest Until Healed": "rest", "Sleep Until Mana is Restored": "sleep",
	"Open": "open", "Close": "close", "< Climb Up Stairs": "stairs_up", "> Climb Down Stairs": "stairs_down",
	# Window
	"Move Vertical": "n/a: the remake has one game window instead of movable child windows",
	"Move Horizontal": "n/a: the remake has one game window instead of movable child windows",
	"Arrange All": "n/a: the remake has one game window instead of movable child windows",
	"Auto Arrange": "n/a: the remake has one game window instead of movable child windows",
	"Open Container": "n/a: containers inside the pack aren't in this slice yet",
	# Help
	"Help Contents": "menu_help", "Keyboard Commands": "menu_keys", "Mouse Commands": "menu_help",
	"Spell Directory": "menu_help", "Object Directory": "menu_help", "Bestiary": "menu_help",
	"Inventory Help": "menu_help", "Store Help": "menu_help",
	"Help On Help": "n/a: it described the Windows 3.1 help viewer",
	"High Scores...": "n/a: high scores aren't in this slice yet",
	"Order Information": "n/a: shareware ordering details from 1993",
	"About Castle of the Winds...": "menu_help",
	# Inventory window menu
	"Sort Pack": "n/a: pack sorting isn't in this slice yet",
	"Name Object": "n/a: naming objects comes with identification, which isn't in this slice yet",
}

## Shown in the cheat sheet: action -> [menu group, description].
const DESCRIPTIONS := {
	"move_n": ["Movement", "Move north"], "move_ne": ["Movement", "Move northeast"],
	"move_e": ["Movement", "Move east"], "move_se": ["Movement", "Move southeast"],
	"move_s": ["Movement", "Move south"], "move_sw": ["Movement", "Move southwest"],
	"move_w": ["Movement", "Move west"], "move_nw": ["Movement", "Move northwest"],
	"wait": ["Verbs", "Wait a turn"], "pickup": ["Verbs", "Get"], "examine": ["Verbs", "Examine"],
	"free_hand": ["Verbs", "Free hand"], "search": ["Verbs", "Search for traps and secret doors"],
	"disarm": ["Verbs", "Disarm trap"], "rest": ["Verbs", "Rest until healed"],
	"sleep": ["Verbs", "Sleep until mana is restored"], "open": ["Verbs", "Open a door"],
	"close": ["Verbs", "Close a door"], "stairs_up": ["Verbs", "Climb up stairs"],
	"stairs_down": ["Verbs", "Climb down stairs"], "view": ["Verbs", "View (scroll the map)"],
	"menu_new": ["File", "New game"], "menu_load": ["File", "Load"], "menu_save": ["File", "Save"],
	"menu_save_as": ["File", "Save as"], "menu_options": ["File", "Options"],
	"menu_story": ["File", "Review story"], "menu_quit": ["File", "Exit"],
	"menu_character": ["Character", "Character sheet"], "menu_inventory": ["Inventory", "Inventory"],
	"menu_map": ["Map", "Toggle the large map"], "menu_spellbook": ["Spells", "Spellbook"],
	"menu_activate": ["Activate", "Activate an item"], "menu_log": ["Window", "Message log"],
	"menu_help": ["Help", "Help contents"], "menu_keys": ["Help", "Keyboard commands (this sheet)"],
	"menu_rebind": ["Help", "Change key bindings"],
}
const GROUP_ORDER := ["Movement", "Verbs", "File", "Character", "Inventory", "Map", "Spells", "Activate", "Window", "Help"]
