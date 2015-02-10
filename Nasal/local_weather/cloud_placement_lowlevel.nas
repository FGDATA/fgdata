########################################################
# routines to set up, transform and manage advanced weather
# Thorsten Renk, April 2012
########################################################

# function			purpose
#
# create_undulatus		to create an undulating cloud pattern
# create_cumulus_alleys		to create an alley pattern of Cumulus clouds
# create_layer			to create a cloud layer with optional precipitation

###########################################################
# place an undulatus pattern 
###########################################################

var create_undulatus = func (type, blat, blong, balt, alt_var, nx, xoffset, edgex, x_var, ny, yoffset, edgey, y_var, und_strength, direction, tri) {

var flag = 0;
var path = "Models/Weather/blank.ac";
local_weather.calc_geo(blat);
var dir = direction * math.pi/180.0;

var ymin = -0.5 * ny * yoffset;
var xmin = -0.5 * nx * xoffset;
var xinc = xoffset * (tri-1.0) /ny;
 
var jlow = int(nx*edgex);
var ilow = int(ny*edgey);

var und = 0.0;
var und_array = [];

for (var i=0; i<ny; i=i+1)
	{
	und = und + 2.0 * (rand() -0.5) * und_strength;
	append(und_array,und);
	}

for (var i=0; i<ny; i=i+1)
	{
	var y = ymin + i * yoffset + 2.0 * (rand() -0.5) * 0.2 * yoffset; 
	
	for (var j=0; j<nx; j=j+1)
		{
		var y0 = y + y_var * 2.0 * (rand() -0.5);
		var x = xmin + j * (xoffset + i * xinc) + x_var * 2.0 * (rand() -0.5) + und_array[i];
		var lat = blat + m_to_lat * (y0 * math.cos(dir) - x * math.sin(dir));
		var long = blong + m_to_lon * (x * math.cos(dir) + y0 * math.sin(dir));

		var alt = balt + alt_var * 2 * (rand() - 0.5);
		
		flag = 0;
		var rn = 6.0 * rand();

		if (((j<jlow) or (j>(nx-jlow-1))) and ((i<ilow) or (i>(ny-ilow-1)))) # select a small or no cloud		
			{
			if (rn > 2.0) {flag = 1;} else {path = select_cloud_model(type,"small");}
			}
		if ((j<jlow) or (j>(nx-jlow-1)) or (i<ilow) or (i>(ny-ilow-1))) 	
			{
			if (rn > 5.0) {flag = 1;} else {path = select_cloud_model(type,"small");}
			}
		else	{ # select a large cloud
			if (rn > 5.0) {flag = 1;} else {path = select_cloud_model(type,"large");}
			}


		if (flag==0){
			if (thread_flag == 1)
				{create_cloud_vec(path, lat, long, alt, 0.0);}
			else
				{local_weather.create_cloud(path, lat, long, alt, 0.0);}
			

				}
		}

	} 

}


###########################################################
# place an advanced undulatus pattern 
###########################################################

