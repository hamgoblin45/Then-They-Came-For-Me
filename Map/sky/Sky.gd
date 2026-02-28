extends Node3D

var sun: DirectionalLight3D
@export var sun_color: Gradient
@export var sun_intensity: Curve

var moon: DirectionalLight3D
@export var moon_color: Gradient
@export var moon_intensity: Curve

# Environment
var environment: WorldEnvironment
var sky_material: Material
@export var sky_top_color: Gradient
@export var sky_horizon_color: Gradient
@export var cloud_light_color: Gradient




func _ready():
	sun = get_node("Sun")
	moon = get_node("Moon")
	environment = get_node("Sky/WorldEnvironment")
	
	
	handle_sky(GameState.hour, GameState.minute)
	
	sky_material = environment.environment.sky.sky_material
	
	EventBus.minute_changed.connect(handle_sky)
	
	#set_weather()


## Controls sun, moon, light, and color of sky
func handle_sky(hour: int, _m: int):
	#SUN
	sun.rotation_degrees.x = GameState.cycle_time * 360 + 90
	sun.light_color = sun_color.sample(GameState.cycle_time)
	sun.light_energy = sun_intensity.sample(GameState.cycle_time)
	
	#MOON
	moon.rotation_degrees.x = GameState.cycle_time * 360 + 270
	moon.light_color = moon_color.sample(GameState.cycle_time)
	moon.light_energy = moon_intensity.sample(GameState.cycle_time)
	
	# VISIBILITY
	sun.visible = sun.light_energy > 0
	moon.visible = moon.light_energy > 0
	
	#SKY COLOR
	environment.environment.sky.sky_material.set_shader_parameter("top_color", sky_top_color.sample(GameState.cycle_time))
	environment.environment.sky.sky_material.set_shader_parameter("bottom_color", sky_horizon_color.sample(GameState.cycle_time))
	environment.environment.sky.sky_material.set_shader_parameter("clouds_light_color", cloud_light_color.sample(GameState.cycle_time))
	
	var star_intensity: float
	var cloud_shadow_intensity: float
	
	if hour < 6.0 or hour > 20.0:
		if star_intensity != 1.0:
			star_intensity = 1.0
		if cloud_shadow_intensity != 0.0:
			cloud_shadow_intensity = 0.0
	elif hour > 8.0 or hour < 18.0:
		if star_intensity != 0.0:
			star_intensity = 0.0
		if cloud_shadow_intensity != 1.0:
			cloud_shadow_intensity = 1.0
		
	if hour > 18.0 and hour <= 20.0:
		star_intensity = (hour - 18.0) / 2
		cloud_shadow_intensity = ((20.0 - hour) / 2)
	
	if hour < 8.0 and hour >= 6.0:
		cloud_shadow_intensity = (hour - 6.0) / 2
		star_intensity = ((8.0 - hour) / 2)
		if star_intensity < 1.0:
			star_intensity += 0.1
			if star_intensity > 1.0:
				star_intensity = 1.0
		print("Star intensity: %s" % str(star_intensity))
		#if cloud_shadow_intensity > 0.0:
			#cloud_shadow_intensity -= 0.05
			#if cloud_shadow_intensity < 0.0:
				#cloud_shadow_intensity = 0.0
	#if GameState.time >= 0.3 or GameState.time <= 0.75:
		#if star_intensity > 0.0:
			#star_intensity -= 0.1
			#if star_intensity < 0.0:
				#star_intensity = 0.0
		#if cloud_shadow_intensity < 1.0:
			#cloud_shadow_intensity += 0.05
			#if cloud_shadow_intensity > 1.0:
				#cloud_shadow_intensity = 1.0
	
	environment.environment.sky.sky_material.set_shader_parameter("stars_intensity", star_intensity)
	environment.environment.sky.sky_material.set_shader_parameter("clouds_shadow_intensity", cloud_shadow_intensity)
	#environment.environment.sky.sky_material.set("ground_bottom_color", sky_top_color.sample(GameState.cycle_time))
	#environment.environment.sky.sky_material.set("ground_horizon_color", sky_horizon_color.sample(GameState.cycle_time))
