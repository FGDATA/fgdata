
#################################################################
# object classes
#################################################################

var seaColorPoint = {
	new: func (lat, lon, weight, deep_r, deep_g, deep_b) {
	        var s = { parents: [seaColorPoint] };
		s.lat = lat;
		s.lon = lon;
		s.weight = weight;
		s.r = deep_r;
		s.g = deep_g;
		s.b = deep_b;
	        return s;
	},
};


#################################################################
# functions
#################################################################

var init_sea_colors = func {

var viewpos = geo.aircraft_position();
var ppos = geo.Coord.new();

# St. Tropez
var s = seaColorPoint.new(43.20, 6.47, 1.0,0.03, 0.22, 0.46);
ppos.set_latlon(s.lat,s.lon,0.0);
s.distance = viewpos.distance_to(ppos);
append(interpolation_vector,s);


# Hawaii
var s = seaColorPoint.new(22.0, -165.0, 1.0,0.03, 0.22, 0.46);
ppos.set_latlon(s.lat,s.lon,0.0);
s.distance = viewpos.distance_to(ppos);
append(interpolation_vector,s);


# St. Maarten
s = seaColorPoint.new(18.03, -63.11, 1.0,0.08, 0.40, 0.425);
ppos.set_latlon(s.lat,s.lon,0.0);
s.distance = viewpos.distance_to(ppos);
append(interpolation_vector,s);


# Venezuela rivers
s = seaColorPoint.new(5.00, -62.11, 3.0,0.17, 0.25, 0.31);
ppos.set_latlon(s.lat,s.lon,0.0);
s.distance = viewpos.distance_to(ppos);
append(interpolation_vector,s);


ivector_size = size(interpolation_vector);

sea_color_loop(0);
}

var sea_color_loop = func (index) {

if (local_weather.local_weather_running_flag == 0) {return;}

if (index > (ivector_size-1)) {index = 0;}

# pick one point for distance re-computation per loop iteration 

var viewpos = geo.aircraft_position();
var ppos = geo.Coord.new();
var s = interpolation_vector[index];
ppos.set_latlon(s.lat,s.lon,0.0);
s.distance = viewpos.distance_to(ppos);


# interpolate the rgb values


var sum_r = 0.148/1000000.0;
var sum_g = 0.27/1000000.0;
var sum_b = 0.3/1000000.0;
var sum_norm = 1.0/1000000.0; # default point is 1000 km away

for (var i = 0; i < ivector_size; i = i + 1) 
	{
	s = interpolation_vector[i];
	sum_norm = sum_norm + 1./s.distance * s.weight;
	sum_r = sum_r + s.r/s.distance * s.weight;
	sum_g = sum_g + s.g/s.distance * s.weight;
	sum_b = sum_b + s.b/s.distance * s.weight;

	#print("index: ", i, " dist: ", s.distance, " r: ", s.r); 
	}

var r = sum_r / sum_norm;
var g = sum_g / sum_norm;
var b = sum_b / sum_norm;

setprop("/environment/sea/color_r", r);
setprop("/environment/sea/color_g", g);
setprop("/environment/sea/color_b", b);


settimer( func {sea_color_loop(index+1) },1.0);
}

var ivector_size = 0;
var interpolation_vector = [];
