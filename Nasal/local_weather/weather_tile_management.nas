########################################################
# routines to set up, transform and manage weather tiles
# Thorsten Renk, March 2011
########################################################

# function			purpose
#
# tile_management_loop		to decide if a tile is created, removed or considered current
# generate_tile			to decide on orientation and type and set up all information for tile creation
# remove_tile			to delete a tile by index
# change_active_tile		to change the tile the aircraft is currently in and to generate neighbour info
# copy_entry			to copy tile information from one node to another
# create_neighbour		to set up information for a new neighbouring tile
# create_neighbours		to initialize the 8 neighbours of the initial tile
# buffer_loop			to manage the buffering of faraway clouds in an array
# housekeeping_loop		to shift clouds from the scenery into the buffer
# remove_impostors		to delete a ring of impostors to mimick distant clouds
# create_impostors		to create a ring of impostors to mimick distant clouds
# shadow_management_loop	to manage cloud shadow information
# watchdog loop			(debug helping structure)
# calc_geo			to get local Cartesian geometry for latitude conversion
# get_lat			to get latitude from Cartesian coordinates
# get_lon			to get longitude from Cartesian coordinates
# relangle			to compute the relative angle between two directions, normalized to [0:180]
# norm_relangle			to compute the relative angle between two directions, normalized to [0:360]
# delete_from_vector		to delete an element 'n' from a vector

# object			purpose
#
# cloud				to provide the data hash for the new cloud rendering system
# cloudBuffer			to store a cloud in a Nasal buffer, to provide methods to move it
# cloudScenery			to store info for clouds in scenery, to provide methods to move and evolve them
# cloudImpostor			to provide the hash data for an impostor cloud sheet


###################################
# tile management loop
###################################

var tile_management_loop = func {


if (local_weather.local_weather_running_flag == 0) {return;}

var tNode = props.globals.getNode(lw~"tiles", 1).getChildren("tile");
var viewpos = geo.aircraft_position(); # using viewpos here triggers massive tile ops for tower view...
var code = getprop(lw~"tiles/tile[4]/code");
var i = 0;
var d_min = 100000.0;
var i_min = 0;
var current_visibility = local_weather.interpolated_conditions.visibility_m;
var current_heading = getprop("orientation/heading-deg");
var loading_flag = getprop(lw~"tmp/asymmetric-tile-loading-flag");
var this_frame_action_flag = 0; # use this flag to avoid overlapping tile operations

setsize(active_tile_list,0);
#append(active_tile_list,0); # tile zero formally containing static objects is always active 

var distance_to_load = current_visibility + 10000.0;

if (distance_to_load > 65000.0) {distance_to_load = 65000.0;}
if (distance_to_load < 29000.0) {distance_to_load = 29000.0;}




var distance_to_remove = distance_to_load + 20000.0;
if (distance_to_remove > 65500.0) {distance_to_remove = 65500.0;}


# check here if we have a new weather station if METAR is running

if ((local_weather.metar_flag == 1) and (getprop(lw~"METAR/station-id") != getprop("/environment/metar/station-id"))) 
	{
	weather_tiles.set_METAR_weather_station();
	}

# compute the averaged framerate and see if cloud visibility needs to be adjusted

if (local_weather.fps_control_flag == 1) 
	{
	local_weather.fps_average = local_weather.fps_sum/local_weather.fps_samples;

	# print("Average framerate: ", local_weather.fps_average);
	
	local_weather.fps_sum = 0.0;
	local_weather.fps_samples = 0;

	if (local_weather.fps_average > 1.1 * local_weather.target_framerate)
		{
		var target_cloud_view_distance = cloud_view_distance * 1.1;
		if (target_cloud_view_distance > 45000.0)
			{target_cloud_view_distance = 45000.0;}	
		setprop(lw~"config/clouds-visible-range-m", target_cloud_view_distance);	
		}
	if (local_weather.fps_average < 0.9 * local_weather.target_framerate)
		{
		var target_cloud_view_distance = cloud_view_distance * 0.9;
		if (target_cloud_view_distance < 15000.0)
			{target_cloud_view_distance = 15000.0;}	
		setprop(lw~"config/clouds-visible-range-m", target_cloud_view_distance);	
		}

	}




foreach (var t; tNode) {

	var tpos = geo.Coord.new();
	tpos.set_latlon(t.getNode("latitude-deg").getValue(),t.getNode("longitude-deg").getValue(),0.0);
	var d = viewpos.distance_to(tpos);
	if (d < d_min) {d_min = d; i_min = i;}
	var flag = t.getNode("generated-flag").getValue();
	
	if ((flag ==2) or (flag ==1)) {append(active_tile_list,t.getNode("tile-index").getValue());}

	var dir = viewpos.course_to(tpos);
	var d_load = distance_to_load;
	var d_remove = distance_to_remove;
	if (loading_flag == 1)
		{
		var angle = abs(dir-current_heading);
		#if (i==7) {print(angle);}
		if ((angle > 135.0) and (angle < 225.0))
			{		
			d_load = 0.7 * d_load;
			d_remove = 0.7 * d_remove;
			} 
		}

	# the tile needs to be generated, unless it already has been
	# and if no other tile has been generated in this loop cycle
	# and the thread and convective system are idle
	# (we want to avoid overlapping tile generation)

	if ((d < d_load) and (flag==0) and (this_frame_action_flag == 0) and (getprop(lw~"tmp/thread-status") == "idle") and (getprop(lw~"tmp/convective-status") == "idle") and (getprop(lw~"tmp/presampling-status") == "idle")) 
		{
		this_frame_action_flag = 1;
		setprop(lw~"tiles/tile-counter",getprop(lw~"tiles/tile-counter")+1);
		if (local_weather.debug_output_flag == 1) 
			{print("Building tile unique index ",getprop(lw~"tiles/tile-counter"), " in direction ",i);}
		append(active_tile_list,getprop(lw~"tiles/tile-counter"));

		if (local_weather.dynamics_flag == 1) 
			{
			var quadtree = [];
			weather_dynamics.generate_quadtree_structure(0, quadtree);
			append(weather_dynamics.cloudQuadtrees,quadtree);
			}

		t.getNode("generated-flag").setValue(1);
		t.getNode("timestamp-sec").setValue(weather_dynamics.time_lw);
		t.getNode("tile-index",1).setValue(getprop(lw~"tiles/tile-counter"));
		generate_tile(code, tpos.lat(), tpos.lon(),i);

		} 

	if ((d > d_remove) and (flag == 2) and (this_frame_action_flag == 0)) # the tile needs to be deleted if it exists
		{
		if (local_weather.debug_output_flag == 1) 
			{print("Removing tile, unique index ", t.getNode("tile-index").getValue()," direction ",i);}
		remove_tile(t.getNode("tile-index").getValue());
		t.getNode("generated-flag").setValue(0);
		this_frame_action_flag = 1;
		}
	i = i + 1;
	} # end foreach

	#print("Minimum distance to: ",i_min);

	var presampling_status = getprop(lw~"tmp/presampling-status");
	var convective_status = getprop(lw~"tmp/convective-status");
	var thread_status = getprop(lw~"tmp/thread-status");

	if ((presampling_status == "idle") and (convective_status == "idle") and (thread_status == "idle"))
		{
		var system_status = "idle";
		} 	
	else
		{system_status = "computing";}
	
	#  and (this_frame_action_flag == 0) and (presampling_status == "idle") and (convective_status=="idle")) 

	# check if we've entered a different tile and if no operation is in progress

	# var gen_flag = tNode[i_min].getNode("generated-flag").getValue();
	if ((i_min != 4) and (system_status == "idle"))
		{

		var gen_flag = tNode[i_min].getNode("generated-flag").getValue();
		if (gen_flag != 2){	
			print("Tile direction ",i_min, " not generated!");
			print("Flag: ",gen_flag);
			}

		if (local_weather.debug_output_flag == 1) 
			{print("Changing active tile to direction ", i_min);}
		change_active_tile(i_min);
			
		}    

	

if (getprop(lw~"tile-loop-flag") ==1) {settimer(tile_management_loop, 4.0);}

}


###################################
# tile generation call
###################################

