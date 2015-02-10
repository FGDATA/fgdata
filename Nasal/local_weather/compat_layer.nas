
########################################################
# compatibility layer for local weather package
# Thorsten Renk, March 2011
########################################################

# function			purpose
#
# setDefaultCloudsOff		to remove the standard Flightgear 3d clouds
# setVisibility			to set the visibility to a given value
# setLift			to set lift to given value
# setRain			to set rain to a given value
# setSnow			to set snow to a given value
# setTurbulence			to set turbulence to a given value
# setTemperature		to set temperature to a given value
# setPressure			to set pressure to a given value
# setDewpoint			to set the dewpoint to a given value
# setLight			to set light saturation to given value
# setWind			to set wind
# setWindSmoothly 		to set the wind gradually across a second
# smooth_wind_loop		(helper function for setWindSmoothly)
# create_cloud			to place a single cloud into the scenery
# create_impostor		to place an impostor sheet mimicking far clouds into the scene
# create_cloud_array		to place clouds from storage arrays into the scenery
# get_elevation			to get the terrain elevation at given coordinates
# get_elevation_vector		to get terrain elevation at given coordinate vector
# set_wxradarecho_storm		to provide info about a storm to the wxradar


# This file contains portability wrappers for the local weather system: 
#   http://wiki.flightgear.org/index.php/A_local_weather_system
#   
# This module is intended to provide a certain degree of backward compatibility for past 
# FlightGear releases, while sketching out the low level APIs used and required by the 
# local weather system, as these
# are being added to FlightGear.
#
# This file contains various workarounds for doing things that are currently not yet directly 
# supported by the core FlightGear/Nasal APIs (fgfs 2.0).
#
# Some of these workarounds are purely implemented in Nasal space, and may thus not provide sufficient
# performance in some situations.
#
# The goal is to move all such workarounds eventually  into this module, so that the high level weather modules
# only refer to this "compatibility layer" (using an "ideal API"), while this module handles 
# implementation details 
# and differences among different versions of FlightGear, so that key APIs can be ported to C++ space 
# for the sake
# of improving runtime performance and efficiency.
#
# This provides an abstraction layer that isolates the rest of the local weather system from low 
# level implementation details.
# 
# C++ developers who want to help improve the local weather system (or the FlightGear/Nasal 
# interface in general) should 
# check out this file (as well as the wiki page) for APIs or features that shall eventually be 
# re/implemented in C++ space for
# improving the local weather system.
#
# 
# This module provides a handful of helpers for dynamically querying the Nasal API of the running fgfs binary,
# so that it can make use of new APIs (where available), while still working with older fgfs versions.
#
# Note: The point of these helpers is that they should really only be used 
# by this module, and not in other parts/files of the 
# local weather system. Any hard coded special cases should be moved into this module.
#
# The compatibility layer is currently work in progress and will be extended as new Nasal 
# APIs are being added to FlightGear.

var weather_dynamics = nil;
var weather_tile_management = nil;
var compat_layer = nil;
var weather_tiles = nil;


_setlistener("/nasal/local_weather/loaded", func { 

compat_layer = local_weather;
weather_dynamics = local_weather;
weather_tile_management = local_weather;
weather_tiles = local_weather;


var result = "yes";

if (1==0) # no compatibility tests for 2.4 binary, it has the required features
	{
print("Compatibility layer: testing for hard coded support");

if (props.globals.getNode("/rendering/scene/saturation", 0) == nil)
	{result = "no"; features.can_set_light = 0;}
else
	{result = "yes"; features.can_set_light = 1;}
print("* can set light saturation:        "~result);


if (props.globals.getNode("/rendering/scene/scattering", 0) == nil)
	{result = "no"; features.can_set_scattering = 0;}
else
	{result = "yes"; features.can_set_scattering = 1;}
print("* can set horizon scattering:      "~result);

if (props.globals.getNode("/environment/terrain", 0) == nil)
	{result = "no"; features.terrain_presampling = 0;}
else
	{result = "yes"; features.terrain_presampling = 1;setprop("/environment/terrain/area[0]/enabled",1);}
print("* hard coded terrain presampling:  "~result);

if ((props.globals.getNode("/environment/terrain/area[0]/enabled",1).getBoolValue() == 1) and (features.terrain_presampling ==1))
	{result = "yes"; features.terrain_presampling_active = 1;}
else
	{result = "no"; features.terrain_presampling_active = 0;}
print("* terrain presampling initialized: "~result);


if (props.globals.getNode("/environment/config/enabled", 0) == nil)
	{result = "no"; features.can_disable_environment = 0;}
else
	{result = "yes"; features.can_disable_environment = 1;}
print("* can disable global weather:      "~result);


print("Compatibility layer: tests done.");
	}


# features of a 2.4 binary

# switch terrainsampler to active, should be initialized


features.can_set_light = 1;
features.can_set_scattering = 1;
features.terrain_presampling = 1;
features.terrain_presampling_active = 1;
features.can_disable_environment = 1;



# features of a current GIT binary

features.fast_geodinfo = 1;


# do actual startup()
local_weather.updateMenu();
local_weather.startup();

});





