########################################################
# routines to simulate cloud wind drift and evolution
# Thorsten Renk, October 2010
########################################################

# function			purpose
#
# get_windfield			to get the current wind in the tile
# timing_loop			to provide accurate timing information for wind drift calculations
# quadtree_loop			to manage drift of clouds in the field of view
# weather_dynamics_loop		to manage drift of weather effects, tile centers and interpolation points
# convective_loop		to regularly recreate convective clouds
# generate_quadtree_structure	to generate a quadtree data structure used for managing the visual field
# sort_into_quadtree		to sort objects into a quadtree structure
# sorting_recursion		to recursively sort into a quadree (helper)
# quadtree_recursion		to search the quadtree for objects in the visual field
# check_visibility		to check if a quadrant is currently visible
# move_tile			to move tile coordinates in the wind
# get_cartesian			to get local Cartesian coordinates out of coordinates


####################################################
# get the windfield for a given location and altitude
# (currently constant, but supposed to be local later)
####################################################


var get_windfield = func (tile_index) {


if (hardcoded_clouds_flag == 1)
	{
	var wind_direction = local_weather.wind.current[0];
	var windspeed = local_weather.wind.current[1] * kt_to_ms;

	var windfield_x = -windspeed * math.sin(wind_direction * math.pi/180.0);
	var windfield_y = -windspeed * math.cos(wind_direction * math.pi/180.0);

	return [windfield_x,windfield_y];
	}





if ((local_weather.wind_model_flag == 1) or (local_weather.wind_model_flag == 3))
	{
	var windspeed = tile_wind_speed[0] * kt_to_ms;
	var wind_direction = tile_wind_direction[0];
	}
else if ((local_weather.wind_model_flag ==2) or (local_weather.wind_model_flag == 4) or (local_weather.wind_model_flag == 5))
	{
	var windspeed = tile_wind_speed[tile_index-1] * kt_to_ms;
	var wind_direction = tile_wind_direction[tile_index-1];
	}



var windfield_x = -windspeed * math.sin(wind_direction * math.pi/180.0);
var windfield_y = -windspeed * math.cos(wind_direction * math.pi/180.0);

return [windfield_x,windfield_y];
}


var get_wind_direction = func (tile_index) {

if (hardcoded_clouds_flag == 1)
	{
	return local_weather.wind.current[0];
	}

if ((local_weather.wind_model_flag == 1) or (local_weather.wind_model_flag == 3))
	{
	return tile_wind_direction[0];
	}
else if ((local_weather.wind_model_flag ==2) or (local_weather.wind_model_flag == 4) or (local_weather.wind_model_flag == 5))
	{
	return tile_wind_direction[tile_index-1];
	}

}

var get_wind_speed = func (tile_index) {

if (hardcoded_clouds_flag == 1)
	{
	return local_weather.wind.current[1];
	}

if ((local_weather.wind_model_flag == 1) or (local_weather.wind_model_flag == 3))
	{
	return tile_wind_speed[0];
	}
else if ((local_weather.wind_model_flag ==2) or (local_weather.wind_model_flag == 4) or (local_weather.wind_model_flag == 5))
	{
	return tile_wind_speed[tile_index-1];
	}

}

########################################################
# timing loop
# this gets the accurate time since the start of weather dynamics
# and hence the timestamps for cloud evolution since
# the available elapsed-time-sec is not accurate enough
########################################################

var timing_loop = func {

if (local_weather.local_weather_running_flag == 0) {return;}

dt_lw = getprop("/sim/time/delta-sec");
time_lw = time_lw + dt_lw;

# this is a really ugly hack to get the sun angle information to the shaders
# directly referencing /sim/time/sun-angle-rad as uniform doesn't
# work since that is a tied property

#var sun_angle = 1.57079632675 - getprop("/sim/time/sun-angle-rad");

#var terminator_offset = sun_angle /  0.017451 * 110000.0;# + 250000.0;
#setprop("/environment/terminator-relative-position-m",terminator_offset);

var viewpos = geo.viewer_position();

# setprop("/environment/alt-in-haze-m", getprop("/environment/ground-haze-thickness-m")-viewpos.alt());

#setprop("/sim/rendering/eye-altitude-m", viewpos.alt());



if (local_weather.presampling_flag == 1)
	{
	var mean_terrain_elevation_m = ft_to_m * local_weather.current_mean_alt ; }
else	
	{var mean_terrain_elevation_m = 0.0;}

setprop("/environment/mean-terrain-elevation-m", mean_terrain_elevation_m);

if (getprop(lw~"timing-loop-flag") ==1) {settimer(timing_loop, 0);}

}


