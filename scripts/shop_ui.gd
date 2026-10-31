class_name ShopUI
extends CanvasLayer
## A simple touch-friendly shop window: a scrolling list of rows, each with a title, a short description and a
## button. Rows are rebuilt from a callable every time something is bought, so prices, stock and
## "sell" counts stay current. Used by the Farmers' Market (buying seeds/saplings/upgrades, selling produce).

var player: Player
var coins: CoinSystem
var title := "Market"
var builder := Callable()        # returns Array of {name, desc, price, label, on_press: Callable, enabled: bool}
var _panel: PanelContainer
var _list: VBoxContainer
var _head: Label
var _open := false


func _ready() -> void:
	layer = 14
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	_panel = PanelContainer.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 40)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.08, 0.05, 0.96)
	sb.border_color = Color(0.9, 0.7, 0.3)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(18)
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	_panel.add_child(vb)
	_head = Label.new()
	_head.add_theme_font_size_override("font_size", 30)
	_head.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	vb.add_child(_head)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.scroll_deadzone = 12
	var bar := sc.get_v_scroll_bar()
	bar.custom_minimum_size = Vector2(40, 0)
	vb.add_child(sc)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 10)
	sc.add_child(_list)
	var close := Button.new()
	close.text = "Close"
	close.custom_minimum_size = Vector2(0, 64)
	close.add_theme_font_size_override("font_size", 28)
	close.pressed.connect(close_shop)
	vb.add_child(close)


func open_shop(t: String, b: Callable) -> void:
	title = t
	builder = b
	_open = true
	visible = true
	player.locked = true
	refresh()


func close_shop() -> void:
	if not _open:
		return
	_open = false
	visible = false
	player.locked = false


func is_open() -> bool:
	return _open


func refresh() -> void:
	_head.text = "%s     %s: %d" % [Loc.t(title), Loc.t("Coins"), coins.balance()]
	for c in _list.get_children():
		c.queue_free()
	var rows: Array = builder.call() if builder.is_valid() else []
	for r in rows:
		var row := r as Dictionary
		if row.has("section"):
			var h := Label.new()
			h.text = Loc.t(String(row["section"]))
			h.add_theme_font_size_override("font_size", 24)
			h.add_theme_color_override("font_color", Color(0.8, 0.9, 0.6))
			_list.add_child(h)
			continue
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 12)
		var tb := VBoxContainer.new()
		tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var n := Label.new()
		n.text = Loc.t(String(row["name"]))
		n.add_theme_font_size_override("font_size", 26)
		tb.add_child(n)
		var d := Label.new()
		d.text = Loc.t(String(row.get("desc", "")))
		d.add_theme_font_size_override("font_size", 20)
		d.add_theme_color_override("font_color", Color(0.75, 0.7, 0.62))
		d.autowrap_mode = TextServer.AUTOWRAP_WORD
		tb.add_child(d)
		hb.add_child(tb)
		var b := Button.new()
		b.text = Loc.t(String(row.get("label", "Buy"))) + ("  %d" % int(row["price"]) if int(row.get("price", 0)) > 0 else "")
		b.custom_minimum_size = Vector2(190, 64)
		b.add_theme_font_size_override("font_size", 24)
		b.disabled = not bool(row.get("enabled", true))
		var cb: Callable = row["on_press"]
		b.pressed.connect(func() -> void:
			cb.call()
			refresh())
		hb.add_child(b)
		_list.add_child(hb)