var setDefaultCloudsOff = func {

var layers = props.globals.getNode("/environment/clouds").getChildren("layer");
	
foreach (var l; layers)
	{
	l.getNode("coverage-type").setValue(5);
	}
	


# we store that information ourselves, so this should be zero, but rain forces us to go for an offset
setprop("/environment/clouds/layer[0]/elevation-ft",0.0);
		
# layer wrapping off
setprop("/sim/rendering/clouds3d-wrap",0);

# rain altitude limit off, detailed precipitation control on

props.globals.getNode("/environment/params/use-external-precipitation-level").setBoolValue("true");
props.globals.getNode("/environment/precipitation-control/detailed-precipitation").setBoolValue("true");


# set skydome unloading off

setprop("/sim/rendering/minimum-sky-visibility", 0.0);

# just to be sure, set other parameters off

compat_layer.setRain(0.0);
compat_layer.setSnow(0.0);
compat_layer.setLight(1.0);

}


####################################
# set visibility to given value
####################################

var setVisibility = func (vis) {

setprop("/environment/visibility-m",vis);
	
}


var setVisibilitySmoothly = func (vis) {


visibility_target = vis;
visibility_current = getprop("/environment/visibility-m");

if (smooth_visibility_loop_flag == 0)
	{
	smooth_visibility_loop_flag = 1;
	visibility_loop();
	}
}

var visibility_loop = func {

if (local_weather.local_weather_running_flag == 0) {return;}

if (visibility_target == visibility_current)
	{smooth_visibility_loop_flag = 0; return;}

if (visibility_target < visibility_current)
	{
	var vis_goal = visibility_target;
	if (vis_goal < 0.97 * visibility_current) {vis_goal = 0.97 * visibility_current;}
	}
else
	{
	var vis_goal = visibility_target;
	if (vis_goal > 1.03 * visibility_current) {vis_goal = 1.03 * visibility_current;}
	}
#	print(vis_goal, " ",local_weather.interpolated_conditions.visibility_m );
if (local_weather.interpolated_conditions.visibility_m > vis_goal)
	{setprop("/environment/visibility-m",vis_goal);}
	visibility_current = vis_goal;	

settimer( func {visibility_loop(); },0);
}


####################################
# set thermal lift to given value
####################################

var setLift = func (lift) {

setprop("/environment/local-weather-lift-fps",lift);
	
}

####################################
# set rain properties
####################################

var setRain = func (rain) {

setprop("/environment/rain-norm", rain);
}


var setRainDropletSize = func (size) {

setprop("/environment/precipitation-control/rain-droplet-size", size);
}

####################################
# set snow properties
####################################

var setSnow = func (snow) {

setprop("/environment/snow-norm", snow);
}

var setSnowFlakeSize = func (size) {

setprop("/environment/precipitation-control/snow-flake-size", size);
}



####################################
# set turbulence to given value
####################################

var setTurbulence = func (turbulence) {
	
setprop("/environment/turbulence/magnitude-norm",turbulence);
setprop("/environment/turbulence/rate-hz",3.0);
}


####################################
# set temperature to given value
####################################

var setTemperature = func (T) {

setprop("/environment/temperature-sea-level-degc",T);
}

####################################
# set pressure to given value
####################################

var setPressure = func (p) {

setprop("/environment/pressure-sea-level-inhg",p);
}

####################################
# set dewpoint to given value
####################################

var setDewpoint = func (D) {

setprop("/environment/dewpoint-sea-level-degc",D);
}