###########################################################
# quadtree loop
# the quadtree loop is a fast loop updating the position
# of visible objects in the field of view only
###########################################################

var quadtree_loop = func {

if (local_weather.local_weather_running_flag == 0) {return;}

var vangle = 0.55 * getprop("/sim/current-view/field-of-view");
var viewdir = getprop("/sim/current-view/goal-heading-offset-deg");
var lat = getprop("position/latitude-deg");
var lon = getprop("position/longitude-deg");
var course = getprop("orientation/heading-deg");

cloud_counter = 0;

# pre-calculate trigonometry 

tan_vangle = math.tan(vangle * math.pi/180.0);



# use the quadtree to move clouds inside the field of view

var tiles = props.globals.getNode(lw~"tiles").getChildren("tile");


foreach (var t; tiles)
	{
	var generated_flag = t.getNode("generated-flag").getValue();
	
	if ((generated_flag == 1) or (generated_flag ==2))
		{
		var index = t.getNode("tile-index").getValue();
		current_tile_index_wd = index;

		var blat = t.getNode("latitude-deg").getValue();
		var blon = t.getNode("longitude-deg").getValue();
		var alpha = t.getNode("orientation-deg").getValue();
		var xy_vec = get_cartesian(blat, blon, alpha, lat, lon);

		var beta = course - alpha - viewdir ;
		cos_beta = math.cos(beta * math.pi/180.0);
		sin_beta = math.sin(beta * math.pi/180.0);
		plane_x = xy_vec[0]; plane_y = xy_vec[1];
		
		windfield = get_windfield(index);

		quadtree_recursion(cloudQuadtrees[index-1],0,1,0.0,0.0);
		}

	}


# dynamically adjust the range of the processed view field
# if there are plenty of moving clouds nearby, no one pays attention to the small motion of distant clouds
# price to pay is that some clouds appear to jump once they get into range

if (cloud_counter < 0.5 * max_clouds_in_loop) {view_distance = view_distance * 1.1;}
else if (cloud_counter > max_clouds_in_loop) {view_distance = view_distance * 0.9;}
if (view_distance > weather_tile_management.cloud_view_distance) {view_distance = weather_tile_management.cloud_view_distance;}

#print(cloud_counter, " ", view_distance/1000.0);

# shift the tile centers with the windfield

var tiles = props.globals.getNode("local-weather/tiles", 1).getChildren("tile");
foreach (var t; tiles) {move_tile(t);}




# loop over

if (getprop(lw~"dynamics-loop-flag") ==1) {settimer(quadtree_loop, 0);}
}


###########################################################
# weather_dynamics_loop
# the weather dynamics loop is a slow loop updating
# position and state of invisible objects, currently
# effect volumes and weather stations
###########################################################



