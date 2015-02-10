// -*-C++-*-

// written by Thorsten Renk, Oct 2011, based on default.frag



varying vec3 relPos;


uniform sampler2D texture;


varying float yprime_alt;

uniform float visibility;
uniform float avisibility;
uniform float scattering;
uniform float ground_scattering;
uniform float cloud_self_shading;
uniform float terminator;
uniform float terrain_alt; 
uniform float hazeLayerAltitude;
uniform float overcast;
uniform float eye_alt;
uniform float dust_cover_factor;
uniform float air_pollution;
uniform float landing_light1_offset;
uniform float landing_light2_offset;

uniform int use_searchlight;
uniform int use_landing_light;
uniform int use_alt_landing_light;
uniform int quality_level;
uniform int tquality_level;


const float EarthRadius = 5800000.0;
const float terminator_width = 200000.0;

float alt;
float mie_angle;


float light_distance_fading(in float dist);
float fog_backscatter(in float avisibility);
float rayleigh_in_func(in float dist, in float air_pollution, in float avisibility, in float eye_alt, in float vertex_alt);

vec3 searchlight();
vec3 landing_light(in float offset);
vec3 get_hazeColor(in float light_arg);





float tree_fog_func (in float targ)
{


float fade_mix;

// for large altitude > 30 km, we switch to some component of quadratic distance fading to
// create the illusion of improved visibility range

targ = 1.25 * targ * smoothstep(0.07,0.1,targ); // need to sync with the distance to which terrain is drawn


if (alt < 30000.0)
	{return exp(-targ - targ * targ * targ * targ);}
else if (alt < 50000.0)
	{
	fade_mix = (alt - 30000.0)/20000.0;
	return fade_mix * exp(-targ*targ - pow(targ,4.0)) + (1.0 - fade_mix) * exp(-targ - pow(targ,4.0));	
	}
else 
	{
	return exp(- targ * targ - pow(targ,4.0));
	}

}

float rand2D(in vec2 co){
    return fract(sin(dot(co.xy ,vec2(12.9898,78.233))) * 43758.5453);
}


float simple_interpolate(in float a, in float b, in float x)
{
return a + smoothstep(0.0,1.0,x) * (b-a);
}

float interpolatedNoise2D(in float x, in float y)
{
      float integer_x    = x - fract(x);
      float fractional_x = x - integer_x;

      float integer_y    = y - fract(y);
      float fractional_y = y - integer_y;

      float v1 = rand2D(vec2(integer_x, integer_y));
      float v2 = rand2D(vec2(integer_x+1.0, integer_y));
      float v3 = rand2D(vec2(integer_x, integer_y+1.0));
      float v4 = rand2D(vec2(integer_x+1.0, integer_y +1.0));

      float i1 = simple_interpolate(v1 , v2 , fractional_x);
      float i2 = simple_interpolate(v3 , v4 , fractional_x);

      return simple_interpolate(i1 , i2 , fractional_y);
}



float Noise2D(in vec2 coord, in float wavelength)
{
return interpolatedNoise2D(coord.x/wavelength, coord.y/wavelength);

}

