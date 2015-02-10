var mode = 0; #current mode
var displayed_screen = 0; #screenModeAndSettings
var page = 0; #current page
var blocked = 0; #boolean: 0 -> possible to cycle pages
var isOn = 0; #ON/OFF: 0 -> OFF
var refresh_timer = 0; #avoid multiple settimers
var freq = 1; #settimer frequency (in sec)
var screen = []; #array containing all screens
var line = []; #array containing the displayed lines
var routes = []; #array containing the preprogrammed tasks
var alt_unit_full_name = ["Feet", "Meters"];
var dist_unit_full_name = ["Nautic Miles", "Kilometers"];
var spd_unit_full_name = ["Knots", "KM/H"];
var alt_unit_short_name = ["ft", "m"];
var dist_unit_short_name = ["nm", "km"];
var spd_unit_short_name = ["kt", "km/h"];
var spd_unit = 0;
var dist_unit = 0;
var alt_unit = 0;
var startpos = nil; #geo.nas aircraft position
var waypointindex = 0; #step in actual task
var thresold_alert = [120, 60, 30, 15];
var thresold_alert_index = 1;
var thresold_next_waypoint = 5;
NOT_YET_IMPLEMENTED = [
    "",
    "    NOT",
    "    YET",
    "IMPLEMENTED",
    ""
];
var LINES = 5; #lines in display
var page_list = [
    [0,0,0,0,0,0],      #0 ModeAndSettings: 1 page for mode, 5 pages for settings
    [1,2,3],            #1 PositionMain, Odometers, WindInfos
    [5,4,1,2,3,6,7],    #2 AirportMain, NavigationMain, PositionMain, Odometers, WindInfos, AirportInfos, SearchAirport
    [8,4,1,2,3,9],      #3 TurnpointSelect, NavigationMain, PositionMain, Odometers, WindInfos, TurnpointInfos
    [10,4,1,2,3,11,12], #4 TaskSelect, NavigationMain, PositionMain, Odometers, WindInfos, WaypointInfos, WaypointsList
    [13]	        #5 Edit (special mode for editing waypoint, called from other modes)
];

             #to ft      m
var alt_conv = [[1.0000,0.3048],  #from ft
                [3.2808,1.0000]]; #from m

	      #to nm      km     m
var dist_conv = [[1.00000   ,1.852, 1852],  #from nm
                 [0.53996   ,1.000, 1000],  #from km
	         [0.00053996,0.001, 1.00]]; #from m

var gps_data = props.globals.getNode("/instrumentation/gps",1);
var scratch = gps_data.getNode("scratch",1);
var gps_wp = gps_data.getNode("wp",1);
var route = props.globals.getNode("/autopilot/route-manager/route",1);

#### warps for buttons and knobs ########################################"
var right_knob = func(dir) { #manage right knob, depends of displayed screen
    isOn > 0 or return;
    screen[displayed_screen].right(dir);
    refresh_display();
}

var enter_button = func() { #manage enter button, depends of displayed screen
    isOn > 0 or return;
    screen[displayed_screen].enter();
    refresh_display();
}

var escape_button = func() { #manage escape button, depends of displayed screen
    isOn > 0 or return;
    screen[displayed_screen].escape();
    refresh_display();
}

var start_button = func() { #manage start button, depends of displayed screen
    isOn > 0 or return;
    screen[displayed_screen].start();
    refresh_display();
}

var left_knob = func(dir) { #manage left button, cycle in mode's pages if not blocked
    isOn > 0 or return;
    if (blocked == 0) {
	if (displayed_screen == 13 and dir) {
	    mode = screenEdit.previous_mode;
	    page = screenEdit.previous_page;
	}
	page = cycle(size(page_list[mode]), page, dir);
	displayed_screen = page_list[mode][page];
    }
    refresh_display();
}

var select_mode = func(dir) { #manage mode knob, cycle into available modes
    isOn > 0 or return;
    blocked = 0;
    if (displayed_screen != 0) {
	displayed_screen = 0; #screenModeAndSettings
	page = 0;
	mode = 0;
    }
    elsif (page == 0) 
	screen[0].mode_ = cycle(size(screen[0].available_modes), screen[0].mode_, dir);
    refresh_display();
}

var power_knob = func() { #manage POWER knob
    if (arg[0] > 0 and isOn < 11) isOn += 1;
    elsif (arg[0] < 0 and isOn > 0) isOn -= 1;
    else return;
    props.globals.getNode("/instrumentation/zkv500/power",1).setIntValue(isOn);	
    var light = 0;
    if (isOn > 0 and getprop("instrumentation/gps/serviceable") != 0)
	light = (isOn - 1)/20;
    props.globals.getNode("/instrumentation/zkv500/retro-light").setDoubleValue(light);
    refresh_display();
}

### useful funcs #########################################################
var display = func () { #display the array line[]
    for (var i = 0; i < LINES; i += 1) line[i].setValue(arg[0][i]);
}

var apply_command = func (command) {
    gps_data.getNode("command").setValue(command);
}