var weather_dynamics_loop = func (index, cindex) {

if (local_weather.local_weather_running_flag == 0) {return;}

var n = 20;
var nc = 1;

var csize = weather_tile_management.n_cloudSceneryArray;

var i_max = index + n;
if (i_max > local_weather.n_effectVolumeArray) {i_max = local_weather.n_effectVolumeArray;}

var ecount = 0;

for (var i = index; i < i_max; i = i+1)
	{
	var ev = local_weather.effectVolumeArray[i];
	if (ev.index !=0)
		{ev.move();}
	if ((ev.lift_flag == 2) and (rand() < 0.05) and (local_weather.presampling_flag == 1))
		{
		if (local_weather.dynamical_convection_flag ==1)
			{
			ev.correct_altitude_and_age();
			
			if (ev.flt > 1.2) # beyond 1.0, sink is still active
				{		
				local_weather.effectVolumeArray = weather_tile_management.delete_from_vector(local_weather.effectVolumeArray,i);
				local_weather.n_effectVolumeArray = local_weather.n_effectVolumeArray - 1;
				i = i-1; i_max = i_max -1; ecount = ecount + 1;
				}

			}
		else
			{ev.correct_altitude();}
		}
	}
setprop(lw~"effect-volumes/number",getprop(lw~"effect-volumes/number")- ecount);

index = index + n;
if (i >= local_weather.n_effectVolumeArray)  {index = 0;} 


var ccount = 0;

if (csize > 0)
	{

	var j_max = cindex + nc;
	if (j_max > csize -1) {j_max = csize-1;}


	for (var j = cindex; j < j_max; j = j+1)
		{
		var cs = weather_tile_management.cloudSceneryArray[j];
		#cs.move();
		if (cs.type !=0) 
			{
			if ((rand() < 0.1) and (local_weather.presampling_flag == 1))
				{
				if (local_weather.dynamical_convection_flag ==1)
					{					
					cs.correct_altitude_and_age();
					if (cs.flt > 1.0) # the cloud has reached its maximum age and decays
						{
						cs.removeNodes();
						weather_tile_management.cloudSceneryArray = weather_tile_management.delete_from_vector(weather_tile_management.cloudSceneryArray,j);
						ccount = ccount + 1;
						}
					}
				else
					{
					cs.correct_altitude();
					}				
				}	
			}
		}

cindex = cindex + nc;
if (j >= csize)  {cindex = 0;} 
	}



foreach (var s; local_weather.weatherStationArray)
	{
	s.move();
	}

foreach (var a; local_weather.atmosphereIpointArray)
	{
	a.move();
	}

if (getprop(lw~"dynamics-loop-flag") ==1) {settimer( func {weather_dynamics_loop(index, cindex); },0);}

}


###########################################################
# convective evolution loop
###########################################################

var convective_loop = func {

if (local_weather.local_weather_running_flag == 0) {return;}

# a 30 second loop needs a different strategy to end, otherwise there is trouble if it is restarted while still running

if (convective_loop_kill_flag == 1)
	{convective_loop_kill_flag = 0; return;}

var cloud_respawning_interval_s = 30.0;


if (getprop(lw~"tmp/thread-status") == "placing") 
	{if (getprop(lw~"convective-loop-flag") ==1) {settimer( func {convective_loop()}, 5.0);} return;}

# open the system for write status
setprop(lw~"tmp/buffer-status","placing");

if (local_weather.debug_output_flag == 1) 
		{print("Respawning convective clouds...");}

for(var i = 0; i < 9; i = i + 1)
	{
	var index = getprop(lw~"tiles/tile["~i~"]/tile-index");
	if ((index == -1) or (index == 0)) {continue;}
	if (getprop(lw~"tiles/tile["~i~"]/generated-flag") != 2)
		{continue;}
	
	var strength = tile_convective_strength[index-1];
	var alt = tile_convective_altitude[index-1];
	var n = weather_tiles.get_n(strength);
	if (local_weather.detailed_clouds_flag == 1) 
		{n = int(0.7 * n);}

	n = n/cloud_convective_lifetime_s * cloud_respawning_interval_s * math.sqrt(0.35);

	var n_res = n - int(n);
	n = int(n);
	if (rand() < n_res) {n=n+1;}

	if (local_weather.debug_output_flag == 1) 
		{print("Tile: ", index, " n: ", n);}	

	var lat = getprop(lw~"tiles/tile["~i~"]/latitude-deg");
	var lon = getprop(lw~"tiles/tile["~i~"]/longitude-deg");
	var alpha = getprop(lw~"tiles/tile["~i~"]/orientation-deg");	

	compat_layer.buffered_tile_latitude = lat;
	compat_layer.buffered_tile_longitude = lon;
	compat_layer.buffered_tile_alpha = alpha;
	compat_layer.buffered_tile_index = index;

	setprop(lw~"tmp/buffer-tile-index", index);

	if (local_weather.presampling_flag == 1)
		{var alt_offset = local_weather.alt_20_array[index -1];}
	else 
		{var alt_offset = getprop(lw~"tmp/tile-alt-offset-ft");}

	local_weather.recreate_cumulus(lat,lon, alt + alt_offset, alpha, n, 20000.0, index);

	} 

# close the write process
setprop(lw~"tmp/buffer-status","idle");



if (getprop(lw~"convective-loop-flag") ==1) {settimer(convective_loop, cloud_respawning_interval_s);}

}

###########################################################
# generate quadtree structure
###########################################################