var generate_tile = func (code, lat, lon, dir_index) {


# the code should never be NIL, but this appears to happen under certain conditions
# so just to be on the safe side make sure it is set to current tile code if
# it actually is NIL

if (code == "")
	{ 
	print("No tile code - falling back on default!");
	code = getprop(lw~"tiles/code");
	}

setprop(lw~"tiles/tmp/latitude-deg", lat);
setprop(lw~"tiles/tmp/longitude-deg",lon);
setprop(lw~"tiles/tmp/code",code);
setprop(lw~"tiles/tmp/dir-index",dir_index);


# do windspeed and orientation before presampling check, but test not to do it again

if (((local_weather.presampling_flag == 1) and (getprop(lw~"tmp/presampling-status") == "idle")) or (local_weather.presampling_flag == 0))
	{

	var alpha = getprop(lw~"tmp/tile-orientation-deg");


	if ((local_weather.wind_model_flag == 2) or (local_weather.wind_model_flag ==4))
		{

		if (local_weather.metar_flag == 0)
			{
			alpha = alpha + 2.0 * (rand()-0.5) * 10.0;
			# account for the systematic spin of weather systems around a low pressure 
			# core dependent on hemisphere
			if (lat >0.0) {alpha = alpha -3.0;}
			else {alpha = alpha +3.0;} 
			}
		else
			{
			
			var step = 20.0;
			
			var alpha_test = getprop("/environment/metar/base-wind-dir-deg");


			if (local_weather.debug_output_flag == 1)
				{print("alpha: ", alpha, " alpha_test: ", alpha_test, " relangle: ", relangle(alpha, alpha_test));}


			var coordinate_rotation_angle = norm_relangle(alpha, alpha_test);

		
			if (coordinate_rotation_angle < 45.0)
				{
				var system_rotation_angle = 0;
				var displacement_angle = coordinate_rotation_angle;
				}
			else if (coordinate_rotation_angle < 135.0)
				{
				var system_rotation_angle = 90.0;
				var displacement_angle = coordinate_rotation_angle - 90.0;
				}
			else if (coordinate_rotation_angle < 225.0)
				{
				var system_rotation_angle = 180.0;
				var displacement_angle = coordinate_rotation_angle - 180.0;
				}
			else if (coordinate_rotation_angle < 315.0)
				{
				var system_rotation_angle = 270.0;
				var displacement_angle = coordinate_rotation_angle - 270.0;
				}
			else
				{
				var system_rotation_angle = 0;
				var displacement_angle = coordinate_rotation_angle - 360.0;
				}

		
			if (displacement_angle < -step)
				{
				print("Coordinate rotation by more than ",step," deg... compensating");
				displacement_angle = -step;
				}
			else if (displacement_angle > step)
				{
				print("Coordinate rotation by more than ",step," deg... compensating");
				displacement_angle = step;
				}

			alpha = alpha + system_rotation_angle + displacement_angle;
				


			#if (relangle(alpha, alpha_test) > step)
			#	{
			#	print("Coordinate rotation by more than ",step," deg... compensating");
			#	if (relangle(alpha + step, alpha_test) < relangle(alpha-step, alpha_test))
			#		{
			#		alpha = alpha + step;
			#		}
			#	else 
			#		{
			#		alpha = alpha - step;
			#		}
			#	}
			#else
			#	{
			#	alpha = alpha_test;
			#	}
			}

	
			

		setprop(lw~"tmp/tile-orientation-deg",alpha);
		
		# compute the new windspeed

		var windspeed = 0;
		if (local_weather.metar_flag == 0)
			{
			windspeed = getprop(lw~"tmp/windspeed-kt");
			windspeed = windspeed + 2.0 * (rand()-0.5) * 2.0;
			if (windspeed < 0) {windspeed = rand();}
			}
		else
			{
			var boundary_correction = 1.0/local_weather.get_slowdown_fraction();
			windspeed = boundary_correction * getprop("/environment/metar/base-wind-speed-kt");
			}
	
		setprop(lw~"tmp/windspeed-kt",windspeed);

		# store the tile orientation and wind strength in an array for fast processing

		append(weather_dynamics.tile_wind_direction, alpha);
		append(weather_dynamics.tile_wind_speed, windspeed);

		}
	else if (local_weather.wind_model_flag ==5) # alpha and windspeed are calculated
		{
		var res = local_weather.wind_interpolation(lat,lon,0.0);
		
		var step = 20.0;		
		var alpha_test = res[0];


		if (local_weather.debug_output_flag == 1)
				{print("alpha: ", alpha, " alpha_test: ", alpha_test, " relangle: ", relangle(alpha, alpha_test));}


		var coordinate_rotation_angle = norm_relangle(alpha, alpha_test);

		#print("Norm_relangle : ", norm_relangle(alpha, alpha_test));

		
		if (coordinate_rotation_angle < 45.0)
			{
			var system_rotation_angle = 0;
			var displacement_angle = coordinate_rotation_angle;
			}
		else if (coordinate_rotation_angle < 135.0)
			{
			var system_rotation_angle = 90.0;
			var displacement_angle = coordinate_rotation_angle - 90.0;
			}
		else if (coordinate_rotation_angle < 225.0)
			{
			var system_rotation_angle = 180.0;
			var displacement_angle = coordinate_rotation_angle - 180.0;
			}
		else if (coordinate_rotation_angle < 315.0)
			{
			var system_rotation_angle = 270.0;
			var displacement_angle = coordinate_rotation_angle - 270.0;
			}
		else
			{
			var system_rotation_angle = 0;
			var displacement_angle = coordinate_rotation_angle - 360.0;
			}

		#print("Displacement angle: ", displacement_angle);
		
		if (displacement_angle < -step)
			{
			print("Coordinate rotation by more than ",step," deg... compensating");
			displacement_angle = -step;
			}
		else if (displacement_angle > step)
			{
			print("Coordinate rotation by more than ",step," deg... compensating");
			displacement_angle = step;
			}
		
		#print("Normalized displacement angle: ", displacement_angle);
		
		alpha = alpha + system_rotation_angle + displacement_angle;
		
		#print("alpha_out: ", alpha);

		#if (relangle(alpha, alpha_test) > step)
		#	{
		#	print("Coordinate rotation by more than ",step," deg... compensating");
		#	if (relangle(alpha + step, alpha_test) < relangle(alpha-step, alpha_test))
		#		{
		#		alpha = alpha + step;
		#		}
		#	else 
		#		{
		#		alpha = alpha - step;
		#		}
		#	}
		#else
		#	{
		#	alpha = alpha_test;
		#	}
			
		#alpha = alpha_test;



		setprop(lw~"tmp/tile-orientation-deg",alpha);				
		var windspeed = res[1];
		setprop(lw~"tmp/windspeed-kt",windspeed);

		append(weather_dynamics.tile_wind_direction,res[0]);
		append(weather_dynamics.tile_wind_speed,res[1]);

		}


	props.globals.getNode(lw~"tiles").getChild("tile",dir_index).getNode("orientation-deg").setValue(alpha);
	}



# now see if we need to presample the terrain

if ((local_weather.presampling_flag == 1) and (getprop(lw~"tmp/presampling-status") == "idle") and (compat_layer.features.terrain_presampling_active == 0)) 
	{
	local_weather.terrain_presampling_start(lat, lon, 1000, 40000, getprop(lw~"tmp/tile-orientation-deg")); 
	return;
	}
else if (compat_layer.features.terrain_presampling_active == 1)# we have hard-coded values available and use those
	{local_weather.terrain_presampling_analysis();}


if (local_weather.debug_output_flag == 1) 
	{print("Current tile type: ", code);}

if (getprop(lw~"tmp/tile-management") == "repeat tile")
	{
	if (code == "altocumulus_sky"){weather_tiles.set_altocumulus_tile();}
	else if (code == "broken_layers") {weather_tiles.set_broken_layers_tile();}
	else if (code == "stratus") {weather_tiles.set_overcast_stratus_tile();}
	else if (code == "cumulus_sky") {weather_tiles.set_fair_weather_tile();}
	else if (code == "gliders_sky") {weather_tiles.set_gliders_sky_tile();}
	else if (code == "blue_thermals") {weather_tiles.set_blue_thermals_tile();}
	else if (code == "summer_rain") {weather_tiles.set_summer_rain_tile();}
	else if (code == "high_pressure_core") {weather_tiles.set_high_pressure_core_tile();}
	else if (code == "high_pressure") {weather_tiles.set_high_pressure_tile();}
	else if (code == "high_pressure_border") {weather_tiles.set_high_pressure_border_tile();}
	else if (code == "low_pressure_border") {weather_tiles.set_low_pressure_border_tile();}
	else if (code == "low_pressure") {weather_tiles.set_low_pressure_tile();}
	else if (code == "low_pressure_core") {weather_tiles.set_low_pressure_core_tile();}
	else if (code == "cold_sector") {weather_tiles.set_cold_sector_tile();}
	else if (code == "warm_sector") {weather_tiles.set_warm_sector_tile();}
	else if (code == "tropical_weather") {weather_tiles.set_tropical_weather_tile();}
	else if (code == "thunderstorms") {weather_tiles.set_thunderstorms_tile();}
	else if (code == "test") {weather_tiles.set_4_8_stratus_tile();}
	else 
		{
		print("Repeat tile not implemented with this tile type!");
		setprop("/sim/messages/pilot", "Local weather: Repeat tile not implemented with this tile type!");
		}
	}
else if (getprop(lw~"tmp/tile-management") == "realistic weather")
	{
	var rn = rand() * getprop(lw~"config/large-scale-persistence");
	
	if (code == "low_pressure_core") 
		{
		if (rn > 0.1) {weather_tiles.set_low_pressure_core_tile();}
		else {weather_tiles.set_low_pressure_tile();}
		}
	else if (code == "low_pressure") 
		{
		if (rn > 0.1) {weather_tiles.set_low_pressure_tile();}
		else if (rn > 0.05) {weather_tiles.set_low_pressure_core_tile();}
		else {weather_tiles.set_low_pressure_border_tile();}
		}
	else if (code == "low_pressure_border") 
		{
		if (rn > 0.2) {weather_tiles.set_low_pressure_border_tile();}
		else if (rn > 0.15) {weather_tiles.set_cold_sector_tile();}
		else if (rn > 0.1) {weather_tiles.set_warm_sector_tile();}
		else if (rn > 0.05) {weather_tiles.set_low_pressure_tile();}
		else {weather_tiles.set_high_pressure_border_tile();}
		}
	else if (code == "high_pressure_border") 
		{
		if (rn > 0.2) {weather_tiles.set_high_pressure_border_tile();}
		else if (rn > 0.15) {weather_tiles.set_cold_sector_tile();}
		else if (rn > 0.1) {weather_tiles.set_warm_sector_tile();}
		else if (rn > 0.05) {weather_tiles.set_high_pressure_tile();}
		else {weather_tiles.set_low_pressure_border_tile();}
		}
	else if (code == "high_pressure") 
		{
		if (rn > 0.1) {weather_tiles.set_high_pressure_tile();}
		else if (rn > 0.05) {weather_tiles.set_high_pressure_border_tile();}
		else {weather_tiles.set_high_pressure_core_tile();}
		}
	else if (code == "high_pressure_core") 
		{
		if (rn > 0.1) {weather_tiles.set_high_pressure_core_tile();}
		else {weather_tiles.set_high_pressure_tile();}
		}
	else if (code == "cold_sector") 
		{
		if (rn > 0.15) {weather_tiles.set_cold_sector_tile();}
		else if (rn > 0.1) 
			{
			if ((dir_index ==0) or (dir_index ==1) or (dir_index==2))
				{weather_tiles.set_warmfront1_tile();}
			else if ((dir_index ==3) or (dir_index ==5))
				{weather_tiles.set_cold_sector_tile();}
			else if ((dir_index ==6) or (dir_index ==7) or (dir_index==8))
				{weather_tiles.set_coldfront_tile();}
			}
		else if (rn > 0.05) {weather_tiles.set_low_pressure_border_tile();}
		else {weather_tiles.set_high_pressure_border_tile();}
		}
	else if (code == "warm_sector") 
		{
		if (rn > 0.15) {weather_tiles.set_warm_sector_tile();}
		else if (rn > 0.1) 
			{
			if ((dir_index ==0) or (dir_index ==1) or (dir_index==2))
				{weather_tiles.set_coldfront_tile();}
			else if ((dir_index ==3) or (dir_index ==5))
				{weather_tiles.set_warm_sector_tile();}
			else if ((dir_index ==6) or (dir_index ==7) or (dir_index==8))
				{weather_tiles.set_warmfront4_tile();}
			}
		else if (rn > 0.05) {weather_tiles.set_low_pressure_border_tile();}
		else {weather_tiles.set_high_pressure_border_tile();}
		}
	else if (code == "warmfront1")
		{
		if ((dir_index ==0) or (dir_index ==1) or (dir_index==2))
			{weather_tiles.set_warmfront2_tile();}
		else if ((dir_index ==3) or (dir_index ==5))
			{
			if (rand() > 0.15)
				{weather_tiles.set_warmfront1_tile();}
			else
				{weather_tiles.set_high_pressure_border_tile();}
			}
		else if ((dir_index ==6) or (dir_index ==7) or (dir_index==8))
			{weather_tiles.set_cold_sector_tile();}
		}
	else if (code == "warmfront2")
		{
		if ((dir_index ==0) or (dir_index ==1) or (dir_index==2))
			{weather_tiles.set_warmfront3_tile();}
		if ((dir_index ==3) or (dir_index ==5))
			{
			if (rand() > 0.15)			
				{weather_tiles.set_warmfront2_tile();}
			else
				{weather_tiles.set_high_pressure_border_tile();}
			}
		if ((dir_index ==6) or (dir_index ==7) or (dir_index==8))
			{weather_tiles.set_warmfront1_tile();}
		}
	else if (code == "warmfront3")
		{
		if ((dir_index ==0) or (dir_index ==1) or (dir_index==2))
			{weather_tiles.set_warmfront4_tile();}
		if ((dir_index ==3) or (dir_index ==5))
			{
			if (rand() > 0.15)
				{weather_tiles.set_warmfront3_tile();}
			else
				{weather_tiles.set_low_pressure_border_tile();}
			}
		if ((dir_index ==6) or (dir_index ==7) or (dir_index==8))
			{weather_tiles.set_warmfront2_tile();}
		}
	else if (code == "warmfront4")
		{
		if ((dir_index ==0) or (dir_index ==1) or (dir_index==2))
			{weather_tiles.set_warm_sector_tile();}
		if ((dir_index ==3) or (dir_index ==5))
			{
			if (rand() > 0.15)			
				{weather_tiles.set_warmfront4_tile();}
			else
				{weather_tiles.set_low_pressure_tile();}
			}
		if ((dir_index ==6) or (dir_index ==7) or (dir_index==8))
			{weather_tiles.set_warmfront3_tile();}
		}
	else if (code == "coldfront")
		{
		if ((dir_index ==0) or (dir_index ==1) or (dir_index==2))
			{weather_tiles.set_cold_sector_tile();}
		else if ((dir_index ==3) or (dir_index ==5))
			{	
			if (rand() > 0.15)
				{weather_tiles.set_coldfront_tile();}
			else
				{weather_tiles.set_high_pressure_border_tile();}
			}
		else if ((dir_index ==6) or (dir_index ==7) or (dir_index==8))
			{weather_tiles.set_warm_sector_tile();}
		}
	else
		{
		print("Realistic weather not implemented with this tile type!");
		setprop("/sim/messages/pilot", "Local weather: Realistic weather not implemented with this tile type!");
		}

	} # end if mode == realistic weather
else if (getprop(lw~"tmp/tile-management") == "METAR")
	{
	weather_tiles.set_METAR_tile();
	}
}
	

