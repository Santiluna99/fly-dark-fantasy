# Hollowfly - Copyright (C) 2026 Santiluna99
# Software libre bajo la GNU GPL v3 (ver LICENSE y NOTICE).
extends Node
func _ready() -> void:
	var m = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(m)
	var mx := -99.0; var mn := 99.0; var steep := 0; var n := 0; var water := 0; var hi := 0
	for i in 160:
		for j in 160:
			var x := -120.0 + i * 1.5; var z := -120.0 + j * 1.5
			var h: float = m.height_at(x, z)
			if h > mx: mx = h
			if h < mn: mn = h
			n += 1
			if h < m.WATER: water += 1
			if h > 6.0: hi += 1
			var sl: float = (absf(m.height_at(x + 1.5, z) - h) + absf(m.height_at(x, z + 1.5) - h)) / 1.5
			if sl > 1.0: steep += 1
	print("TERRENO max=", snappedf(mx, 0.1), " min=", snappedf(mn, 0.1), " agua%=", snappedf(100.0 * water / n, 0.1), " h>6%=", snappedf(100.0 * hi / n, 0.1), " empinado(>45°)%=", snappedf(100.0 * steep / n, 0.1))
	get_tree().quit()