var create_adv_undulatus = func (arg) {

var markov_array = [];
var rnd_array = [];
var max_num_clouds = int(arg.xsize/arg.cloud_spacing)+1;
var max_num_streaks = int(arg.ysize/arg.undulatus_spacing)+1;
var path = "Models/Weather/blank.ac";
var counter = 0;

append(markov_array,0.0);

var rn = 0.0;
arg.dir = arg.dir + 90.0;

for (var i=1; i<max_num_clouds; i=i+1)
	{
	rn = rand();
	append(markov_array, markov_array[i-1] + 2.0 * (rn -0.5) * arg.undulatus_amplitude + arg.undulatus_slant);
	append(rnd_array, rn);
	}

for (i=0; i< max_num_streaks; i=i+1)
	{
	var streak_ypos = -0.5 * arg.ysize + i * arg.undulatus_spacing;
	var aspect_num_clouds = int((arg.aspect + (1.0-arg.aspect) * i/max_num_streaks) * max_num_clouds);
	
	for (var j = 0; j< aspect_num_clouds; j=j+1)
		{
		var y = streak_ypos + markov_array[j];
		var x = -0.5 * arg.xsize + j * arg.cloud_spacing;
		
		x = x - arg.Dx + 2.0 * rand() * arg.Dx;
		y = y - arg.Dy + 2.0 * rand() * arg.Dy;
		
		var flag = 0;
		var bias =1.0 - (math.abs(i-0.5 * max_num_streaks)/max_num_streaks +  math.abs(j-0.5 * aspect_num_clouds)/aspect_num_clouds);
		var comp = -.25 * rnd_array[j] + 0.75 * bias;
		
		comp = comp + arg.size_bias;
		if (comp > 0.7)
			{
			flag = 1;
			path = select_cloud_model(arg.type,"large")
			}
		else if (comp > 0.4)
			{
			flag = 1;
			path = select_cloud_model(arg.type,"small")
			}
		
		var edge = math.pow(bias, arg.edge_power);
		local_weather.alpha_factor = edge * arg.core_alpha + (1.0-edge) * arg.edge_alpha;
			
		var lat = arg.blat + m_to_lat * (y * math.cos(arg.dir) - x * math.sin(arg.dir));
		var lon = arg.blon + m_to_lon * (x * math.cos(arg.dir) + y * math.sin(arg.dir));

		var alt = arg.balt + arg.alt_var * 2 * (rand() - 0.5);
		
		if (flag > 0)
			{create_cloud_vec(path, lat, lon, alt, 0.0); counter = counter +1;}
		}
	
	}
	#print("Cloud count: ",counter);
	local_weather.alpha_factor = 1.0;
}


###########################################################
# place a stick bundle pattern 
###########################################################

var sgn = func (x) {

if (x<0.0) {return -1.0;}
else {return 1.0;}
}

var create_stick_bundle = func (arg) {

var path = "Models/Weather/blank.ac";
var base_size_scale = local_weather.cloud_size_scale;

for (var i = 0; i<arg.n_sticks; i=i+1)
	{
	var stick_x = 0.5 * math.pow(rand(),2.0) * arg.xsize * sgn(rand()-0.5);
	var stick_y = 0.5 * math.pow(rand(),2.0) * arg.ysize * sgn(rand()-0.5);
		
	var stick_length = arg.stick_length_min + int(rand() * (arg.stick_length_max - arg.stick_length_min) );
	var stick_Dphi = arg.stick_Dphi_min + rand() * (arg.stick_Dphi_max - arg.stick_Dphi_min);
	var stick_size_scale = 0.8 + 0.2 * rand();
	for (var j=0; j<stick_length;j=j+1)
		{
		var y = stick_y;
		var x = stick_x - 0.5 * stick_length * arg.cloud_spacing;
		var inc = j * arg.cloud_spacing;
		var pos_size_scale = base_size_scale +  base_size_scale * 2.0* (1.0 - 2.0* math.abs(0.5 * stick_length - j)/stick_length);
		local_weather.cloud_size_scale = pos_size_scale;
		local_weather.cloud_size_scale = stick_size_scale * local_weather.cloud_size_scale;
		inc = inc *  stick_size_scale;
		
		x = x + inc * math.cos(stick_Dphi);
		y = y + inc * math.sin(stick_Dphi);

		x = x - arg.Dx + 2.0 * rand() * arg.Dx;
		y = y - arg.Dy + 2.0 * rand() * arg.Dy;

		path = select_cloud_model(arg.type,"large");

		var lat = arg.blat + m_to_lat * (y * math.cos(arg.dir) - x * math.sin(arg.dir));
		var lon = arg.blon + m_to_lon * (x * math.cos(arg.dir) + y * math.sin(arg.dir));

		var alt = arg.balt + arg.alt_var * 2 * (rand() - 0.5);

		create_cloud_vec(path, lat, lon, alt, 0.0);
		}
	}

}

###########################################################
# place a nested domains pattern 
###########################################################

