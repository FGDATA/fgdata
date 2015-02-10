var screenModeAndSettings = { # screen for changing the GPS mode and settings
    help : 0,
    mode_: 0,
    page_: 0,
    available_modes : ["POSITION","AIRPORT","TURNPOINT","TASK"],
    quit_help : func {
	me.help = 0;
	me.lines();
    },
    right : func {
	if (page == 1)
	    alt_unit = cycle(size(alt_unit_full_name), alt_unit, arg[0]);
	elsif (page == 2)
	    dist_unit = cycle(size(dist_unit_full_name), dist_unit, arg[0]);
	elsif (page == 3)
	    spd_unit = cycle(size(spd_unit_full_name), spd_unit, arg[0]);
	elsif (page == 4)
	    thresold_alert_index = cycle(size(thresold_alert), thresold_alert_index, arg[0]);
	elsif (page == 5)
	    thresold_next_waypoint = cycle(10, thresold_next_waypoint, arg[0]);
    },
    enter : func {
	if (!me.help) {
	    display (NOT_YET_IMPLEMENTED);
	    me.help = 1;
	}
	else me.quit_help();
    },
    escape : func {
	if (me.help) me.quit_help();
    },
    start : func {
	if (me.help) me.quit_help();
	else { 
	    mode = me.mode_ + 1;
	    page = 0;
	    displayed_screen = page_list[mode][page];
	    if (mode == 4) 
		screenTaskSelect.n = list_routes();
	    elsif (mode == 3)
		screenTurnpointSelect.n = load_bookmarks();
	}
    },
    lines : func {
	if (page == 0) {
	    var mode_str = me.available_modes[me.mode_];
	    l0 = "  -- GPS STATUS : --";
	    l1 = sprintf("MODE: %s", mode_str);
	}
	else {
	    if (page < 4)
		l0 = "  -- SET UNITS --";
	    else
		l0 = "- SET TIME THRESOLDS -";
	    if (page == 1) 
		l1 = sprintf("ALT: %s", alt_unit_full_name[alt_unit]);
	    elsif (page == 2)
		l1 = sprintf("DIST: %s", dist_unit_full_name[dist_unit]);
	    elsif (page == 3)
		l1 = sprintf("SPEED: %s", spd_unit_full_name[spd_unit]);
	    elsif (page == 4)
		l1 = sprintf("ALERT: %d s", thresold_alert[thresold_alert_index]);
	    elsif (page == 5)
		l1 = sprintf("NEXT WAYPOINT: %d s", thresold_next_waypoint);
	}
	display ([
	l0,
	l1,
	"",
	"ENTER -> HELP",
	"START -> ENTER MODE"
	]);
    }
};

var screenPositionMain = { # screens for POSITION mode
    coord : [0,0,0],
    right : func {
    },
    enter : func {
	var ac = geo.aircraft_position();
	me.coord = [ac.lat(), ac.lon(), ac.alt()];
	EditMode(6, "EDIT WAYPOINT ID", "SAVE");
    },
    escape : func {
    },
    start : func {
	if (mode == 5) {
	    add_bookmark(arg[0], arg[0], "GPS", me.coord);
	    return 1; #make gps quitting edition mode, back to previous mode and page
	}
    },
    lines : func {
	display ([
	sprintf("LAT: %s", 
	    props.globals.getNode("/position/latitude-string",1).getValue()),
	sprintf("LON: %s", 
	    props.globals.getNode("/position/longitude-string",1).getValue()),
	sprintf("ALT: %d %s", 
	    gps_data.getNode("indicated-altitude-ft").getValue() * alt_conv[0][alt_unit],
	    alt_unit_short_name[alt_unit]),
	sprintf("HDG: %d°", 
	    gps_data.getNode("indicated-track-true-deg").getValue()),
	sprintf("SPD: %d %s", 
	    gps_data.getNode("indicated-ground-speed-kt").getValue() * dist_conv[0][spd_unit],
	    spd_unit_short_name[spd_unit])
	]);
    }
};

var screenOdometers = {
    begin_time : 0,
    elapsed : 0,
    odotime : func {
	me.elapsed = props.globals.getNode("/sim/time/elapsed-sec",1).getValue() - me.begin_time;
        seconds_to_string(me.elapsed);
    },
    right: func {
    },
    enter: func {
    },
    escape: func {
	startpos = geo.Coord.new(geo.aircraft_position());
	me.begin_time = props.globals.getNode("/sim/time/elapsed-sec",1).getValue();
	gps_data.getNode("odometer",1).setDoubleValue(0.0);
    },
    start: func {
    },
    lines: func {
	    display ([
	    sprintf("ODO: %d %s", 
	        gps_data.getNode("odometer",1).getValue() * dist_conv[0][dist_unit],
		dist_unit_short_name[dist_unit]),
	    sprintf("TRIP: %d %s", 
		gps_data.getNode("trip-odometer",1).getValue() * dist_conv[0][dist_unit],
		dist_unit_short_name[dist_unit]),
	    sprintf("TIME: %s", 
		me.odotime()),
	    sprintf("AVG HDG: %03d*", 
		startpos.course_to(geo.aircraft_position())),
	    sprintf("AVG SPD: %d %s",
		gps_data.getNode("odometer",1).getValue() / me.elapsed * 3600 * dist_conv[0][spd_unit],
		spd_unit_short_name[spd_unit])
	    ]);
    }
};