####################################
# set light saturation to given value
####################################

var setLight = func (s) {

setprop("/rendering/scene/saturation",s);
}

var setLightSmoothly = func (s) {

light_target = s;
light_current = getprop("/rendering/scene/saturation");

if (smooth_light_loop_flag == 0)
	{
	smooth_light_loop_flag = 1;
	light_loop();
	}
}

var light_loop = func {

if (local_weather.local_weather_running_flag == 0) {return;}

if (light_target == light_current)
	{smooth_light_loop_flag = 0; return;}

if (light_target < light_current)
	{
	var light_goal = light_target;
	if (light_goal < 0.97 * light_current) {light_goal = 0.97 * light_current;}
	}
else
	{
	var light_goal = light_target;
	if (light_goal > 1.03 * light_current) {light_goal = 1.03 * light_current;}
	}
	
setprop("/rendering/scene/saturation",light_goal);
light_current = light_goal;	

settimer( func {light_loop(); },0);
}


####################################
# set horizon scattering
####################################

var setScattering = func (s) {

setprop("/rendering/scene/scattering",s);
}

####################################
# set overcast haze
####################################

var setOvercast = func (o) {

setprop("/rendering/scene/overcast",o);
}


####################################
# set skydome scattering parameters
####################################

var setSkydomeShader = func (r, m, d) {

setprop("/sim/rendering/rayleigh", r);
setprop("/sim/rendering/mie", m);
setprop("/sim/rendering/dome-density",d);
}

###########################################################
# set wind to given direction and speed
###########################################################


var setWind = func (dir, speed) {

setprop("/environment/wind-from-heading-deg",dir);
setprop("/environment/wind-speed-kt",speed);
	

# this is needed to trigger the cloud drift to pick up the new wind setting
setprop("/environment/clouds/layer[0]/elevation-ft",0.0);
	
}

###########################################################
# set wind smoothly to given direction and speed
# interpolating across several frames
###########################################################


var setWindSmoothly = func (dir, speed) {

setWind(dir, speed);	
}


###########################################################
# place a single cloud 
###########################################################