var browse = func (entries_nbr, index_pointer, index_page,dir) {
    #browse multipaged entries, returns [pointer in page, page]
    nl = entries_nbr - (index_page * LINES) >= LINES ? LINES : math.mod(entries_nbr - (index_page * LINES), LINES);
    if (index_pointer + 1 == nl) {
       np = int(entries_nbr / LINES) + (math.mod(entries_nbr,LINES) ? 1 : 0);
       index_page = cycle(np, index_page, dir);
    }
    index_pointer = cycle(nl, index_pointer, dir);
    return [index_pointer, index_page];
}

var cycle = func (entries_nbr, actual_entrie, dir) {
    #cycle through entries, return entry index
    entries_nbr -= 1;
    if (dir == 1 and actual_entrie == entries_nbr) return 0;
    elsif (dir == -1 and actual_entrie == 0) return entries_nbr;
    else return actual_entrie + dir;
}

var refresh_display = func(forced = 1) { #refresh displayed lines, settimer if necessary
    if (!forced) refresh_timer -= 1;
    screen[displayed_screen].lines();
    if (isOn and 0 < displayed_screen and displayed_screen < 5 and !refresh_timer) {
	refresh_timer += 1;
	settimer(func { refresh_display(0); }, freq, 1);
    }
    waypointAlert();
}

var seconds_to_string = func (time) { #converts secs (double) in string "hh:mm:ss"
    var hh = int(time / 3600);
    if (hh > 100) return "--:--:--";
    var mm = int((time - (hh * 3600)) / 60);
    var ss = int(time - (hh * 3600 + mm * 60));
    return sprintf("%02d:%02d:%02d", hh, mm, ss);
}

### route management ######################################################
var list_routes = func { #load preprogrammed tasks
    routes = [];
    var path = getprop("/sim/fg-home") ~ "/Routes";
    var s = io.stat(path);
    if (s != nil and s[11] == "dir") {
	foreach (var file; directory(path)) 
	    if (file[0] != 46) append(routes, file);
#	size(routes) != 0 or return;
#	routes = sort(routes, func(a,b) {
#	    num(a[1]) == nil or num(b[1]) == nil ? cmp(a[1], b[1]) : a[1] - b[1];
#	});
#	print(size(routes));
#	foreach (var r; routes) print (r ~ ":" ~ r[0]);
    }
    return size(routes);
}

var add_waypoint = func (ID, name, type, coord) { #add a waypoint to a route
    var waypoint = gps_data.getNode("route/Waypoint["~screenWaypointsList.n~"]/",1);
    screenWaypointsList.n += 1;
    waypoint.getNode("ID",1).setValue(ID);
    waypoint.getNode("latitude-deg",1).setDoubleValue(coord[0]);
    waypoint.getNode("longitude-deg",1).setDoubleValue(coord[1]);
    waypoint.getNode("altitude-ft",1).setDoubleValue(coord[2]*alt_conv[1][0]);
    waypoint.getNode("name",1).setValue(name);
    waypoint.getNode("desc",1).setValue("no infos");
    waypoint.getNode("waypoint-type",1).setValue(type);
}

var save_route = func { #save the route
    screenWaypointsList.n != 0 or return;
    var first_id = gps_data.getNode("route/Waypoint/ID").getValue();
    var last_id = gps_data.getNode("route/Waypoint["~(screenWaypointsList.n - 1)~"]/ID").getValue();
    var path = getprop("/sim/fg-home") ~ "/Export/"~first_id~"-"~last_id~".xml";
    var args = props.Node.new({ filename : path });
    var export = args.getNode("data", 1);
    props.copy(gps_data.getNode("route"), export);
    fgcommand("savexml", args);
}

var Waypoint_to_scratch = func (node) {
    scratch.getNode("latitude-deg",1).setValue(node.getNode("latitude-deg").getValue());
    scratch.getNode("longitude-deg",1).setValue(node.getNode("longitude-deg").getValue());
    scratch.getNode("altitude-ft",1).setValue(node.getNode("altitude-ft").getValue());
    scratch.getNode("ident").setValue(node.getNode("ID").getValue());
    if (node.getNode("name") != nil)
        scratch.getNode("name",1).setValue(node.getNode("name").getValue());
    else
        scratch.getNode("name",1).setValue("");
    if (node.getNode("type") != nil)
        scratch.getNode("type",1).setValue(node.getNode("waypoint-type").getValue());
    else
        scratch.getNode("type",1).setValue("");
}

var waypointAlert = func { #alert pilot about waypoint approach
    if (mode) { 
	var ttw = getprop("/instrumentation/gps/wp/wp[1]/TTW-sec");
	ttw > -1 or return;
	if (ttw < thresold_alert[thresold_alert_index])
	    gps_data.getNode("waypoint-alert",1).setBoolValue(1);
	else
	    gps_data.getNode("waypoint-alert",1).setBoolValue(0);
    }
}