var screenWindInfos = {
    right: func {
    },
    enter: func {
    },
    escape: func {
    },
    start: func {
    },
    lines: func {
	if (gps_data.getNode("indicated-ground-speed-kt").getValue() > 10)
	    display ([
	    "WIND INFOS",
	    sprintf("SPEED: %d %s", 
	        props.globals.getNode("/environment/wind-speed-kt",1).getValue() * dist_conv[0][dist_unit],
	        spd_unit_short_name[spd_unit]),
	    sprintf("FROM: %d*",
	        props.globals.getNode("/environment/wind-from-heading-deg",1).getValue()),
	    "", 
	    "" 
	    ]);
	else
	    display ([
	    "WIND INFOS",
	    sprintf("SPEED: --- %s", spd_unit_short_name[spd_unit]),
	    "FROM: ---*",
	    "", 
	    "" 
	    ]);
    }
};

var screenNavigationMain = {
    right : func {
    },
    enter : func {
	if (mode == 4) apply_command("next");
	else add_waypoint(gps_wp.getNode("wp[1]/ID",1).getValue(),
			  gps_wp.getNode("wp[1]/name",1).getValue(),
			  gps_wp.getNode("wp[1]/waypoint-type",1).getValue(),
			  [gps_wp.getNode("wp[1]/latitude-deg",1).getValue(),
			   gps_wp.getNode("wp[1]/longitude-deg",1).getValue(),
			   gps_wp.getNode("wp[1]/altitude-ft",1).getValue()]);
    },
    escape : func {
    },
    start : func {
	if (mode != 4) save_route();
    },
    lines : func {
	me.waypoint = gps_wp.getNode("wp[1]");
        var crs_deviation = me.waypoint.getNode("course-error-nm").getValue();
	var dist = me.waypoint.getNode("course-error-nm").getValue();
	if (dist < 5) crs_deviation *= 5;
	else crs_deviation *= 2.5;
	if (crs_deviation > 5)
	    me.graph = "[- - - - - ^ > > > > >]";
	elsif (crs_deviation < -5)
	    me.graph = "[< < < < < ^ - - - - -]";
	else {
	    me.graph = "[+ + + + + ^ + + + + +]";
	    cursor = int((crs_deviation * 2) + 11);
	    me.graph = substr(me.graph,0, cursor) ~ "|" ~ substr(me.graph, cursor+1, size(me.graph));
	}
	var ID = me.waypoint.getNode("ID");
	var current_wp = getprop("/autopilot/route-manager/current-wp") - 1;
	var type = nil;
	if (current_wp > -1)
	    type = gps_data.getNode("route/Waypoint[" ~ current_wp ~ "]/waypoint-type");
	display ([
	sprintf("ID: %s [%s]",
	    ID != nil ? ID.getValue() : "-----",
	    type != nil ? type.getValue() : "---"),
	sprintf("BRG: %d°  DST: %d %s",
	    me.waypoint.getNode("bearing-mag-deg",1).getValue(),
	    me.waypoint.getNode("distance-nm",1).getValue() * dist_conv[0][dist_unit],
	    dist_unit_short_name[dist_unit]),
	sprintf("XCRS: %d* (%.1f %s)",
	    me.waypoint.getNode("course-deviation-deg").getValue(), 
	    dist * dist_conv[0][dist_unit],
	    dist_unit_short_name[dist_unit]),
	sprintf("TTW: %s", 
	    me.waypoint.getNode("TTW").getValue()),
	me.graph]);
    }
};

var screenEdit = {
    previous_mode: 0,
    previous_page: 0,
    carset: [["A","B","C","D","E","F","G","H","I","J","K","L","M","N","O","P",
	       "Q","R","S","T","U","V","W","X","Y","Z", "0","1","2","3","4","5","6","7","8","9"],
             ["0","1","2","3","4","5","6","7","8","9","."]],
    start_command: "",
    edit_zone: "",
    edit_title : "",
    set: 0,
    map: [],
    pointer: 0,
    value: 0,
    init: func (length, title, start_command, set) {
	me.map = [];
	for (var i = 0; i < length; i += 1) append(me.map, "-");
	me.edit_title = title;
	me.start_command = start_command;
	me.set = set;
	me.pointer = 0;
	me.value = 0;
	left_knob(0); # force display
    },
    right : func {
	me.value = cycle(size(me.carset[me.set]), me.value, arg[0]);
	me.map[me.pointer] = me.carset[me.set][me.value];
    },
    enter : func {
	me.pointer = cycle(size(me.map), me.pointer, 1);
	me.value = 0;
    },
    escape : func {
	me.map = [];
	me.pointer = 0;
	me.value = 0;
	me.start_command = "";
	me.edit_zone = "";
	me.edit_title = "";
	me.set = 0;
	me.map = [];
	mode = me.previous_mode;
	page = me.previous_page;
	left_knob(0); # force new display
    },
    start : func {
	var str = "";
	for (var i = 0; i < size(me.map); i += 1)
	    str ~= me.map[i] != "-" ? me.map[i] : "";
	if (screen[page_list[me.previous_mode][me.previous_page]].start(str)) 
	    me.escape();
	else
	    me.init(size(me.map), me.edit_title, me.start_command, me.set);
    },
    lines : func {
	me.right(0); #init car
	me.edit_zone = "";
	for (var i=0; i < size(me.map); i+=1) me.edit_zone ~= me.map[i];
	display([
	me.edit_title,
	me.edit_zone,
	"",
	"ESC -> RESET",
	sprintf("START -> %s", me.start_command)
	]);
    }
};