var create_domains = func (arg) {

var path = "Models/Weather/blank.ac";

for (var j=0; j<arg.n_domains; j=j+1)
	{
	var domain_pos_x = -0.5 * arg.xsize + rand() * arg.xsize;
	var domain_pos_y = -0.5 * arg.ysize + rand() * arg.ysize;

	var domain_size_x = arg.min_domain_size_x + rand() * (arg.max_domain_size_x - arg.min_domain_size_x);
	var domain_size_y = arg.min_domain_size_y + rand() * (arg.max_domain_size_y - arg.min_domain_size_y);

	var n_node = int(arg.node_fraction * arg.n);
	var n_halo = int(arg.halo_fraction * arg.n);
	var n_bulk = arg.n - n_node - n_halo;
	
	for (var i=0; i<n_halo; i=i+1)
		{
		var x = domain_pos_x - 0.5 * domain_size_x + rand() * domain_size_x;
		var y = domain_pos_y - 0.5 * domain_size_y + rand() * domain_size_y;
		var lat = arg.blat + m_to_lat * (y * math.cos(arg.dir) - x * math.sin(arg.dir));
		var lon = arg.blon + m_to_lon * (x * math.cos(arg.dir) + y * math.sin(arg.dir));
		var alt = arg.balt + arg.alt_var * 2 * (rand() - 0.5);
		local_weather.alpha_factor = arg.halo_alpha - 0.2 + rand() * 0.2;		
		if ((math.abs(x-domain_pos_x) < 0.3 * domain_size_x) or (math.abs(y-domain_pos_y) < 0.3 * domain_size_y))
			{path = select_cloud_model(arg.htype,arg.hsubtype);
			create_cloud_vec(path, lat, lon, alt, 0.0);}

		}
	for (i=0; i<n_bulk; i=i+1)
		{
		x = domain_pos_x - 0.5 * 0.4* domain_size_x + rand() * 0.4* domain_size_x;
		y = domain_pos_y - 0.5 * 0.4* domain_size_y + rand() * 0.4* domain_size_y;
		lat = arg.blat + m_to_lat * (y * math.cos(arg.dir) - x * math.sin(arg.dir));
		lon = arg.blon + m_to_lon * (x * math.cos(arg.dir) + y * math.sin(arg.dir));
		alt = arg.balt + arg.alt_var * 2 * (rand() - 0.5);
		local_weather.alpha_factor = arg.bulk_alpha - 0.2 + rand() * 0.2;				
		if ((math.abs(x-domain_pos_x) < 0.4 * domain_size_x) or (math.abs(y-domain_pos_y) < 0.4 * domain_size_y))
			{
			path = select_cloud_model(arg.type,arg.subtype);
			create_cloud_vec(path, lat, lon, alt, 0.0);
			}
		}
	for (i=0; i<n_node; i=i+1)
		{
		x = domain_pos_x - 0.5 * 0.1* domain_size_x + rand() * 0.1* domain_size_x;
		y = domain_pos_y - 0.5 * 0.1* domain_size_y + rand() * 0.1* domain_size_y;
		lat = arg.blat + m_to_lat * (y * math.cos(arg.dir) - x * math.sin(arg.dir));
		lon = arg.blon + m_to_lon * (x * math.cos(arg.dir) + y * math.sin(arg.dir));
		alt = arg.balt + arg.alt_var * 2 * (rand() - 0.5);
		local_weather.alpha_factor = arg.node_alpha - 0.2 + rand() * 0.2;				
		path = select_cloud_model(arg.ntype,arg.nsubtype);
		create_cloud_vec(path, lat, lon, alt, 0.0);
		}

	}

	local_weather.alpha_factor = 1.0;

}




###########################################################
# place a Cumulus alley pattern 
###########################################################