###################################
# tile removal call
###################################

var remove_tile = func (index) {

# remove tile from active list

var s = size(active_tile_list);

for (var j = 0; j < s; j=j+1)
	{
	if (index == active_tile_list[j])
		{	
		active_tile_list = delete_from_vector(active_tile_list,j);
		break;
		}
	}

settimer( func { props.globals.getNode("local-weather/clouds", 1).removeChild("tile",index) },100);


var effectNode = props.globals.getNode("local-weather/effect-volumes").getChildren("effect-volume");

var ecount = 0;

for (var i = 0; i < local_weather.n_effectVolumeArray; i = i + 1)
	{
	ev = local_weather.effectVolumeArray[i];
	if (ev.index == index)
		{	
		local_weather.effectVolumeArray = delete_from_vector(local_weather.effectVolumeArray,i);
		local_weather.n_effectVolumeArray = local_weather.n_effectVolumeArray - 1;
		i = i - 1;
		ecount = ecount + 1;
		}
	else if (ev.index == 0) # use the opportunity to check if static effects should also be removed
		{
		if (ev.get_distance() > 80000.0)
			{
			local_weather.effectVolumeArray = delete_from_vector(local_weather.effectVolumeArray,i);
			local_weather.n_effectVolumeArray = local_weather.n_effectVolumeArray - 1;
			i = i - 1;
			ecount = ecount + 1;
			}
		}
	}


setprop(lw~"effect-volumes/number",getprop(lw~"effect-volumes/number")- ecount);

# set placement indices to zero to reinitiate search for free positions

setprop(lw~"clouds/placement-index",0);
setprop(lw~"clouds/model-placement-index",0);
setprop(lw~"effect-volumes/effect-placement-index",0);

# remove quadtree structures 

if (local_weather.dynamics_flag ==1)
	{
	settimer( func {setsize(weather_dynamics.cloudQuadtrees[index-1],0);},1.0);
	}

# rebuild effect volume vector

local_weather.assemble_effect_array(); 

if (local_weather.wxradar_support_flag == 1)
	{
	local_weather.remove_wxradar_echos();
	}

}



