extends Node

enum CharacterType { HEALER, GUARD, WORKER, REBEL }
enum Personality { LOYAL, UNRELIABLE, CUNNING }

var player_hp: int = 100
var current_day: int = 1
var days_until_raid: int = 3
var next_raid_size: int = 10
var base_population: Array[Dictionary] = []
var population_limit: int = 50
var resources: Dictionary = {"food": 100, "medicine": 50, "materials": 75}
var game_over: bool = false
var is_paused: bool = false

signal day_passed(new_day: int)
signal raid_warning(days_left: int, raid_size: int)
signal population_changed(population: Array[Dictionary])
signal player_hp_changed(new_hp: int)
signal resources_changed(resources: Dictionary)
signal game_ended(won: bool)

func _ready():
	add_character_to_base(CharacterType.WORKER, Personality.LOYAL)
	add_character_to_base(CharacterType.GUARD, Personality.LOYAL)
	add_character_to_base(CharacterType.HEALER, Personality.LOYAL)

func add_character_to_base(type: CharacterType, personality: Personality):
	var character = {"id": str(Time.get_unix_time_from_system()), "type": type, "personality": personality, "health": 100, "is_injured": false, "days_in_base": 0}
	if base_population.size() < population_limit:
		base_population.append(character)
		population_changed.emit(base_population)

func advance_day():
	if game_over or is_paused: return
	current_day += 1
	days_until_raid -= 1
	for character in base_population: character.days_in_base += 1
	check_for_betrayal()
	if days_until_raid <= 0: trigger_raid()
	consume_daily_resources()
	day_passed.emit(current_day)
	raid_warning.emit(days_until_raid, next_raid_size)
	population_changed.emit(base_population)
	resources_changed.emit(resources)

func check_for_betrayal():
	for character in base_population:
		if character.type == CharacterType.REBEL and randf() < calculate_betrayal_chance(character):
			process_betrayal(character)

func calculate_betrayal_chance(character):
	var chance = 0.1
	match character.personality:
		Personality.UNRELIABLE: chance = 0.3
		Personality.CUNNING: chance = 0.2
		Personality.LOYAL: chance = 0.05
	if character.is_injured: chance += 0.1
	if character.days_in_base > 7: chance += 0.1
	return min(chance, 0.5)

func process_betrayal(traitor):
	base_population.erase(traitor)
	match randi() % 3:
		0: player_hp -= 20
		1: resources.food -= 30
		2: if base_population.size() > 0: base_population.erase(base_population[randi() % base_population.size()])
	player_hp_changed.emit(player_hp)
	population_changed.emit(base_population)
	resources_changed.emit(resources)
	check_game_over()

func trigger_raid():
	var guard_count = count_character_type(CharacterType.GUARD)
	if guard_count < next_raid_size: process_raid_damage(next_raid_size - guard_count)

func process_raid_damage(damage):
	player_hp -= damage * 5
	player_hp_changed.emit(player_hp)
	var casualties = min(damage, base_population.size())
	for i in casualties: 
		if base_population.size() > 0: base_population.erase(base_population[randi() % base_population.size()])
	population_changed.emit(base_population)
	check_game_over()

func count_character_type(type):
	var count = 0
	for character in base_population: 
		if character.type == type: count += 1
	return count

func consume_daily_resources():
	var population_size = base_population.size()
	resources.food -= population_size
	var injured_count = 0
	for character in base_population: 
		if character.is_injured: injured_count += 1
	resources.medicine -= injured_count * 2
	resources_changed.emit(resources)

func process_action_result(hit_location):
	advance_day()
	var result = {"success": false, "population_change": 0, "new_characters": [], "damage_taken": 0}
	match hit_location:
		"head": 
			result.success = true
			result.population_change = 1
			add_character_to_base(CharacterType.WORKER, Personality.LOYAL)
		"chest": 
			result.success = true
			result.population_change = 2
			add_character_to_base(CharacterType.WORKER, Personality.LOYAL)
			var new_rebel = {"id": str(Time.get_unix_time_from_system()), "type": CharacterType.REBEL, "personality": [Personality.LOYAL, Personality.UNRELIABLE, Personality.CUNNING][randi() % 3], "health": 50, "is_injured": true, "days_in_base": 0}
			base_population.append(new_rebel)
		"leg": 
			if randf() < 0.5: 
				result.success = true
				result.population_change = 1
				add_character_to_base(CharacterType.WORKER, Personality.UNRELIABLE)
			else: 
				result.damage_taken = 15
				player_hp -= result.damage_taken
				player_hp_changed.emit(player_hp)
	population_changed.emit(base_population)
	check_game_over()
	return result

func check_game_over():
	if player_hp <= 0 or base_population.size() == 0: 
		game_over = true
		game_ended.emit(false)
	elif current_day >= 100: 
		game_over = true
		game_ended.emit(true)

func get_character_color(type):
	match type:
		CharacterType.HEALER: return Color.BLUE
		CharacterType.GUARD: return Color.GREEN
		CharacterType.WORKER: return Color.GRAY
		CharacterType.REBEL: return Color.RED
	return Color.WHITE

func get_base_status():
	return {"population_size": base_population.size(), "population_limit": population_limit, "guards": count_character_type(CharacterType.GUARD), "healers": count_character_type(CharacterType.HEALER), "workers": count_character_type(CharacterType.WORKER), "rebels": count_character_type(CharacterType.REBEL), "injured_count": count_injured_characters()}

func count_injured_characters():
	var count = 0
	for character in base_population: 
		if character.is_injured: count += 1
	return count