var generate_quadtree_structure = func (depth, tree_base_vec) {

var c_vec = [];

for (var i=0; i<4; i=i+1)
	{
	if (depth == quadtree_depth)
		{var c = [];}
	else
		{var c = generate_quadtree_structure(depth+1, tree_base_vec);}

	if (depth==0) 
		{append(tree_base_vec,c); }
	else	
		{append(c_vec,c); }	
	}

if (depth ==0) {return tree_base_vec;} else {return c_vec;}

}


###########################################################
# sort into quadtree
###########################################################

var sort_into_quadtree = func (blat, blon, alpha, lat, lon, tree, object) {

var xy_vec = get_cartesian (blat, blon, alpha, lat, lon);

sorting_recursion (xy_vec[0], xy_vec[1], tree, object, 0);

}


var sorting_recursion = func (x, y, tree, object, depth) {

if (depth == quadtree_depth+1) {append(tree,object); return;}

var length_scale = 20000.0 / math.pow(2,depth);

# print("depth: ", depth, "x: ", x, "y: ",y);

if (y > 0.0) 
	{
	if (x < 0.0)
		{var v = tree[0]; x = x + 0.5 * length_scale; y = y - 0.5 * length_scale;}
	else
		{var v = tree[1]; x = x - 0.5 * length_scale; y = y - 0.5 * length_scale;}
	}
else
	{
	if (x < 0.0)
		{var v = tree[2]; x = x + 0.5 * length_scale; y = y + 0.5 * length_scale;}
	else
		{var v = tree[3]; x = x - 0.5 * length_scale; y = y + 0.5 * length_scale;}
	}

sorting_recursion(x, y, v, object, depth+1);

}


####################################################
# quadtree recursive search
####################################################

var quadtree_recursion = func (tree, depth, flag, qx, qy) {

# flag = 0: quadrant invisible, stop search
# flag = 1: quadrant partially visible, continue search with visibility tests
# flag = 2: quadrant fully visible, no further visibility test needed


if (depth == quadtree_depth +1)
	{
	foreach (var c; tree)
		{
		c.move();
		c.to_target_alt();
		cloud_counter = cloud_counter + 1;
		}
	return;
	}



for (var i =0; i<4; i=i+1)
	{
	if (flag==2) {quadtree_recursion(tree[i], depth+1, flag, qx, qy);}
	else if (flag==1)
		{
		# compute the subquadrant coordinates
		var length_scale = 20000.0 / math.pow(2,depth);
		if (i==0) {var qxnew = qx - 0.5 * length_scale; var qynew = qy + 0.5 * length_scale;}
		else if (i==1) {var qxnew = qx + 0.5 * length_scale; var qynew = qy + 0.5 * length_scale;}
		else if (i==2) {var qxnew = qx - 0.5 * length_scale; var qynew = qy - 0.5 * length_scale;}
		else if (i==3) {var qxnew = qx + 0.5 * length_scale; var qynew = qy - 0.5 * length_scale;}
		

		var newflag = check_visibility(qxnew,qynew, length_scale);	

		if (newflag!=0) {quadtree_recursion(tree[i], depth+1, newflag, qxnew, qynew);}
		}
	}

}

####################################################
# quadrant visibility test
####################################################

var check_visibility = func (qx,qy, length_scale) {

# (qx,qy) are the quadrant coordinates in tile local Cartesian
# beta is the plane course in the tile local Cartesian

# the function returns a flag: 0: invisible 1:  partially visible, track further 2: fully visible



# first translate/rotate (qx,qy) into the plane system

qx = qx - plane_x; qy = qy - plane_y;

var x = qx * cos_beta - qy * sin_beta;
var y = qy * cos_beta + qx * sin_beta;

# now get the maximum and minimum quadrant extensions

var ang_factor = abs(cos_beta) + abs(sin_beta); # a square seen from an angle extends larger

var xmax = x + 0.5 * length_scale * ang_factor;
var xmin = x - 0.5 * length_scale * ang_factor;

var ymax = y + 0.5 * length_scale * ang_factor;
var ymin = y - 0.5 * length_scale * ang_factor;

# now do visibility checks

if ((ymax < 0.0) and (ymin < 0.0)) # quadrant is behind us, we can never see it
	{return 0;} 

if (ymin > view_distance) # the quadrant is beyond visible range
	{return 0;}

var xcomp_min = ymin * tan_vangle;
var xcomp_max = ymax * tan_vangle;

if ((ymax > 0.0) and (ymin < 0.0)) # object is at most partially visible, check if  in visual cone at ymax
	{
	if ((xmax < -xcomp_max) and (xmin < -xcomp_max)) {return 0;}
	if ((xmax > xcomp_max) and (xmin > xcomp_max)) {return 0;}
	return 1;		
	}

# now we know the quadrant must be in front

# check if invisible

if ((xmax < -xcomp_max) and (xmin < -xcomp_max)) {return 0;}
if ((xmax > xcomp_max) and (xmin > xcomp_max)) {return 0;}

# check if completely visible

if ((xmax > -xcomp_min) and (xmin > -xcomp_min) and (xmax < xcomp_min) and (xmin < xcomp_min))
	{return 2;}

# at this point, it must be partially visible

return 1;
}

