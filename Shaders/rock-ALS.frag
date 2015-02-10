// -*-C++-*-

// written by Thorsten Renk, Oct 2011, based on default.frag
// Ambient term comes in gl_Color.rgb.
varying vec4 diffuse_term;
varying vec3 normal;
varying vec3 relPos;
varying vec2 rawPos;
varying vec3 worldPos;
varying vec3 ecViewdir;



varying float steepness;
varying vec2 grad_dir;


uniform float visibility;
uniform float avisibility;
uniform float scattering;
uniform float terminator;
uniform float terrain_alt; 
uniform float hazeLayerAltitude;
uniform float overcast;
uniform float eye_alt;
uniform float snowlevel;
uniform float dust_cover_factor;
uniform float lichen_cover_factor;
uniform float wetness;
uniform float fogstructure;
uniform float snow_thickness_factor;
uniform float cloud_self_shading;
uniform float contrast;
uniform float air_pollution;
uniform float intrinsic_wetness;
uniform float transition_model;
uniform float overlay_bias;
uniform float crack_depth;
uniform float crack_pattern_stretch;
uniform float grain_fade_power;
uniform float rock_brightness;
uniform float overlay_alpha;
uniform float dust_resistance;
uniform float slopeline_strength;
uniform float landing_light1_offset;
uniform float landing_light2_offset;
uniform float osg_SimulationTime;

uniform vec3 base_color;
uniform vec3 overlay_color;

uniform int wind_effects;
uniform int cloud_shadow_flag;
uniform int rock_strata;
uniform int use_searchlight;
uniform int use_landing_light;
uniform int use_alt_landing_light;

const float EarthRadius = 5800000.0;
const float terminator_width = 200000.0;

float alt;
float eShade;
float yprime_alt;
float mie_angle;

float shadow_func (in float x, in float y, in float noise, in float dist);
float Noise2D(in vec2 coord, in float wavelength);
float Noise3D(in vec3 coord, in float wavelength);
float VoronoiNoise2D(in vec2 coord, in float wavelength, in float xrand, in float yrand);	
float SlopeLines2D(in vec2 coord, in vec2 gradDir, in float wavelength, in float steepness);
float Strata3D(in vec3 coord, in float wavelength, in float variation);
float fog_func (in float targ, in float alt);
float rayleigh_in_func(in float dist, in float air_pollution, in float avisibility, in float eye_alt, in float vertex_alt);
float alt_factor(in float eye_alt, in float vertex_alt);
float light_distance_fading(in float dist);
float fog_backscatter(in float avisibility);

vec3 rayleigh_out_shift(in vec3 color, in float outscatter);
vec3 get_hazeColor(in float light_arg);
vec3 searchlight();
vec3 landing_light(in float offset);

float light_func (in float x, in float a, in float b, in float c, in float d, in float e)
{
x = x - 0.5;

// use the asymptotics to shorten computations
if (x > 30.0) {return e;}
if (x < -15.0) {return 0.0;}

return e / pow((1.0 + a * exp(-b * (x-c)) ),(1.0/d));
}


// a fade function for procedural scales which are smaller than a pixel

float detail_fade (in float scale, in float angle, in float dist)
{
float fade_dist = 2000.0 * scale * angle/max(pow(steepness,4.0), 0.1);

return 1.0 - smoothstep(0.5 * fade_dist, fade_dist, dist);
}