void main()
{


  vec3 shadedFogColor = vec3(0.55, 0.67, 0.88);



  vec3 lightDir = gl_LightSource[0].position.xyz;
  float intensity;

  mie_angle = gl_Color.a;
  vec4 texel = texture2D(texture, gl_TexCoord[0].st);

  float effective_scattering = min(scattering, cloud_self_shading);
  float dist = length(relPos);

  if (quality_level > 3)
	{
	// mix dust
    	vec4 dust_color = vec4 (0.76, 0.71, 0.56, texel.a);

    	texel = mix(texel, dust_color, clamp(0.6 * dust_cover_factor ,0.0, 1.0) );
	}


// ALS secondary light sources

    vec3 secondary_light = vec3 (0.0,0.0,0.0);

    if ((quality_level>5) && (tquality_level>5))
    {
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
    }

   vec4 fragColor = vec4 (gl_Color.rgb +secondary_light * light_distance_fading(dist),1.0) * texel;




   float lightArg = (terminator-yprime_alt)/100000.0;

    vec3 hazeColor = get_hazeColor(lightArg);

  

// Rayleigh color shift due to in-scattering

    if ((quality_level > 5) && (tquality_level > 5))
    	{
	float rShade = 1.0 - 0.9 * smoothstep(-terminator_width+ terminator, terminator_width + terminator, yprime_alt + 420000.0);
	float lightIntensity = length(hazeColor * effective_scattering) * rShade;
	vec3 rayleighColor = vec3 (0.17, 0.52, 0.87) * lightIntensity;
   	float rayleighStrength = rayleigh_in_func(dist, air_pollution, avisibility/max(lightIntensity,0.05), eye_alt, eye_alt + relPos.z);
  	fragColor.rgb = mix(fragColor.rgb, rayleighColor,rayleighStrength);
	}



// here comes the terrain haze model


float delta_z = hazeLayerAltitude - eye_alt;
float mvisibility = min(visibility,avisibility);

if (dist > max(40.0, 0.07 * mvisibility)) 
{

alt = eye_alt;


float transmission;
float vAltitude;
float delta_zv;
float H;
float distance_in_layer;
float transmission_arg;

// angle with horizon
float ct = dot(vec3(0.0, 0.0, 1.0), relPos)/dist;


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
float ctlayer; 
float ctblur = 	0.035 ;

float blur_dist;

if ((abs(delta_z) < 400.0)&&(quality_level>5)&&(tquality_level>5))
	{
	ctlayer = delta_z/dist-0.01 + 0.02 * Noise2D(vec2(cphi,1.0),0.1) -0.01;
	blur_dist = dist * (1.0-smoothstep(0.0,300.0,-delta_z)) * smoothstep(-400.0,-200.0, -delta_z);
	blur_dist = blur_dist * smoothstep(ctlayer-4.0*ctblur, ctlayer-ctblur, ct) * (1.0-smoothstep(ctlayer+0.5*ctblur, ctlayer+ctblur, ct));
	distance_in_layer = max(distance_in_layer, blur_dist);
	}

// ground haze cannot be thinner than aloft visibility in the model,
// so we need to use aloft visibility otherwise


transmission_arg = (dist-distance_in_layer)/avisibility;


float eqColorFactor;

//float scattering = ground_scattering + (1.0 - ground_scattering) * smoothstep(hazeLayerAltitude -100.0, hazeLayerAltitude + 100.0, relPos.z + eye_alt);

if (visibility < avisibility)
	{
	transmission_arg = transmission_arg + (distance_in_layer/visibility);
	// this combines the Weber-Fechner intensity
	eqColorFactor = 1.0 - 0.1 * delta_zv/visibility - (1.0 -effective_scattering);

	}
else 
	{
	transmission_arg = transmission_arg + (distance_in_layer/avisibility);
	// this combines the Weber-Fechner intensity
	eqColorFactor = 1.0 - 0.1 * delta_zv/avisibility - (1.0 -effective_scattering);
	}



transmission =  tree_fog_func(transmission_arg);

// there's always residual intensity, we should never be driven to zero
if (eqColorFactor < 0.2) eqColorFactor = 0.2;





// now dim the light for haze
float eShade = 1.0 - 0.9 * smoothstep(-terminator_width+ terminator, terminator_width + terminator, yprime_alt);

// Mie-like factor

if (lightArg < 10.0)
	{intensity = length(hazeColor);
	float mie_magnitude = 0.5 * smoothstep(350000.0, 150000.0, terminator-sqrt(2.0 * EarthRadius * terrain_alt));
	hazeColor = intensity * ((1.0 - mie_magnitude) + mie_magnitude * mie_angle) * normalize(mix(hazeColor,  vec3 (0.5, 0.58, 0.65), mie_magnitude * (0.5 - 0.5 * mie_angle)) ); 
	}

// high altitude desaturation of the haze color

intensity = length(hazeColor);
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


// don't let the light fade out too rapidly
lightArg = (terminator + 200000.0)/100000.0;
float minLightIntensity = min(0.2,0.16 * lightArg + 0.5);
vec3 minLight = minLightIntensity * vec3 (0.2, 0.3, 0.4);

hazeColor.rgb *= eqColorFactor * eShade;
hazeColor.rgb = max(hazeColor.rgb, minLight.rgb);

// determine the right mix of transmission and haze

hazeColor = clamp(hazeColor,0.0,1.0);
fragColor.rgb = mix( hazeColor  + secondary_light * fog_backscatter(mvisibility), fragColor.rgb,transmission);

}

gl_FragColor = fragColor;
}

