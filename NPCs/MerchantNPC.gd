extends NPC
class_name MerchantNPC

@export_category("Merchant Settings")
@export var merchant_id: String = "black_market_1"
@export var is_legal_merchant: bool = false
@export var inventory_pool: InventoryData 
@export var guaranteed_items: Array[ItemData] 

var is_trading: bool = false

func _ready():
	super._ready()
	Dialogic.signal_event.connect(_on_dialogic_signal)
	EventBus.shop_closed.connect(_on_shop_closed)

func open_shop():
	# Print ID to detect duplicates
	print("MerchantNPC (%s): Opening Shop..." % get_instance_id())
	is_trading = true
	
	var config = { "pool": inventory_pool, "guaranteed": guaranteed_items }
	var daily_stock = ShopManager.get_shop_inventory(merchant_id, config)
	
	EventBus.open_specific_shop.emit(daily_stock, is_legal_merchant)

func _on_dialogic_signal(arg):
	# Must match GameState.talking_to (now fixed in VisitorManager)
	if GameState.talking_to != self: return
	
	var signal_name = ""
	if arg is Dictionary:
		signal_name = arg.get("signal_name", "")
	elif arg is String:
		signal_name = arg
	
	if signal_name == "open_shop":
		open_shop()
	
	if signal_name == "visitor_leave":
		EventBus.visitor_leave_requested.emit()

func _on_shop_closed():
	print("MerchantNPC (%s): Recieved shop_closed signal. Is Trading: %s" % [get_instance_id(), is_trading])
	
	if is_trading:
		is_trading = false
		
		# Clear Dialogic
		if Dialogic.current_timeline != null:
			Dialogic.end_timeline()
			
		await get_tree().create_timer(0.1).timeout
		
		# Re-assert focus so DialogueManager knows who we are talking to
		print("MerchantNPC: Starting closing dialogue 'merchant_closing'")
		DialogueManager.start_dialogue("merchant_closing", self ,npc_data.name)
