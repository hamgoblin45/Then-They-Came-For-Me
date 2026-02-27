extends Node3D

#var time: float
#@export var day_length: float = 800000.0
@export var start_time: float = 0.25

var time_rate: float = 0.0001

@onready var timer: Timer = $Timer


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
	##GameTime.cycle_time = start_time
	#if GameTime.day <= 1:
		#GameTime.time = 17
	#
	#GameTime.cycle_time = GameTime.time / 24
	
	sun = get_node("Sun")
	moon = get_node("Moon")
	environment = get_node("Sky/WorldEnvironment")
	
	
	#handle_time()
	
	sky_material = environment.environment.sky.sky_material
	
	#set_weather()

#func handle_time():
	#GameTime.time = 1440 * GameTime.cycle_time / 60
	#GameTime.hour = floor(GameTime.time)
	#var minute_fraction = GameTime.time - GameTime.hour
	#GameTime.minute = 60 * minute_fraction
	#
	##print("Hour: %s" % GameTime.hour)
	##print("Minute: %s" % GameTime.minute)
	##print("It is %s minute" % minute_fraction)
	#if GameTime.cycle_time >= 1.0:
		##next_day()
		#GameTime.cycle_time = 0.0
		#
		### Ends the day if past 4am
		#if GameTime.time >= 4 and GameTime.time < 5:
			#Global.main_viewport.end_day()

## Controls sun, moon, light, and color of sky
func handle_sky():
		#SUN
		#sun.rotation_degrees.x = GameTime.cycle_time * 360 + 90
		#sun.light_color = sun_color.sample(GameTime.cycle_time)
		#sun.light_energy = sun_intensity.sample(GameTime.cycle_time)
		
		#MOON
		#moon.rotation_degrees.x = GameTime.cycle_time * 360 + 270
		#moon.light_color = moon_color.sample(GameTime.cycle_time)
		#moon.light_energy = moon_intensity.sample(GameTime.cycle_time)
		
		# VISIBILITY
		sun.visible = sun.light_energy > 0
		moon.visible = moon.light_energy > 0
		
		#SKY COLOR
		#environment.environment.sky.sky_material.set_shader_parameter("top_color", sky_top_color.sample(GameTime.cycle_time))
		#environment.environment.sky.sky_material.set_shader_parameter("bottom_color", sky_horizon_color.sample(GameTime.cycle_time))
		#environment.environment.sky.sky_material.set_shader_parameter("clouds_light_color", cloud_light_color.sample(GameTime.cycle_time))
		
		var star_intensity: float
		var cloud_shadow_intensity: float
		
		#if GameTime.time < 6.0 or GameTime.time > 20.0:
			#if star_intensity != 1.0:
				#star_intensity = 1.0
			#if cloud_shadow_intensity != 0.0:
				#cloud_shadow_intensity = 0.0
		#elif GameTime.time > 8.0 or GameTime.time < 18.0:
			#if star_intensity != 0.0:
				#star_intensity = 0.0
			#if cloud_shadow_intensity != 1.0:
				#cloud_shadow_intensity = 1.0
			#
		#if GameTime.time > 18.0 and GameTime.time <= 20.0:
			#star_intensity = (GameTime.time - 18.0) / 2
			#cloud_shadow_intensity = ((20.0 - GameTime.time) / 2)
		
		#if GameTime.time < 8.0 and GameTime.time >= 6.0:
		#cloud_shadow_intensity = (GameTime.time - 6.0) / 2
		#star_intensity = ((8.0 - GameTime.time) / 2)
		#_star_intensity
		#if star_intensity < 1.0:
			#star_intensity += 0.1
			#if star_intensity > 1.0:
				#star_intensity = 1.0
		print("Star intensity: %s" % str(star_intensity))
			#if cloud_shadow_intensity > 0.0:
				#cloud_shadow_intensity -= 0.05
				#if cloud_shadow_intensity < 0.0:
					#cloud_shadow_intensity = 0.0
		#if GameTime.time >= 0.3 or GameTime.time <= 0.75:
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
		#environment.environment.sky.sky_material.set("ground_bottom_color", sky_top_color.sample(GameTime.cycle_time))
		#environment.environment.sky.sky_material.set("ground_horizon_color", sky_horizon_color.sample(GameTime.cycle_time))
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
			##if GameTime.season == "Spring":
			#
			#weather_options = [
				#"sunny",
				#"cloudy",
				#"rain"
			#]
		#
			#var last_day
			#if Save.weathers.size() <= 0:
				#last_day = GameTime.day
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
			#if forecast.day == GameTime.day:
				#GameTime.weather = forecast.type
		#
		#
		#match GameTime.weather:
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
			##GameTime.cycle_time = 0.0
			##GameTime.day += 1
			##GameTime.overall_day += 1
			##
			##match GameTime.weekday:
				##"Monday":
					##GameTime.weekday = "Tuesday"
				##"Tuesday":
					##GameTime.weekday = "Wednesday"
				##"Wednesday":
					##GameTime.weekday = "Thursday"
				##"Thursday":
					##GameTime.weekday = "Friday"
				##"Friday":
					##GameTime.weekday = "Saturday"
				##"Saturday":
					##GameTime.weekday = "Sunday"
				##"Sunday":
					##GameTime.weekday = "Monday"
			##
			##if GameTime.day >= 29:
				##GameTime.day = 1
				##match GameTime.season:
					##"Spring":
						##GameTime.season = "Summer"
					##"Summer":
						##GameTime.season = "Fall"
					##"Fall":
						##GameTime.season = "Winter"
					##"Winter":
						##GameTime.season = "Spring"
#
#func handle_lights():
	#if GameTime.time >= 17.5 or GameTime.time < 6.0:
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
		#GameTime.cycle_time += time_rate * GameTime.time_speed
		#
		##print("Cycle Time: %f" % GameTime.cycle_time)
		##print("Time: %f" % GameTime.time)
		#
		#handle_time()
		#
		#handle_sky()
		#
		#handle_lights()
		#GameTime.time_tracker()