### turnpoints management ######################################################
var load_bookmarks = func { #load turnpoints
    var n = 0;
    gps_data.getNode("bookmarks",1).removeChildren("bookmark");
    var file = getprop("/sim/fg-home") ~ "/Export/bookmarks.xml";
    var s = io.stat(file);
    if (s != nil) {
	fgcommand("loadxml", props.Node.new({
	    "filename": file,
	    "targetnode": "/instrumentation/gps/bookmarks"
	}));
	foreach (var c ;props.globals.getNode("/instrumentation/gps/bookmarks").getChildren("bookmark")) n += 1;
    }
    else 
	print(file ~ " not found...");
    return n;
}

var save_bookmarks = func { #save turnpoints
    var path = getprop("/sim/fg-home") ~ "/Export/bookmarks.xml";
    var args = props.Node.new({ filename : path });
    var export = args.getNode("data", 1);
    props.copy(gps_data.getNode("bookmarks"), export);
    fgcommand("savexml", args);
}

var add_bookmark = func (ID, name, type, coord) { #add turnpoint
    var bookmark = gps_data.getNode("bookmarks/bookmark["~screenTurnpointSelect.n~"]/",1);
    screenTurnpointSelect.n += 1;
    bookmark.getNode("ID",1).setValue(ID);
    bookmark.getNode("latitude-deg",1).setDoubleValue(coord[0]);
    bookmark.getNode("longitude-deg",1).setDoubleValue(coord[1]);
    bookmark.getNode("altitude-ft",1).setDoubleValue(coord[2]*alt_conv[1][0]);
    bookmark.getNode("desc",1).setValue("no infos");
    bookmark.getNode("name",1).setValue(name);
    bookmark.getNode("waypoint-type",1).setValue(type);
    save_bookmarks();
}

var EditMode = func (length, title, start_command, numcar = 0) {
    #special mode for editing simple text
    screenEdit.previous_mode = mode;
    screenEdit.previous_page = page;
    mode = 5; #ID edition
    page = 0;
    screenEdit.init(length, title, start_command, numcar);
}

### initialisation stuff ###################################################
var load_screens = func {
    var zkv500_dir = getprop("/sim/fg-root") ~ "/Aircraft/Instruments-3d/zkv500/";
    io.load_nasal(zkv500_dir ~ "AirportScreens.nas","zkv500");
    io.load_nasal(zkv500_dir ~ "TurnpointScreens.nas","zkv500");
    io.load_nasal(zkv500_dir ~ "MainScreens.nas","zkv500");
    io.load_nasal(zkv500_dir ~ "TaskScreens.nas","zkv500");
}

var organize_screens = func {
    screen = []; #empty screens
    append(screen, zkv500.screenModeAndSettings); #0
    append(screen, zkv500.screenPositionMain);    #1
    append(screen, zkv500.screenOdometers);	  #2
    append(screen, zkv500.screenWindInfos);	  #3
    append(screen, zkv500.screenNavigationMain);  #4
    append(screen, zkv500.screenAirportMain);     #5
    append(screen, zkv500.screenAirportInfos);    #6
    append(screen, zkv500.screenSearchAirport);   #7
    append(screen, zkv500.screenTurnpointSelect); #8
    append(screen, zkv500.screenTurnpointInfos);  #9
    append(screen, zkv500.screenTaskSelect);      #10
    append(screen, zkv500.screenWaypointInfos);   #11
    append(screen, zkv500.screenWaypointsList);   #12
    append(screen, zkv500.screenEdit);		  #13
}

var init_gps_variables = func {
    mode = 0;
    page = 0;
    displayed_screen = 0; #screenModeAndSettings
    blocked = 0; #unlock left_knob
    #isOn = 0; #start OFF
    startpos = nil; #unset start position
    waypointindex = 0; #route waypoint index on beginning
}

var init_gps_props = func {
    for (var i = 0; i < LINES; i += 1) {
	append(line, props.globals.getNode("/instrumentation/zkv500/line[" ~ i ~ "]", 1));
	line[i].setValue("");
    }
    props.globals.getNode("/instrumentation/zkv500/retro-light",1).setDoubleValue(0);
    props.globals.getNode("/instrumentation/zkv500/power",1).setIntValue(0);
    aircraft.light.new("/sim/model/gps/redled", [0.1, 0.1, 0.1, 0.7], "/instrumentation/gps/waypoint-alert");
    aircraft.light.new("/sim/model/gps/greenled", [0.6, 0.3], "/instrumentation/gps/message-alert");
    startpos = geo.Coord.new(geo.aircraft_position());
    screenPositionMain.begin_time = props.globals.getNode("/sim/time/elapsed-sec",1).getValue();
    setlistener("/instrumentation/gps/serviceable", func {
	if (getprop("/instrumentation/gps/serviceable") == 0)
	    setprop("/instrumentation/zkv500/retro-light", 0);
	elsif (isOn > 0)
	    setprop("/instrumentation/zkv500/retro-light", (isOn - 1)/20);
    }, 0, 0);
}

var init = func() {
    load_screens();
    organize_screens();
    init_gps_variables();
    init_gps_props();
    print("GPS... initialized");
}

setlistener("/sim/signals/fdm-initialized",init);
