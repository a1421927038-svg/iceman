extends Control

## Throwaway preview: reproduces what the live game renders when a mouth ball is
## hovered — the engine's TooltipPanel wrapper (themed) with the custom tooltip
## control inside — so the paper card can be eyeballed without hovering.

func _ready() -> void:
	print("gui/theme/custom=", ProjectSettings.get_setting("gui/theme/custom", "<none>"))
	var project_theme: Theme = ThemeDB.get_project_theme()
	print("project_theme=", project_theme, " tooltip_panel=", project_theme != null and project_theme.has_stylebox("panel", "TooltipPanel"))

	var bg := ColorRect.new()
	bg.color = Color(0.85, 0.85, 0.55)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# What the engine wrapper the tooltip actually lives in resolves to.
	var popup := PopupPanel.new()
	popup.set_theme_type_variation("TooltipPanel")
	add_child(popup)
	var resolved: StyleBox = popup.get_theme_stylebox("panel")
	if resolved is StyleBoxFlat:
		print("TOOLTIP_PANEL_BG=", (resolved as StyleBoxFlat).bg_color, " corner=", (resolved as StyleBoxFlat).corner_radius_top_left)

	# The same card, drawn inline so it lands in the captured viewport.
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", resolved)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(card)

	var ball := FridgeYarnBall.new()
	ball.setup("tomato", "番茄钟", true, 5)
	var tip: Object = ball.call("_make_custom_tooltip", "番茄钟\n18 秒")
	if tip is Control:
		card.add_child(tip as Control)

	var card_size := card.get_combined_minimum_size()
	card.size = card_size
	card.position = Vector2(576.0, 324.0) - card_size * 0.5