####################################################
# move a tile
####################################################

var move_tile = func (t) {

# get the old spacetime position of the tile

var lat_old = t.getNode("latitude-deg").getValue();
var lon_old = t.getNode("longitude-deg").getValue();
var timestamp = t.getNode("timestamp-sec").getValue();

var tile_index = t.getNode("tile-index").getValue();

# if the tile is not yet generated, we use the windfield of the tile we're in

if (tile_index == -1)
	{
	tile_index = props.globals.getNode(lw~"tiles").getChild("tile",4).getNode("tile-index").getValue();
	}

# get windfield and time since last update

var windfield = get_windfield(tile_index);
var dt = time_lw - timestamp;


# update the spacetime position of the tile

t.getNode("latitude-deg",1).setValue(lat_old + windfield[1] * dt * local_weather.m_to_lat);
t.getNode("longitude-deg",1).setValue(lon_old + windfield[0] * dt * local_weather.m_to_lon);
t.getNode("timestamp-sec",1).setValue(weather_dynamics.time_lw);

}



###########################################################
# get local Cartesian coordinates
###########################################################

var get_cartesian = func (blat, blon, alpha, lat, lon) {

var xy_vec = [];

var phi = alpha * math.pi/180.0;

var delta_lat = lat - blat;
var delta_lon = lon - blon;

var x1 = delta_lon * lon_to_m;
var y1 = delta_lat * lat_to_m;

var x = x1 * math.cos(phi) - y1 * math.sin(phi);
var y = y1 * math.cos(phi) + x1 * math.sin(phi);

append(xy_vec,x);
append(xy_vec,y);

return xy_vec;

}


################################
# globals, constants, properties
################################



var lat_to_m = 110952.0; # latitude degrees to meters
var m_to_lat = 9.01290648208234e-06; # meters to latitude degrees
var ft_to_m = 0.30480;
var m_to_ft = 1.0/ft_to_m;
var inhg_to_hp = 33.76389;
var hp_to_inhg = 1.0/inhg_to_hp;

var kt_to_ms = 0.514;
var ms_to_kt = 1./kt_to_ms; 

var lon_to_m = 0.0; # needs to be calculated dynamically
var m_to_lon = 0.0; # we do this on startup

# abbreviations

var lw = "/local-weather/";


# globals

var time_lw = 0.0;
var dt_lw = 0.0;
var max_clouds_in_loop = 250;
var cloud_max_vertical_speed_fts = 30.0;
var cloud_convective_lifetime_s = 1800.0; # max. lifetime of convective clouds 

var convective_loop_kill_flag = 0;

# the quadtree structure

var cloudQuadtrees = [];
var quadtree_depth = 3; 

# the wind info for the individual weather tiles 
# (used for 'constant in tile' wind model)

var tile_wind_direction = [];
var tile_wind_speed = [];
var tile_convective_altitude = [];
var tile_convective_strength = [];

# define these as global, as we need to evaluate them only once per frame
# but use them over and over

var tan_vangle = 0;
var cos_beta = 0;
var sin_beta = 0;
var plane_x = 0;
var plane_y = 0;
var windfield = [];

var current_tile_index_wd = 0;

var cloud_counter = 0;
var view_distance = 30000.0;

# create the loop flags

setprop(lw~"timing-loop-flag",0);
setprop(lw~"dynamics-loop-flag",0);
