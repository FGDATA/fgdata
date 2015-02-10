io.include("Aircraft/Generic/soaring-instrumentation-sdk.nas");

# Initialize exported properties
setprop("/instrumentation/ilec-sc7/volume", 0.8);
setprop("/instrumentation/ilec-sc7/audio", 2);
setprop("/instrumentation/ilec-sc7/mode", 1);
setprop("/instrumentation/ilec-sc7/sensitivity", 3);
setprop("/instrumentation/ilec-sc7/lcd-digits-abs", 0);
setprop("/instrumentation/ilec-sc7/lcd-digits-sgn", 0);
setprop("/instrumentation/ilec-sc7/te-reading-mps", 0);
setprop("/instrumentation/variometer/te-reading-mps", 0);

# Helper function for updating lcd display
var update_lcd_props = func(value) {
	setprop("/instrumentation/ilec-sc7/lcd-digits-abs", math.abs(value));
	setprop("/instrumentation/ilec-sc7/lcd-digits-sgn", (value < 0) ? 0 : 1);
};

# Instrument setup:

# One TE probe feeds two vario needles and a 25s averager.
# LCD digits are controlled by the.. um.. lcd_controller
# that switches between battery level, temperature and averager
# depending on mode switch posiion.

# Why a second needle? A digital vario is usually installed together
# with a mechanical one, so now we are at it, why not provide a bonus
# TE reading for it and avoid loading an extra script?

var probe = TotalEnergyProbe.new();

var sc7_needle = Dampener.new(
	input: probe,
	dampening: 3,
	on_update: update_prop("/instrumentation/ilec-sc7/te-reading-mps"));

var extra_needle = Dampener.new(
	input: probe,
	dampening: 2.7,
	on_update: update_prop("/instrumentation/variometer/te-reading-mps"));

var averager = Averager.new(
	input: probe,
	buffer_size: 25);

var battery_level = { output: 9.9 };

var temperature = PropertyReader.new(
	property: "environment/temperature-degc",
	scale: 0.1);

var lcd_controller = InputSwitcher.new(
	inputs: [battery_level, averager, temperature],
	active_input: 1,
	on_update: update_lcd_props);

# Subscribe property listeners for instrument switches
setlistener("instrumentation/ilec-sc7/mode",
	func(n) { lcd_controller.select_input(n.getValue()) }, 0, 0);

setlistener("instrumentation/ilec-sc7/sensitivity",
	func(n) { sc7_needle.dampening = n.getValue() }, 0, 0);

# Wrap everything together into an instrument
var fast_instruments = Instrument.new(
	update_period: 0,
	components: [probe, sc7_needle, extra_needle],
	enable: 1);

var slow_instruments = Instrument.new(
	update_period: 1,
	components: [averager, temperature, lcd_controller],
	enable: 1);