###################################
# active tile change and neighbour 
# recomputation
###################################

var change_active_tile = func (index) {

var t = props.globals.getNode(lw~"tiles").getChild("tile",index,0);

var lat = t.getNode("latitude-deg").getValue();
var lon = t.getNode("longitude-deg").getValue();
# var alpha = getprop(lw~"tmp/tile-orientation-deg");

var alpha_old = getprop(lw~"tiles/tile[4]/orientation-deg");
var alpha = t.getNode("orientation-deg").getValue();

var coordinate_rotation_angle = norm_relangle(alpha_old, alpha);

if (coordinate_rotation_angle < 45.0)
	{
	var system_rotation_angle = 0;
	var displacement_angle = coordinate_rotation_angle;
	}
else if (coordinate_rotation_angle < 135.0)
	{
	var system_rotation_angle = 90.0;
	var displacement_angle = coordinate_rotation_angle - 90.0;
	}
else if (coordinate_rotation_angle < 225.0)
	{
	var system_rotation_angle = 180.0;
	var displacement_angle = coordinate_rotation_angle - 180.0;
	}
else if (coordinate_rotation_angle < 315.0)
	{
	var system_rotation_angle = 270.0;
	var displacement_angle = coordinate_rotation_angle - 270.0;
	}
else
	{
	var system_rotation_angle = 0;
	var displacement_angle = coordinate_rotation_angle - 360.0;
	}

alpha = alpha_old + displacement_angle;

if (index == 0)
	{
	copy_entry(4,8);
	copy_entry(3,7);
	copy_entry(1,5);
	copy_entry(0,4);
	create_neighbour(lat,lon,0,alpha);
	create_neighbour(lat,lon,1,alpha);
	create_neighbour(lat,lon,2,alpha);
	create_neighbour(lat,lon,3,alpha);
	create_neighbour(lat,lon,6,alpha);
	}
else if (index == 1)
	{
	copy_entry(3,6);
	copy_entry(4,7);
	copy_entry(5,8);
	copy_entry(0,3);
	copy_entry(1,4); 
	copy_entry(2,5);
	create_neighbour(lat,lon,0,alpha);
	create_neighbour(lat,lon,1,alpha);
	create_neighbour(lat,lon,2,alpha);
	}
else if (index == 2)
	{
	copy_entry(4,6);
	copy_entry(1,3);
	copy_entry(2,4);
	copy_entry(5,7);
	create_neighbour(lat,lon,0,alpha);
	create_neighbour(lat,lon,1,alpha);
	create_neighbour(lat,lon,2,alpha);
	create_neighbour(lat,lon,5,alpha);
	create_neighbour(lat,lon,8,alpha);
	}
else if (index == 3)
	{
	copy_entry(1,2);
	copy_entry(4,5);
	copy_entry(7,8);
	copy_entry(0,1);
	copy_entry(3,4); 
	copy_entry(6,7);
	create_neighbour(lat,lon,0,alpha);
	create_neighbour(lat,lon,3,alpha);
	create_neighbour(lat,lon,6,alpha);
	}
else if (index == 5)
	{
	copy_entry(1,0);
	copy_entry(4,3);
	copy_entry(7,6);
	copy_entry(2,1);
	copy_entry(5,4); 
	copy_entry(8,7);
	create_neighbour(lat,lon,2,alpha);
	create_neighbour(lat,lon,5,alpha);
	create_neighbour(lat,lon,8,alpha);
	}
else if (index == 6)
	{
	copy_entry(4,2);
	copy_entry(3,1);
	copy_entry(6,4);
	copy_entry(7,5);
	create_neighbour(lat,lon,0,alpha);
	create_neighbour(lat,lon,3,alpha);
	create_neighbour(lat,lon,6,alpha);
	create_neighbour(lat,lon,7,alpha);
	create_neighbour(lat,lon,8,alpha);
	}
else if (index == 7)
	{
	copy_entry(3,0);
	copy_entry(4,1);
	copy_entry(5,2);
	copy_entry(6,3);
	copy_entry(7,4); 
	copy_entry(8,5);
	create_neighbour(lat,lon,6,alpha);
	create_neighbour(lat,lon,7,alpha);
	create_neighbour(lat,lon,8,alpha);
	}
else if (index == 8)
	{
	copy_entry(4,0);
	copy_entry(7,3);
	copy_entry(8,4);
	copy_entry(5,1);
	create_neighbour(lat,lon,2,alpha);
	create_neighbour(lat,lon,5,alpha);
	create_neighbour(lat,lon,6,alpha);
	create_neighbour(lat,lon,7,alpha);
	create_neighbour(lat,lon,8,alpha);
	}




if (system_rotation_angle > 0.0)
	{
	if (local_weather.debug_output_flag == 1)
		{print("Rotating coordinate system by ", system_rotation_angle, " degrees");}
	
	# create a buffer entry for rotation, this is deleted in the rotation routine

	create_neighbour(lat, lon, 9, alpha);
	rotate_tile_scheme(system_rotation_angle);
	}

# ready the system for creating impostors

impostor_trigger = 1;

}


###################################
# rotate tile scheme  
###################################

var rotate_tile_scheme = func (angle) {

if (angle < 45.0)
	{
	return;
	}
else if (angle < 135)
	{


	copy_entry(2,9);
	copy_entry(8,2);
	copy_entry(6,8);
	copy_entry(0,6);
	copy_entry(9,0);
	copy_entry(5,9);
	copy_entry(7,5);
	copy_entry(3,7);
	copy_entry(1,3);
	copy_entry(9,1);

	props.globals.getNode(lw~"tiles").removeChild("tile",9);
	}
else if (angle < 225)
	{
	copy_entry(8,9);
	copy_entry(0,8);
	copy_entry(9,0);

	copy_entry(7,9);
	copy_entry(1,7);
	copy_entry(9,1);

	copy_entry(6,9);
	copy_entry(2,6);
	copy_entry(9,2);

	copy_entry(5,9);
	copy_entry(3,5);
	copy_entry(9,3);
	
	props.globals.getNode(lw~"tiles").removeChild("tile",9);
	}
else if (angle < 315)
	{
	copy_entry(0,9);
	copy_entry(6,0);	
	copy_entry(8,6);
	copy_entry(2,8);
	copy_entry(9,2);
	copy_entry(3,9);
	copy_entry(7,3);
	copy_entry(5,7);
	copy_entry(1,5);
	copy_entry(9,1);

	props.globals.getNode(lw~"tiles").removeChild("tile",9);
	}
else 
	{
	return;
	}
}


#####################################
# copy tile info in neighbour matrix
#####################################

