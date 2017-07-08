----------------------------------------------------------------
---- Cabal Online EBM file importer script
---- Author: Kanaho
----------------------------------------------------------------

--------------------------------
-- Functions
--------------------------------

/* Reads a string of length '_length' from the file */
function readtext _file _length =
(
	local result = ""
	
	-- Read each byte, convert it to a character, and append it to our string
	for i = 1 to _length do
	(
		next_byte = readbyte _file
		result += bit.intaschar(next_byte)
	)
	
	-- Return the resulting string
	result
)

/* Reads the header chunk from the file */
function readheader _file =
(
	ebm_header = EBMHeader()
	
	-- Populate the header struct with the data from the file
	ebm_header.magic = readlong _file #unsigned
	ebm_header.unk0 = readshort _file #unsigned
	ebm_header.flag = readbyte _file #unsigned
	ebm_header.alpha_threshold = readbyte _file #unsigned
	ebm_header.unk1 = readshort _file #unsigned
	x = readfloat _file; y = readfloat _file; z = readfloat _file
	ebm_header.bounds_min = [x, y, z]
	x = readfloat _file; y = readfloat _file; z = readfloat _file
	ebm_header.bounds_max = [x, y, z]
	ebm_header.scale_percentage = readlong _file
)

/* Reads the materials chunk from the file */
function readmaterials _file =
(
	global in_materials = #()
	mat_count = readshort _file
	
	-- Iterate through each material and read its data
	for i = 1 to mat_count do
	(
		-- Colours need to be converted from a max value of 1.0 to a max value of 255
		r = readfloat _file; g = readfloat _file; b = readfloat _file; a = readfloat _file
		mp_ambient = color (r * 255) (g * 255) (b * 255) (a * 255)
		
		r = readfloat _file; g = readfloat _file; b = readfloat _file; a = readfloat _file
		mp_diffuse = color (r * 255) (g * 255) (b * 255) (a * 255)
		
		r = readfloat _file; g = readfloat _file; b = readfloat _file; a = readfloat _file
		mp_specular = color (r * 255) (g * 255) (b * 255) (a * 255)
		
		r = readfloat _file; g = readfloat _file; b = readfloat _file; a = readfloat _file
		mp_emissive = color (r * 255) (g * 255) (b * 255) (a * 255)
		
		-- Self-illumination strength
		mp_power = readfloat _file
		
		-- Read the texture name
		name_length = readshort _file
		tex_name = readtext _file name_length
		
		-- Read the texture data and save it as an external file
		tex_size = readlong _file #unsigned
		tex_file = (pathconfig.getdir #import) + "\\" + tex_name
		tex_out = fopen tex_file "wb"
		
		for j = 1 to tex_size do
		(
			val = readbyte _file
			writebyte tex_out val
		)
		
		fclose tex_out
		
		-- Open the saved texture file
		tex = openbitmap tex_file
		tex_bmp = bitmaptexture bitmap:tex
		
		-- Create the material and set its attributes
		local new_mat = standard name:tex_name
		new_mat.adlock = false
		new_mat.diffusemap = tex_bmp
		new_mat.showinviewport = true
		new_mat.ambient = mp_ambient
		new_mat.diffuse = mp_diffuse
		new_mat.specular = mp_specular
		new_mat.selfillumination = mp_power
		new_mat.filtercolor = mp_emissive
		
		-- Add the material to an array for later use
		append in_materials new_mat
		
		-- Skip the Layer information for now
		fseek _file 26 #seek_cur
	)
)

/* Reads the bones from the file */
function readarmature _file =
(
	-- More globals!
	global bone_array = #()
	global bone_names = #()
	global bone_matrices = #()
	global bone_p_matrices = #()
	
	global bone_count = readshort _file
	
	-- Set our array lengths
	bone_array.count = bone_count
	bone_names.count = bone_count
	bone_matrices.count = bone_count
	bone_p_matrices.count = bone_count
	
	-- Iterate through each bone and read its data
	for i = 1 to bone_count do
	(
		-- Read the bone name
		local name_length = readshort _file
		local bone_name = readtext _file name_length
		bone_names[i] = bone_name
		
		-- Read the parent bone ID
		parent_id = readlong _file
		
		-- Read the transformation matrix
		m11 = readfloat _file; m12 = readfloat _file; m13 = readfloat _file
		readfloat _file
		m21 = readfloat _file; m22 = readfloat _file; m23 = readfloat _file
		readfloat _file
		m31 = readfloat _file; m32 = readfloat _file; m33 = readfloat _file
		readfloat _file
		m41 = readfloat _file; m42 = readfloat _file; m43 = readfloat _file
		readfloat _file
		
		-- Read the parent transformation matrix (not actually used by 3ds Max)
		pm11 = readfloat _file; pm12 = readfloat _file; pm13 = readfloat _file
		readfloat _file
		pm21 = readfloat _file; pm22 = readfloat _file; pm23 = readfloat _file
		readfloat _file
		pm31 = readfloat _file; pm32 = readfloat _file; pm33 = readfloat _file
		readfloat _file
		pm41 = readfloat _file; pm42 = readfloat _file; pm43 = readfloat _file
		readfloat _file
		
		-- Create 4x3 matrices from the data we read and add it to our arrays
		tm = matrix3 \
			[m11, m12, m13] \
			[m21, m22, m23] \
			[m31, m32, m33] \
			[m41, m42, m43]
			
		bone_matrices[i] = tm
		
		-- Invert the transformation matrix because Cabal is ghey like that
		tm = inverse tm
		
		ptm = matrix3 \
			[pm11, pm12, pm13] \
			[pm21, pm22, pm23] \
			[pm31, pm32, pm33] \
			[pm41, pm42, pm43]
			
		bone_p_matrices[i] = ptm
		
		-- Create a bone and set its attributes
		new_bone = bonesys.createbone [0, 0, 0] [0, 0, 0] [0, 0, 0]
		new_bone.transform = tm
		new_bone.name = bone_name
		new_bone.wirecolor = yellow
		
		-- Set the bones parent if it has one
		if (parent_id > -1) then
			new_bone.parent = bone_array[parent_id + 1]
		
		-- Add the bone to an array for later use
		bone_array[i] = new_bone
	)
	
	-- Reset the stretch of all bones so that they extend to their child (stupid 3ds Max...)
	for i in 1 to bone_count do
		bone_array[i].resetbonestretch()
)

function readanimations _file =
(
	anim_count = readshort _file
	
	animate off
	
	offset = 1f
	
	-- Initialise our animations list and array
	cabalebmpanel.lb_anims.items = #()
	animations = #()
	
	-- Iterate through each animation and read its data
	for i = 1 to anim_count do
	(
		-- Read the animation name
		local name_length = readshort _file
		local anim_name = readtext _file name_length
		
		cabalebmpanel.lb_anims.items = append cabalebmpanel.lb_anims.items anim_name
		
		local trans_count = readshort _file
		
		local anim_length = 0f
		
		-- Tell 3ds Max to start making keys
		with animate on
		(
			-- Iterate through each transform and read its data
			for j = 1 to trans_count do
			(
				-- Read the affected node name
				local name_length = readshort _file
				local node_name = readtext _file name_length
				local anim_node = getnodebyname node_name
				
				local t_count = readlong _file
				
				-- Iterate through each translation and read its data
				for k = 1 to t_count do
				(
					local kfs = readfloat _file	-- Keyframe second
					local x = readfloat _file	-- New position (relative to parent)
					local y = readfloat _file
					local z = readfloat _file
					
					transl = [x, y, z]
					
					-- Get the animation length
					if (kfs * 30.0) > anim_length then
						anim_length = (kfs * 30.0)
					
					if ebm_header.magic < 0x3ef03 then
						at time (offset + kfs * 30.0) (in coordsys parent anim_node.pos = transl)
					--else
						--at time (offset + kfs * 30) _node.pos = [_x, _y, _z]
				)
				
				local r_count = readlong _file				
				
				-- Iterate through each rotation and read its data
				for k = 1 to r_count do
				(
					local kfs = readfloat _file
					local x = readfloat _file	-- New rotation (relative to parent)
					local y = readfloat _file
					local z = readfloat _file
					local w = readfloat _file
					
					-- Create a quaternion from the read data and inverse it
					rot = quat x y z w
					rot = inverse rot
					
					if (kfs * 30.0) > anim_length then
						anim_length = (kfs * 30.0)
					
					if ebm_header.magic < 0x3ef03 then
						at time (offset + kfs * 30.0) (in coordsys parent anim_node.rotation = rot)
					--else
						--at time (offset + kfs * 30) (in coordsys ((matrix3 1) * (transmatrix _node.transform.pos)) _node.rotation = _q)
				)
			)
		)
		
		-- Add our animation range to an array for later use
		animations[i] = interval offset (offset + anim_length)
		
		-- Increase the offset by the animation length and leave a 1 frame gap
		offset += anim_length + 1
	)
	
	-- Set the animation range to the first animation
	if animations.count > 0 then
		animationrange = animations[1]
	else
		animationrange = interval 0 100
)

/* Reads the meshes from the file */
function readmeshes _file =
(
	mesh_count = readshort _file
	
	-- Iterate through each mesh and read its data
	for c = 1 to mesh_count do
	(
		vert_array = #()
		normal_array = #()
		tvert_array = #()
		face_array = #()
		
		-- Read the mesh name
		name_length = readshort _file
		mesh_name = readtext _file name_length
		
		-- Skip the matrices for now as we don't need them
		fseek _file 128 #seek_cur
		
		root_bone = readlong _file
		mat_id = readbyte _file #unsigned
		
		vert_count = readshort _file #unsigned
		face_count = readshort _file #unsigned
		
		-- Initialise our data arrays
		vert_array.count = vert_count
		normal_array.count = vert_count
		tvert_array.count = vert_count
		face_array.count = face_count
		
		-- Iterate through each vertex and read its data
		for i = 1 to vert_count do
		(
			x = readfloat _file; y = readfloat _file; z = readfloat _file
			norm_x = readfloat _file; norm_y = readfloat _file; norm_z = readfloat _file
			uv_x = readfloat _file; uv_y = readfloat _file
			
			vert_array[i] = [x, y, z]
			normal_array[i] = [norm_x, norm_y, norm_z]
			tvert_array[i] = [uv_x, 1 - uv_y, 0]
		)
		
		-- Iterate through each face and read its data
		for i = 1 to face_count do
		(
			v1 = readshort _file; v2 = readshort _file; v3 = readshort _file
			
			face_array[i] = [v1 + 1, v2 + 1, v3 + 1]
		)
		
		new_mesh = mesh vertices:vert_array faces:face_array tverts:tvert_array
		
		-- Set the mesh's texture vertices so we have UV
		if vert_count > 0 then
			buildtvfaces new_mesh
		
		for i = 1 to new_mesh.numfaces do
			setTVFace new_mesh i (getFace new_mesh i)
		
		if vert_count > 0 then
		(
			fseek _file 4 #seek_cur	-- Influence chunk ID
			
			inf_count = readshort _file #unsigned
			
			-- Create our skin modifier
			if inf_count > 0 then
			(
				mesh_skin = skin()
				addmodifier new_mesh mesh_skin
				max modify mode
				modpanel.setcurrentobject mesh_skin
				
				-- Add all of our bones to the skin modifier
				for i = 1 to bone_count do
					skinops.addbone mesh_skin bone_array[i] 0
				
				-- Needed in order to populate the skin with our vertices
				completeredraw()
			)
			
			-- Iterate through each influence and read its data
			for i = 1 to inf_count do
			(
				-- Read the influences for each bone
				for j = 1 to bone_count do
				(
					vert_inf_count = readlong _file #unsigned
					vertid_array = #()
					weight_array = #()
					
					for k = 1 to vert_inf_count do
						vertid_array[k] = readlong _file
					
					for k = 1 to vert_inf_count do
						weight_array[k] = (readfloat _file)
					
					-- Set the vertex weights in our skin
					for k = 1 to vert_inf_count do
						skinops.setvertexweights mesh_skin (vertid_array[k] + 1) j (weight_array[k] as float)
				)
			)
		)
		
		-- Set our mesh's name and material
		new_mesh.name = mesh_name
		new_mesh.material = in_materials[mat_id + 1]
		
		-- Create an edit_normals modifier
		-- (because setting them with setnormal() doesn't seem to work...)
		mesh_norm = edit_normals()
		addmodifier new_mesh mesh_norm
		max modify mode
		modpanel.setcurrentobject mesh_norm
		
		for i = 1 to new_mesh.numfaces do
		(
			for j in 1 to 3 do
			(
				local n = mesh_norm.getnormalid i j
				local v = mesh_norm.getvertexid i j
				mesh_norm.setnormal n normal_array[v]
			)
		)
	)
)

/* Cleans up our arrays (probably don't need this) */
function _cleanup =
(
	free vert_array
	free face_array
	free normal_array
	free tvert_array
	free bone_array
	
	vert_array = undefined
	face_array = undefined
	normal_array = undefined
	tvert_array = undefined
	bone_array = undefined
)

--------------------------------
-- Main
--------------------------------

global file_name = getopenfilename \
	caption:"Select a model to import..." \
	types:"Cabal Model Files|*.ebm;*.ech"

if file_name != undefined then
(
	-- Open the file with read rights in binary mode
	local in_file = fopen file_name "rb"

	-- Clear our scene
	delete objects

	readheader in_file

	while true do
	(
		id = readlong in_file	-- Chunk ID
		
		if id == 0x41470201 then readmaterials in_file else
		if id == 0x41470202 then readmeshes in_file else
		if id == 0x41470203 then readarmature in_file else
		if id == 0x41470204 then (readanimations in_file; exit())
	)

	fclose in_file

	_cleanup()
	clearselection()

	print "EBM successfully imported!"
)