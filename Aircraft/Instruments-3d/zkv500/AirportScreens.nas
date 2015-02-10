var screenAirportMain = {
    pos: nil,
    apt_coord: nil,
    apt: nil,
    searched: 0,
    oaci: nil,
    search: func {
	me.apt = me.oaci != nil ? airportinfo(me.oaci) : airportinfo();
	if (me.apt != nil) {
	    #glide_slope_tunnel.complement_runways(me.apt);
	    return 1;
	}
	else
	    return 0;
    },
    right : func {
    },
    enter : func { #add to route
	add_waypoint(me.apt.id, me.apt.name, "APT", 
		    [me.apt_coord.lat(), me.apt_coord.lon(), 
		    me.apt_coord.alt()*alt_conv[1][0]]);
    },
    escape : func {
	me.searched = 0;
	me.oaci = nil;
    },
    start : func {  #add bookmark, enter turnpoint mode
	add_bookmark(me.apt.id, me.apt.name, "APT", 
		    [me.apt_coord.lat(), me.apt_coord.lon(), 
		    me.apt_coord.alt()*alt_conv[1][0]]);
	screenTurnpointSelect.selected = screenTurnpointSelect.n - 1;
	screenTurnpointSelect.start();
    },
    lines : func {
	if (me.search() == 1) { #FIXME: THE SEARCH SHOULD BE DONE ONLY ONE TIME, 
				#       BUT IT SEEMS TO BE EXECUTED 3 TIMES/SEC
				#       I DON'T KNOW YET WHY... :/
	    var rwy = glide_slope_tunnel.best_runway(me.apt);
	    me.pos = geo.Coord.new(geo.aircraft_position());
	    me.apt_coord = geo.Coord.new().set_latlon(rwy.lat, rwy.lon);
	    var ac_to_apt = [me.pos.distance_to(me.apt_coord), me.pos.course_to(me.apt_coord)];
	    var ete = ac_to_apt[0] / getprop("instrumentation/gps/indicated-ground-speed-kt") * 3600 * 1852;
	    display([
	    sprintf("%s APT: %s", me.searched != 0 ? "SEARCHED" : "NEAREST", me.apt.id),
	    sprintf("ELEV: %d %s", me.apt.elevation * alt_conv[1][alt_unit],alt_unit_short_name[alt_unit]),
	    sprintf("DIST: %d %s",ac_to_apt[0] * dist_conv[2][dist_unit],dist_unit_short_name[dist_unit]),
	    sprintf("BRG: %d°    RWY: %02d",ac_to_apt[1], int(rwy.heading) / 10),
	    sprintf("ETE: %s",seconds_to_string(ete))
	    ]);
	}
	else
	    display([
	    "",
	    " ! ERROR !",
	    "NO  AIRPORT",
	    "   FOUND",
	    ""
	    ]);
    }
};

var screenAirportInfos = {
    page : 0,
    rwylist: [],
    right : func {
	np = int(size(me.rwylist) / 4) + (math.mod(size(me.rwylist),4) ? 1 : 0);
	me.page = cycle(np, me.page, arg[0]);
    },
    enter : func {
    },
    escape : func {
    },
    start : func {
    },
    lines : func {
	me.rwylist = [];
	foreach (var r; keys(screenAirportMain.apt.runways)) {
	    string.isdigit(r[0]) or continue;
	    var number = math.mod(num(substr(r, 0, 2)) + 18, 36);
	    var side = substr(r, 2, 1);
	    var comp = sprintf("%02d%s", number, side == "R" ? "L" : side == "L" ? "R" : side);
	    append(me.rwylist, [r, comp, 
				screenAirportMain.apt.runways[r].length, 
				screenAirportMain.apt.runways[r].width]);
	}
	line[0].setValue(sprintf("%s", screenAirportMain.apt.name)); #TODO check length to truncate if too long
	rwyindex = me.page * 4;
	for (var l = 1; l < LINES; l += 1) {
	    rwyindex += 1;
	    if (rwyindex < size(me.rwylist))
		line[l].setValue(sprintf("%s - %s [%dm / %dm]", 
					me.rwylist[rwyindex][0],
					me.rwylist[rwyindex][1], 
					me.rwylist[rwyindex][2],
					me.rwylist[rwyindex][3]));
	    else
		line[l].setValue("");
	}
    }
};

var screenSearchAirport = {
    right : func {
    },
    enter : func {
    },
    escape : func {
    },
    start : func {
	screenAirportMain.oaci = arg[0];
	var found = screenAirportMain.search();
	if (found != 0) {
	    screenAirportMain.searched = 1;
	    screenEdit.previous_page = 0;
	    return 1;
	}
	else
	    return 0;
    },
    lines : func {
	EditMode(4, "AIRPORT CODE", "SEARCH");
    }
};


