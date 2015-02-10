var screenTurnpointSelect = {
    n: 0,
    page: 0,
    pointer: 0,
    loaded: 0,
    selected: 0,
    right : func {
	me.loaded = 0;
	blocked = 1;
	var t = browse(me.n, me.pointer, me.page, arg[0]);
	me.pointer = t[0];
	me.page = t[1];
	me.selected = me.page * LINES + me.pointer;
    },
    enter : func {
    },
    escape : func {
    },
    start : func {
	me.n > 0 or return;
	Waypoint_to_scratch(gps_data.getNode("bookmarks/bookmark["~me.selected~"]/"));
	apply_command("obs");
	blocked = 0;
	me.loaded = 1;
	page = 1;
	mode = 3;
	left_knob(0);
    },
    lines : func {
	if (me.loaded != 1) blocked = 1;
	if (me.n > 0)
	    for (var l = 0; l < LINES; l += 1) {
		if ((me.page * LINES + l) < me.n) {
		    name = gps_data.getNode("bookmarks/bookmark["~((me.page * LINES) + l)~"]/ID").getValue();
		    line[l].setValue(sprintf("%s %s",me.pointer == l ? ">" : " ", name));
		}
		else
		    line[l].setValue("");
	    }
	else
	    display([
	    " ",
	    " ",
	    " NO BOOKMARKS",
	    " ",
	    " "
	    ]);
    }
};

var screenTurnpointInfos = {
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
