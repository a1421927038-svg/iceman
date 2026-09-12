class_name CoinPriceButton
extends Button

var show_coin := true


func setup_price(coin_amount: int, unlocked: bool, can_unlock: bool) -> void:
	show_coin = coin_amount > 0
	text = "     %d" % coin_amount if show_coin else "免费"
	disabled = unlocked or not can_unlock
	if unlocked:
		tooltip_text = "已解锁"
	elif can_unlock:
		tooltip_text = "点击解锁"
	else:
		tooltip_text = "金币不足"
	queue_redraw()


func _draw() -> void:
	if not show_coin:
		return
	var center := Vector2(20.0, size.y * 0.5)
	draw_circle(center, 8.0, Color(1.0, 0.78, 0.18, 1.0))
	draw_circle(center, 5.0, Color(1.0, 0.90, 0.36, 1.0))
	draw_arc(center, 8.0, 0.0, TAU, 24, Color(0.62, 0.36, 0.05, 0.95), 1.5, true)
