extends Control

@onready var population_label = $MainContainer/LeftPanel/LeftPanelContainer/BaseStatus/PopulationLabel
@onready var guards_label = $MainContainer/LeftPanel/LeftPanelContainer/BaseStatus/GuardsLabel
@onready var healers_label = $MainContainer/LeftPanel/LeftPanelContainer/BaseStatus/HealersLabel
@onready var workers_label = $MainContainer/LeftPanel/LeftPanelContainer/BaseStatus/WorkersLabel
@onready var rebels_label = $MainContainer/LeftPanel/LeftPanelContainer/BaseStatus/RebelsLabel
@onready var raid_timer = $MainContainer/LeftPanel/LeftPanelContainer/RaidWarning/RaidWarningContainer/RaidTimer
@onready var raid_size = $MainContainer/LeftPanel/LeftPanelContainer/RaidWarning/RaidWarningContainer/RaidSize
@onready var base_area = $MainContainer/LeftPanel/LeftPanelContainer/BaseArea
@onready var head_target = $MainContainer/CenterPanel/CenterPanelContainer/ActionArea/TargetContainer/HeadTarget
@onready var chest_target = $MainContainer/CenterPanel/CenterPanelContainer/ActionArea/TargetContainer/ChestTarget
@onready var leg_target = $MainContainer/CenterPanel/CenterPanelContainer/ActionArea/TargetContainer/LegTarget
@onready var crosshair = $MainContainer/CenterPanel/CenterPanelContainer/ActionArea/Crosshair
@onready var timer_label = $MainContainer/CenterPanel/CenterPanelContainer/ActionArea/TimerLabel
@onready var hp_label = $MainContainer/RightPanel/RightPanelContainer/PlayerStats/HPLabel
@onready var hp_bar = $MainContainer/RightPanel/RightPanelContainer/PlayerStats/HPBar
@onready var day_label = $MainContainer/RightPanel/RightPanelContainer/PlayerStats/DayLabel
@onready var food_label = $MainContainer/RightPanel/RightPanelContainer/Resources/FoodLabel
@onready var medicine_label = $MainContainer/RightPanel/RightPanelContainer/Resources/MedicineLabel
@onready var materials_label = $MainContainer/RightPanel/RightPanelContainer/Resources/MaterialsLabel
@onready var pause_button = $MainContainer/RightPanel/RightPanelContainer/GameControls/PauseButton
@onready var restart_button = $MainContainer/RightPanel/RightPanelContainer/GameControls/RestartButton

func _ready():
	GameManager.day_passed.connect(_on_day_passed)
	GameManager.raid_warning.connect(_on_raid_warning)
	GameManager.population_changed.connect(_on_population_changed)
	GameManager.player_hp_changed.connect(_on_player_hp_changed)
	GameManager.resources_changed.connect(_on_resources_changed)
	GameManager.game_ended.connect(_on_game_ended)
	head_target.pressed.connect(_on_head_target_pressed)
	chest_target.pressed.connect(_on_chest_target_pressed)
	leg_target.pressed.connect(_on_leg_target_pressed)
	pause_button.pressed.connect(_on_pause_button_pressed)
	restart_button.pressed.connect(_on_restart_button_pressed)
	update_ui_from_game_manager()
	start_action_timer()

func update_ui_from_game_manager():
	var base_status = GameManager.get_base_status()
	population_label.text = "Population: %d/%d" % [base_status.population_size, GameManager.population_limit]
	guards_label.text = "Guards: %d" % base_status.guards
	healers_label.text = "Healers: %d" % base_status.healers
	workers_label.text = "Workers: %d" % base_status.workers
	rebels_label.text = "Rebels: %d" % base_status.rebels
	hp_label.text = "HP: %d/100" % GameManager.player_hp
	hp_bar.value = GameManager.player_hp
	day_label.text = "Day: %d" % GameManager.current_day
	food_label.text = "Food: %d" % GameManager.resources.food
	medicine_label.text = "Medicine: %d" % GameManager.resources.medicine
	materials_label.text = "Materials: %d" % GameManager.resources.materials
	raid_timer.text = "%d days until raid" % GameManager.days_until_raid
	raid_size.text = "%d rebels will attack" % GameManager.next_raid_size

