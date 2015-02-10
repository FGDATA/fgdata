# Vibrating yaw string

io.include("Aircraft/Generic/soaring-instrumentation-sdk.nas");

var yawstring = YawString.new(
	on_update: update_prop("instrumentation/yawstring"));

var string_instrument = Instrument.new(
	components: [yawstring],
	enable: 1);
