# Hollowfly - Copyright (C) 2026 Santiluna99
# Software libre bajo la GNU GPL v3 (ver LICENSE y NOTICE).
class_name Assets
## Carga las texturas (assets/textures/*.png) y modelos (assets/models/*.mdl) generados
## con tools/gen_textures.py y tools/gen_models.py. Si falta algo, el juego usa el
## fallback procedural.

static var _tex := {}
static var _models := {}


## Carga una textura PNG de assets/textures (con mipmaps). Devuelve null si no existe.
static func tex(n: String) -> Texture2D:
	if _tex.has(n):
		return _tex[n]
	var path := "res://assets/textures/%s.png" % n
	var t: Texture2D = null
	if ResourceLoader.exists(path):
		var base: Texture2D = load(path)
		var img: Image = base.get_image()
		if img:
			img.generate_mipmaps()
			t = ImageTexture.create_from_image(img)
		else:
			t = base
	_tex[n] = t
	return t


## Devuelve {"mesh": ArrayMesh, "meta": Dictionary} o {} si no existe.
static func model(n: String) -> Dictionary:
	if _models.has(n):
		return _models[n]
	var p := "res://assets/models/%s.mdl" % n
	if not FileAccess.file_exists(p):
		_models[n] = {}
		return {}
	var f := FileAccess.open(p, FileAccess.READ)
	var verts := PackedVector3Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	while not f.eof_reached():
		var line := f.get_line()
		if line.begins_with("v "):
			var s := line.split(" ")
			verts.append(Vector3(float(s[1]), float(s[2]), float(s[3])))
			cols.append(Color(float(s[4]), float(s[5]), float(s[6])))
		elif line.begins_with("f "):
			var s2 := line.split(" ")
			idx.append(int(s2[1]) - 1)
			idx.append(int(s2[2]) - 1)
			idx.append(int(s2[3]) - 1)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in idx:
		st.set_color(cols[i])
		st.add_vertex(verts[i])
	st.generate_normals()   # sin índices compartidos: caras planas, aspecto low-poly
	var meta := {}
	var mp := "res://assets/models/%s.json" % n
	if FileAccess.file_exists(mp):
		meta = JSON.parse_string(FileAccess.get_file_as_string(mp))
	var d := {"mesh": st.commit(), "meta": meta}
	_models[n] = d
	return d
