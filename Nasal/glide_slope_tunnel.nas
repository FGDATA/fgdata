# Draw 3 degree glide slope tunnel for the nearest airport's most suitable runway
# considering wind direction and runway size.
# Activate with  --prop:sim/rendering/glide-slope-tunnel=1 or via Help menu

var MARKER = "Models/Geometry/square.xml";	# tunnel marker
var DIST = 1000;				# distance between markers
var NUM = 30;					# number of tunnel markers
var ANGLE = 3 * math.pi / 180;			# glide slope angle in radian
var HOFFSET = 274;				# distance between begin of runway and touchdown area (900 ft)
var INTERVAL = 5;				# check for nearest airport

var voffset = DIST * math.sin(ANGLE) / math.cos(ANGLE);
var apt = nil;
var tunnel = [];
setsize(tunnel, NUM);


var normdeg = func(a) {
	while (a >= 180)
		a -= 360;
	while (a < -180)
		a += 360;
	return a;
}


# Find best runway for current wind direction (or 270), also considering length and width.
#
var best_runway = func(apt) {
	var wind_speed = getprop("/environment/wind-speed-kt");
	var wind_from = wind_speed ? getprop("/environment/wind-from-heading-deg") : 270;
	var max = -1;
	var rwy = nil;

	foreach (var r; keys(apt.runways)) {
		var curr = apt.runways[r];
		var deviation = math.abs(normdeg(wind_from - curr.heading)) + 1e-20;
		var v = (0.01 * curr.length + 0.01 * curr.width) / deviation;

		if (v > max) {
			max = v;
			rwy = curr;
		}
	}
	return rwy;
}


# Draw 3 degree glide slope tunnel.
#
var draw_tunnel = func(rwy) {
	var m = geo.Coord.new().set_latlon(rwy.lat, rwy.lon);
	m.apply_course_distance(rwy.heading + 180, rwy.length / 2 - rwy.threshold - HOFFSET);

	var g = geodinfo(m.lat(), m.lon());
	var elev = g != nil ? g[0] : apt.elevation;
	forindex (var i; tunnel) {
		if (tunnel[i] != nil)
			tunnel[i].remove();

		m.set_alt(elev);
		tunnel[i] = geo.put_model(MARKER, m, rwy.heading);
		m.apply_course_distance(rwy.heading + 180, DIST);
		elev += voffset;
	}
}


var loop = func(id) {
	id == loopid or return;
	var a = airportinfo();
	if (apt == nil or apt.id != a.id) {
		apt = a;
		var is_heliport = 1;
		foreach (var rwy; keys(apt.runways))
			if (rwy[0] != `H`)
				is_heliport = 0;

		if (!is_heliport) {
			draw_tunnel(best_runway(apt));
			gui.popupTip(apt.id ~ " - \"" ~ apt.name ~ "\"", 6);
		}
	}
	settimer(func loop(id), INTERVAL);
}


var loopid = 0;

var fdm_init_listener = _setlistener("/sim/signals/fdm-initialized", func {
	removelistener(fdm_init_listener); # uninstall, so we're only called once
	# remove top bar unless otherwise specified
	var top = props.globals.initNode("/sim/model/geometry/square/top", 1, "BOOL");

	setlistener("/sim/rendering/glide-slope-tunnel", func(n) {
		loopid += 1;
		if (n.getValue()) {
			apt = nil;
			return loop(loopid);
		}

		forindex (var i; tunnel) {
			if (tunnel[i] != nil) {
				tunnel[i].remove();
				tunnel[i] = nil;
			}
		}
	}, 1);
});


