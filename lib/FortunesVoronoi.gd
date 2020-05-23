extends Node

# Input set of sites as Vector3s with x and z set
var delaunay_verts = []

var bounds : = AABB(Vector3.ZERO, Vector3.ONE)
const IMPROVE_SPEED = 1.5

var sweep_loc = bounds.end.z
var sites = []            # Points - need this?
var edge_list = []        # VoronoiEdge

var break_points = BreakPointSet.new()
var arcs = ArcMap.new()
var events = EventSet.new()

var generation_time = 0.0 # How long does vonoroi take?
var status_text = ""      # Status text

var surfTool = SurfaceTool.new() # need to generate mesh
var done = false

func set_bounds_2D(bounds_2d : Rect2):
	bounds = AABB(Vector3(bounds_2d.position.x, 0.0, bounds_2d.position.y), Vector3(bounds_2d.end.x, 1.0, bounds_2d.end.y))

func get_voronoi_2D(vector_array : Array) -> Array:
	# Transpose 2D positions into 3D coords
	for vect in vector_array:
		delaunay_verts.append(Vector3(vect.x, 0.0, vect.y))
	
	create_voronoi_graph()
	
	var results := []
	for site in sites:
		var res_site = ResultSite2D.new(Vector2(site.x, site.z))
		for point in site.bound_verts:
			res_site.add(Vector2(point.x, point.z))
		results.append(res_site)
	
	return results

class ResultSite2D:
	var nucleus : Vector2
	var bounds : PoolVector2Array
	
	func _init(n : Vector2):
		nucleus = n
		bounds  = PoolVector2Array()
	
	func add(vect : Vector2):
		bounds.append(vect)

class Point:
	const EPSILON = 0.0000001
	var x
	var z
	var _vect # only create if distance_to gets called
	func _init(nx, nz):
		x = nx
		z = nz
	
	func compare_to(o):
		if x == o.x or (is_nan(x) and is_nan(o.x)):
			if z == o.z: return 0
			return -1 if z < o.z else 1
		return -1 if x < o.x else 1

	static func float_equals(a, b):
		if a == b: return true
		return abs(a - b) < EPSILON * max(abs(a), abs(b))

	func equals(o):
		return float_equals(x, o.x) and float_equals(z, o.z)
	
	func min_z_ordered_compare_to(o):
		if z < o.z: return 1
		if z > o.z: return -1
		if x == o.x: return 0
		return -1 if x < o.x else 1
	
	func mid_point(o, set_point):
		set_point.x = (x + o.x) / 2.0
		set_point.z = (z + o.z) / 2.0
		return set_point

	static func ccw(a, b, c):
		# Returns -1: clockwise, 0: collinear, 1:anti-clockwise 
		var area2 = (b.x - a.x) * (c.z - a.z) - (b.z - a.z) * (c.x - a.x)
		if area2 < 0:
			return -1
		elif area2 > 0:
			return +1
		else:
			return 0
	
	func distance_to(that):
		if not _vect: _vect = Vector2(x,z)
		if not that._vect: that._vect = Vector2(that.x,that.z)
		return _vect.distance_to(that._vect)
	
	func get_xz_vertex():
		return Vector3(x, 0.0, z)
	
	func _str():
		return "[" + str(self.get_instance_id()) + ":(" + str(x) + "," + str(z) + ")]"

class Bounds:
	# Used by site point to check bounds breaches
	var boundary
	func _init(bounds : AABB):
		# The order here might need corrected:
		boundary = [ \
			Point.new(bounds.position.x, bounds.position.z), \
			Point.new(bounds.end.x, bounds.position.z), \
			Point.new(bounds.end.x, bounds.end.z), \
			Point.new(bounds.position.x, bounds.end.z) \
		]
	
	static func is_inside(a, b, c):
		return Point.ccw(a, b, c) > 0
	
	static func intersection(a, b, p, q):
		var A1 = b.z - a.z
		var B1 = a.x - b.x
		var C1 = A1 * a.x + B1 * a.z

		var A2 = q.z - p.z
		var B2 = p.x - q.x
		var C2 = A2 * p.x + B2 * p.z

		var det = A1 * B2 - A2 * B1
		var x = (B2 * C1 - B1 * C2) / det
		var z = (A1 * C2 - A2 * C1) / det

		return Point.new(x, z)

	func clip_site(site):
		var result = site.get_edge_vertices()  # becomes input on first iter
		var blen = len(boundary)
		var intersected = false
		for i in blen:

			var vlen = len(result)
			var input = result
			result = []

			var A = boundary[(i + blen - 1) % blen]
			var B = boundary[i]

			for j in vlen:
				var P = input[(j + vlen -1) % vlen]
				var Q = input[j]

				if is_inside(A, B, Q):
					if not is_inside(A, B, P):
						result.append(intersection(A, B, P, Q))
						intersected = true
					result.append(Q)
				elif is_inside(A, B, P):
					result.append(intersection(A, B, P, Q))
					intersected = true
		
		site.bound_verts = result