var create_cumulus_alleys = func (blat, blon, balt, alt_var, nx, xoffset, edgex, x_var, ny, yoffset, edgey, y_var, und_strength, direction, tri) {

var flag = 0;
var path = "Models/Weather/blank.ac";
local_weather.calc_geo(blat);
var dir = direction * math.pi/180.0;

var ymin = -0.5 * ny * yoffset;
var xmin = -0.5 * nx * xoffset;
var xinc = xoffset * (tri-1.0) /ny;
 
var jlow = int(nx*edgex);
var ilow = int(ny*edgey);

var und = 0.0;
var und_array = [];

var spacing = 0.0;
var spacing_array = [];


for (var i=0; i<ny; i=i+1)
	{
	und = und + 2.0 * (rand() -0.5) * und_strength;
	append(und_array,und);
	}

for (var i=0; i<nx; i=i+1)
	{
	spacing = spacing + 2.0 * (rand() -0.5) * 0.5 * xoffset;
	append(spacing_array,spacing);
	}


for (var i=0; i<ny; i=i+1)
	{
	var y = ymin + i * yoffset; 
	var xshift = 2.0 * (rand() -0.5) * 0.5 * xoffset; 
	x_var = 0.0; xshift = 0.0;

	for (var j=0; j<nx; j=j+1)
		{
		var y0 = y + y_var * 2.0 * (rand() -0.5);
		var x = xmin + j * (xoffset + i * xinc) + x_var * 2.0 * (rand() -0.5) + spacing_array[j] + und_array[i];
		var lat = blat + m_to_lat * (y0 * math.cos(dir) - x * math.sin(dir));
		var lon = blon + m_to_lon * (x * math.cos(dir) + y0 * math.sin(dir));

		var alt = balt + alt_var * 2 * (rand() - 0.5);
		
		flag = 0;
		var strength = 0.0;
		var rn = 6.0 * rand();

		if (((j<jlow) or (j>(nx-jlow-1))) and ((i<ilow) or (i>(ny-ilow-1)))) # select a small or no cloud		
			{
			if (rn > 2.0) {flag = 1;} else {strength = 0.3 + rand() * 0.5;}
			}
		if ((j<jlow) or (j>(nx-jlow-1)) or (i<ilow) or (i>(ny-ilow-1))) 	
			{
			if (rn > 5.0) {flag = 1;} else {strength = 0.7 + rand() * 0.5;}
			}
		else	{ # select a large cloud
			if (rn > 5.0) {flag = 1;} else {strength = 1.1 + rand() * 0.6;}
			}


		if (flag==0){create_detailed_cumulus_cloud(lat, lon, alt, strength); }
		}

	} 

}



###########################################################
# place a Cumulus alley pattern 
###########################################################

var create_developing_cumulus_alleys = func (blat, blon, balt, alt_var, nx, xoffset, edgex, x_var, ny, yoffset, edgey, y_var, und_strength, direction, tri) {

var flag = 0;
var path = "Models/Weather/blank.ac";
local_weather.calc_geo(blat);
var dir = direction * math.pi/180.0;

var ymin = -0.5 * ny * yoffset;
var xmin = -0.5 * nx * xoffset;
var xinc = xoffset * (tri-1.0) /ny;
 
var jlow = int(nx*edgex);
var ilow = int(ny*edgey);

var und = 0.0;
var und_array = [];

var spacing = 0.0;
var spacing_array = [];


for (var i=0; i<ny; i=i+1)
	{
	und = und + 2.0 * (rand() -0.5) * und_strength;
	append(und_array,und);
	}

for (var i=0; i<nx; i=i+1)
	{
	spacing = spacing + 2.0 * (rand() -0.5) * 0.5 * xoffset;
	append(spacing_array,spacing);
	}


for (var i=0; i<ny; i=i+1)
	{
	var y = ymin + i * yoffset; 
	var xshift = 2.0 * (rand() -0.5) * 0.5 * xoffset; 
	x_var = 0.0; xshift = 0.0;

	for (var j=0; j<nx; j=j+1)
		{
		var y0 = y + y_var * 2.0 * (rand() -0.5);
		var x = xmin + j * (xoffset + i * xinc) + x_var * 2.0 * (rand() -0.5) + spacing_array[j] + und_array[i];
		var lat = blat + m_to_lat * (y0 * math.cos(dir) - x * math.sin(dir));
		var lon = blon + m_to_lon * (x * math.cos(dir) + y0 * math.sin(dir));

		var alt = balt + alt_var * 2 * (rand() - 0.5);
		
		flag = 0;
		var strength = 0.0;
		var rn = 6.0 * rand();

		if (((j<jlow) or (j>(nx-jlow-1))) and ((i<ilow) or (i>(ny-ilow-1)))) # select a small or no cloud		
			{
			if (rn > 2.0) {flag = 1;} else {strength = 0.1 + rand() * 0.5;}
			}
		if ((j<jlow) or (j>(nx-jlow-1)) or (i<ilow) or (i>(ny-ilow-1))) 	
			{
			if (rn > 5.0) {flag = 1;} else {strength = 0.4 + rand() * 0.5;}
			}
		else	{ # select a large cloud
			if (rn > 5.0) {flag = 1;} else {strength = 0.6 + rand() * 0.6;}
			}


		if (flag==0){create_detailed_cumulus_cloud(lat, lon, alt, strength); }
		}

	} 

}


###########################################################
# place a cloud layer 
###########################################################

