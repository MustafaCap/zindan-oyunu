## Events — oyun genelindeki sinyal merkezi.
## Sistemler birbirini doğrudan çağırmak yerine buradaki sinyallerle haberleşir.
extends Node

# Run akışı
signal run_started(race_id: String)
signal run_ended(victory: bool, floor_reached: int)
signal floor_entered(floor_index: int)

# Oda akışı
signal room_entered(room_id: int)
signal room_cleared(room_id: int)

# Savaş
signal damage_dealt(source: Node, target: Node, amount: float, is_crit: bool, element: String)
signal enemy_killed(enemy: Node, is_elite: bool, is_boss: bool)
signal player_damaged(amount: float)
signal player_died()
signal combo_triggered(combo_id: String, target: Node)

# İlerleme
signal xp_gained(amount: float)
signal level_up(new_level: int)
signal reward_offered(source: String, choices: Array)

# Envanter
signal inventory_changed()
signal gold_changed(new_amount: int)
