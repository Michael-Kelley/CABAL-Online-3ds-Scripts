----------------------------------------------------------------
---- Cabal Online custom UI for import/export control
---- Author: Kanaho
----------------------------------------------------------------

--------------------------------
-- Functions
--------------------------------

/* Resets the panel controls (used when resetting 3ds Max) */
function clearebmpanel =
(
	if cabalebmpanel != undefined then
	(
		cabalebmpanel.txt_magic.text = ""
		cabalebmpanel.txt_unk0.text = ""
		cabalebmpanel.txt_flag.text = ""
		cabalebmpanel.txt_alpha.text = ""
		cabalebmpanel.txt_unk1.text = ""
		cabalebmpanel.txt_scale.text = ""
		
		cabalebmpanel.lb_anims.items = #()
		animations = #()
		
		cabalebmpanel.cb_meshonly.checked = false
		
		-- Set the animation slider back to default
		animationrange = interval 0 100
		slidertime = 0
	)
)

--------------------------------
-- Structs
--------------------------------

/* Structure to hold data from the header block */
struct EBMHeader
(
	magic = 0,	-- Magic number (includes file version)
	unk0 = 0,	-- ?
	flag = 0,	-- Model flags (will document this more later)
	alpha_threshold = 0,	-- Alpha threshold for textures
	unk1 = 0,	-- ?
	bounds_min = [0,0,0],	-- Bounding box for entire model
	bounds_max = [0,0,0],
	scale_percentage = 0	-- Scale of entire model (default: 100%)
)

--------------------------------
-- Main
--------------------------------

