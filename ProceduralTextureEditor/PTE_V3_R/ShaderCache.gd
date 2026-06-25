class_name ShaderCache extends RefCounted

# ---------------------------------------------------------------------------
# Topo-sorted function list — computed ONCE at startup from the static
# library data, never again (circular deps can only be introduced by editing
# FunctionData resources, which requires a full editor restart).
# ---------------------------------------------------------------------------
var _sorted_functions: PackedStringArray = PackedStringArray()
var _function_graph: Dictionary = {}          # name -> { code, requires }
var _library_ready := false

# ---------------------------------------------------------------------------
# Preamble cache — keyed by a canonical string that represents the exact
# set of generator / modifier / blend-mode names in use.
# The preamble contains: helper functions + generator/modifier/blend bodies.
# It is invalidated only when the *set* of used resources changes (layer
# added / removed, or generator / modifier type swapped).
# ---------------------------------------------------------------------------
var _preamble_cache: Dictionary = {}          # key:String -> String
var _last_preamble_key: String = ""
var _last_preamble: String = ""

# ---------------------------------------------------------------------------
# Fragment cache — the void fragment(){} block.
# Invalidated on any parameter change, opacity change, or layer reorder.
# ---------------------------------------------------------------------------
var _fragment_dirty := true
var _last_fragment: String = ""

# ---------------------------------------------------------------------------
# Full shader cache — concatenation of header + preamble + fragment.
# Only rebuilt when either part is dirty.
# ---------------------------------------------------------------------------
var _shader_dirty := true
var _last_shader: String = ""

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Call once at startup (or whenever the library is hot-reloaded in editor).
## Resolves all FunctionLibrary entries, topologically sorts them, and stores
## the result so every subsequent preamble build can skip this step.
func warm_up_library() -> void:
	_function_graph = {}

	# Resolve entire FunctionLibrary into a dependency graph.
	for fname in FunctionLibrary.get_all_names():
		var res: FunctionData = FunctionLibrary.get_function(fname)
		if res:
			_function_graph[fname] = {
				"code":     res.code,
				"requires": res.required_functions
			}

	_sorted_functions = _topological_sort(_function_graph)
	_library_ready = true

	# Library changed → all preambles that used these functions are stale.
	invalidate_preamble()


## Call when the *set* of used resources changes (layer added/removed,
## generator or modifier *type* changed — not just parameters).
func invalidate_preamble() -> void:
	_preamble_cache.clear()
	_last_preamble_key = ""
	_last_preamble = ""
	_shader_dirty = true
	# Fragment itself is not dirty — only the static bodies above it changed.
	# However the full shader string must be rebuilt.


## Call when anything inside layers changes that affects the fragment body:
## parameter values, opacity, layer order, blend mode on an existing layer.
func invalidate_fragment() -> void:
	_fragment_dirty = true
	_shader_dirty = true


## Returns the complete shader string, rebuilding only the dirty parts.
## `preamble_key`  — canonical string describing the active resource set
##                   (built cheaply by MaterialCodeGenerator).
## `preamble_fn`   — Callable() -> String, called only on a cache miss.
## `fragment_fn`   — Callable() -> String, called only when fragment is dirty.
func get_shader(
		preamble_key: String,
		preamble_fn: Callable,
		fragment_fn: Callable
) -> String:
	if not _shader_dirty:
		return _last_shader

	# --- Preamble ---
	if preamble_key != _last_preamble_key or not _preamble_cache.has(preamble_key):
		_last_preamble = preamble_fn.call()
		_preamble_cache[preamble_key] = _last_preamble
		_last_preamble_key = preamble_key
	else:
		_last_preamble = _preamble_cache[preamble_key]

	# --- Fragment ---
	if _fragment_dirty:
		_last_fragment = fragment_fn.call()
		_fragment_dirty = false

	_last_shader = _last_preamble + "\n" + _last_fragment
	_shader_dirty = false
	return _last_shader


## Expose the pre-sorted function list to PreambleBuilder.
func get_sorted_functions() -> PackedStringArray:
	if not _library_ready:
		warm_up_library()
	return _sorted_functions


func get_function_graph() -> Dictionary:
	return _function_graph


# ---------------------------------------------------------------------------
# Topological sort (Kahn's algorithm) — only called from warm_up_library().
# Kept here so ShaderCache is self-contained; PreambleBuilder never needs it.
# ---------------------------------------------------------------------------
func _topological_sort(deps: Dictionary) -> PackedStringArray:
	var indegree := {}
	var dependents := {}
	var all_nodes := deps.keys()

	for name in all_nodes:
		indegree[name] = deps[name]["requires"].size()
		dependents[name] = []

	for name in all_nodes:
		for req in deps[name]["requires"]:
			if dependents.has(req):
				dependents[req].append(name)

	var queue := []
	for name in all_nodes:
		if indegree[name] == 0:
			queue.append(name)

	var sorted := PackedStringArray()
	while not queue.is_empty():
		var name = queue[0]
		queue.remove_at(0)
		sorted.append(name)
		for dependent in dependents[name]:
			indegree[dependent] -= 1
			if indegree[dependent] == 0:
				queue.append(dependent)

	if sorted.size() != all_nodes.size():
		push_error("ShaderCache: circular dependency in FunctionLibrary — sorted order may be incomplete")

	return sorted
