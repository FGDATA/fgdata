var VOLTS_THRESHOLD = 24.5;
var FUEL_THRESHOLD = 5.0;
var VACUUM_THRESHOLD = 3.0;
var OIL_PRESSURE_THRESHOLD = 20.0;


var ann = {
	new : func(p) {
		var m = { parents : [ann] };
		m.node = props.globals.initNode(p, 0, "BOOL");
		m.stamp = nil;
		m.state = 0;
		return m;
	},
	switch : func(v) {
		if (v) {
			if (!me.state) {
				me.stamp = sec + 10;
				me.state = 1;
			}
			me.node.setBoolValue(sec < me.stamp ? clock : 1);

		} else {
			if (me.state)
				me.node.setBoolValue(me.state = 0);
		}
	},
};


var volts = props.globals.initNode("/systems/electrical/volts");
var vac_l = props.globals.initNode("/systems/vacuum[0]/suction-inhg");
var vac_r = props.globals.initNode("/systems/vacuum[1]/suction-inhg");
var fuel_l = props.globals.initNode("/consumables/fuel/tank[0]/level-gal_us");
var fuel_r = props.globals.initNode("/consumables/fuel/tank[1]/level-gal_us");
var oil_px = props.globals.initNode("/engines/engine[0]/oil-pressure-psi");
var elapsed = props.globals.initNode("/sim/time/elapsed-sec");


var ann_volts = ann.new("/instrumentation/annunciator/volts");
var ann_vac_l = ann.new("/instrumentation/annunciator/vacuum-left");
var ann_vac_r = ann.new("/instrumentation/annunciator/vacuum-right");
var ann_fuel_l = ann.new("/instrumentation/annunciator/fuel-left");
var ann_fuel_r = ann.new("/instrumentation/annunciator/fuel-right");
var ann_oil_px = ann.new("/instrumentation/annunciator/oil-pressure");


var clock = 0;
var sec = nil;

var main = func {
	clock = !clock;
	sec = elapsed.getValue();

	var v = volts.getValue();
	if (v < 5.0 or !serviceable) {
		ann_volts.switch(0);
		ann_vac_l.switch(0);
		ann_vac_r.switch(0);
		ann_fuel_l.switch(0);
		ann_fuel_r.switch(0);
		ann_oil_px.switch(0);
	} else {
		ann_volts.switch(v < VOLTS_THRESHOLD);
		ann_fuel_l.switch(fuel_l.getValue() < FUEL_THRESHOLD);
		ann_fuel_r.switch(fuel_r.getValue() < FUEL_THRESHOLD);
		ann_vac_l.switch(vac_l.getValue() < VACUUM_THRESHOLD);
		ann_vac_r.switch(vac_r.getValue() < VACUUM_THRESHOLD);
		ann_oil_px.switch(oil_px.getValue() < OIL_PRESSURE_THRESHOLD);
	}
	settimer(main, 0.5);
}


var serviceable = nil;

settimer(func {
	setlistener("/systems/electrical/serviceable", func(n) serviceable = n.getBoolValue(), 1);
	main();
}, 0);