var create_cloud = func(path, lat, long, alt, heading) {

var tile_counter = getprop(lw~"tiles/tile-counter");
var buffer_flag = getprop(lw~"config/buffer-flag");
var d_max = weather_tile_management.cloud_view_distance + 1000.0;

# noctilucent clouds should not be deleted with the tile, hence they're assigned to tile zero
if (find("noctilucent",path) != -1)
	{tile_counter=0;}

# check if we deal with a convective cloud - no need to do this any more, convective clouds go via a different system

var convective_flag = 0;

#if (find("cumulus",path) != -1)
#	{
#	if ((find("alto",path) != -1) or (find("cirro", path) != -1) or (find("strato", path) != -1))
#		{convective_flag = 0;}
#	else if ((find("small",path) != -1) or (find("whisp",path) != -1)) 
#		{convective_flag = 1;}
#	else if (find("bottom",path) != -1) 
#		{convective_flag = 4;}
#	else	
#		{convective_flag = 2;}
#	
#	}
#else if (find("congestus",path) != -1)
#	{
#	if (find("bottom",path) != -1) 
#		{convective_flag = 5;}
#	else
#		{convective_flag = 3;}
#	} 

#print("path: ", path, " flag: ", convective_flag);

# first check if the cloud should be stored in the buffer
# we keep it if it is in visual range or at high altitude (where visual range is different)



# now check if we are writing from the buffer, in this case change tile index
# to buffered one

if (getprop(lw~"tmp/buffer-status") == "placing")
	{
	tile_counter = buffered_tile_index;
	}



# if the cloud is not buffered, get property tree nodes and write it 
# into the scenery

var n = props.globals.getNode("local-weather/clouds", 1);
var c = n.getChild("tile",tile_counter,1);


var cloud_number = n.getNode("placement-index").getValue();
		for (var i = cloud_number; 1; i += 1)
			if (c.getChild("cloud", i, 0) == nil)
				break;
var cl = c.getChild("cloud", i, 1);
n.getNode("placement-index").setValue(i);

var placement_index = i;

var model_number = n.getNode("model-placement-index").getValue();
var m = props.globals.getNode("models", 1);
		for (var i = model_number; 1; i += 1)
			if (m.getChild("model", i, 0) == nil)
				break;
var model = m.getChild("model", i, 1);
n.getNode("model-placement-index").setValue(i);	



var latN = cl.getNode("position/latitude-deg", 1); latN.setValue(lat);
var lonN = cl.getNode("position/longitude-deg", 1); lonN.setValue(long);
var altN = cl.getNode("position/altitude-ft", 1); altN.setValue(alt);
var hdgN = cl.getNode("orientation/true-heading-deg", 1); hdgN.setValue(heading);

cl.getNode("tile-index",1).setValue(tile_counter);

model.getNode("path", 1).setValue(path);
model.getNode("latitude-deg", 1).setValue(lat);
model.getNode("longitude-deg", 1).setValue(long);
model.getNode("elevation-ft", 1).setValue(alt);
model.getNode("heading-deg", 1).setValue(local_weather.wind.cloudlayer[0]+180.0);
model.getNode("tile-index",1).setValue(tile_counter);
model.getNode("speed-kt",1).setValue(local_weather.wind.cloudlayer[1]);
model.getNode("load", 1).remove();


#model.getNode("latitude-deg-prop", 1).setValue(latN.getPath());
#model.getNode("longitude-deg-prop", 1).setValue(lonN.getPath());
#model.getNode("elevation-ft-prop", 1).setValue(altN.getPath());
#model.getNode("heading-deg-prop", 1).setValue(hdgN.getPath());

# sort the cloud into the cloud hash array

if (buffer_flag == 1)
	{
	var cs = weather_tile_management.cloudScenery.new(tile_counter, convective_flag, cl, model);
	append(weather_tile_management.cloudSceneryArray,cs);
	}

# if weather dynamics is on, also create a timestamp property and sort the cloud hash into quadtree

if (local_weather.dynamics_flag == 1)
	{
	cs.timestamp = weather_dynamics.time_lw;
	cs.write_index = placement_index;


	if (getprop(lw~"tmp/buffer-status") == "placing")
		{
		var blat = buffered_tile_latitude;
		var blon = buffered_tile_longitude;
		var alpha = buffered_tile_alpha;
		}
	else
		{
		var blat = getprop(lw~"tiles/tmp/latitude-deg");
		var blon = getprop(lw~"tiles/tmp/longitude-deg");
		var alpha = getprop(lw~"tmp/tile-orientation-deg");
		}
	weather_dynamics.sort_into_quadtree(blat, blon, alpha, lat, long, weather_dynamics.cloudQuadtrees[tile_counter-1], cs); 
	}

}


###########################################################
# place an impostor sheet 
###########################################################

var create_impostor = func(path, lat, long, alt, heading) {

var n = props.globals.getNode("local-weather/clouds", 1);
var model_number = n.getNode("model-placement-index").getValue();
var m = props.globals.getNode("models", 1);
		for (var i = model_number; 1; i += 1)
			if (m.getChild("model", i, 0) == nil)
				break;
var model = m.getChild("model", i, 1);
n.getNode("model-placement-index").setValue(i);	


model.getNode("path", 1).setValue(path);
model.getNode("latitude-deg", 1).setValue(lat);
model.getNode("longitude-deg", 1).setValue(long);
model.getNode("elevation-ft", 1).setValue(alt);
model.getNode("heading-deg", 1).setValue(local_weather.wind.cloudlayer[0]+180.0);
model.getNode("speed-kt",1).setValue(local_weather.wind.cloudlayer[1]);
model.getNode("load", 1).remove();


var imp = weather_tile_management.cloudImpostor.new(model);
append(weather_tile_management.cloudImpostorArray,imp);


}


###########################################################
# place a  model
###########################################################

var place_model = func(path, lat, lon, alt, heading, pitch, yaw) {



var m = props.globals.getNode("models", 1);
		for (var i = 0; 1; i += 1)
			if (m.getChild("model", i, 0) == nil)
				break;
var model = m.getChild("model", i, 1);


model.getNode("path", 1).setValue(path);
model.getNode("latitude-deg", 1).setValue(lat);
model.getNode("longitude-deg", 1).setValue(lon);
model.getNode("elevation-ft", 1).setValue(alt);
model.getNode("heading-deg", 1).setValue(heading);
model.getNode("pitch-deg", 1).setValue(pitch);
model.getNode("roll-deg", 1).setValue(yaw);
model.getNode("load", 1).remove();


}