var copy_entry = func (from_index, to_index) {

var tNode = props.globals.getNode(lw~"tiles");

var f = tNode.getChild("tile",from_index,0);
var t = tNode.getChild("tile",to_index,0);

t.getNode("latitude-deg").setValue(f.getNode("latitude-deg").getValue());
t.getNode("longitude-deg").setValue(f.getNode("longitude-deg").getValue());
t.getNode("generated-flag").setValue(f.getNode("generated-flag").getValue());
t.getNode("tile-index").setValue(f.getNode("tile-index").getValue());
t.getNode("timestamp-sec").setValue(f.getNode("timestamp-sec").getValue());
t.getNode("orientation-deg").setValue(f.getNode("orientation-deg").getValue());
t.getNode("code").setValue(f.getNode("code").getValue());


}

#####################################
# create adjacent tile coordinates
#####################################

var create_neighbour = func (blat, blon, index, alpha) {

var x = 0.0;
var y = 0.0;
var phi = alpha * math.pi/180.0;

calc_geo(blat);

if ((index == 0) or (index == 3) or (index == 6)) {x =-40000.0;}
if ((index == 2) or (index == 5) or (index == 8)) {x = 40000.0;}

if ((index == 0) or (index == 1) or (index == 2)) {y = 40000.0;}
if ((index == 6) or (index == 7) or (index == 8)) {y = -40000.0;}

var t = props.globals.getNode(lw~"tiles").getChild("tile",index,1);

# use the last built tile code as default, in case a tile isn't formed when reached,
# the code is not empty but has a plausible value

var default_code = getprop(lw~"tiles/code");

t.getNode("latitude-deg",1).setValue(blat + get_lat(x,y,phi));
t.getNode("longitude-deg",1).setValue(blon + get_lon(x,y,phi));
t.getNode("generated-flag",1).setValue(0);
t.getNode("tile-index",1).setValue(-1);
t.getNode("code",1).setValue(default_code);
t.getNode("timestamp-sec",1).setValue(weather_dynamics.time_lw);
t.getNode("orientation-deg",1).setValue(0.0);
}

#####################################
# find the 8 adjacent tile coordinates
# after the initial setup call
#####################################

var create_neighbours = func (blat, blon, alpha)	{

var x = 0.0;
var y = 0.0;
var phi = alpha * math.pi/180.0;

calc_geo(blat);

x = -40000.0; y = 40000.0; 
setprop(lw~"tiles/tile[0]/latitude-deg",blat + get_lat(x,y,phi));
setprop(lw~"tiles/tile[0]/longitude-deg",blon + get_lon(x,y,phi));
setprop(lw~"tiles/tile[0]/generated-flag",0);
setprop(lw~"tiles/tile[0]/tile-index",-1);
setprop(lw~"tiles/tile[0]/code","");
setprop(lw~"tiles/tile[0]/timestamp-sec",weather_dynamics.time_lw);
setprop(lw~"tiles/tile[0]/orientation-deg",alpha);

x = 0.0; y = 40000.0; 
setprop(lw~"tiles/tile[1]/latitude-deg",blat + get_lat(x,y,phi));
setprop(lw~"tiles/tile[1]/longitude-deg",blon + get_lon(x,y,phi));
setprop(lw~"tiles/tile[1]/generated-flag",0);
setprop(lw~"tiles/tile[1]/tile-index",-1);
setprop(lw~"tiles/tile[1]/code","");
setprop(lw~"tiles/tile[1]/timestamp-sec",weather_dynamics.time_lw);
setprop(lw~"tiles/tile[1]/orientation-deg",alpha);

x = 40000.0; y = 40000.0; 
setprop(lw~"tiles/tile[2]/latitude-deg",blat + get_lat(x,y,phi));
setprop(lw~"tiles/tile[2]/longitude-deg",blon + get_lon(x,y,phi));
setprop(lw~"tiles/tile[2]/generated-flag",0);
setprop(lw~"tiles/tile[2]/tile-index",-1);
setprop(lw~"tiles/tile[2]/code","");
setprop(lw~"tiles/tile[2]/timestamp-sec",weather_dynamics.time_lw);
setprop(lw~"tiles/tile[2]/orientation-deg",alpha);

x = -40000.0; y = 0.0; 
setprop(lw~"tiles/tile[3]/latitude-deg",blat + get_lat(x,y,phi));
setprop(lw~"tiles/tile[3]/longitude-deg",blon + get_lon(x,y,phi));
setprop(lw~"tiles/tile[3]/generated-flag",0);
setprop(lw~"tiles/tile[3]/tile-index",-1);
setprop(lw~"tiles/tile[3]/code","");
setprop(lw~"tiles/tile[3]/timestamp-sec",weather_dynamics.time_lw);
setprop(lw~"tiles/tile[3]/orientation-deg",alpha);

# this is the current tile
x = 0.0; y = 0.0; 
setprop(lw~"tiles/tile[4]/latitude-deg",blat + get_lat(x,y,phi));
setprop(lw~"tiles/tile[4]/longitude-deg",blon + get_lon(x,y,phi));
setprop(lw~"tiles/tile[4]/generated-flag",1);
setprop(lw~"tiles/tile[4]/tile-index",1);
setprop(lw~"tiles/tile[4]/code","");
setprop(lw~"tiles/tile[4]/timestamp-sec",weather_dynamics.time_lw);
setprop(lw~"tiles/tile[4]/orientation-deg",getprop(lw~"tmp/tile-orientation-deg"));


x = 40000.0; y = 0.0; 
setprop(lw~"tiles/tile[5]/latitude-deg",blat + get_lat(x,y,phi));
setprop(lw~"tiles/tile[5]/longitude-deg",blon + get_lon(x,y,phi));
setprop(lw~"tiles/tile[5]/generated-flag",0);
setprop(lw~"tiles/tile[5]/tile-index",-1);
setprop(lw~"tiles/tile[5]/code","");
setprop(lw~"tiles/tile[5]/timestamp-sec",weather_dynamics.time_lw);
setprop(lw~"tiles/tile[5]/orientation-deg",alpha);

x = -40000.0; y = -40000.0; 
setprop(lw~"tiles/tile[6]/latitude-deg",blat + get_lat(x,y,phi));
setprop(lw~"tiles/tile[6]/longitude-deg",blon + get_lon(x,y,phi));
setprop(lw~"tiles/tile[6]/generated-flag",0);
setprop(lw~"tiles/tile[6]/tile-index",-1);
setprop(lw~"tiles/tile[6]/code","");
setprop(lw~"tiles/tile[6]/timestamp-sec",weather_dynamics.time_lw);
setprop(lw~"tiles/tile[6]/orientation-deg",alpha);

x = 0.0; y = -40000.0; 
setprop(lw~"tiles/tile[7]/latitude-deg",blat + get_lat(x,y,phi));
setprop(lw~"tiles/tile[7]/longitude-deg",blon + get_lon(x,y,phi));
setprop(lw~"tiles/tile[7]/generated-flag",0);
setprop(lw~"tiles/tile[7]/tile-index",-1);
setprop(lw~"tiles/tile[7]/code","");
setprop(lw~"tiles/tile[7]/timestamp-sec",weather_dynamics.time_lw);
setprop(lw~"tiles/tile[7]/orientation-deg",alpha);

x = 40000.0; y = -40000.0; 
setprop(lw~"tiles/tile[8]/latitude-deg",blat + get_lat(x,y,phi));
setprop(lw~"tiles/tile[8]/longitude-deg",blon + get_lon(x,y,phi));
setprop(lw~"tiles/tile[8]/generated-flag",0);
setprop(lw~"tiles/tile[8]/tile-index",-1);
setprop(lw~"tiles/tile[8]/code","");
setprop(lw~"tiles/tile[8]/timestamp-sec",weather_dynamics.time_lw);
setprop(lw~"tiles/tile[8]/orientation-deg",alpha);
}




###############################
# housekeeping loop
###############################