class SitePoint:
	extends Point
	var site_edges
	var bound_verts

	func _init(nx, nz).(nx, nz):
		site_edges = []
	
	func add_edge(edge):
		if not site_edges.has(edge):
			site_edges.append(edge)
	
	func sort_vertices(a, b):
		# Probably won't work :-(
		return Point.ccw(a, b, self) <= 0

	func get_edge_vertices():
		var vertices = []
		for edge in site_edges:
			for point in [edge.p1, edge.p2]:
				if not vertices.has(point):
					var ins_ind = vertices.bsearch_custom(point, self, "sort_vertices")
					vertices.insert(ins_ind, point)
		return vertices

class Event:
	var p
	func _init(point):
		p = point
	
	func compare_to(o):
		return p.min_z_ordered_compare_to(o.p)

class CircleEvent:
	var p
	var arc
	var vert
	func _init(a, point, v):
		p = point
		arc = a
		vert = v
	
	func compare_to(o):
		return p.min_z_ordered_compare_to(o.p)

class ArcKey:
	static func compare(this, that):
		var my_left = this.get_left()
		var my_right = this.get_right()
		var your_left = that.get_left()
		var your_right = that.get_right()

		# If one arc contains the query, say they're the same
		if (that.arc_query or this.arc_query) and\
				((my_left.x <= your_left.x and my_right.x >= your_right.x) or\
				(your_left.x <= my_left.x and your_right.x >= my_right.x)):
			return 0

		if my_left.x == your_left.x and my_right.x == your_right.x:
			return 0
		if my_left.x >= your_right.x:
			return 1
		if my_right.x <= your_left.x:
			return -1
		
		var my_mid = my_left.mid_point(my_right, Point.new(0,0))
		var your_mid = your_left.mid_point(your_right, Point.new(0,0))
		return my_mid.compare_to(your_mid)

class ArcQuery:
	extends ArcKey
	var p
	var arc_query = true
	func _init(point):
		p = point
		
	func get_right():
		return p
	
	func get_left():
		return p
	
	func compare_to(o):
		return compare(self, o)

class Arc:
	extends ArcKey
	var v          # Voronoi Graph - What for ?
	var left       # BreakPoint
	var right      # BreakPoint
	var site
	var arc_query = false
	func _init(l, r, s, voronoi):
		v = voronoi
		if s:
			site = s
		else:
			left = l
			right = r
			site = left.s2 if left else right.s1

	func compare_to(o):
		return compare(self, o)
	
	func get_right():
		if right:
			return right.get_point()
		return Point.new(INF, INF)
	
	func get_left():
		if left:
			return left.get_point()
		return Point.new(-INF, INF)
	
	func check_circle():
		if not left or not right:
			return null
		if Point.ccw(left.s1, site, right.s2) != -1:
			return null
		return left.get_edge().intersection(right.get_edge())