###########################################################
# place a single cloud using hard-coded system
###########################################################

var create_cloud_new = func(c) {



var tile_counter = getprop(lw~"tiles/tile-counter");
cloud_index = cloud_index + 1;

c.index = tile_counter;
c.cloud_index = cloud_index;

# light must be such that the top of a cloud cannot be darker than the bottom

if (c.bottom_shade > c.top_shade) {c.bottom_shade = c.top_shade;}
c.middle_shade = c.top_shade;

# write the actual cloud into the scenery


var p = props.Node.new({ "layer" : 0,
                         "index": cloud_index,
                         "lat-deg": c.lat,
                         "lon-deg": c.lon,
			 "min-sprite-width-m": c.min_width,
			 "max-sprite-width-m": c.max_width,
			 "min-sprite-height-m": c.min_height,
			 "max-sprite-height-m": c.max_height,
			 "num-sprites": c.n_sprites,
			 "min-bottom-lighting-factor": c.bottom_shade,
			 "min-middle-lighting-factor": c.middle_shade,
			 "min-top-lighting-factor": c.top_shade,
			 "alpha-factor": c.alpha_factor,
			 "min-shade-lighting-factor": c.bottom_shade,
			 "texture": c.texture_sheet,
			 "num-textures-x": c.num_tex_x,
			 "num-textures-y": c.num_tex_y,
			 "min-cloud-width-m": c.min_cloud_width,
			 "max-cloud-width-m": c.min_cloud_width,
			 "min-cloud-height-m": c.min_cloud_height + c.min_cloud_height * 0.2 * local_weather.height_bias,	
			 "max-cloud-height-m": c.min_cloud_height + c.min_cloud_height * 0.2 * local_weather.height_bias,	
			 "z-scale": c.z_scale,
			 "height-map-texture": 0,
                         "alt-ft" :  c.alt });
fgcommand("add-cloud", p);

#print("alt: ", c.alt);

# add other management properties to the hash if dynamics is on

if (local_weather.dynamics_flag == 1)
	{
	c.timestamp = weather_dynamics.time_lw;
	}


# add cloud to array

append(weather_tile_management.cloudArray,c);
	

}







###########################################################
# place a cloud layer from arrays, split across frames 
###########################################################

var create_cloud_array = func (i, clouds_path, clouds_lat, clouds_lon, clouds_alt, clouds_orientation) {

if (getprop(lw~"tmp/thread-status") != "placing") {return;}
if (getprop(lw~"tmp/convective-status") != "idle") {return;}
if ((i < 0) or (i==0)) 
	{
	if (local_weather.debug_output_flag == 1) 
		{print("Cloud placement from array finished!"); }

	# then place all clouds using the new rendering system
	if (local_weather.hardcoded_clouds_flag == 1)
		{
		var s = size(local_weather.cloudAssemblyArray);
		create_new_cloud_array(s,cloudAssemblyArray);
		}
	
	setprop(lw~"tmp/thread-status", "idle");

	# now set flag that tile has been completely processed
	var dir_index = props.globals.getNode(lw~"tiles/tmp/dir-index").getValue();

	setprop(lw~"tiles/tile["~dir_index~"]/generated-flag",2);	

	return;
	}


var k_max = 30;
var s = size(clouds_path);  

if (s < k_max) {k_max = s;}

for (var k = 0; k < k_max; k = k+1)
	{
	if (getprop(lw~"config/dynamics-flag") ==1)
		{
		cloud_mean_altitude = local_weather.clouds_mean_alt[s-k-1];
		cloud_flt = local_weather.clouds_flt[s-k-1];
		cloud_evolution_timestamp = local_weather.clouds_evolution_timestamp[s-k-1];
		}
	create_cloud(clouds_path[s-k-1], clouds_lat[s-k-1], clouds_lon[s-k-1], clouds_alt[s-k-1], clouds_orientation[s-k-1]);
	#create_cloud_new(clouds_path[s-k-1], clouds_lat[s-k-1], clouds_lon[s-k-1], clouds_alt[s-k-1], clouds_orientation[s-k-1]);
	}

setsize(clouds_path,s-k_max);
setsize(clouds_lat,s-k_max);
setsize(clouds_lon,s-k_max);
setsize(clouds_alt,s-k_max);
setsize(clouds_orientation,s-k_max);

if (getprop(lw~"config/dynamics-flag") ==1)
		{
		setsize(local_weather.clouds_mean_alt,s-k_max);
		setsize(local_weather.clouds_flt,s-k_max);
		setsize(local_weather.clouds_evolution_timestamp,s-k_max);
		}

settimer( func {create_cloud_array(i - k, clouds_path, clouds_lat, clouds_lon, clouds_alt, clouds_orientation ) }, 0 );
};