-- Get rid of any existing dialogs or callbacks
try (cui.unregisterdialogbar ::CabalEBMPanel) catch()
try (destroyDialog ::CabalAnimProps) catch()
try (destroyDialog ::CabalEBMPanel) catch()
try (callbacks.removescripts id:#clearebm) catch()

-- Load our logo image for the panel
logo_path = getsourcefilename()
logo_path = getfilenamepath logo_path
logo_path += "forge_small.png"
logo = openbitmap logo_path

-- Just some globals we need to declare because MaxScript is stupid like that
global file_name
global ebm_header = EBMHeader()
global animations = #()

/* Animation properties dialog
	Allows editing of animation name and length */
rollout CabalAnimProps "Animation Properties"
(
	-- Controls
	edittext txt_anim_name "Name:" fieldwidth:100 offset:[0, 4]
	edittext txt_anim_length "Duration:" align:#right fieldwidth:46 offset:[0, -22]
	
	button btn_ok "Ok" width:68 align:#right offset:[-74, 6]
	button btn_cancel "Cancel" width:68 align:#right offset:[0, -26]
	
	/* Called when this dialog is shown
		Gets the info for the currently selected animation */
	on CabalAnimProps open do
	(
		txt_anim_name.text = cabalebmpanel.lb_anims.selected
		local i = cabalebmpanel.lb_anims.selection
		txt_anim_length.text = (animations[i].end - animations[i].start) as string
	)
	
	/* Called when the "OK" button is clicked
		Applies the changes made to the animation */
	on btn_ok pressed do
	(
		-- Update the animation name and length
		cabalebmpanel.lb_anims.selected = txt_anim_name.text
		local i = cabalebmpanel.lb_anims.selection
		animations[i] = interval animations[i].start (animations[i].start + (txt_anim_length.text as Float))
		
		-- Set the animation slider to the new animation length
		animationrange = animations[i]
		slidertime = animationrange.start
		
		-- Close this dialog
		destroydialog CabalAnimProps
	)
	
	/* Called when the "Cancel" button is clicked
		Just closes this dialog */
	on btn_cancel pressed do
		destroydialog CabalAnimProps
)

/* Model properties panel
	Allows saving, loading and editing of Cabal model files (EBM/ECH) 
	Stores the header data for models */
rollout CabalEBMPanel "Cabal EBM Toolbox"
(
	-- Forge logo
	imgtag forge bitmap:logo style:#bmp_center pos:[4, 0]
	
	-- Group box for EBM/ECH model attributes
	group "EBM:"
	(
		-- Controls
		button btn_open "Open..." width:68 height:18 pos:[10, 104]
		button btn_save "Save..." width:68 height:18 pos:[84, 104]
		
		edittext txt_magic "Magic:" align:#right fieldwidth:48
		edittext txt_unk0 "Unk0:" align:#right fieldwidth:48
		edittext txt_flag "Flag:" align:#right fieldwidth:48
		edittext txt_alpha "Alpha:" align:#right fieldwidth:48
		edittext txt_unk1 "Unk1:" align:#right fieldwidth:48
		edittext txt_scale "Scale:" align:#right fieldwidth:48
		
		listbox lb_anims "Animations:" height:8
		button btn_add "+" width:18 height:18 align:#right offset:[-18, -6]
		button btn_remove "-" width:18 height:18 align:#right offset:[0, -23]
		
		checkbox cb_meshonly "Export only mesh?"
	)
	
	/* Called when the "Open..." button is clicked
		Displays an open file dialog for the user to select a model to import */
	on btn_open pressed do
	(
		-- Call the EBM import script
		scriptfile = "import_ebm_cabal.ms"
		filein scriptfile
		
		-- If a file was selected, populate our controls with the header data
		if file_name != undefined then
		(
			txt_magic.text = bit.intashex ebm_header.magic
			txt_unk0.text = ebm_header.unk0 as string
			txt_flag.text = bit.intashex ebm_header.flag
			txt_alpha.text = ebm_header.alpha_threshold as string
			txt_unk1.text = ebm_header.unk1 as string
			txt_scale.text = (ebm_header.scale_percentage as string) + "%"
			
			cb_meshonly.checked = false
		)
	)
	
	/* Called when the "Save..." button is clicked
		Displays a save file dialog for the user to select where to export the model */
	on btn_save pressed do
	(
		-- Just an error boolean
		error = false
		
		-- Prepare to export the entire scene
		if cb_meshonly.checked == false then
		(
			-- Populate the header structure with the data from our controls
			ebm_header.magic = bit.hexasint txt_magic.text
			ebm_header.unk0 = txt_unk0.text as Integer
			ebm_header.flag = bit.hexasint txt_flag.text
			ebm_header.alpha_threshold = txt_alpha.text as Integer
			ebm_header.unk1 = txt_unk1.text as Integer
			-- Remove the '%' character from the scale before converting to an int
			ebm_scale = txt_scale.text
			ebm_scale = replace ebm_scale ebm_scale.count 1 ""
			ebm_header.scale_percentage = ebm_scale as Integer
		)
		-- Export only the selected mesh if "Export only mesh?" is enabled
		else
		(
			-- Make sure only 1 mesh is selected
			if selection.count > 1 then
			(
				messagebox "Please select only 1 mesh!" title:"Error"
				error = true
			)
			-- Make sure a mesh is selected
			else if selection.count == 0 then
			(
				messagebox "Please select a mesh to export!" title:"Error"
				error = true
			)
			-- Make sure the selected node is a mesh
			else if classof(selection[1]) != editable_mesh then
			(
				messagebox "The selected object is not a mesh!" title:"Error"
				error = true
			)
		)
		
		-- If all the checks passed, call the EBM export script
		if error == false then
		(
			scriptfile = "export_ebm_cabal.ms"
			filein scriptfile
		)
	)
	
	/* Called when the user selects an item from the animation list */
	on lb_anims selected i do
	(
		-- Set the animation slider to the selected animation range
		animationrange = animations[i]
		slidertime = animationrange.start
	)
	
	/* Called when an item in the animation list is double-clicked */
	on lb_anims doubleclicked i do
	(
		-- Destroy any existing animation properties dialog (just in case)
		try (destroyDialog ::CabalAnimProps) catch()
		-- Show the animation properties dialog as a modal window (don't allow user interaction outside of dialog)
		createdialog CabalAnimProps width:274 style:#(#style_toolwindow) modal:true
	)
	
	/* Called when the "+" button below the animations list is clicked
		Adds a new animation to the animation list */
	on btn_add pressed do
	(
		-- Set a default name for the aninmations ("ANIMATION{X}", where {X} is the new animation count)
		lb_anims.items = append lb_anims.items ("ANIMATION " + (lb_anims.items.count + 1) as string)
		lb_anims.selection = lb_anims.items.count
		
		-- Add a new animation range to the animations array
		if animations.count == 0 then
			append animations (interval 1 2)
		else		
			append animations (interval (animations[animations.count].end + 1) (animations[animations.count].end + 2))
		
		-- You should know what this does
		try (destroydialog ::CabalAnimProps) catch()
		createdialog CabalAnimProps width:274 style:#(#style_toolwindow) modal:true
	)
	
	/* Called when the "-" button below the animations list is clicked
		Removes the selected animation */
	on btn_remove pressed do
	(
		-- Remove the selected animation from the list and animations array
		deleteitem animations lb_anims.selection
		lb_anims.items = deleteitem lb_anims.items lb_anims.selection
	)
)

-- Main entry point of our script
-- Creates the panel and docks it to the right
createdialog CabalEBMPanel
cui.registerdialogbar CabalEBMPanel style:#(#cui_dock_right, #cui_floatable) minsize:#(272, 160) maxsize:#(272, 160)
cui.dockdialogbar CabalEBMPanel #cui_dock_right

-- Register a function to be called when 3ds Max is reset
callbacks.addscript #systempostreset "clearebmpanel()" id:#clearebm