func _on_day_passed(new_day): update_ui_from_game_manager()
func _on_raid_warning(days_left, raid_size): update_ui_from_game_manager()
func _on_population_changed(population): update_ui_from_game_manager(), update_base_area_visuals()
func _on_player_hp_changed(new_hp): update_ui_from_game_manager()
func _on_resources_changed(resources): update_ui_from_game_manager()
func _on_game_ended(won): show_game_message("VICTORY!" if won else "GAME OVER", "You survived 100 days!" if won else "You didn't survive...")

func show_game_message(title, message):
	var popup = AcceptDialog.new()
	popup.dialog_text = message
	popup.title = title
	add_child(popup)
	popup.popup_centered()

func _on_head_target_pressed(): process_action("head")
func _on_chest_target_pressed(): process_action("chest")
func _on_leg_target_pressed(): process_action("leg")

func process_action(hit_location):
	if GameManager.game_over or GameManager.is_paused: return
	var result = GameManager.process_action_result(hit_location)
	show_action_feedback(hit_location, result)
	start_action_timer()

func show_action_feedback(hit_location, result):
	var feedback_text = ""
	match hit_location: "head": feedback_text = "Headshot! Victim saved (+1 population)" if result.success else "Missed!"
	"chest": feedback_text = "Chest shot! Both saved (+2 population, 1 injured)" if result.success else "Missed!"
	"leg": feedback_text = "Leg shot! Enemy surrendered (+1 worker)" if result.success else "Counter-attack! -%d HP" % result.damage_taken
	timer_label.text = feedback_text
	timer_label.modulate = Color.GREEN if result.success else Color.RED
	await get_tree().create_timer(2.0).timeout
	timer_label.modulate = Color.WHITE

func start_action_timer():
	var time_left = 3.0
	while time_left > 0 and not GameManager.game_over and not GameManager.is_paused:
		timer_label.text = "Time: %.1f" % time_left
		await get_tree().create_timer(0.1).timeout
		time_left -= 0.1
	if time_left <= 0 and not GameManager.game_over: process_action("missed")

func update_base_area_visuals():
	for child in base_area.get_children(): child.queue_free()
	var population = GameManager.base_population
	var area_size = base_area.size
	var character_size = 20
	for i in range(population.size()):
		var character = population[i]
		var char_rect = ColorRect.new()
		char_rect.size = Vector2(character_size, character_size)
		char_rect.color = GameManager.get_character_color(character.type)
		var x = randf() * (area_size.x - character_size)
		var y = randf() * (area_size.y - character_size)
		char_rect.position = Vector2(x, y)
		if character.is_injured:
			var injury_indicator = ColorRect.new()
			injury_indicator.size = Vector2(4, 4)
			injury_indicator.position = Vector2(character_size - 4, 0)
			injury_indicator.color = Color.RED
			char_rect.add_child(injury_indicator)
		base_area.add_child(char_rect)
		animate_character_movement(char_rect, area_size, character_size)

func animate_character_movement(character, area_size, char_size):
	var tween = create_tween()
	tween.set_loops()
	while true:
		var target_x = randf() * (area_size.x - char_size)
		var target_y = randf() * (area_size.y - char_size)
		tween.tween_property(character, "position", Vector2(target_x, target_y), 2.0 + randf() * 2.0)
		await tween.finished

func _on_pause_button_pressed():
	GameManager.is_paused = not GameManager.is_paused
	pause_button.text = "Resume Game" if GameManager.is_paused else "Pause Game"

func _on_restart_button_pressed():
	GameManager.player_hp = 100
	GameManager.current_day = 1
	GameManager.days_until_raid = 3
	GameManager.next_raid_size = 10
	GameManager.base_population.clear()
	GameManager.resources = {"food": 100, "medicine": 50, "materials": 75}
	GameManager.game_over = false
	GameManager.is_paused = false
	GameManager.add_character_to_base(GameManager.CharacterType.WORKER, GameManager.Personality.LOYAL)
	GameManager.add_character_to_base(GameManager.CharacterType.GUARD, GameManager.Personality.LOYAL)
	GameManager.add_character_to_base(GameManager.CharacterType.HEALER, GameManager.Personality.LOYAL)
	update_ui_from_game_manager()
	start_action_timer()