var housekeeping_loop = func (index, index1) {

if (local_weather.local_weather_running_flag == 0) {return;}

# supply a few properties which are used more generally

lwObserverLat = getprop("/position/latitude-deg");
lwObserverLon = getprop("/position/longitude-deg");

var heading = getprop("/orientation/heading-deg");
var offset =  getprop("/sim/current-view/heading-offset-deg");
lwViewDir = (heading - offset) * math.pi/180.0 ;
setsize(lwViewVec,0);
append(lwViewVec,math.cos(lwViewDir));
append(lwViewVec,-math.sin(lwViewDir));


var n = 5;
var n_max = size(cloudSceneryArray);
n_cloudSceneryArray = n_max;
var s = size(active_tile_list);

var m_max = size(cloudArray);

setprop(lw~"clouds/cloud-scenery-count",n_max+m_max);

# don't do anything as long as the array is empty

if ((n_max == 0) and (m_max == 0)) # nothing to do, loop over
	{if (getprop(lw~"housekeeping-loop-flag") ==1) {settimer( func {housekeeping_loop(index, index1)}, 0);} return;}

# parse the flags


# now process the Scenery array

if (index > n_max-1) {index = 0;}

var i_max = index + n;
if (i_max > n_max) {i_max = n_max;}

for (var i = index; i < i_max; i = i+1)
	{
	var c = cloudSceneryArray[i];

	var flag = 0;
	
	for (var j = 0; j < s; j = j+1)
		{
		if (active_tile_list[j] == c.index) {flag = 1; break;}
		if (c.index == 0) {flag =1; break;} # clouds in tile index 0 are special
		}

	if (flag == 0)
		{
		c.removeNodes();
		cloudSceneryArray = delete_from_vector(cloudSceneryArray,i);
		i = i -1; i_max = i_max - 1; n_max = n_max - 1;
		n_cloudSceneryArray = n_cloudSceneryArray -1;
		continue;
		}
	}


# now process the hard coded cloud array and see a tile has been removed

if (index1 > m_max-1) {index1 = 0;}

var j_max = index1 + n;
if (j_max > m_max) {j_max = m_max;}

for (var j = index1; j < j_max; j = j+1)
	{
	var c = cloudArray[j];

	var flag = 0;
	
	for (var k = 0; k < s; k = k+1)
		{
		if (active_tile_list[k] == c.index) {flag = 1; break;}
		}

	if (flag == 0)
		{
		c.remove();
		cloudArray = delete_from_vector(cloudArray,j);
		j = j -1; j_max = j_max - 1; m_max = m_max - 1;
		continue;
		}
	}

if (getprop(lw~"housekeeping-loop-flag") ==1) {settimer( func {housekeeping_loop(i,j)}, 0);}
}


###############################
# impostor handline routines
###############################

var impostor_trigger = 0;

var impostor_type_map = {"low_pressure_core" : "Nimbus", "low_pressure" : "broken", "low_pressure_border": "broken", "high_pressure_border" : "scattered", "high_pressure" : "few", "high_pressure_core": "few"};

var remove_impostors = func {

foreach (entry;cloudImpostorArray)
	{
	entry.removeNodes();
	}
setsize(cloudImpostorArray,0);
}

var create_impostors = func {

var visibility = getprop("/environment/visibility-m");
var cloud_range = getprop("/sim/rendering/clouds3d-vis-range");

if ((visibility < 80000.0) or (cloud_range < 70000.0)) {return;}

if (visibility < cloud_range) {var range = visibility;}
else	{var range = cloud_range;}

var n = int ((range - 60000.0)/40000.0); 

var lat = getprop(lw~"tiles/tile[4]/latitude-deg");
var lon = getprop(lw~"tiles/tile[4]/longitude-deg");
var alpha = getprop(lw~"tiles/tile[4]/orientation-deg");
var code = getprop(lw~"tiles/tile[4]/code");
var index = getprop(lw~"tiles/tile[4]/tile-index");
var alt_offset = getprop(lw~"tmp/tile-alt-offset-ft");
var alt = weather_dynamics.tile_convective_altitude[index-1] + 1000.0 + alt_offset;

if (contains(impostor_type_map,code)) {var type = impostor_type_map[code];}
else {var type = "scattered";}

if (local_weather.debug_output_flag == 1)
	{
	printf("Creating impostor ring...");
	print(lat, " ", lon, " ", alt, " ", alpha, " ", type, " ", n);
	}
	
weather_tiles.create_impostor_ring(lat, lon, alt, alpha, type, n);
}


###############################
# Cloud shadow management
###############################



var shadow_management_loop = func (index) {

if (local_weather.local_weather_running_flag == 0) {return;}

var n = 50;
var n_max = size(cloudShadowCandidateArray);
var s = size(active_tile_list);

# don't do anything as long as the array is empty

if (n_max == 0)  # nothing to do, loop over
	{
	setprop("/local-weather/cloud-shadows/cloud-shadow-flag",0);
	if (getprop(lw~"shadow-loop-flag") ==1) {settimer( func {shadow_management_loop(index)}, 0);} 
	return;
	}
else
	{
	setprop("/local-weather/cloud-shadows/cloud-shadow-flag",1);
	}



# compute some general-purpose stuff for the loop
	
var eyeLat = lwObserverLat; 
var eyeLon = lwObserverLon; 

#var sec_to_rad = 2.0 * math.pi/86400;
var time = getprop("/sim/time/utc/day-seconds") + getprop("/sim/time/local-offset");
var sun_angle = getprop("/sim/time/sun-angle-rad");
var cloud_alt = getprop("/environment/ground-haze-thickness-m");
var offset_mag = cloud_alt * math.tan(sun_angle);
var offset_x = -math.cos(time * local_weather.sec_to_rad) * math.cos(eyeLat) * offset_mag;
var offset_y = -math.sin(time * local_weather.sec_to_rad) * math.sin(eyeLat) * offset_mag;


# indexing, we don't want to run through hundreds of candidates per frame

if (index > n_max-1) {index = 0;}

var i_max = index + n;
if (i_max > n_max) {i_max = n_max;}

for (var i = index; i < i_max; i = i+1)
	{
	var shadow = cloudShadowCandidateArray[i];
	
	# housekeeping - delete shadows from deleted tiles
	
	var flag = 0;
	
	for (var j = 0; j < s; j = j+1)
		{
		if (active_tile_list[j] == shadow.index) {flag = 1; break;}
		if (shadow.index == 0) {flag =1; break;} # clouds in tile index 0 are special
		}
	if (flag == 0)
		{
		#print("Shadow management housekeeping!");
		cloudShadowCandidateArray = delete_from_vector(cloudShadowCandidateArray,i);
		i = i -1; i_max = i_max - 1; n_max = n_max - 1;
		continue;
		}
			
	# find nearest shadows
	
	if (shadow.shadow_flag == 0)
		{
		var diffx = (shadow.lat - eyeLat) * local_weather.lat_to_m + offset_x;
		var diffy = -(shadow.lon - eyeLon) * local_weather.lon_to_m + offset_y;
		var dist = math.sqrt(diffx * diffx + diffy * diffy) ;
		if (getprop("/local-weather/cloud-shadows/cloud-shadow-fov-flag")==1)
			{
			var viewDotPos = (diffx * lwViewVec[0] + diffy * lwViewVec[1])/dist;
			if (viewDotPos <0.7) {dist = dist -(viewDotPos - 0.7) * 10000.0;}
			}
		if (dist < cloudShadowMaxDist)
			{
			#print("Shadow management:");
			#print("Max. dist is now: ", dist);
			#print("Adding cloud");
			#print("Array size is now: ", size(cloudShadowArray));
			#print("CloudShadowMinIndex is now: ", cloudShadowMinIndex);
			cloudShadowMaxDist = dist;
			if (size(cloudShadowArray)>cloudShadowArraySize-1)
				{
				cloudShadowArray[cloudShadowMinIndex].shadow_flag = 0;
				cloudShadowArray = delete_from_vector(cloudShadowArray,cloudShadowMinIndex);
				}
			append(cloudShadowArray,shadow);
			shadow.shadow_flag = 1;
			break;
			}
		}		
	}

var index_max = -1;
var dist_max = -1.0;

var counter = 0;

foreach(s; cloudShadowArray)
	{
	var diffx = (s.lat - eyeLat) * local_weather.lat_to_m + offset_x;
	var diffy = -(s.lon - eyeLon) * local_weather.lon_to_m + offset_y;
	
	var dist = math.sqrt(diffx*diffx + diffy*diffy);
	if (getprop("/local-weather/cloud-shadows/cloud-shadow-fov-flag")==1)
		{
		var viewDotPos = (diffx * lwViewVec[0] + diffy * lwViewVec[1])/dist;
		if (viewDotPos <0.7) {dist = dist  -(viewDotPos - 0.7) * 10000.0;}
		}
	if (dist > dist_max) {dist_max = dist; index_max = counter;}
	
	setprop("/local-weather/cloud-shadows/cloudpos-x["~counter~"]",int(diffx) + s.size);
	setprop("/local-weather/cloud-shadows/cloudpos-y["~counter~"]",int(diffy) + s.strength );
	counter = counter+1;
	}
	#print("Dist_max:", dist_max, " index_max: ", index_max);
	cloudShadowMinIndex = index_max;
	if (dist_max > 0.0) {cloudShadowMaxDist = dist_max;}	
	
	
settimer( func {shadow_management_loop(i)}, 0);	
}	



