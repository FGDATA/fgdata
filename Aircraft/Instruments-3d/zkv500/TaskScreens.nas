var screenTaskSelect = {
    page : 0,
    pointer: 0,
    n: 0,
    loaded: 0,
    right : func {
	me.loaded = 0;
	blocked = 1;
	var t = browse(size(routes), me.pointer, me.page, arg[0]);
	me.pointer = t[0];
	me.page = t[1];
    },
    load : func {
        setprop("/autopilot/route-manager/active", 0);
	gps_data.getNode("route",1).removeChildren("Waypoint");
	getprop("/autopilot/route-manager/route/num") == 0 or apply_command("route-delete");
	fgcommand("loadxml", props.Node.new({
            "filename": getprop("/sim/fg-home") ~ "/Routes/" ~ routes[(me.page * 5) + me.pointer],
            "targetnode": "/instrumentation/gps/route"
        }));
        var n = 0;
        scratch.getNode("index").setIntValue(-1);
    	apply_command("route-insert-after");
	foreach (var c; gps_data.getNode("route").getChildren("Waypoint")) n += 1;
	for (var i = 0; i < n; i += 1) {
	    scratch.getNode("index").setIntValue(-1);
	    Waypoint_to_scratch(gps_data.getNode("route/Waypoint[" ~ i ~ "]"));
	    apply_command("route-insert-after");
	}
	apply_command("leg");
        setprop("/autopilot/route-manager/active", 1);
	me.loaded = 1;
    },
    enter : func {
    },
    escape : func {
    },
    start : func {
	me.n > 0 or return;
	me.load();
	blocked = 0;
	left_knob(1);
    },
    lines : func {
	if (me.loaded != 1) blocked = 1;
	if (me.n == 0) {
	    display([
	    "",
	    "",
	    "NO ROUTE FOUND",
	    "",
	    ""
	    ]);
	}
	else for (var l = 0; l < LINES; l += 1) {
	    if ((me.page * LINES + l) < me.n) {
		name = routes[me.page * LINES + l];
		if (substr(name, -4) == ".xml") name = substr(name, 0, size(name) - 4);
		name = string.uc(name);
		line[l].setValue(sprintf("%s %s",me.pointer == l ? ">" : " ", name));
	    }
	    else
		line[l].setValue("");
	}
    }
};

var screenWaypointsList = {
    n: 0,
    page: 0,
    pointer: 0,
    right : func {
	var t = browse(me.n, me.pointer, me.page, arg[0]);
	me.pointer = t[0];
	me.page = t[1];
    },
    enter : func {
    },
    escape : func {
    },
    start : func {
    },
    lines : func {
	for (var l = 0; l < LINES; l += 1) {
	   if ((me.page * LINES + l) < me.n) {
		name = gps_data.getNode("route/Waypoint["~((me.page * LINES) + l)~"]/ID").getValue();
		line[l].setValue(sprintf("%s %s",me.pointer == l ? ">" : " ", name));
	    }
	    else
		line[l].setValue("");
	}
    }
};

var screenWaypointInfos = {
    right : func {
    },
    enter : func {
    },
    escape : func {
    },
    start : func {
    },
    lines : func {
	display(NOT_YET_IMPLEMENTED);
    }
};