var create_new_cloud_array = func (i, cloudArray)
{




if ((i < 0) or (i==0)) 
	{
	if (local_weather.debug_output_flag == 1) 
		{print("Processing add-cloud calls finished!"); }
	return;
	}


var k_max = 20;
var s = size(cloudArray);  

if (s < k_max) {k_max = s;}

for (var k = 0; k < k_max; k = k+1)
	{
	local_weather.create_cloud_new(cloudArray[s-k-1]);
	#print(cloudArray[s-k-1].alt);
	}

setsize(cloudArray,s-k_max);



settimer( func {create_new_cloud_array(i - k, cloudArray) }, 0 );
}





###########################################################
# get terrain elevation
###########################################################

var get_elevation = func (lat, lon) {

var info = geodinfo(lat, lon);
	if (info != nil) {var elevation = info[0] * local_weather.m_to_ft;}
	else {var elevation = -1.0; }


return elevation;
}

###########################################################
# get terrain elevation vector
###########################################################

var get_elevation_array = func (lat, lon) {

var elevation = [];
var n = size(lat);


for(var i = 0; i < n; i=i+1)
	{
	append(elevation, get_elevation(lat[i], lon[i]));
	}
	

return elevation;
}

###########################################################
# set the wxradar echo of a storm
###########################################################

var set_wxradarecho_storm = func (lat, lon, base, top, radius, ref, turb, type) {

# look for the next free index in the wxradar property tree entries

var n = props.globals.getNode("/instrumentation/wxradar", 1);
		for (var i = 0; 1; i += 1)
			if (n.getChild("storm", i, 0) == nil)
				break;
var s = n.getChild("storm", i, 1);


s.getNode("latitude-deg",1).setValue(lat);
s.getNode("longitude-deg",1).setValue(lon);
s.getNode("heading-deg",1).setValue(0.0);
s.getNode("base-altitude-ft",1).setValue(base);
s.getNode("top-altitude-ft",1).setValue(top);
s.getNode("radius-nm",1).setValue(radius * m_to_nm);
s.getNode("reflectivity-norm",1).setValue(ref);
s.getNode("turbulence-norm",1).setValue(turb);
s.getNode("type",1).setValue(type);
s.getNode("show",1).setValue(1);
}

###########################################################
# remove unused echos
###########################################################

var remove_wxradar_echos = func { 

var distance_to_remove = 70000.0;

var storms = props.globals.getNode("/instrumentation/wxradar", 1).getChildren("storm");

var pos = geo.aircraft_position();

foreach (s; storms)
	{
	var d_sq = local_weather.calc_d_sq(pos.lat(), pos.lon(), s.getNode("latitude-deg").getValue(), s.getNode("longitude-deg").getValue());
	if (d_sq > distance_to_remove * distance_to_remove)
		{
		s.remove();
		}
	}

}

############################################################
# global variables
############################################################

# conversions

var nm_to_m = 1852.00;
var m_to_nm = 1.0/nm_to_m; 

# some common abbreviations

var lw = "/local-weather/";
var ec = "/environment/config/";

# storage arrays for model vector

var mvec = [];
var msize = 0;

# loop flags and variables

var smooth_visibility_loop_flag = 0;

var visibility_target = 0.0;
var visibility_current = 0.0;

var smooth_light_loop_flag = 0;

var light_target = 0.0;
var light_current = 0.0;

# available hard-coded support

var features = {};

# globals to transmit info if clouds are written from buffer

var buffered_tile_latitude = 0.0;
var buffered_tile_longitude = 0.0;
var buffered_tile_alpha = 0.0;
var buffered_tile_index = 0;

# globals to handle additional info for Cumulus cloud dynamics

var cloud_mean_altitude = 0.0;
var cloud_flt = 0.0;
var cloud_evolution_timestamp = 0.0;

# globals to handle new cloud indexing

var cloud_index = 0;
