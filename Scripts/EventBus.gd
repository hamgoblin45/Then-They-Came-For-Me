extends Node

signal show_test_value(key: String, value: float)

signal main_scene_loaded

## -- 3D Interaction
signal looking_at_interactable(Interactable, bool) # Interact icon, text, goes here
signal item_interacted(object: Interactable, interact_type: String, engaged: bool) # Which object, how player is interacting with it, and if engaged or released
signal item_dropped() # also handles throwing, force applied by character.gd
signal item_grabbed(body)

#####-----INTERFACE
signal force_ui_open(open: bool)
signal request_screen_shake(intensity: float, duration: float)
## --- Status
signal change_stat(stat: String, value: float)
signal stat_changed(_stat: String)

signal money_updated(new_total: float)
## --- Inventory
signal inventory_interacted(inv: InventoryData, slot: PanelContainer, slot_data: SlotData, type: String) # Goes to managers, which then emit confirmation signals like "select_item"
signal inventory_item_updated(inv_data: SlotData, index: int) # Emit from Manager to confirm something changed a slot
signal select_item(slot_data: SlotData) # When clicking an item in an inventory, used to set context ui
signal removing_item(item: ItemData, qty: int, slot: SlotData) # Requests removing an item from an inventory
signal adding_item(item_data: ItemData, qty: int) # Requests adding an item to an inventory

signal update_grabbed_slot(slot: SlotData) # for picking up items between inventory slots. emit null to clear out
signal item_discarded(slot_data: SlotData, drop_position: Vector2) # should do the same as item drop AFTER spawning the object

signal request_pockets_inventory # Sent by UI when it's ready to get data
signal setting_pockets_inventory(inv: InventoryData)
signal pockets_inventory_set(inv: InventoryData)

## - External Invs (Containers)
signal setting_external_inventory(inv_data: InventoryData) # Populates container inventories
signal external_inventory_set(inv_data: InventoryData) # Confirms an external inventory was loaded

## - Hotbar
signal using_item(slot_data: SlotData) # Requests use of an item
signal equipping_item(item: ItemData)
signal use_equipped_item
signal drop_equipped_item
signal hotbar_index_changed(index: int)
signal consume_progress(value: float)

## - Splitting
signal open_split_stack_ui(slot_data: SlotData)
signal splitting_item_stack(grab_slot_data: SlotData) # Requests splitting a slot
signal item_stack_split(slot_data: SlotData, orig_slot: SlotData) # Confirms a slot was split

## - Shopping
# Consider changing shopping to emit a string id for shop type if you want different kinds of vendors
signal open_specific_shop(inventory: InventoryData, is_legal: bool)
signal shopping(legal: bool) # Opens up either the legal shop or the black market
signal shop_closed # Resets player inventory slots if they had been disabled for selling
signal selling_item(slot: SlotData) # Requests sale

# Request signals (when attempting)
signal assign_objective(objective: ObjectiveData)
signal advance_objective(objective: ObjectiveData)
signal complete_objective(objective: ObjectiveData)
signal turn_in_objective(objective: ObjectiveData)
signal remove_objective(objective: ObjectiveData)

# Confirmation signals (when succeeded)
signal objective_assigned(objective: ObjectiveData)
signal objective_advanced(objective: ObjectiveData)
signal objective_completed(objective: ObjectiveData)
signal objective_turned_in(objective: ObjectiveData)
signal objective_removed(objective: ObjectiveData)

signal update_objective(objective: ObjectiveData)

signal world_changed(id: String, value: bool)

## --- Searches
signal raid_starting
signal raid_finished
signal answering_door
signal door_opened_for_visitor
signal raid_timer_updated(seconds: float)
signal interrogation_started(item, qty)
signal player_arrested(reason: String, details: String)
signal game_over(reason: String)

## -- PATHING ---
signal setting_path(schedule: ScheduleData, path: PathData)
signal path_finished(npc: NPCData, path: PathData)
signal follow_player(NPC, bool)

## -- GUESTS -- 
signal giving_item(item: SlotData)
signal open_guest_selection_menu(spot: HidingSpot, guests: Array)

## -- VISITORS --
signal visitor_arrived(npc)
signal visitor_leave_requested(npc)
signal toggle_peephole(is_open: bool, description: String)

## -- TIME ---
signal end_day # To initiate day transition
signal change_day() # to initiate the change
signal day_changed() # to acknowledge the change and initiate follow-up logic
signal start_day # To load back into the main scene in a full game

signal hour_changed(hour: int)
signal time_changed(time: float)
signal minute_changed(hour: float, minute: int)

signal set_paused(bool)

## -- END OF DAY
signal show_morning_report(title: String, text: String)