class VoronoiEdge:
	var site1
	var site2
	var m        # - parameters for line edge rests on
	var b        # /
	var is_vertical
	var is_horizontal
	var p1
	var p2
	func _init(s1, s2):
		site1 = s1
		site2 = s2
		site1.add_edge(self)
		site2.add_edge(self)
		# Work out the gradient
		is_vertical = (s1.z == s2.z)
		is_horizontal = (s1.x == s2.x)
		var midpoint = s1.mid_point(s2, Point.new(0,0))
		if is_vertical:
			m = INF
			b = 0
		elif is_horizontal:
			m = 0
			b = midpoint.z
		else:
			m = -1.0 / ((s1.z - s2.z) / (s1.x - s2.x))
			b = midpoint.z - m * midpoint.x
	
	func intersection(that):
		if m == that.m and b != that.b and is_vertical == that.is_vertical:
			# No intersection
			return null
		if is_horizontal and that.is_horizontal and b != that.b:
			# Can't intersect either
			return null
		var x
		var z
		if is_vertical:
			x = (site1.x + site2.x) / 2.0
			z = that.m * x + that.b
		elif that.is_vertical:
			x = (that.site1.x + that.site2.x) / 2.0
			z = m * x + b
		else:
			x = (that.b - b) / (m - that.m)
			z = m * x + b
		return Point.new(x, z)

class BreakPoint:
	var v               # Voronoi Graph - For the sweep loc ?
	var s1              # Point
	var s2              # Point
	var e               # VoronoiEdge
	var is_edge_left    # bool
	var edge_begin      # Point
	var cache_sweep_loc # float
	var cache_point     # Point
	func _init(left, right, edge, edge_left, voronoi):
		v = voronoi
		s1 = left
		s2 = right
		e = edge
		is_edge_left = edge_left
		edge_begin = get_point()
	
	static func sq(f):
		return f * f
	
	func finish(vert):
		if not vert:
			vert = get_point()
		if is_edge_left:
			e.p1 = vert
		else:
			e.p2 = vert
	
	func get_point():
		var l = v.sweep_loc
		if l == cache_sweep_loc:
			return cache_point
		cache_sweep_loc = l
		var x
		var z

		# Handle grid line cases
		if s1.z == s2.z:
			# Handle Horizontal line case - on sweep loc
			if s1.z == l:
				x = (s1.x + s2.x) / 2.0
				z = INF
			else:
				# Handle vertical line case 
				x = (s1.x + s2.x) / 2.0
				# parabola focus-directrix definition ?
				z = (sq(x - s1.x) + sq(s1.z) - sq(l)) / (2.0 * (s1.z - l))
		else:
			# Intersect the line of the edge with the parabola of the higher point
			var px = s1.x if s1.z > s2.z else s2.x
			var pz = s1.z if s1.z > s2.z else s2.z
			var m = e.m
			var b = e.b
			var d = 2.0 * (pz - l)

			# Quadratic
			var A = 1
			var B = -2 * px - d * m
			var C = sq(px) + sq(pz) - sq(l) - d * b
			var sgn = -1 if s1.z > s2.z else 1
			var det = sq(B) - 4.0 * A * C

			# Fix tiny negative determinant
			if det <= 0:
				x = -B / (2.0 * A)
			else:
				x = (-B + sgn * sqrt(det)) / (2.0 * A)
			z = m * x + b
		cache_point = Point.new(x, z)
		return cache_point

	func get_edge():
		return e

class BreakPointSet:
	# Just allow add remove of break points, 
	# It's a set, so no duplicates
	var break_points
	func _init():
		break_points = []

	func clear():
		break_points.clear()

	func finish():
		# Call .finish() on all breakpoints
		for bp in break_points:
			bp.finish(null)

	func add(bp):
		if not break_points.has(bp):
			break_points.append(bp)

	func remove(bp):
		break_points.erase(bp)

class Sort:
	static func sort(a, b):
		return a.compare_to(b) < 0

class ArcMap:
	# Maintain a sorted list of arcs
	# with optional mappings to events
	var keys
	var key_values
	func _init():
		keys = []
		key_values = {}

	func clear():
		keys.clear()
		key_values.clear()

	func put(arc, event):
		if not keys.has(arc):
			var ins_ind = keys.bsearch_custom(arc, Sort, "sort")
			keys.insert(ins_ind, arc)
		if event:
			key_values[arc] = event

	func empty():
		return keys.empty()

	func size():
		return len(keys)

	func floor_entry(arc):
		# Returns an arc associated with the greatest key 
		# less than or equal to the given key, 
		# or null if there is nothing lower.
		var ins_ind = keys.bsearch_custom(arc, Sort, "sort")
		if arc.compare_to(keys[ins_ind]) == 0:
			return keys[ins_ind]
		elif ins_ind > 0:
			return keys[ins_ind - 1]
		return null
		
	func lower_entry(arc):
		# Returns an arc associated with the greatest key
		# strictly less than the given key, or null if there is no such key.
		var ins_ind = keys.bsearch_custom(arc, Sort, "sort")
		if ins_ind > 0:
			return keys[ins_ind - 1]
		return null

	func higher_entry(arc):
		# Returns an arc associated with the least key strictly 
		# greater than the given key, or null if there is no such key
		var ins_ind = keys.bsearch_custom(arc, Sort, "sort", false)
		if ins_ind >= keys.size():
			return null
		return keys[ins_ind]

	func remove(arc):
		if keys.has(arc):
			if key_values.has(arc):
				key_values.erase(arc)
			keys.erase(arc)

	func value(arc):
		# Get Event, if one is mapped
		if key_values.has(arc):
			return key_values[arc]
		return null

