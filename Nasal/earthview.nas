###########################################################
# Earthview orbital rendering
###########################################################

var start = func() {

if (earthview_running_flag ==1) {return;}

earthview_running_flag = 1;

var lat = getprop("/position/latitude-deg");
var lon = getprop("/position/longitude-deg");

earth_model.node = earthview.place_earth_model("Models/Astro/earth.xml",lat, lon, 0.0, 0.0, 0.0, 0.0);
cloudsphere_model.node = earthview.place_earth_model("Models/Astro/cloudsphere.xml",lat, lon, 0.0, 0.0, 0.0, 0.0);

# set Basic Weather off
props.globals.getNode("/environment/config/enabled").setBoolValue(0);
props.globals.getNode("/environment/params/metar-updates-environment").setBoolValue(0);

# set some reasonable defaults

setprop("/environment/visibility-m", 80000.0);
setprop("/sim/rendering/mie", 0.0);
setprop("/sim/rendering/rayleigh", 0.00002);
setprop("/sim/rendering/dome-density", 1.0);

control_loop();

}

var stop = func () {

earth_model.node.remove();
cloudsphere_model.node.remove();
setprop("/earthview/control_loop_flag",0);

earthview_running_flag = 0;
}

var place_earth_model = func(path, lat, lon, alt, heading, pitch, roll) {



var m = props.globals.getNode("models", 1);
		for (var i = 0; 1; i += 1)
			if (m.getChild("model", i, 0) == nil)
				break;
var model = m.getChild("model", i, 1);

var R1 = 5800000.0;
var R2 = 58000.0;

var altitude1 = getprop("/position/altitude-ft");
var altitude2 = R2/R1 * altitude1;
var model_alt = altitude1 - altitude2 - R2 * m_to_ft;

setprop("/earthview/latitude-deg", lat);
setprop("/earthview/longitude-deg", lon);
setprop("/earthview/elevation-ft", model_alt);
setprop("/earthview/heading-deg", heading);
setprop("/earthview/pitch-deg", pitch);
setprop("/earthview/roll-deg", roll);
setprop("/earthview/yaw-deg", 0.0);

var eview = props.globals.getNode("earthview", 1);
var latN = eview.getNode("latitude-deg",1);
var lonN = eview.getNode("longitude-deg",1);
var altN = eview.getNode("elevation-ft",1);
var headN = eview.getNode("heading-deg",1);
var pitchN = eview.getNode("pitch-deg",1);
var rollN = eview.getNode("roll-deg",1);



model.getNode("path", 1).setValue(path);
model.getNode("latitude-deg-prop", 1).setValue(latN.getPath());
model.getNode("longitude-deg-prop", 1).setValue(lonN.getPath());
model.getNode("elevation-ft-prop", 1).setValue(altN.getPath());
model.getNode("heading-deg-prop", 1).setValue(headN.getPath());
model.getNode("pitch-deg-prop", 1).setValue(pitchN.getPath());
model.getNode("roll-deg-prop", 1).setValue(rollN.getPath());
model.getNode("load", 1).remove();

setprop("/earthview/heading-deg",90);
setprop("/earthview/control_loop_flag",1);



return model;
}


var control_loop = func {

var R1 = 5800000.0;
var R2 = 58000.0;

var altitude1 = getprop("/position/altitude-ft");
var altitude2 = R2/R1 * altitude1;
var model_alt = altitude1 - altitude2 - R2 * m_to_ft;

setprop("/earthview/elevation-ft", model_alt);

var lat = getprop("/position/latitude-deg");
var lon = getprop("/position/longitude-deg");

setprop("/earthview/latitude-deg", lat);
setprop("/earthview/longitude-deg", lon);

setprop("/earthview/roll-deg", -(90-lat));
setprop("/earthview/yaw-deg", -lon);

# now set scattering paramaters

if (getprop("/earthview/mrd-flag") == 1)
	{
	var rayleigh = 0.0002;
	var mie = 0.001;
	var density = 1.0;
	
	if (altitude1 < 300000.0)
		{
		setprop("/sim/rendering/rayleigh",rayleigh);
		setprop("/sim/rendering/mie",mie);
		setprop("/sim/rendering/dome-density",density);
		}
	else if (altitude1 < 650000.0)
		{
		rayleigh = rayleigh - 0.00018 * (altitude1-300000.0)/350000.0;
		mie = mie - 0.001 * (altitude1-300000.0)/350000.0;
		density = 1.0;
		setprop("/sim/rendering/rayleigh",rayleigh);
		setprop("/sim/rendering/mie",mie);
		setprop("/sim/rendering/dome-density",density);
		}
	else
		{
		rayleigh = 0.00002;
		mie = 0.0;
		density = 1.0;
		setprop("/sim/rendering/rayleigh",rayleigh);
		setprop("/sim/rendering/mie",mie);
		setprop("/sim/rendering/dome-density",density);
		}
	
	}


if (getprop("/earthview/control_loop_flag") ==1) {settimer( func {control_loop(); },0);}
}


var ft_to_m = 0.30480;
var m_to_ft = 1.0/ft_to_m;
var earth_model = {};
var cloudsphere_model = {};
var earthview_running_flag = 0;