void main()
{


yprime_alt = diffuse_term.a;
//diffuse_term.a = 1.0;
mie_angle = gl_Color.a;
float effective_scattering = min(scattering, cloud_self_shading);

// distance to fragment
float dist = length(relPos);
// angle of view vector with horizon
float ct = dot(vec3(0.0, 0.0, 1.0), relPos)/dist;
// float altitude of fragment above sea level
float msl_altitude = (relPos.z + eye_alt);


  vec3 shadedFogColor = vec3(0.55, 0.67, 0.88);
// this is taken from default.frag
    vec3 n;
    float NdotL, NdotHV, fogFactor;
    vec4 color = gl_Color;
    color.a = 1.0;
    vec3 lightDir = gl_LightSource[0].position.xyz;
    vec3 halfVector = normalize(normalize(lightDir) + normalize(ecViewdir));
    vec4 texel;
    vec4 snow_texel;
    vec4 detail_texel;
    vec4 mix_texel;
	vec4 grain_texel;
	vec4 dot_texel;
	vec4 gradient_texel;
	vec4 foam_texel;
    vec4 fragColor;
    vec4 specular = vec4(0.0);
    float intensity;
    


// Perlin noise

float noise_100m = Noise2D(rawPos.xy,100.0);
float noise_50m = Noise2D(rawPos.xy, 50.0);
float noise_25m = Noise2D(rawPos.xy, 25.0);
float noise_10m = Noise2D(rawPos.xy, 10.0);
float noise_5m = Noise2D(rawPos.xy ,5.0);
float noise_2m = Noise2D(rawPos.xy ,2.0); 
float noise_1m = Noise2D(rawPos.xy ,1.0);
float noise_05m = Noise2D(rawPos.xy,0.5);
float noise_02m = Noise2D(rawPos.xy,0.2);
float noise_01m = Noise2D(rawPos.xy, 0.1);

float noisegrad_10m;
float noisegrad_5m;
float noisegrad_2m;
float noisegrad_1m;
float noisegrad_05m;
float noisegrad_02m;
float noisegrad_01m;





float noise_250m = Noise3D(worldPos.xyz,250.0);
float noise_500m = Noise3D(worldPos.xyz, 500.0);
float noise_1500m = Noise3D(worldPos.xyz, 1500.0);
float noise_2000m = Noise3D(worldPos.xyz, 2000.0);

// dot noise

float dotnoise_2m = 0.0;
float dotnoise_10m = 0.0;
float dotnoise_15m = 0.0;

float dotnoisegrad_10m;

// slope noise

float slopenoise_50m = SlopeLines2D(rawPos, grad_dir, 50.0, steepness);
float slopenoise_100m = SlopeLines2D(rawPos, grad_dir, 100.0, steepness);

float snownoise_25m = mix(noise_25m, slopenoise_50m, clamp(3.0*(1.0-steepness),0.0,1.0));
float snownoise_50m = mix(noise_50m, slopenoise_100m, clamp(3.0*(1.0-steepness),0.0,1.0));





// get the texels

    float noise_term;
    float snow_alpha;
    float local_autumn_factor; 

	// we need to fade procedural structures when they get smaller than a single pixel, for this we need
	// to know under what angle we see the surface

    float view_angle = abs(dot(normalize(normal), normalize(ecViewdir)));


	// the snow texel is generated procedurally
    if (msl_altitude +500.0 > snowlevel)
	{
	snow_texel = vec4 (0.95, 0.95, 0.95, 1.0) * (0.9 + 0.1* noise_500m + 0.1* (1.0 - noise_10m) );
	snow_texel.r = snow_texel.r * (0.9 + 0.05 * (noise_10m + noise_5m));
	snow_texel.g = snow_texel.g * (0.9 + 0.05 * (noise_10m + noise_5m));
	snow_texel.a = 1.0;
	noise_term = 0.1 * (noise_500m-0.5) ;
	noise_term = noise_term + 0.2 * (snownoise_50m -0.5) * detail_fade(50.0, view_angle, 0.5*dist) ;
	noise_term = noise_term + 0.2 * (snownoise_25m -0.5) * detail_fade(25.0, view_angle, 0.5*dist) ;
	noise_term = noise_term + 0.3 * (noise_10m -0.5) * detail_fade(10.0, view_angle, 0.8*dist) ;
	noise_term = noise_term + 0.3 * (noise_5m - 0.5) * detail_fade(5.0, view_angle, dist);
	noise_term = noise_term + 0.15 * (noise_2m -0.5) * detail_fade(2.0, view_angle, dist);
	noise_term = noise_term + 0.08 * (noise_1m -0.5) * detail_fade(1.0, view_angle, dist);
	snow_texel.a = snow_texel.a * 0.2+0.8* smoothstep(0.2,0.8, 0.3 +noise_term + snow_thickness_factor +0.0001*(msl_altitude -snowlevel) );
	}


	



   


   


   
   
   // strata noise

	float stratnoise_50m;
	float stratnoise_10m;
	
	if (rock_strata==1)
		{
		stratnoise_50m = Strata3D(vec3 (rawPos.x, rawPos.y, msl_altitude), 50.0, 0.2);
		stratnoise_10m = Strata3D(vec3 (rawPos.x, rawPos.y, msl_altitude), 10.0, 0.2);
		stratnoise_50m = mix(stratnoise_50m, 1.0, smoothstep(0.8,0.9, steepness));
		stratnoise_10m = mix(stratnoise_10m, 1.0, smoothstep(0.8,0.9, steepness));
		texel *= (0.4 + 0.4 * stratnoise_50m + 0.2 * stratnoise_10m);
		}   
   


   
	

 
 // procedural rock texture generation
 
 texel.rgb = base_color;
 
 // use powers of Perlin noise to generate the base pattern

 float grainy_noise;
 float fade_norm;
 
 float gfp = grain_fade_power;
 float gfptmp;
 
 grainy_noise = (0.5 * (1.0-slopenoise_100m) + 0.5 *noise_50m) + gfp * (0.5 * slopenoise_50m + 0.5 * noise_25m);
 fade_norm = 1.0+gfp; 
 
 gfptmp = gfp * gfp;
 grainy_noise += noise_10m * gfptmp * detail_fade(10.0, view_angle, dist) ;
 fade_norm += gfptmp * detail_fade(10.0, view_angle, dist) ;
 
 gfptmp = gfptmp * gfp;
 grainy_noise += noise_5m * gfptmp * detail_fade(5.0, view_angle, dist) ;
 fade_norm += gfptmp * detail_fade(5.0, view_angle, dist) ;
 
 gfptmp = gfptmp * gfp;
 grainy_noise += noise_2m * gfptmp * detail_fade(2.0, view_angle, dist) ;
 fade_norm += gfptmp * detail_fade(2.0, view_angle, dist) ;

 gfptmp = gfptmp * gfp;
 grainy_noise += noise_1m * gfptmp * detail_fade(1.0, view_angle, dist) ;
 fade_norm += gfptmp * detail_fade(1.0, view_angle, dist) ;
 
 gfptmp = gfptmp * gfp;
 grainy_noise += noise_05m * gfptmp * detail_fade(0.5, view_angle, dist) ;
 fade_norm += gfptmp * detail_fade(0.5, view_angle, dist) ;
 
 grainy_noise = grainy_noise/fade_norm; 
 grainy_noise = smoothstep(-0.2, 1.2, grainy_noise);
 
 // generate the crack pattern from isovalue lines of stretched Perlin noise

 float cnoise_500m = Noise2D(vec2(rawPos.x+10.0, crack_pattern_stretch * rawPos.y), 500.0);
 float cnoise_250m = Noise2D(vec2(rawPos.x+10.0, crack_pattern_stretch * rawPos.y), 250.0);
 float cnoise_100m = Noise2D(vec2(rawPos.x+10.0, crack_pattern_stretch * rawPos.y), 100.0);
 float cnoise_50m = Noise2D(vec2(rawPos.x+10.0, crack_pattern_stretch * rawPos.y), 50.0);
 float cnoise_25m = Noise2D(vec2(rawPos.x+10.0, crack_pattern_stretch * rawPos.y), 25.0);
 float cnoise_10m = Noise2D(vec2(rawPos.x+10.0, crack_pattern_stretch * rawPos.y), 10.0);
 float cnoise_5m = Noise2D(vec2(rawPos.x+10.0, crack_pattern_stretch * rawPos.y), 5.0);
 float cnoise_2m = Noise2D(vec2(rawPos.x+10.0, crack_pattern_stretch * rawPos.y), 2.0); 
 float cnoise_1m = Noise2D(vec2(rawPos.x+10.0, crack_pattern_stretch * rawPos.y), 1.0);

 float crack_noise;
 float crack_factor;
 float crack_size;
 float scrack_noise;
 float scrack_size; 
 
 crack_noise = cnoise_500m + 0.65 * cnoise_250m + 0.42 * cnoise_100m * detail_fade(50.0, view_angle, dist) ;
 crack_noise = crack_noise + 0.27 * cnoise_50m * detail_fade(25.0, view_angle, dist) ;
 crack_noise = crack_noise + 0.17 * cnoise_25m * detail_fade(10.0, view_angle, dist) ;
 crack_noise = crack_noise + 0.11 * cnoise_10m * detail_fade(5.0, view_angle, dist) ;
 crack_noise = 0.381 * crack_noise;
  

 
 scrack_noise = cnoise_10m + 0.65 * cnoise_5m * detail_fade(5.0, view_angle, dist);
 scrack_noise = scrack_noise + 0.3 * cnoise_2m + 0.1 * cnoise_1m * detail_fade(1.0, view_angle, dist);
 scrack_noise = 0.48 * scrack_noise;  

  crack_size = 0.02 +0.00001 * dist;
  crack_factor = smoothstep(0.5-crack_size,0.50,crack_noise) * (1.0-smoothstep(0.51,0.51+crack_size,crack_noise));
  //crack_factor = step(0.5-0.2*crack_size,crack_noise) * (1.0-step(0.5+0.2*crack_size,crack_noise));

  crack_size *= 0.5;
  crack_factor += smoothstep(0.42,0.42+crack_size,crack_noise) * (1.0-smoothstep(0.43,0.43+crack_size,crack_noise));

  scrack_size = crack_size * 4.0;
  crack_factor += 0.75 * smoothstep(0.5-scrack_size,0.50,scrack_noise) * (1.0-smoothstep(0.51,0.51+scrack_size,scrack_noise))* (1.0- smoothstep(250.0,1000.0,dist));


  crack_factor = crack_factor * min(1.0,0.03/crack_size);

 

// distribution of overlay color


 float overlay_noise;
 float overlay_factor;
 
 overlay_noise = 0.381 * (noise_50m + 0.65 * noise_25m + 0.42 * noise_10m + 0.27 * noise_5m + 0.17 * noise_2m + 0.11 * noise_1m);
 overlay_noise = overlay_noise + 0.1 * (smoothstep(0.8,0.9, steepness));
 
 overlay_factor = smoothstep(0.7, 0.72, overlay_noise + overlay_bias) + (1.0 - smoothstep(0.2, 0.22, overlay_noise - overlay_bias));



// merge the noise components

 //grainy_noise = grainy_noise * (1.0-crack_depth * crack_factor) + 0.5 * crack_depth * crack_factor;
 texel.rgb = ((1.0 - contrast)  + contrast * grainy_noise ) * texel.rgb;
 texel.rgb = mix(texel.rgb, overlay_color.rgb,overlay_alpha * overlay_factor);
 texel.rgb = texel.rgb * ((1.0-crack_depth) +crack_depth*(1.0-crack_factor * (0.5 + 0.5 * noise_50m) ));

 texel.rgb = texel.rgb * rock_brightness;

 texel.rgb = texel.rgb * (1.0 + 0.4 * (noise_01m-0.5) * detail_fade(0.1, view_angle, dist)) ;
 
 
const vec4 dust_color  = vec4 (0.76, 0.65, 0.45, 1.0);
const vec4 lichen_color = vec4 (0.17, 0.20, 0.06, 1.0);

// mix vegetation
float gradient_factor = smoothstep(0.5, 1.0, steepness);
texel = mix(texel, lichen_color, gradient_factor * (0.4 * lichen_cover_factor +  0.8 * lichen_cover_factor * 0.5 * (noise_10m + (1.0 - noise_5m)))  );
// mix dust
texel = mix(texel, dust_color, clamp(0.5 * dust_cover_factor *dust_resistance + 3.0 * dust_cover_factor * dust_resistance *(((noise_1500m - 0.5) * 0.125)+0.125 ) - 0.03*slopenoise_100m,0.0, 1.0) );
// mix snow
float snow_mix_factor = 0.0;
if (msl_altitude +500.0 > snowlevel)
	{
   	snow_alpha = max(1.0,smoothstep(0.75, 0.85, abs(steepness)) +crack_factor);
	snow_mix_factor = snow_texel.a* smoothstep(snowlevel, snowlevel+200.0,  snow_alpha * msl_altitude+ (noise_2000m + 0.1 * noise_10m -0.55) *400.0);
	texel = mix(texel, snow_texel, snow_mix_factor);
	}
	
 


// get distribution of water when terrain is wet

float combined_wetness = min(1.0, wetness + intrinsic_wetness);
float water_threshold1;
float water_threshold2;
float water_factor =0.0;


if ((dist < 5000.0) && (combined_wetness>0.0))
		{
		water_threshold1 = 1.0-0.5* combined_wetness;
		water_threshold2 = 1.0 - 0.3 * combined_wetness;
		water_factor = smoothstep(water_threshold1, water_threshold2 ,   (0.3 * (2.0 * (1.0-noise_10m) + (1.0 -noise_5m)) *   (1.0 - smoothstep(2000.0, 5000.0, dist))) - 5.0 * (1.0 -steepness));
	}

// darken wet terrain

    texel.rgb = texel.rgb * (1.0 - 0.6 * combined_wetness);
	


// light computations


    vec4 light_specular = gl_LightSource[0].specular;

    // If gl_Color.a == 0, this is a back-facing polygon and the
    // normal should be reversed.
    //n = (2.0 * gl_Color.a - 1.0) * normal;
    n = normal;
    n = normalize(n);

    NdotL = dot(n, lightDir);
	
	noisegrad_10m = (noise_10m - Noise2D(rawPos.xy+ 0.05 * normalize(lightDir.xy),10.0))/0.05;
	noisegrad_5m = (noise_5m - Noise2D(rawPos.xy+ 0.05 * normalize(lightDir.xy),5.0))/0.05;
	noisegrad_2m = (noise_2m - Noise2D(rawPos.xy+ 0.05 * normalize(lightDir.xy),2.0))/0.05;
	noisegrad_1m = (noise_1m - Noise2D(rawPos.xy+ 0.05 * normalize(lightDir.xy),1.0))/0.05;
	noisegrad_05m = (noise_05m - Noise2D(rawPos.xy+ 0.05 * normalize(lightDir.xy),0.5))/0.05;

	
	dotnoisegrad_10m = 0.0;//(dotnoise_10m - DotNoise2D(rawPos.xy+ 0.05 * normalize(lightDir.xy),10.0 * dot_size,0.5, 0.0))/0.05;

	
	//NdotL = NdotL + (noisegrad_10m * detail_fade(10.0, view_angle,dist) + 0.8* noisegrad_5m * detail_fade(5.0, view_angle,dist));
	//NdotL = NdotL + 0.4 * noisegrad_2m * detail_fade(2.0,view_angle,dist);
	//NdotL = NdotL + 0.2 * noisegrad_2m * detail_fade(2.0,view_angle,dist);
	//NdotL = NdotL + 0.05 * noisegrad_1m * detail_fade(1.0, view_angle,dist);
	//NdotL = NdotL + 0.02 * noisegrad_05m * detail_fade(0.5, view_angle,dist);

	//NdotL = NdotL + (1.0-snow_mix_factor) * 0.3* dot_texel.a * (0.5* dotnoisegrad_10m * detail_fade(1.0 * dot_size, view_angle, dist) +0.5 * dotnoisegrad_10m * noise_01m * detail_fade(0.1, view_angle, dist)) ;
	//NdotL = NdotL + 0.2 * grainy_noise;
	
	float snow_factor;
	float fresnel;
	
    if (NdotL > 0.0) {
	if (cloud_shadow_flag == 1) {NdotL = NdotL * shadow_func(relPos.x, relPos.y, 0.3 * noise_250m + 0.5 * noise_500m+0.2 * noise_1500m, dist);}
        color += diffuse_term * NdotL;
        NdotHV = max(dot(n, halfVector), 0.0);
		
		fresnel = 1.0 + 5.0 * (1.0-smoothstep(0.0,0.2, dot(normalize(ecViewdir),n)));
        snow_factor = 0.2 * smoothstep(0.7,0.9,snow_mix_factor) * fresnel;
		
        //if (gl_FrontMaterial.shininess > 0.0)
            specular.rgb = ((gl_FrontMaterial.specular.rgb * 0.1 + snow_factor * vec3(1.0,1.0,1.0) + (water_factor * vec3 (1.0, 1.0, 1.0)))
                            * light_specular.rgb
                            * pow(NdotHV, max(gl_FrontMaterial.shininess,4.0) + (20.0 * water_factor)));
    }
    color.a = 1.0;//diffuse_term.a;
    // This shouldn't be necessary, but our lighting becomes very
    // saturated. Clamping the color before modulating by the texture
    // is closer to what the OpenGL fixed function pipeline does.
    color = clamp(color, 0.0, 1.0);

   vec3 secondary_light = vec3 (0.0,0.0,0.0);

    if (use_searchlight == 1)
	{
	secondary_light += searchlight();
	}
    if (use_landing_light == 1)
	{
	secondary_light += landing_light(landing_light1_offset);
	}
    if (use_alt_landing_light == 1)
	{
	secondary_light += landing_light(landing_light2_offset);
	}
    color.rgb +=secondary_light * light_distance_fading(dist);


    fragColor = color * texel + specular;

float lightArg = (terminator-yprime_alt)/100000.0;	
vec3 hazeColor = get_hazeColor(lightArg);



// Rayleigh color shift due to out-scattering
    float rayleigh_length = 0.5 * avisibility * (2.5 - 1.9 * air_pollution)/alt_factor(eye_alt, eye_alt+relPos.z);
    float outscatter = 1.0-exp(-dist/rayleigh_length);
    fragColor.rgb = rayleigh_out_shift(fragColor.rgb,outscatter);

// Rayleigh color shift due to in-scattering

   float rShade = 1.0 - 0.9 * smoothstep(-terminator_width+ terminator, terminator_width + terminator, yprime_alt + 420000.0);
   float lightIntensity = length(hazeColor * effective_scattering) * rShade;
   vec3 rayleighColor = vec3 (0.17, 0.52, 0.87) * lightIntensity;
   float rayleighStrength = rayleigh_in_func(dist, air_pollution, avisibility/max(lightIntensity,0.05), eye_alt, eye_alt + relPos.z);
  fragColor.rgb = mix(fragColor.rgb, rayleighColor,rayleighStrength);


// here comes the terrain haze model


float delta_z = hazeLayerAltitude - eye_alt;

float mvisibility = min(visibility,avisibility);

if (dist > 0.04 * mvisibility) 

{

alt = eye_alt;


float transmission;
float vAltitude;
float delta_zv;
float H;
float distance_in_layer;
float transmission_arg;




// we solve the geometry what part of the light path is attenuated normally and what is through the haze layer

if (delta_z > 0.0) // we're inside the layer
	{
	if (ct < 0.0) // we look down 
		{
		distance_in_layer = dist;
		vAltitude = min(distance_in_layer,mvisibility) * ct;
  		delta_zv = delta_z - vAltitude;
		}
	else 	// we may look through upper layer edge
		{
		H = dist * ct;
		if (H > delta_z) {distance_in_layer = dist/H * delta_z;}
		else {distance_in_layer = dist;}
		vAltitude = min(distance_in_layer,visibility) * ct;
  		delta_zv = delta_z - vAltitude;	
		}
	}
  else // we see the layer from above, delta_z < 0.0
	{	
	H = dist * -ct;
	if (H  < (-delta_z)) // we don't see into the layer at all, aloft visibility is the only fading
		{
		distance_in_layer = 0.0;
		delta_zv = 0.0;
		}		
	else
		{
		vAltitude = H + delta_z;
		distance_in_layer = vAltitude/H * dist; 
		vAltitude = min(distance_in_layer,visibility) * (-ct);
		delta_zv = vAltitude;
		} 
	}
	
// blur of the haze layer edge

float blur_thickness = 50.0;
float cphi = dot(vec3(0.0, 1.0, 0.0), relPos)/dist;
float ctlayer = delta_z/dist-0.01 + 0.02 * Noise2D(vec2(cphi,1.0),0.1) -0.01;
float ctblur = 	0.035 ;

float blur_dist;

if (abs(delta_z) < 400.0)
	{
	blur_dist = dist * (1.0-smoothstep(0.0,300.0,-delta_z)) * smoothstep(-400.0,-200.0, -delta_z);
	blur_dist = blur_dist * smoothstep(ctlayer-4.0*ctblur, ctlayer-ctblur, ct) * (1.0-smoothstep(ctlayer+0.5*ctblur, ctlayer+ctblur, ct));
	distance_in_layer = max(distance_in_layer, blur_dist);
	}


// ground haze cannot be thinner than aloft visibility in the model,
// so we need to use aloft visibility otherwise


transmission_arg = (dist-distance_in_layer)/avisibility;


float eqColorFactor;



if (visibility < avisibility)
	{
	transmission_arg = transmission_arg + (distance_in_layer/(1.0 * visibility + 1.0 * visibility * fogstructure * 0.06 * (noise_1500m + noise_2000m -1.0) ));
	// this combines the Weber-Fechner intensity
	eqColorFactor = 1.0 - 0.1 * delta_zv/visibility - (1.0 - effective_scattering);
	}
else 
	{
	transmission_arg = transmission_arg + (distance_in_layer/(1.0 * avisibility + 1.0 * avisibility * fogstructure * 0.06 * (noise_1500m + noise_2000m  - 1.0) ));
	// this combines the Weber-Fechner intensity
	eqColorFactor = 1.0 - 0.1 * delta_zv/avisibility - (1.0 - effective_scattering);
	}



transmission =  fog_func(transmission_arg, alt);

// there's always residual intensity, we should never be driven to zero
if (eqColorFactor < 0.2) eqColorFactor = 0.2;







// now dim the light for haze
eShade = 1.0 - 0.9 * smoothstep(-terminator_width+ terminator, terminator_width + terminator, yprime_alt);

// Mie-like factor

	if (lightArg < 10.0)
		{
		intensity = length(hazeColor);
		float mie_magnitude = 0.5 * smoothstep(350000.0, 150000.0, terminator-sqrt(2.0 * EarthRadius * terrain_alt));
		hazeColor = intensity * ((1.0 - mie_magnitude) + mie_magnitude * mie_angle) * normalize(mix(hazeColor,  vec3 (0.5, 0.58, 0.65), mie_magnitude * (0.5 - 0.5 * mie_angle)) ); 
		}

intensity = length(hazeColor);

if (intensity > 0.0) // this needs to be a condition, because otherwise hazeColor doesn't come out correctly
{
	

	// high altitude desaturation of the haze color
	hazeColor = intensity * normalize (mix(hazeColor, intensity * vec3 (1.0,1.0,1.0), 0.7* smoothstep(5000.0, 50000.0, alt)));

	// blue hue of haze
	hazeColor.x = hazeColor.x * 0.83;
	hazeColor.y = hazeColor.y * 0.9; 


	// additional blue in indirect light
	float fade_out = max(0.65 - 0.3 *overcast, 0.45);
	intensity = length(hazeColor);
	hazeColor = intensity * normalize(mix(hazeColor,  1.5* shadedFogColor, 1.0 -smoothstep(0.25, fade_out,eShade) )); 

	// change haze color to blue hue for strong fogging
	hazeColor = intensity * normalize(mix(hazeColor,  shadedFogColor, (1.0-smoothstep(0.5,0.9,eqColorFactor)))); 

	

	// reduce haze intensity when looking at shaded surfaces, only in terminator region
	float shadow = mix( min(1.0 + dot(n,lightDir),1.0), 1.0, 1.0-smoothstep(0.1, 0.4, transmission));
	hazeColor = mix(shadow * hazeColor, hazeColor, 0.3 + 0.7* smoothstep(250000.0, 400000.0, terminator));
	}

// don't let the light fade out too rapidly
lightArg = (terminator + 200000.0)/100000.0;
float minLightIntensity = min(0.2,0.16 * lightArg + 0.5);
vec3 minLight = minLightIntensity * vec3 (0.2, 0.3, 0.4);

hazeColor.rgb *= eqColorFactor * eShade;
hazeColor.rgb = max(hazeColor.rgb, minLight.rgb);


fragColor.rgb = mix(hazeColor + secondary_light * fog_backscatter(mvisibility), fragColor.rgb,transmission);

}

gl_FragColor = fragColor;


}