class EventSet:
	# TreeSet<Event>
	var events
	func _init():
		events = []

	func clear():
		events.clear()

	func add(event):
		if not events.has(event):
			var ins_ind = events.bsearch_custom(event, Sort, "sort")
			events.insert(ins_ind, event)

	func remove(event):
		if events.has(event):
			events.erase(event)

	func empty():
		return events.empty()

	func poll_first():
		return events.pop_front()

func create_voronoi_graph():

	sweep_loc = bounds.end.z
	sites.clear()
	edge_list.clear()
	break_points.clear()
	arcs.clear()
	events.clear()

	# Convert delaunay_verts to Points
	for dv in delaunay_verts:
		# Check points are valid to begin with
		if dv.x > bounds.end.x or dv.x < bounds.position.x or dv.z > bounds.end.z or dv.z < bounds.position.z:
			print ("Invalid input: ", str(dv))
			return
		var site = SitePoint.new(dv.x, dv.z)
		sites.append(site)
		events.add(Event.new(site))
	
	# Parse events until the list is empty
	var e_p = 0
	while not events.empty():
		var cur = events.poll_first()
		sweep_loc = cur.p.z
		# Handle different events
		if cur is Event:
			handle_site_event(cur)
		elif cur is CircleEvent:
			handle_circle_event(cur)
		else:
			print ("Unknown event type: ", var2str(cur))
		e_p += 1
	
	# Handling infinite points
	sweep_loc = bounds.position.z
	break_points.finish()

	# Need to remove edges that aren't connected at both ends
	# Not doing this leaves some terrible artifacts in the graph
	# Doing this kills off some of the cells on the boundaries,
	# but is probably the lesser of 2 evils here
	for edge in edge_list:
		# for each edge in site, see how many have points that connect to this one
		var match1 = false
		var match2 = false
		for site in [edge.site1, edge.site2]:
			for o_edge in site.site_edges:
				if edge == o_edge:
					continue
				if edge.p1.equals(o_edge.p1) or edge.p1.equals(o_edge.p2):
					match1 = true
				if edge.p2.equals(o_edge.p1) or edge.p2.equals(o_edge.p2):
					match2 = true
		if not (match1 and match2):
			edge.site1.site_edges.erase(edge)
			edge.site2.site_edges.erase(edge)
			# print ("removing edge from sites ", str(edge.site1), ", ", str(edge.site2))
	
	# For each site, tidy up edges that exit the bounds
	var bounds_edit = Bounds.new(bounds)
	for site in sites:
		bounds_edit.clip_site(site)
	