###############################
# watchdog loop for debugging
###############################


var watchdog_loop = func {

var tNode = props.globals.getNode(lw~"tiles", 1).getChildren("tile");

var i = 0;

print("====================");

var viewpos = geo.aircraft_position();
var n_stations = size(local_weather.weatherStationArray);

var sum_T = 0.0;
var sum_p = 0.0;
var sum_D = 0.0;
var sum_norm = 0.0;

var sum_wind = [0,0];

var wsize = size(local_weather.windIpointArray);

var alt = getprop("position/altitude-ft");	

for (var i = 0; i < wsize; i=i+1) {
	

	var w = local_weather.windIpointArray[i];

	var wpos = geo.Coord.new();
	wpos.set_latlon(w.lat,w.lon,1000.0);



	var d = viewpos.distance_to(wpos);
	if (d <100.0) {d = 100.0;} # to prevent singularity at zero

	sum_norm = sum_norm + (1./d);

	var res = local_weather.wind_altitude_interpolation(alt,w);
	
	sum_wind = local_weather.add_vectors(sum_wind[0], sum_wind[1], res[0], (res[1]/d));	
	
	print(i, " dir: ", res[0], " speed: ", res[1], " d: ",d);
	}

print("dir_int: ", sum_wind[0], " speed_int: ", sum_wind[1]/sum_norm);

if (0==1)
{
for (var i = 0; i < n_stations; i=i+1) {
	
	s = local_weather.weatherStationArray[i];
	

	var stpos = geo.Coord.new();
	stpos.set_latlon(s.lat,s.lon,0.0);

	var d = viewpos.distance_to(stpos);
	if (d <100.0) {d = 100.0;} # to prevent singularity at zero

	sum_norm = sum_norm + 1./d * s.weight;

	sum_T = sum_T + (s.T/d) * s.weight;
	sum_D = sum_D + (s.D/d) * s.weight;
	sum_p = sum_p + (s.p/d) * s.weight;
	
	print(i, " p: ", s.p, " T: ", s.T, " D: ", s.D, " d: ",d);
	
	}

print("p_int: ", sum_p/sum_norm, " T_int: ", sum_T/sum_norm, " D_int: ", sum_D/sum_norm);
}

if (0==1)
{

foreach(t; tNode)
	{
	var code = t.getNode("code").getValue();
	var index = t.getNode("tile-index").getValue();
	var flag = t.getNode("generated-flag").getValue();
	var alpha = t.getNode("orientation-deg").getValue();

	print(i,": code: ", code, " unique id: ", index, " flag: ", flag, " alpha: ",alpha); 
	
	i = i + 1;
	}
print("alpha: ",getprop(lw~"tmp/tile-orientation-deg"));

var lat = getprop("/position/latitude-deg");
var lon = getprop("/position/longitude-deg");

var res = local_weather.wind_interpolation(lat,lon,0.0);

print("Wind: ", res[0], " tile alpha: ", getprop(lw~"tiles/tile[4]/orientation-deg"));
print("Mismatch: ", relangle(res[0], getprop(lw~"tiles/tile[4]/orientation-deg")));
}


print("====================");

settimer(watchdog_loop, 10.0);
}



###################
# global variables
###################

# these already exist in different namespace, but for ease of typing we define them here as well

var lat_to_m = 110952.0; # latitude degrees to meters
var m_to_lat = 9.01290648208234e-06; # meters to latitude degrees
var ft_to_m = 0.30480;
var m_to_ft = 1.0/ft_to_m;
var inhg_to_hp = 33.76389;
var hp_to_inhg = 1.0/inhg_to_hp;
var lon_to_m = 0.0; #local_weather.lon_to_m;
var m_to_lon = 0.0; # local_weather.m_to_lon;
var lw = "/local-weather/";
var cloud_shadow_flag = 0;

var cloud_view_distance = getprop(lw~"config/clouds-visible-range-m");

var modelArrays = [];
var active_tile_list = [];

# a bunch of variables to be updated per frame used by different
# routines, managed by the housekeeping loop

var lwObserverLat = 0.0;
var lwObserverLon = 0.0;
var lwViewDir = 0.0;
var lwViewVec = [];
var lwTileIndex = 0;


#####################################################
# hashes to manage clouds in scenery or in the buffer
#####################################################

var cloudBufferArray = [];


var cloudBuffer = {
	new: func(lat, lon, alt, path, orientation, index, type) {
	        var c = { parents: [cloudBuffer] };
	        c.lat = lat;
		c.lon = lon;
		c.alt = alt;
		c.path = path;
		c.orientation = orientation;
		c.index = index;
		c.type = type;
	        return c;
	},
	get_distance: func {
		var pos = geo.aircraft_position();
		var cpos = geo.Coord.new();
		cpos.set_latlon(me.lat,me.lon,0.0);
		return pos.distance_to(cpos);
	},
	get_course: func {
		var pos = geo.aircraft_position();
		var cpos = geo.Coord.new();
		cpos.set_latlon(me.lat,me.lon,0.0);
		return pos.course_to(cpos);
	},
	show: func {
		print("lat: ",me.lat," lon: ",me.lon," alt: ",me.alt);
		print("path: ",me.path);
	
	},
	move: func {
		var windfield = weather_dynamics.get_windfield(me.index);
		var dt = weather_dynamics.time_lw - me.timestamp;
		me.lat = me.lat + windfield[1] * dt * local_weather.m_to_lat;
		me.lon = me.lon + windfield[0] * dt * local_weather.m_to_lon;
		me.timestamp = weather_dynamics.time_lw;
	},
  
};


var cloudImpostorArray = [];

var cloudImpostor = {
	new: func(modelNode) {
	        var c = { parents: [cloudImpostor] };
		c.modelNode = modelNode;
	        return c;
	},
	removeNodes: func {
		me.modelNode.remove();
	},
};


var cloudShadowArray = [];
var cloudShadowCandidateArray = [];
var cloudShadowArraySize = 20;
var cloudShadowMaxDist = 100000.0;
var cloudShadowMinIndex = -1;

var cloudShadow = {
	new: func (lat, lon, size, strength) {
			var s = {parents: [cloudShadow] };
		s.lat = lat;
		s.lon = lon;
		s.size = size;
		s.strength = strength;
		s.shadow_flag = 0;
		return s;
	},
};	


var cloudSceneryArray = [];
var n_cloudSceneryArray = 0;

