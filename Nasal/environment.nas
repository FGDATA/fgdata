##
## environment.nas
##
##  Nasal code for implementing environment-specific functionality.

##
# Handler.  Increase visibility by one step
#
var increaseVisibility = func {
	adjustVisibility(1.1);
}

##
# Handler.  Decrease visibility by one step
#
var decreaseVisibility = func {
	adjustVisibility(0.9);
}

var adjustVisibility = func( factor ) {
	var val = 0;
	var aux_val = 0;
    # better to use a non gui/dialog property here, but there doesn't
    # seem to be one for local-weather. 
	var localWeatherEnabled = getprop("sim/gui/dialogs/metar/mode/local-weather");
	var max_aux_vis = 12.429216196;
	var min_aux_vis = 9.90348;

    if (localWeatherEnabled) {
		if (factor == 1.1)
			factor = 1.001;
		else 
			factor = 0.999;

		aux_val = auxvisibilityProp.getValue() * factor;

		if( aux_val <= min_aux_vis)
			auxvisibilityProp.setDoubleValue(min_aux_vis);
		elsif(aux_val >= max_aux_vis)
			auxvisibilityProp.setDoubleValue(max_aux_vis);
		else
			auxvisibilityProp.setDoubleValue(aux_val);
 
		gui.popupTip(sprintf("Max Visibility: %.0f m", getprop("/local-weather/config/max-vis-range-m")));
	} else {
		val = visibilityProp.getValue() * factor;

		if( val < 1.0 ) val = getprop("/environment/visibility-m");

		if( val > 30 ) {
			visibilityProp.setDoubleValue(val);
			visibilityOverrideProp.setBoolValue(1);
			}

		gui.popupTip(sprintf("Visibility: %.0f m", val));
	}
}

##
# Handler.  Reset visibility to default.
#
var resetVisibility = func {
    visibilityProp.setDoubleValue(0);
    visibilityOverrideProp.setBoolValue(0);
}


var visibilityProp = nil;
var visibilityOverrideProp = nil;
var auxvisibilityProp = nil;

_setlistener("/sim/signals/nasal-dir-initialized", func {
	print ("environment init");
	visibilityProp = props.globals.initNode("/environment/config/presets/visibility-m", 0, "DOUBLE" );
	visibilityOverrideProp = props.globals.initNode("/environment/config/presets/visibility-m-override", 0, "BOOL" );
	auxvisibilityProp = props.globals.initNode("/local-weather/config/aux-max-vis-range-m", 0, "DOUBLE" );
});