func handle_site_event(cur):
	# Deal with first point case
	if arcs.empty():
		arcs.put(Arc.new(null, null, cur.p, self), null)
		return
	
	# Find the arc above this site
	var arc_above = arcs.floor_entry(ArcQuery.new(cur.p))

	# Deal with the degenerate case where the first two points are at the same y value
	if arcs.empty() and abs(arc_above.site.z - cur.p.z) < Point.EPSILON:
		var new_edge = VoronoiEdge.new(arc_above.site, cur.p)
		new_edge.p1 = Point.new((cur.p.x + arc_above.site.x) / 2.0, INF)
		var new_break = BreakPoint.new(arc_above.site, cur.p, new_edge, false, self)
		break_points.add(new_break)
		edge_list.append(new_edge)
		var arc_left = Arc.new(null, new_break, null, self)
		var arc_right = Arc.new(new_break, null, null, self)
		arcs.remove(arc_above)
		arcs.put(arc_left, null)
		arcs.put(arc_right, null)
		return
	
	var false_ce = arcs.value(arc_above)
	if false_ce:
		events.remove(false_ce)
	
	var break_l = arc_above.left
	var break_r = arc_above.right
	var new_edge = VoronoiEdge.new(arc_above.site, cur.p)
	edge_list.append(new_edge)
	var new_break_l = BreakPoint.new(arc_above.site, cur.p, new_edge, true, self)
	var new_break_r = BreakPoint.new(cur.p, arc_above.site, new_edge, false, self)
	break_points.add(new_break_l)
	break_points.add(new_break_r)

	var arc_left = Arc.new(break_l, new_break_l, null, self)
	var center = Arc.new(new_break_l, new_break_r, null, self)
	var arc_right = Arc.new(new_break_r, break_r, null, self)

	arcs.remove(arc_above)
	arcs.put(arc_left, null)
	arcs.put(center, null)
	arcs.put(arc_right, null)

	check_for_circle_event(arc_left)
	check_for_circle_event(arc_right)

func handle_circle_event(ce):
	arcs.remove(ce.arc)
	ce.arc.left.finish(ce.vert)
	ce.arc.right.finish(ce.vert)
	break_points.remove(ce.arc.left)
	break_points.remove(ce.arc.right)

	var entry_right = arcs.higher_entry(ce.arc)
	var entry_left = arcs.lower_entry(ce.arc)
	var arc_right = null
	var arc_left = null
	var ce_arc_left = ce.arc.get_left() # Arc.left is breakpoint Arc.get_left is Point
	var cocircular_junction = ce.arc.get_right().equals(ce_arc_left)

	if entry_right:
		arc_right = entry_right
		while cocircular_junction and arc_right.get_right().equals(ce_arc_left):
			arcs.remove(arc_right)
			arc_right.left.finish(ce.vert)
			arc_right.right.finish(ce.vert)
			break_points.remove(arc_right.left)
			break_points.remove(arc_right.right)

			var false_ce = arcs.value(entry_right)
			if false_ce:
				events.remove(false_ce)
		
			entry_right = arcs.higher_entry(arc_right)
			arc_right = entry_right
		
		var false_ce = arcs.value(entry_right)
		if false_ce:
			events.remove(false_ce)
			arcs.put(arc_right, null)
	
	if entry_left:
		arc_left = entry_left
		while cocircular_junction and arc_left.get_left().equals(ce_arc_left):
			arcs.remove(arc_left)
			arc_left.left.finish(ce.vert)
			arc_left.right.finish(ce.vert)
			break_points.remove(arc_left.left)
			break_points.remove(arc_left.right)

			var false_ce = arcs.value(entry_left)
			if false_ce:
				events.remove(false_ce)
		
			entry_left = arcs.lower_entry(arc_left)
			arc_left = entry_left
		
		var false_ce = arcs.value(entry_left)
		if false_ce:
			events.remove(false_ce)
			arcs.put(arc_left, null)

	var e = VoronoiEdge.new(arc_left.right.s1, arc_right.left.s2)
	edge_list.append(e)

	# Edges that take a right turn are above the current point
	var turns_left = 1 == Point.ccw(arc_left.right.edge_begin, ce.p, arc_right.left.edge_begin) 
	# If turns left, then below this point -> the slow is negative then vertex is left
	var is_left_point = e.m < 0 if turns_left else e.m > 0
	if is_left_point:
		e.p1 = ce.vert
	else:
		e.p2 = ce.vert
	
	var new_bp = BreakPoint.new(arc_left.right.s1, arc_right.left.s2, e, not is_left_point, self)
	break_points.add(new_bp)

	arc_right.left = new_bp
	arc_left.right = new_bp

	check_for_circle_event(arc_left)
	check_for_circle_event(arc_right)

func check_for_circle_event(a):
	var circle_center = a.check_circle()
	if circle_center:
		var radius = a.site.distance_to(circle_center)
		var circle_event_point = Point.new(circle_center.x, circle_center.z - radius)
		var ce = CircleEvent.new(a, circle_event_point, circle_center)
		arcs.put(a, ce)
		events.add(ce)