#
### sets weather effects based on what var weather is set to by new_day() and/or _ready()
### The code to decide what weather it is has not been written yet, put that in new_day()
### Call new_day() after day transition. Maybe just from _ready() since DayNightCycle enters the scene after DayTransition
#func set_weather():
	#if Global.player:
		#print("Setting weather...")
		### Picks new weather
		#if Save.weathers.size() < 7:
			#var weather_options = []
			##if GameState.season == "Spring":
			#
			#weather_options = [
				#"sunny",
				#"cloudy",
				#"rain"
			#]
		#
			#var last_day
			#if Save.weathers.size() <= 0:
				#last_day = GameState.day
			#else:
				#last_day = Save.weathers[-1].day
			#
			#for i in 7 - Save.weathers.size():
				#var selected_weather = weather_options.pick_random()
				#if selected_weather == "rain":
					#var intensities = ["rain_light","rain_normal","rain_heavy"]
					#selected_weather = intensities.pick_random()
				#var weather_data = WeatherData.new()
				#weather_data.type = selected_weather
				#
				#weather_data.day = last_day
				#Save.weathers.append(weather_data)
				#
				#last_day += 1
				#
				#print("Selected weather for %s: %s" % [str(weather_data.day), weather_data.type])
			#
		#
		### Assigns pre-picked weather
		#
		#for forecast in Save.weathers:
			#if forecast.day == GameState.day:
				#GameState.weather = forecast.type
		#
		#
		#match GameState.weather:
			#"rain_light":
				#environment.environment.volumetric_fog_enabled = true
				#environment.environment.volumetric_fog_density = 0.005
				#environment.environment.sky.sky_material.set_shader_parameter("clouds_density", 0.7)
				#environment.environment.sky.sky_material.set_shader_parameter("fog_sun_scatter", 0.7)
				#sun.light_energy = 0.6
				#weather_node = RAIN_LIGHT.instantiate()
				##rain.global_position = Global.player.global_position
			#"rain_normal":
				#environment.environment.volumetric_fog_enabled = true
				#environment.environment.volumetric_fog_density = 0.02
				#environment.environment.sky.sky_material.set_shader_parameter("clouds_density", 0.8)
				#environment.environment.sky.sky_material.set_shader_parameter("fog_sun_scatter", 0.0)
				#sun.light_energy = 0.2
				#weather_node = RAIN_NORMAL.instantiate()
			#"rain_heavy":
				#environment.environment.volumetric_fog_enabled = true
				#environment.environment.volumetric_fog_density = 0.04
				#environment.environment.sky.sky_material.set_shader_parameter("clouds_density", 0.8)
				#environment.environment.sky.sky_material.set_shader_parameter("fog_sun_scatter", 0.0)
				#sun.light_energy = 0.1
				#weather_node = RAIN_HEAVY.instantiate()
			#"snow":
				#environment.environment.volumetric_fog_enabled = true
				#environment.environment.volumetric_fog_density = 0.03
				#environment.environment.sky.sky_material.set_shader_parameter("clouds_density", 0.7)
				#environment.environment.sky.sky_material.set_shader_parameter("fog_sun_scatter", 0.0)
				#sun.light_energy = 0.1
				#weather_node = SNOW.instantiate()
		#
		#Global.player.add_child(weather_node)
#
### Rolls over time to a new day
##func next_day():
			###Make it so each day has to be ended, like Stardew. If it reaches a certain time, Player passes out and loses
			###some resource.
			##
			##GameState.cycle_time = 0.0
			##GameState.day += 1
			##GameState.overall_day += 1
			##
			##match GameState.weekday:
				##"Monday":
					##GameState.weekday = "Tuesday"
				##"Tuesday":
					##GameState.weekday = "Wednesday"
				##"Wednesday":
					##GameState.weekday = "Thursday"
				##"Thursday":
					##GameState.weekday = "Friday"
				##"Friday":
					##GameState.weekday = "Saturday"
				##"Saturday":
					##GameState.weekday = "Sunday"
				##"Sunday":
					##GameState.weekday = "Monday"
			##
			##if GameState.day >= 29:
				##GameState.day = 1
				##match GameState.season:
					##"Spring":
						##GameState.season = "Summer"
					##"Summer":
						##GameState.season = "Fall"
					##"Fall":
						##GameState.season = "Winter"
					##"Winter":
						##GameState.season = "Spring"
#
#func handle_lights():
	#if GameState.time >= 17.5 or GameState.time < 6.0:
		#for lamp in get_tree().get_nodes_in_group("lamps"):	
			#lamp.light_on()
	#else:
		#for lamp in get_tree().get_nodes_in_group("lamps"):	
			#lamp.light_off()
#
### Controls time in a more optimized manner than running it in _process()
#func _on_timer_timeout() -> void:
	#
	##if Objectives.day_1_tour_complete:
	#
		#GameState.cycle_time += time_rate * GameState.time_speed
		#
		##print("Cycle Time: %f" % GameState.cycle_time)
		##print("Time: %f" % GameState.time)
		#
		#handle_time()
		#
		#handle_sky()
		#
		#handle_lights()
		#GameState.time_tracker()
