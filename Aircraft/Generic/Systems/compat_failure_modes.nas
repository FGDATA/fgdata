# Compatibility failure modes
#
# Loads FailureMgr with the failure modes that where previously hardcoded,
# emulating former behavior and allowing backward compatibility.
#
# Copyright (C) 2014 Anton Gomez Alvedro
# Based on previous work by Stuart Buchanan, Erobo & John Denker
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation; either version 2 of the
# License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.

io.include("Aircraft/Generic/Systems/failures.nas");


MTBF = 0;
MCBF = 1;

SERV = 0;
JAM = 1;
ENG = 2;


var compat_modes = [
	# Instruments
	{ id: "instrumentation/adf",                      type: MTBF, failure: SERV, desc: "ADF" },
	{ id: "instrumentation/dme",                      type: MTBF, failure: SERV, desc: "DME" },
	{ id: "instrumentation/airspeed-indicator",       type: MTBF, failure: SERV, desc: "ASI" },
	{ id: "instrumentation/altimeter",                type: MTBF, failure: SERV, desc: "Altimeter" },
	{ id: "instrumentation/attitude-indicator",       type: MTBF, failure: SERV, desc: "Attitude Indicator" },
	{ id: "instrumentation/heading-indicator",        type: MTBF, failure: SERV, desc: "Heading Indicator" },
	{ id: "instrumentation/magnetic-compass",         type: MTBF, failure: SERV, desc: "Magnetic Compass" },
	{ id: "instrumentation/nav/gs",                   type: MTBF, failure: SERV, desc: "Nav 1 Glideslope" },
	{ id: "instrumentation/nav/cdi",                  type: MTBF, failure: SERV, desc: "Nav 1 CDI" },
	{ id: "instrumentation/nav[1]/gs",                type: MTBF, failure: SERV, desc: "Nav 2 Glideslope" },
	{ id: "instrumentation/nav[1]/cdi",               type: MTBF, failure: SERV, desc: "Nav 2 CDI" },
	{ id: "instrumentation/slip-skid-ball",           type: MTBF, failure: SERV, desc: "Slip/Skid Ball" },
	{ id: "instrumentation/turn-indicator",           type: MTBF, failure: SERV, desc: "Turn Indicator" },
	{ id: "instrumentation/vertical-speed-indicator", type: MTBF, failure: SERV, desc: "VSI" },

	# Systems
	{ id: "systems/electrical",                       type: MTBF, failure: SERV, desc: "Electrical system" },
	{ id: "systems/pitot",                            type: MTBF, failure: SERV, desc: "Pitot system" },
	{ id: "systems/static",                           type: MTBF, failure: SERV, desc: "Static system" },
	{ id: "systems/vacuum",                           type: MTBF, failure: SERV, desc: "Vacuum system" },

	# Controls
	{ id: "controls/flight/aileron",                  type: MTBF, failure: JAM, desc: "Aileron" },
	{ id: "controls/flight/elevator",                 type: MTBF, failure: JAM, desc: "Elevator" },
	{ id: "controls/flight/rudder",                   type: MTBF, failure: JAM, desc: "Rudder" },
	{ id: "controls/flight/flaps",                    type: MCBF, failure: JAM, desc: "Flaps" },
	{ id: "controls/flight/speedbrake",               type: MCBF, failure: JAM, desc: "Speed Brake" },
	{ id: "controls/gear",                            type: MCBF, failure: SERV, desc: "Gear", prop: "/gear", mcbf_prop: "/controls/gear/gear-down" }
];


##
# Handles the old failures.nas property tree interface,
# sending the appropriate commands to the new FailureMgr.

var compat_listener = func(prop) {

	var new_trigger = func {
		if (name == "mtbf") {
			MtbfTrigger.new(value);
		}
		else {
			var control = id;

			forindex(var i; compat_modes) {
				var mode = compat_modes[i];
				if (mode.id == id and contains(compat_modes[i], "mcbf_prop")) {
					control = mode.mcbf_prop;
					break;
				}
			}

			McbfTrigger.new(control, value);
		}
	};

	var name = prop.getName();
	var value = prop.getValue();
	var id = string.replace(io.dirname(prop.getPath()), FailureMgr.proproot, "");
	id = string.trim(id, 0, func(c) c == `/`);

	if (name == "serviceable") {
		FailureMgr.set_failure_level(id, 1 - value);
		return;
	}

	if (name == "failure-level") {
		setprop(io.dirname(prop.getPath()) ~ "/serviceable", value ? 0 : 1);
		return;
	}

	# mtbf and mcbf parameter handling
	var trigger = FailureMgr.get_trigger(id);

	if (value == 0) {
		trigger != nil and FailureMgr.set_trigger(id, nil);
		return;
	}

	if (trigger == nil) {
		FailureMgr.set_trigger(id, new_trigger());
	}
	else {
		trigger.set_param(name, value);
		trigger.reset();
	}
}

##
# Called from the ramdom-failures dialog to set the global MCBF parameter

var apply_global_mcbf = func(value) {
	foreach (var mode; compat_modes) {
		mode.type != MCBF and continue;
		setprop(FailureMgr.proproot ~ mode.id ~ "/mcbf", value);
	}
}

##
# Called from the ramdom-failures dialog to set the global MTBF parameter

var apply_global_mtbf = func(value) {
	foreach (var mode; compat_modes) {
		mode.type != MTBF and continue;
		setprop(FailureMgr.proproot ~ mode.id ~ "/mtbf", value);
	}
}

##
# Discover aircraft engines dynamically and add a failure mode to the
# compat_modes table for each engine.

var populate_engine_data = func {

	var engines = props.globals.getNode("/engines");
	var engine_id = 0;

	foreach (var e; engines.getChildren("engine")) {
		var starter = e.getChild("starter");
		var running = e.getChild("running");

		(starter != nil and starter != "" and starter.getType() != "NONE")
		or (running != nil and running != "" and running.getType() != "NONE")
		or continue;

		var id = "engines/engine";
		if (engine_id > 0)
			id = id ~ "[" ~ engine_id ~ "]";

		var entry = {
			id: id,
			desc: "Engine " ~ (engine_id + 1),
			type: MTBF,
			failure: ENG
		};

		append(compat_modes, entry);
		engine_id += 1;
	}
}

##
# Subscribes all failure modes that the old failures.nas module did,
# and recreates the same property tree interface (more or less).

var compat_setup = func {

	removelistener(lsnr);
	populate_engine_data();

	foreach (var m; compat_modes) {
		var control_prop = contains(m, "prop") ? m.prop : m.id;

		FailureMgr.add_failure_mode(
			id: m.id,
			description: m.desc,
			actuator: if (m.failure == SERV) set_unserviceable(control_prop)
			          elsif (m.failure == JAM) set_readonly(control_prop)
			          else fail_engine(io.basename(control_prop)));

		# Recreate the prop tree interface
		var prop = FailureMgr.proproot ~ m.id;
		var n = props.globals.initNode(prop ~ "/serviceable", 1, "BOOL");

		setlistener(n, compat_listener, 0, 0);
		setlistener(prop ~ "/failure-level", compat_listener, 0, 0);

		var trigger_type = (m.type == MTBF) ? "/mtbf" : "/mcbf";
		setprop(prop ~ trigger_type, 0);
		setlistener(prop ~ trigger_type, compat_listener, 0, 0);
	}
}


var lsnr = setlistener("sim/signals/fdm-initialized", compat_setup);