var cloudScenery = {
	new: func(index, type, cloudNode, modelNode) {
	        var c = { parents: [cloudScenery] };
		c.index = index;
		c.type = type;
		c.cloudNode = cloudNode;
		c.modelNode = modelNode;
		c.calt = cloudNode.getNode("position/altitude-ft");
		c.clat = cloudNode.getNode("position/latitude-deg");
		c.clon = cloudNode.getNode("position/longitude-deg");
		c.alt = c.calt.getValue();
		c.lat = c.clat.getValue();
		c.lon = c.clon.getValue();
	        return c;
	},
	removeNodes: func {
		me.modelNode.remove();
		me.cloudNode.remove();
	},
	to_buffer: func {
		var path = me.modelNode.getNode("path").getValue();
		var orientation = me.cloudNode.getNode("orientation/true-heading-deg").getValue();
		var b = cloudBuffer.new(me.lat, me.lon, me.alt, path, orientation, me.index, me.type);

		if (local_weather.dynamics_flag == 1)
			{
			b.timestamp = me.timestamp;

			if (me.type !=0) # Cumulus clouds get some extra info
				{
				b.flt = me.flt;
				b.rel_alt = me.rel_alt;
				b.evolution_timestamp = me.evolution_timestamp;
				}
			}

		me.removeNodes();
		return b;
	},
	get_distance: func {
		var pos = geo.aircraft_position();
		var cpos = geo.Coord.new();
		var lat = me.clat.getValue();
		var lon = me.clon.getValue();
		cpos.set_latlon(lat,lon,0.0);
		return pos.distance_to(cpos);
	},
	get_course: func {
		var pos = geo.aircraft_position();
		var cpos = geo.Coord.new();
		var lat = me.clat.getValue();
		var lon = me.clon.getValue();
		cpos.set_latlon(lat,lon,0.0);
		return pos.course_to(cpos);
	},
	get_altitude: func {
		return me.calt.getValue();
	},
	correct_altitude: func {	
		var lat = me.lat;
		var lon = me.lon;
		var convective_alt = weather_dynamics.tile_convective_altitude[me.index-1] + local_weather.alt_20_array[me.index-1];
		var elevation = compat_layer.get_elevation(lat, lon);
		
		if (local_weather.detailed_terrain_interaction_flag == 1)
			{
			var phi = local_weather.get_wind_direction(me.index) * math.pi/180.0;
			var grad = local_weather.get_terrain_gradient(lat, lon, elevation, phi, 1000.0);
			}
		else 
			{var grad = 0.0;}

		var alt_new = local_weather.get_convective_altitude(convective_alt, elevation, me.index, grad);
		me.target_alt = alt_new + me.rel_alt;
	},
	correct_altitude_and_age: func {	
		var lat = me.lat;
		var lon = me.lon;
		var convective_alt = weather_dynamics.tile_convective_altitude[me.index-1] + local_weather.alt_20_array[me.index-1];
		
		# get terrain elevation and landcover	

		var elevation = -1.0; var p_cover = 0.2;# defaults if there is no info
		var info = geodinfo(lat, lon);
		if (info != nil) 
			{
			elevation = info[0] * local_weather.m_to_ft;
			if (info[1] != nil)
				{
         			var landcover = info[1].names[0];
	 			if (contains(local_weather.landcover_map,landcover)) {p_cover = local_weather.landcover_map[landcover];}
				else {p_cover = 0.2;}
				}	
			}

		if (local_weather.detailed_terrain_interaction_flag == 1)
			{
			var phi = local_weather.get_wind_direction(me.index) * math.pi/180.0;
			var grad = local_weather.get_terrain_gradient(lat, lon, elevation, phi, 1000.0);
			var lee_bias = local_weather.get_lee_bias(grad);
			}
		else 
			{	
			var grad = 0.0;
			var lee_bias = 1.0;
			}

		# correct the altitude
		var alt_new = local_weather.get_convective_altitude(convective_alt, elevation, me.index, grad);
		me.target_alt = alt_new + me.rel_alt;

		# correct fractional lifetime based on terrain below

		var current_lifetime = math.sqrt(p_cover * lee_bias)/math.sqrt(0.35) * weather_dynamics.cloud_convective_lifetime_s;
		var fractional_increase = (weather_dynamics.time_lw - me.evolution_timestamp)/current_lifetime;
		me.flt = me.flt + fractional_increase;
		me.evolution_timestamp = weather_dynamics.time_lw;
	},
	to_target_alt: func {	
		if (me.type ==0) {return;}
		var alt_diff = me.target_alt - me.alt;
		if (alt_diff == 0.0) {return;}
		var max_vertical_movement_ft = weather_dynamics.dt_lw * weather_dynamics.cloud_max_vertical_speed_fts;
		if (abs(alt_diff) < max_vertical_movement_ft)
			{
			me.alt = me.target_alt; 
			}
		else if (alt_diff < 0)
			{
			me.alt = me.alt -max_vertical_movement_ft;
			}
		else
			{
			me.alt = me.alt + max_vertical_movement_ft;
			}
		setprop(lw~"clouds/tile["~me.index~"]/cloud["~me.write_index~"]/position/altitude-ft", me.alt);
	},
	move: func {
		
		
		var windfield = weather_dynamics.windfield;
		var dt = weather_dynamics.time_lw - me.timestamp;

		me.lat = me.lat + windfield[1] * dt * local_weather.m_to_lat;
		me.lon = me.lon + windfield[0] * dt * local_weather.m_to_lon;
		
		setprop(lw~"clouds/tile["~me.index~"]/cloud["~me.write_index~"]/position/latitude-deg", me.lat);
		setprop(lw~"clouds/tile["~me.index~"]/cloud["~me.write_index~"]/position/longitude-deg", me.lon);
		
		me.timestamp = weather_dynamics.time_lw;
		
	},
	show: func {
		var lat = me.clat.getValue();
		var lon = me.clon.getValue();
		var alt = me.calt.getValue();		
		
		var convective_alt = weather_dynamics.tile_convective_altitude[me.index-1] + local_weather.alt_20_array[me.index-1];
		var elevation = compat_layer.get_elevation(lat, lon);
		print("lat :", lat, " lon: ", lon, " alt: ", alt);
		print("path: ", me.modelNode.getNode("path").getValue());
		print("elevation: ", compat_layer.get_elevation(lat, lon), " cloudbase: ", convective_alt);
		if (me.type !=0) {print("relative: ", me.rel_alt, "target: ", me.target_alt);}
	},
};

var cloudArray = [];

var cloud = {
	new: func(type, subtype) {
	        var c = { parents: [cloud] };
		c.type = type;
		c.subtype = subtype;		
		c.tracer_flag = 0;
	        return c;
	},
	remove: func {
		var p = props.Node.new({ "layer" : 0,
                         "index": me.cloud_index });
		fgcommand("del-cloud", p);
	},
	move: func {	
		# this doesn't move a cloud in the scenery, but updates its position in internal space	
		var windfield = local_weather.windfield;
		var dt = local_weather.time_lw - me.timestamp;

		me.lat = me.lat + windfield[1] * dt * local_weather.m_to_lat;
		me.lon = me.lon + windfield[0] * dt * local_weather.m_to_lon;
		me.timestamp = weather_dynamics.time_lw;
		
	},
	correct_altitude: func {	
		var convective_alt = weather_dynamics.tile_convective_altitude[me.index-1] + local_weather.alt_20_array[me.index-1];
		var elevation = compat_layer.get_elevation(me.lat, me.lon);
		
		if (local_weather.detailed_terrain_interaction_flag == 1)
			{
			var phi = local_weather.get_wind_direction(me.index) * math.pi/180.0;
			var grad = local_weather.get_terrain_gradient(me.lat, me.lon, elevation, phi, 1000.0);
			}
		else 
			{var grad = 0.0;}

		var alt_new = local_weather.get_convective_altitude(convective_alt, elevation, me.index, grad);
		var target_alt = alt_new + me.rel_alt;

		var p = props.Node.new({ "layer" : 0,
                         "index": me.cloud_index,
 			 "lat-deg": me.lat,
                         "lon-deg": me.lon,
			 "alt-ft": target_alt
			 });
		fgcommand("move-cloud",p);

		me.alt = target_alt;
	},
};


###################
# helper functions
###################

var calc_geo = func(clat) {

lon_to_m  = math.cos(clat*math.pi/180.0) * lat_to_m;
m_to_lon = 1.0/lon_to_m;
}

var get_lat = func (x,y,phi) {

return (y * math.cos(phi) - x * math.sin(phi)) * m_to_lat;
}

var get_lon = func (x,y,phi) {

return (x * math.cos(phi) + y * math.sin(phi)) * m_to_lon;
}


var relangle = func (alpha, beta) {

var angdiff = abs (alpha - beta);

if ((360.0 - angdiff) < angdiff)
	{angdiff = 360.0 - angdiff};

return angdiff;
}


var norm_relangle = func (alpha, beta) {

var angdiff = beta - alpha;

while (angdiff < 0.0) 
	{angdiff = angdiff + 360.0;}

while (angdiff > 360.0)
	{angdiff = angdiff - 360.0;}

if (angdiff == 360.0) 
	{angdiff = 0.0;}

return angdiff;
}


var delete_from_vector = func(vec, index) {

var n = index+1;

var vec_end = subvec(vec, n);

setsize(vec, n-1);
return vec~vec_end;
	
}
