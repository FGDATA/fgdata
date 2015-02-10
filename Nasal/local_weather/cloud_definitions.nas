
########################################################
# routines to set up, transform and manage local weather
# Thorsten Renk, August 2011
########################################################

# function			purpose
#
# select_cloud_model		to define the cloud parameters, given the cloud type and subtype


###########################################################
# define various cloud models
###########################################################

var select_cloud_model = func(type, subtype) {

var rn = rand();
var path="Models/Weather/blank.ac";


if (type == "Cumulus (cloudlet)"){
		
	cloudAssembly = local_weather.cloud.new(type, subtype);

	if (subtype == "small") 
		{
		cloudAssembly.texture_sheet = "/Models/Weather/cumulus_sheet2.rgb";
		cloudAssembly.n_sprites = 10;
		cloudAssembly.min_width = 500.0;
		cloudAssembly.max_width = 700.0;
		cloudAssembly.min_height = 500.0;
		cloudAssembly.max_height = 700.0;
		cloudAssembly.min_cloud_width = 1300;
		cloudAssembly.min_cloud_height = 750;
		cloudAssembly.bottom_shade = 0.4;
		}
	else
		{
		cloudAssembly.texture_sheet = "/Models/Weather/cumulus_sheet1.rgb";
		cloudAssembly.n_sprites = 5;
		cloudAssembly.min_width = 600.0;
		cloudAssembly.max_width = 900.0;
		cloudAssembly.min_height = 600.0;
		cloudAssembly.max_height = 900.0;
		cloudAssembly.min_cloud_width = 1300;
		cloudAssembly.min_cloud_height = 950;
		cloudAssembly.bottom_shade = 0.4;
		}
			

	# characterize the basic texture sheet
	cloudAssembly.num_tex_x = 3;
	cloudAssembly.num_tex_y = 3;
	
	#characterize the cloud
	cloudAssembly.z_scale = 1.0;

	#signal that new routines are used
	path = "new";
	}

else if (type == "Cu (volume)"){



	cloudAssembly = local_weather.cloud.new(type, subtype);

	if (subtype == "small") 
		{
		cloudAssembly.texture_sheet = "/Models/Weather/cumulus_sheet2.rgb";
		cloudAssembly.n_sprites = 5;
		cloudAssembly.min_width = 400.0;
		cloudAssembly.max_width = 700.0;
		cloudAssembly.min_height = 400.0;
		cloudAssembly.max_height = 700.0;
		cloudAssembly.min_cloud_width = 1000;
		cloudAssembly.min_cloud_height = 1000;
		cloudAssembly.bottom_shade = 0.4;
		}
	else
		{
		cloudAssembly.texture_sheet = "/Models/Weather/cumulus_sheet1.rgb";
		cloudAssembly.n_sprites = 5;
		cloudAssembly.min_width = 800.0;
		cloudAssembly.max_width = 1100.0;
		cloudAssembly.min_height = 800.0;
		cloudAssembly.max_height = 1100.0;
		cloudAssembly.min_cloud_width = 1500;
		cloudAssembly.min_cloud_height = 1150;
		cloudAssembly.bottom_shade = 0.4;
		}
			

	# characterize the basic texture sheet
	cloudAssembly.num_tex_x = 3;
	cloudAssembly.num_tex_y = 3;
	
	#characterize the cloud
	cloudAssembly.z_scale = 1.0;

	#signal that new routines are used
	path = "new";
	}


else if (type == "Congestus"){
	
	cloudAssembly = local_weather.cloud.new(type, subtype);

	if (subtype == "small") 
		{
		cloudAssembly.texture_sheet = "/Models/Weather/cumulus_sheet1.rgb";
		cloudAssembly.num_tex_x = 3;
		cloudAssembly.num_tex_y = 3;
		cloudAssembly.n_sprites = 5;
		cloudAssembly.min_width = 600.0;
		cloudAssembly.max_width = 900.0;
		cloudAssembly.min_height = 600.0;
		cloudAssembly.max_height = 900.0;
		cloudAssembly.min_cloud_width = 1300;
		cloudAssembly.min_cloud_height = 1000;
		cloudAssembly.bottom_shade = 0.4;
		}
	else 
		{	

		if (rand() > 0.5)
			{
			cloudAssembly.texture_sheet = "/Models/Weather/congestus_sheet1.rgb";
			cloudAssembly.num_tex_x = 1;
			cloudAssembly.num_tex_y = 3;
			cloudAssembly.min_width = 1300.0;
			cloudAssembly.max_width = 2000.0;
			cloudAssembly.min_height = 600.0;
			cloudAssembly.max_height = 900.0;			
			}
		else	
			{
			cloudAssembly.texture_sheet = "/Models/Weather/congestus_sheet2.rgb";
			cloudAssembly.num_tex_x = 1;
			cloudAssembly.num_tex_y = 2;
			cloudAssembly.min_width = 1200.0;
			cloudAssembly.max_width = 1800.0;
			cloudAssembly.min_height = 700.0;
			cloudAssembly.max_height = 1000.0;			
			}


		cloudAssembly.n_sprites = 3;
		cloudAssembly.min_cloud_width = 2200.0;
		cloudAssembly.min_cloud_height = 1200.0;
		cloudAssembly.bottom_shade = 0.4;

		}
	cloudAssembly.z_scale = 1.0;

	#signal that new routines are used
	path = "new";

	}
else if (type == "Stratocumulus"){

		cloudAssembly = local_weather.cloud.new(type, subtype);

		if (subtype == "small") 
			{
			cloudAssembly.texture_sheet = "/Models/Weather/cumulus_sheet1.rgb";
			cloudAssembly.num_tex_x = 3;
			cloudAssembly.num_tex_y = 3;
			cloudAssembly.n_sprites = 7;
			cloudAssembly.min_width = 600.0;
			cloudAssembly.max_width = 900.0;
			cloudAssembly.min_height = 600.0;
			cloudAssembly.max_height = 900.0;
			cloudAssembly.min_cloud_width = 1300;
			cloudAssembly.min_cloud_height = 1300;
			cloudAssembly.bottom_shade = 0.4;
			}
		else
			{
			if (rand() > 0.66)
				{
				cloudAssembly.texture_sheet = "/Models/Weather/congestus_sheet1.rgb";
				cloudAssembly.num_tex_x = 1;
				cloudAssembly.num_tex_y = 3;
				cloudAssembly.min_width = 1900.0;
				cloudAssembly.max_width = 2100.0;
				cloudAssembly.min_height = 1000.0;
				cloudAssembly.max_height = 1100.0;	
				cloudAssembly.n_sprites = 3;	
				cloudAssembly.bottom_shade = 0.5;
				cloudAssembly.min_cloud_width = 3500.0;	
				cloudAssembly.min_cloud_height = 1600.0;
				}
			else if (rand() > 0.33)
				{
				cloudAssembly.texture_sheet = "/Models/Weather/congestus_sheet2.rgb";
				cloudAssembly.num_tex_x = 1;
				cloudAssembly.num_tex_y = 2;
				cloudAssembly.min_width = 1900.0;
				cloudAssembly.max_width = 2000.0;
				cloudAssembly.min_height = 1000.0;
				cloudAssembly.max_height = 1100.0;	
				cloudAssembly.n_sprites = 3;	
				cloudAssembly.bottom_shade = 0.4;
				cloudAssembly.min_cloud_width = 3500.0;
				cloudAssembly.min_cloud_height = 1600.0;	
				}	
			else 
				{
				cloudAssembly.texture_sheet = "/Models/Weather/cumulus_sheet1.rgb";
				cloudAssembly.num_tex_x = 3;
				cloudAssembly.num_tex_y = 3;
				cloudAssembly.min_width = 800.0;
				cloudAssembly.max_width = 1000.0;
				cloudAssembly.min_height = 800.0;
				cloudAssembly.max_height = 1000.0;	
				cloudAssembly.n_sprites = 5;	
				cloudAssembly.bottom_shade = 0.4;
				cloudAssembly.min_cloud_width = 3000.0;
				cloudAssembly.min_cloud_height = 1100.0;	
				}	
			}
			

		cloudAssembly.z_scale = 1.0;

		#signal that new routines are used
		path = "new";
		

	
	}
else if (type == "Cumulus (whisp)"){

	
	cloudAssembly = local_weather.cloud.new(type, subtype);

	var mult = 1.0;

	# characterize the basic texture sheet
	cloudAssembly.texture_sheet = "/Models/Weather/altocumulus_sheet1.rgb";
	cloudAssembly.num_tex_x = 3;
	cloudAssembly.num_tex_y = 3;
	
	#characterize the cloud
	cloudAssembly.bottom_shade = 0.8;
	cloudAssembly.n_sprites = 4;
	cloudAssembly.min_width = 400.0 * mult;
	cloudAssembly.max_width = 600.0 * mult;
	cloudAssembly.min_height = 400.0 * mult;
	cloudAssembly.max_height = 600.0 * mult;
	cloudAssembly.min_cloud_width = 800;
	cloudAssembly.min_cloud_height = 800;
	cloudAssembly.z_scale = 1.0;

	#signal that new routines are used
	path = "new";
	
	
	}
else if (type == "Cumulus bottom"){

	cloudAssembly = local_weather.cloud.new(type, subtype);

	var mult = 1.0;

	# characterize the basic texture sheet
	cloudAssembly.texture_sheet = "/Models/Weather/cumulus_bottom_sheet1.rgb";
	cloudAssembly.num_tex_x = 1;
	cloudAssembly.num_tex_y = 1;
	
	#characterize the cloud
	cloudAssembly.bottom_shade = 0.4;
	cloudAssembly.n_sprites = 4;
	cloudAssembly.min_width = 600.0 * mult;
	cloudAssembly.max_width = 800.0 * mult;
	cloudAssembly.min_height = 600.0 * mult;
	cloudAssembly.max_height = 800.0 * mult;
	cloudAssembly.min_cloud_width = 1200 * mult * mult;
	cloudAssembly.min_cloud_height = 800 * mult * mult;
	cloudAssembly.z_scale = 0.6;

	#signal that new routines are used
	path = "new";
		
	}
else if (type == "Congestus bottom"){

	cloudAssembly = local_weather.cloud.new(type, subtype);

	var mult = 1.0;

	# characterize the basic texture sheet
	cloudAssembly.texture_sheet = "/Models/Weather/cumulus_bottom_sheet1.rgb";
	cloudAssembly.num_tex_x = 1;
	cloudAssembly.num_tex_y = 1;
	
	#characterize the cloud
	cloudAssembly.bottom_shade = 0.4;
	cloudAssembly.n_sprites = 4;
	cloudAssembly.min_width = 1100.0 * mult;
	cloudAssembly.max_width = 1400.0 * mult;
	cloudAssembly.min_height = 1100.0 * mult;
	cloudAssembly.max_height = 1400.0 * mult;
	cloudAssembly.min_cloud_width = 1600 * mult * mult;
	cloudAssembly.min_cloud_height = 1200 * mult * mult;
	cloudAssembly.z_scale = 0.4;

	#signal that new routines are used
	path = "new";
	
	}
else if (type == "Stratocumulus bottom"){

	cloudAssembly = local_weather.cloud.new(type, subtype);

	# characterize the basic texture sheet
	cloudAssembly.texture_sheet = "/Models/Weather/cumulus_bottom_sheet1.rgb";
	cloudAssembly.num_tex_x = 1;
	cloudAssembly.num_tex_y = 1;
	
	#characterize the cloud
	cloudAssembly.bottom_shade = 0.7;
	cloudAssembly.n_sprites = 3;
	cloudAssembly.min_width = 1200.0;
	cloudAssembly.max_width = 1600.0;
	cloudAssembly.min_height = 1200.0 ;
	cloudAssembly.max_height = 1600.0;
	cloudAssembly.min_cloud_width = 2000 ;
	cloudAssembly.min_cloud_height = 1700;
	cloudAssembly.z_scale = 0.4;

	#signal that new routines are used
	path = "new";
	
	}
else if (type == "Cumulonimbus (cloudlet)"){

	cloudAssembly = local_weather.cloud.new(type, subtype);

	# characterize the basic texture sheet
				

	cloudAssembly.num_tex_x = 2;
	cloudAssembly.num_tex_y = 2;
		
	if (rand() < 0.5)
		{cloudAssembly.texture_sheet = "/Models/Weather/cumulonimbus_sheet2.rgb";}			
	else
		{cloudAssembly.texture_sheet = "/Models/Weather/cumulonimbus_sheet1.rgb";}
		
	var mult = 1.0;
	if (subtype == "small") {mult = 0.7;}

	#characterize the cloud
	cloudAssembly.bottom_shade = 0.6;
	cloudAssembly.n_sprites = 5;			
	cloudAssembly.min_width = 1700.0 * mult;
	cloudAssembly.max_width = 2200.0 * mult;
	cloudAssembly.min_height = 1700.0 * mult;
	cloudAssembly.max_height = 2200.0 * mult;
	cloudAssembly.min_cloud_width = 3500.0 * mult;
	cloudAssembly.min_cloud_height = 3500.0 * mult;
	cloudAssembly.z_scale = 1.0;

	#signal that new routines are used
	path = "new";
	}

else if (type == "Altocumulus"){
		
	cloudAssembly = local_weather.cloud.new(type, subtype);

	var mult = 1.0;
	if (subtype == "small") {mult = 0.7;}
	else {mult = 1.0;}

	# characterize the basic texture sheet
	cloudAssembly.texture_sheet = "/Models/Weather/altocumulus_sheet1.rgb";
	cloudAssembly.num_tex_x = 3;
	cloudAssembly.num_tex_y = 3;
	
	#characterize the cloud
	cloudAssembly.bottom_shade = 0.7;
	cloudAssembly.n_sprites = 6;
	cloudAssembly.min_width = 40.0 * mult;
	cloudAssembly.max_width = 600.0 * mult;
	cloudAssembly.min_height = 400.0 * mult;
	cloudAssembly.max_height = 600.0 * mult;
	cloudAssembly.min_cloud_width = 1000 * mult * mult;
	cloudAssembly.min_cloud_height = 1000 * mult * mult;
	cloudAssembly.z_scale = 0.8;

	#signal that new routines are used
	path = "new";
	}

else if (type == "Stratus (structured)"){
		
	cloudAssembly = local_weather.cloud.new(type, subtype);

	var mult = 1.0;
	if (subtype == "small") {mult = 0.7;}
	else {mult = 1.0;}

	# characterize the basic texture sheet
	cloudAssembly.texture_sheet = "/Models/Weather/altocumulus_sheet1.rgb";
	cloudAssembly.num_tex_x = 3;
	cloudAssembly.num_tex_y = 3;
	
	#characterize the cloud
	cloudAssembly.bottom_shade = 0.4;
	# cloudAssembly.n_sprites = 25;
	cloudAssembly.n_sprites = 12;
	cloudAssembly.min_width = 1700.0 * mult;
	cloudAssembly.max_width = 2500.0 * mult;
	cloudAssembly.min_height = 1700.0 * mult;
	cloudAssembly.max_height = 2500.0 * mult;
	cloudAssembly.min_cloud_width = 3200.0 * mult * mult;
	cloudAssembly.min_cloud_height = 500.0 * mult * mult + cloudAssembly.max_height;
	cloudAssembly.z_scale = 0.3;

	#signal that new routines are used
	path = "new";
	}
	
else if (type == "Stratus structured CS"){
		
	cloudAssembly = local_weather.cloud.new(type, subtype);

	var mult = 1.0;
	
	mult = mult * local_weather.cloud_size_scale;

	# characterize the basic texture sheet
	cloudAssembly.texture_sheet = "/Models/Weather/altocumulus_sheet1.rgb";
	cloudAssembly.num_tex_x = 3;
	cloudAssembly.num_tex_y = 3;
	
	#characterize the cloud
	cloudAssembly.bottom_shade = 0.4;
	cloudAssembly.n_sprites = 6;
	cloudAssembly.min_width = 1000.0 * mult;
	cloudAssembly.max_width = 1000.0 * mult;
	cloudAssembly.min_height = 1000.0 * mult;
	cloudAssembly.max_height = 1000.0 * mult;
	cloudAssembly.min_cloud_width = 1305 * mult;
	cloudAssembly.min_cloud_height = 1305.0 * mult;
	cloudAssembly.z_scale = 0.3;

	#signal that new routines are used
	path = "new";
	}	
	
else if (type == "Altocumulus perlucidus"){

	# new code
	cloudAssembly = local_weather.cloud.new(type, subtype);

	var mult = 1.0;
	if (subtype == "small") {mult = 0.7;}
	else if (subtype == "huge") {mult = 1.5;}

	# characterize the basic texture sheet
	cloudAssembly.texture_sheet = "/Models/Weather/altocumulus_sheet1.rgb";
	cloudAssembly.num_tex_x = 3;
	cloudAssembly.num_tex_y = 3;
	
	#characterize the cloud
	cloudAssembly.bottom_shade = 0.7;
	cloudAssembly.n_sprites = 25;
	cloudAssembly.min_width = 1700.0 * mult;
	cloudAssembly.max_width = 2500.0 * mult;
	cloudAssembly.min_height = 1700.0 * mult;
	cloudAssembly.max_height = 2500.0 * mult;
	cloudAssembly.min_cloud_width = 3200.0 * mult * mult;
	cloudAssembly.min_cloud_height = 500.0 * mult * mult + cloudAssembly.max_height;
	cloudAssembly.z_scale = 0.2;

	#signal that new routines are used
	path = "new";
	}
else if ((type == "Cumulonimbus") or (type == "Cumulonimbus (rain)")) {
	if (subtype == "small") {
		if (rn > 0.5) {path = "Models/Weather/cumulonimbus_small1.xml";}
		else  {path = "Models/Weather/cumulonimbus_small2.xml";}
		}	
	else if (subtype == "large") {
		if (rn > 0.5) {path = "Models/Weather/cumulonimbus_small1.xml";}
		else  {path = "Models/Weather/cumulonimbus_small2.xml";}
		}
	}	
else if (type == "Cirrus") {
	if (subtype == "large") {
		if (rn > 0.916) {path = "Models/Weather/cirrus1.xml";}
		else if (rn > 0.833) {path = "Models/Weather/cirrus2.xml";}
		else if (rn > 0.75) {path = "Models/Weather/cirrus3.xml";}
		else if (rn > 0.666) {path = "Models/Weather/cirrus4.xml";}
		else if (rn > 0.583) {path = "Models/Weather/cirrus5.xml";}
		else if (rn > 0.500) {path = "Models/Weather/cirrus6.xml";}
		else if (rn > 0.416) {path = "Models/Weather/cirrus7.xml";}
		else if (rn > 0.333) {path = "Models/Weather/cirrus8.xml";}
		else if (rn > 0.250) {path = "Models/Weather/cirrus9.xml";}
		else if (rn > 0.166) {path = "Models/Weather/cirrus10.xml";}
		else if (rn > 0.083) {path = "Models/Weather/cirrus11.xml";}
		else  {path = "Models/Weather/cirrus12.xml";}
		}	
	else if (subtype == "small") {
		if (rn > 0.75) {path = "Models/Weather/cirrus_amorphous1.xml";}
		else if (rn > 0.5) {path = "Models/Weather/cirrus_amorphous2.xml";}
		else if (rn > 0.25) {path = "Models/Weather/cirrus_amorphous3.xml";}
		else  {path = "Models/Weather/cirrus_amorphous4.xml";}
		}	
	}
else if (type == "Cirrocumulus") {
	if (subtype == "small") {
		if (rn > 0.5) {path = "Models/Weather/cirrocumulus1.xml";}
		else  {path = "Models/Weather/cirrocumulus2.xml";}
		}	
	else if (subtype == "large") {
		if (rn > 0.875) {path = "Models/Weather/cirrocumulus1.xml";}
		else if (rn > 0.750){path = "Models/Weather/cirrocumulus4.xml";}
		else if (rn > 0.625){path = "Models/Weather/cirrocumulus5.xml";}
		else if (rn > 0.500){path = "Models/Weather/cirrocumulus6.xml";}
		else if (rn > 0.385){path = "Models/Weather/cirrocumulus7.xml";}
		else if (rn > 0.250){path = "Models/Weather/cirrocumulus8.xml";}
		else if (rn > 0.125){path = "Models/Weather/cirrocumulus9.xml";}
		else {path = "Models/Weather/cirrocumulus10.xml";}
		}	
	}
else if (type=="Noctilucent") {
		if (rn>0.75) {path = "Models/Weather/noctilucent7.xml";}
		else if (rn > 0.5) {path = "Models/Weather/noctilucent8.xml";}
		else if (rn > 0.25) {path = "Models/Weather/noctilucent9.xml";}
		else  {path = "Models/Weather/noctilucent10.xml";}
	}
else if (type=="Impostor sheet") {
		if (subtype=="Nimbus") {
			if (rn>0.0) {path = "Models/Weather/impostor_nimbus.xml";}
			}
		else if (subtype=="broken") {
			if (rn>0.5) {path = "Models/Weather/impostor_broken1.xml";}
			else if (rn>0.0) {path = "Models/Weather/impostor_broken2.xml";}
			}
		else if (subtype=="scattered") {
			if (rn>0.6) {path = "Models/Weather/impostor_scattered1.xml";}
			else if (rn>0.4) {path = "Models/Weather/impostor_scattered2.xml";}
			else if (rn > 0.2) {path = "Models/Weather/impostor_few1.xml";}
			else  {path = "Models/Weather/impostor_few2.xml";}
			}	
		else if (subtype=="few") {
			if (rn>0.7) {path = "Models/Weather/impostor_few1.xml";}
			else if (rn>0.4) {path = "Models/Weather/impostor_few2.xml";}
			else if (rn>0.3) {path = "Models/Weather/impostor_scattered2.xml";}
			else {path = "void";}
			}				
	}
else if (type == "Cirrocumulus (cloudlet)") {

	cloudAssembly = local_weather.cloud.new(type, subtype);

	var mult = 1.0;
	if (subtype == "small") {mult = 0.6;}
	else if (subtype == "huge") {mult = 1.5;}

	# characterize the basic texture sheet
	cloudAssembly.texture_sheet = "/Models/Weather/cirrocumulus_sheet1.rgb";
	cloudAssembly.num_tex_x = 3;
	cloudAssembly.num_tex_y = 3;
	
	#characterize the cloud
	cloudAssembly.bottom_shade = 1.0;
	cloudAssembly.n_sprites = 8;
	cloudAssembly.min_width = 700.0 * mult;
	cloudAssembly.max_width = 1200.0 * mult;
	cloudAssembly.min_height = 700.0 * mult;
	cloudAssembly.max_height = 1200.0 * mult;
	cloudAssembly.min_cloud_width = 1500.0;
	cloudAssembly.min_cloud_height = 1300.0 * mult;
	cloudAssembly.z_scale = 0.3;

	path = "new";
	}
else if (type == "Cirrocumulus (new)") {

	cloudAssembly = local_weather.cloud.new(type, subtype);

	var mult = 1.0;
	if (subtype == "small") {mult = 0.7;}
	else {mult = 1.3;}

	# characterize the basic texture sheet
	cloudAssembly.texture_sheet = "/Models/Weather/cirrocumulus_sheet1.rgb";
	cloudAssembly.num_tex_x = 3;
	cloudAssembly.num_tex_y = 3;
	
	#characterize the cloud
	cloudAssembly.bottom_shade = 1.0;
	cloudAssembly.n_sprites = 2;
	cloudAssembly.min_width = 200.0 * mult;
	cloudAssembly.max_width = 300.0 * mult;
	cloudAssembly.min_height = 200.0 * mult;
	cloudAssembly.max_height = 300.0 * mult;
	cloudAssembly.min_cloud_width = 400.0 * mult;
	cloudAssembly.min_cloud_height = 400.0 * mult;
	cloudAssembly.z_scale = 0.5;

	#signal that new routines are used
	path = "new";		
	}

else if (type == "Fogpatch") {

	cloudAssembly = local_weather.cloud.new(type, subtype);

	var mult = 1.0;
	if (subtype == "small") {mult = 0.7;}
	else {mult = 1.0;}
	
	mult = mult * local_weather.cloud_size_scale;

	# characterize the basic texture sheet
	cloudAssembly.texture_sheet = "/Models/Weather/fogpatch_sheet1.rgb";
	cloudAssembly.num_tex_x = 1;
	cloudAssembly.num_tex_y = 1;
	
	#characterize the cloud
	cloudAssembly.bottom_shade = 1.0;
	cloudAssembly.n_sprites = 1;
	cloudAssembly.min_width = 300.0 * mult;
	cloudAssembly.max_width = 300.0 * mult;
	cloudAssembly.min_height = 300.0 * mult;
	cloudAssembly.max_height = 300.0 * mult;
	cloudAssembly.min_cloud_width = 305.0 * mult;
	cloudAssembly.min_cloud_height = 305.0 * mult;
	cloudAssembly.z_scale = 0.5;

	#signal that new routines are used
	path = "new";		
	}	
	
else if (type == "Nimbus") {
	
	cloudAssembly = local_weather.cloud.new(type, subtype);

	var mult = 1.0;
	if (subtype == "small") {mult = 0.7;}
	else {mult = 1.0;}

	# characterize the basic texture sheet
	cloudAssembly.texture_sheet = "/Models/Weather/nimbus_sheet1.rgb";
	cloudAssembly.num_tex_x = 2;
	cloudAssembly.num_tex_y = 3;
	
	#characterize the cloud
	cloudAssembly.bottom_shade = 0.6;
	#cloudAssembly.n_sprites = 10;
	cloudAssembly.n_sprites = 5;
	cloudAssembly.min_width = 2700.0 * mult;
	cloudAssembly.max_width = 3000.0 * mult;
	cloudAssembly.min_height = 2700.0 * mult;
	cloudAssembly.max_height = 3000.0 * mult;
	cloudAssembly.min_cloud_width = 3500.0 * mult;
	cloudAssembly.min_cloud_height = 3200.0 * mult;
	cloudAssembly.z_scale = 0.4;
	cloudAssembly.tracer_flag = 1;

	#signal that new routines are used
	path = "new";
	}
else if (type == "Stratus") {
		
	cloudAssembly = local_weather.cloud.new(type, subtype);

	var mult = 1.0;
	if (subtype == "small") 
		{
		mult = 0.8;
		cloudAssembly.texture_sheet = "/Models/Weather/cirrocumulus_sheet1.rgb";
		cloudAssembly.num_tex_x = 3;
		cloudAssembly.num_tex_y = 3;
		cloudAssembly.n_sprites = 10;
		cloudAssembly.z_scale = 0.6;
		}
	else 	
		{
		mult = 1.0;
		cloudAssembly.texture_sheet = "/Models/Weather/stratus_sheet1.rgb";
		cloudAssembly.num_tex_x = 3;
		cloudAssembly.num_tex_y = 2;
		#cloudAssembly.n_sprites = 10;
		cloudAssembly.n_sprites = 6;
		cloudAssembly.z_scale = 0.4;
		}
	
	#characterize the cloud
	cloudAssembly.bottom_shade = 0.4;
	cloudAssembly.min_width = 2000.0 * mult;
	cloudAssembly.max_width = 2500.0 * mult;
	cloudAssembly.min_height = 2000.0 * mult;
	cloudAssembly.max_height = 2500.0 * mult;
	cloudAssembly.min_cloud_width = 5000.0;
	cloudAssembly.min_cloud_height = 2600 * mult; #1.1 *  cloudAssembly.max_height;


	#signal that new routines are used
	path = "new";
	
	}
else if (type == "Stratus (thin)") {

	cloudAssembly = local_weather.cloud.new(type, subtype);

	var mult = 1.0;
	if (subtype == "small") 
		{
		mult = 0.5;
		cloudAssembly.texture_sheet = "/Models/Weather/cirrocumulus_sheet1.rgb";
		cloudAssembly.num_tex_x = 3;
		cloudAssembly.num_tex_y = 3;
		# cloudAssembly.n_sprites = 20;
		cloudAssembly.n_sprites = 10;
		cloudAssembly.z_scale = 0.4;
		}
	else 
		{
		mult = 1.0;
		cloudAssembly.texture_sheet = "/Models/Weather/stratus_sheet1.rgb";
		cloudAssembly.num_tex_x = 3;
		cloudAssembly.num_tex_y = 2;
		# cloudAssembly.n_sprites = 10;
		cloudAssembly.n_sprites = 6;
		cloudAssembly.z_scale = 0.3;
		}

		
	
	#characterize the cloud
	cloudAssembly.bottom_shade = 0.8;
	cloudAssembly.min_width = 1900.0 * mult;
	cloudAssembly.max_width = 2400.0 * mult;
	cloudAssembly.min_height = 1900.0 * mult;
	cloudAssembly.max_height = 2400.0 * mult;
	cloudAssembly.min_cloud_width = 4200.0;		
	cloudAssembly.min_cloud_height = 2500.0 * mult;


	#signal that new routines are used
	path = "new";
		
	
	}
else if (type == "Cirrostratus") {
		
	cloudAssembly = local_weather.cloud.new(type, subtype);

	var mult = 1.0;
	if (subtype == "small") {mult = 0.7;}
	else {mult = 1.0;}

	# characterize the basic texture sheet
	cloudAssembly.texture_sheet = "/Models/Weather/cirrostratus_sheet1.rgb";
	cloudAssembly.num_tex_x = 2;
	cloudAssembly.num_tex_y = 2;
	
	#characterize the cloud
	cloudAssembly.bottom_shade = 1.0;
	cloudAssembly.n_sprites = 4;
	cloudAssembly.min_width = 3500.0 * mult;
	cloudAssembly.max_width = 4000.0 * mult;
	cloudAssembly.min_height = 3500.0 * mult;
	cloudAssembly.max_height = 4000.0 * mult;
	cloudAssembly.min_cloud_width = 8000.0;
	cloudAssembly.min_cloud_height = 50.0;
	cloudAssembly.z_scale = 0.3;

	#signal that new routines are used
	path = "new";
	
	}
else if (type == "Cirrostratus (small)") {
		
	cloudAssembly = local_weather.cloud.new(type, subtype);

	var mult = 1.0;
	if (subtype == "small") {mult = 0.45;}
	else {mult = 0.7;}

	# characterize the basic texture sheet
	cloudAssembly.texture_sheet = "/Models/Weather/cirrostratus_sheet1.rgb";
	cloudAssembly.num_tex_x = 2;
	cloudAssembly.num_tex_y = 2;
	
	#characterize the cloud
	cloudAssembly.bottom_shade = 1.0;
	cloudAssembly.n_sprites = 2;
	cloudAssembly.min_width = 3500.0 * mult;
	cloudAssembly.max_width = 4000.0 * mult;
	cloudAssembly.min_height = 3500.0 * mult;
	cloudAssembly.max_height = 4000.0 * mult;
	cloudAssembly.min_cloud_width = 4500.0 * mult;
	cloudAssembly.min_cloud_height = 4500.0 * mult;
	cloudAssembly.z_scale = 0.5;

	#signal that new routines are used
	path = "new";
	
	}	
	
else if (type == "Fog (thin)") {
	if (subtype == "small") {
		if (rn > 0.8) {path = "Models/Weather/stratus_thin1.xml";}
		else if (rn > 0.6) {path = "Models/Weather/stratus_thin2.xml";}
		else if (rn > 0.4) {path = "Models/Weather/stratus_thin3.xml";}
		else if (rn > 0.2) {path = "Models/Weather/stratus_thin4.xml";}
		else  {path = "Models/Weather/stratus_thin5.xml";}
		}	
	else if (subtype == "large") {
		if (rn > 0.8) {path = "Models/Weather/stratus_thin1.xml";}
		else if (rn > 0.6) {path = "Models/Weather/stratus_thin2.xml";}
		else if (rn > 0.4) {path = "Models/Weather/stratus_thin3.xml";}
		else if (rn > 0.2) {path = "Models/Weather/stratus_thin4.xml";}
		else  {path = "Models/Weather/stratus_thin5.xml";}
		}	
	}
else if (type == "Fog (thick)") {

	cloudAssembly = local_weather.cloud.new(type, subtype);

	var mult = 1.0;
	if (subtype == "small") 
		{
		mult = 0.8;
		cloudAssembly.texture_sheet = "/Models/Weather/stratus_sheet1.rgb";
		cloudAssembly.num_tex_x = 3;
		cloudAssembly.num_tex_y = 2;
		cloudAssembly.n_sprites = 5;
		cloudAssembly.z_scale = 1.0;
		}
	else 	
		{
		mult = 1.0;
		cloudAssembly.texture_sheet = "/Models/Weather/stratus_sheet1.rgb";
		cloudAssembly.num_tex_x = 3;
		cloudAssembly.num_tex_y = 2;
		cloudAssembly.n_sprites = 5;
		cloudAssembly.z_scale = 1.0;
		}
	
	#characterize the cloud
	cloudAssembly.bottom_shade = 0.4;
	cloudAssembly.min_width = 2000.0 * mult;
	cloudAssembly.max_width = 2500.0 * mult;
	cloudAssembly.min_height = 2000.0 * mult;
	cloudAssembly.max_height = 2500.0 * mult;
	cloudAssembly.min_cloud_width = 5000.0;
	cloudAssembly.min_cloud_height = 1.1 *  cloudAssembly.max_height;


	#signal that new routines are used
	path = "new";
	}
else if (type == "Test") {path="Models/Weather/single_cloud.xml";}
else if (type == "Box_test") {
	if (subtype == "standard") {
		if (rn > 0.8) {path = "Models/Weather/cloudbox1.xml";}
		else if (rn > 0.6) {path = "Models/Weather/cloudbox2.xml";}
		else if (rn > 0.4) {path = "Models/Weather/cloudbox3.xml";}
		else if (rn > 0.2) {path = "Models/Weather/cloudbox4.xml";}
		else  {path = "Models/Weather/cloudbox5.xml";}		
		}
	else if (subtype == "core") {
		if (rn > 0.8) {path = "Models/Weather/cloudbox_core1.xml";}
		else if (rn > 0.6) {path = "Models/Weather/cloudbox_core2.xml";}
		else if (rn > 0.4) {path = "Models/Weather/cloudbox_core3.xml";}
		else if (rn > 0.2) {path = "Models/Weather/cloudbox_core4.xml";}
		else  {path = "Models/Weather/cloudbox_core5.xml";}		
		}
	else if (subtype == "bottom") {
		if (rn > 0.66) {path = "Models/Weather/cloudbox_bottom1.xml";}
		else if (rn > 0.33) {path = "Models/Weather/cloudbox_bottom2.xml";}
		else if (rn > 0.0) {path = "Models/Weather/cloudbox_bottom3.xml";}	
		}
	}
else if (type == "Cb_box") {

		cloudAssembly = local_weather.cloud.new(type, subtype);

		if (subtype == "standard")
			{
			if (rand() > 0.5) # use a Congestus texture
				{

				if (rand() > 0.5)
					{
					cloudAssembly.texture_sheet = "/Models/Weather/congestus_sheet1.rgb";
					cloudAssembly.num_tex_x = 1;
					cloudAssembly.num_tex_y = 3;
					cloudAssembly.min_width = 1300.0;
					cloudAssembly.max_width = 2000.0;
					cloudAssembly.min_height = 600.0;
					cloudAssembly.max_height = 900.0;			
					}
				else	
					{
					cloudAssembly.texture_sheet = "/Models/Weather/congestus_sheet2.rgb";
					cloudAssembly.num_tex_x = 1;
					cloudAssembly.num_tex_y = 2;
					cloudAssembly.min_width = 1200.0;
					cloudAssembly.max_width = 1800.0;
					cloudAssembly.min_height = 700.0;
					cloudAssembly.max_height = 1000.0;			
					}

				cloudAssembly.n_sprites = 3;
				cloudAssembly.min_cloud_width = 2200.0;
				cloudAssembly.min_cloud_height = 1200.0;
				cloudAssembly.bottom_shade = 0.6;
				cloudAssembly.z_scale = 1.0;
				}
			else
				{
				# characterize the basic texture sheet
				cloudAssembly.texture_sheet = "/Models/Weather/cumulonimbus_sheet2.rgb";
				cloudAssembly.num_tex_x = 2;
				cloudAssembly.num_tex_y = 2;
		
				#characterize the cloud
				cloudAssembly.bottom_shade = 0.6;
				cloudAssembly.n_sprites = 6;
				cloudAssembly.min_width = 800.0;
				cloudAssembly.max_width = 1100.0;
				cloudAssembly.min_height = 800.0;
				cloudAssembly.max_height = 1100.0;
				cloudAssembly.min_cloud_width = 3000.0;
				cloudAssembly.min_cloud_height = 1500.0;
				cloudAssembly.z_scale = 1.0;
				

				}
			}
		else if (subtype == "core")
			{
			# characterize the basic texture sheet
			cloudAssembly.texture_sheet = "/Models/Weather/cumulonimbus_sheet1.rgb";
			cloudAssembly.num_tex_x = 2;
			cloudAssembly.num_tex_y = 2;
	
			#characterize the cloud
			cloudAssembly.bottom_shade = 0.6;
			cloudAssembly.n_sprites = 20;
			cloudAssembly.min_width = 1000.0;
			cloudAssembly.max_width = 1500.0;
			cloudAssembly.min_height = 1000.0;
			cloudAssembly.max_height = 1500.0 ;
			cloudAssembly.min_cloud_width = 3500.0;
			cloudAssembly.min_cloud_height = 2000.0;
			cloudAssembly.z_scale = 1.0;
			}
		else if (subtype == "bottom")
			{
			cloudAssembly.texture_sheet = "/Models/Weather/cumulus_bottom_sheet1.rgb";
			cloudAssembly.num_tex_x = 1;
			cloudAssembly.num_tex_y = 1;
	
			#characterize the cloud
			cloudAssembly.bottom_shade = 0.4;
			cloudAssembly.n_sprites = 4;
			cloudAssembly.min_width = 1100.0;
			cloudAssembly.max_width = 1400.0;
			cloudAssembly.min_height = 1100.0;
			cloudAssembly.max_height = 1400.0;
			cloudAssembly.min_cloud_width = 1600;
			cloudAssembly.min_cloud_height = 1200;
			cloudAssembly.z_scale = 0.4;

			}

		#signal that new routines are used
		path = "new";

	
	}


else {print("Cloud type ", type, " subtype ",subtype, " not available!");}

return path;
}

# hash for assembling hard-coded clouds

var cloudAssembly = {};