var create_layer = func (type, blat, blon, balt, bthick, rx, ry, phi, density, edge, rainflag, rain_density) {


var i = 0;
var area = math.pi * rx * ry;
var circ = math.pi * (rx + ry); # that's just an approximation
var n = int(area/80000000.0 * 100 * density);
var m = int(circ/63000.0 * 40 * rain_density);
var path = "Models/Weather/blank.ac";

#print("density: ",n);

phi = phi * math.pi/180.0;

if (contains(local_weather.cloud_vertical_size_map, type)) 
		{var alt_offset = cloud_vertical_size_map[type]/2.0 * m_to_ft;}
	else {var alt_offset = 0.0;}

while(i<n)
	{
	var x = rx * (2.0 * rand() - 1.0); 
	var y = ry * (2.0 * rand() - 1.0); 
	var alt = balt + bthick * rand() + 0.8 * alt_offset;
	var res = (x*x)/(rx*rx) + (y*y)/(ry*ry);

	if (res < 1.0)
		{
		var lat = blat + m_to_lat * (y * math.cos(phi) - x * math.sin(phi));
		var lon = blon + m_to_lon * (x * math.cos(phi) + y * math.sin(phi));
		if (res > ((1.0 - edge) * (1.0- edge)))
			{
			if (rand() > 0.4) {
				path = select_cloud_model(type,"small");
			if (thread_flag == 1)
				{create_cloud_vec(path, lat, lon, alt, 0.0);}
			else
				{compat_layer.create_cloud(path, lat, lon, alt, 0.0);}
				}
			}
		else {
			path = select_cloud_model(type,"large");
			if (thread_flag == 1)
				{create_cloud_vec(path, lat, lon, alt, 0.0);}
			else 
				{compat_layer.create_cloud(path, lat, lon, alt, 0.0);}
			}
		i = i + 1;
		}
	}

i = 0;

if (rainflag ==1){

if (local_weather.hardcoded_clouds_flag == 1) {balt = balt + local_weather.offset_map[type]; }

	while(i<m)
		{
		var alpha = rand() * 2.0 * math.pi;
		x = 0.8 * (1.0 - edge) * (1.0-edge) * rx * math.cos(alpha);
		y = 0.8 * (1.0 - edge) * (1.0-edge) * ry * math.sin(alpha);

		lat = blat + m_to_lat * (y * math.cos(phi) - x * math.sin(phi));
		lon = blon + m_to_lon * (x * math.cos(phi) + y * math.sin(phi));	
	
		path = "Models/Weather/rain1.xml";
 		if (contains(cloud_vertical_size_map,type)) {var alt_shift = cloud_vertical_size_map[type];}
		else {var alt_shift = 0.0;}
		
		if (thread_flag == 1)
		{create_cloud_vec(path, lat, lon,balt +0.5*bthick+ alt_shift, 0.0);}		
		else		
		{compat_layer.create_cloud(path, lat, lon, balt + 0.5 * bthick + alt_shift, 0.0);}
		i = i + 1;
		} # end while	
	} # end if (rainflag ==1)
}


###########################################################
# place a Cumulus layer with excluded regions
# to avoid placing cumulus underneath a thunderstorm
###########################################################

var cumulus_exclusion_layer = func (blat, blon, balt, n, size_x, size_y, alpha, s_min, s_max, n_ex, exlat, exlon, exrad) {


var strength = 0;
var flag = 1;
var phi = alpha * math.pi/180.0;

var i_max = int(0.35*n);



for (var i =0; i< i_max; i=i+1)
	{
	var x = (2.0 * rand() - 1.0) * size_x;
	var y = (2.0 * rand() - 1.0) * size_y; 

	var lat = blat + (y * math.cos(phi) - x * math.sin(phi)) * m_to_lat;
	var lon = blon + (x * math.cos(phi) + y * math.sin(phi)) * m_to_lon;

	flag = 1;

	for (var j=0; j<n_ex; j=j+1)
		{
		if (calc_d_sq(lat, lon, exlat[j], exlon[j]) < (exrad[j] * exrad[j])) {flag = 0;}
		}
	if (flag == 1)
		{
		strength = s_min + rand() * (s_max - s_min);		
		create_detailed_cumulus_cloud(lat, lon, balt, strength);
		} 

	} # end for i

}

