// -*-C++-*-

// written by Thorsten Renk, Oct 2011, based on default.frag
// Ambient term comes in gl_Color.rgb.
varying vec4 diffuse_term;
varying vec3 normal;
varying vec3 relPos;
varying vec2 rawPos;
varying vec3 worldPos;



uniform sampler2D texture;
uniform sampler2D detail_texture;
uniform sampler2D mix_texture;

//varying float yprime_alt;
//varying float mie_angle;
varying float steepness;


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
uniform float season;
uniform float transition_model;
uniform float hires_overlay_bias;
uniform int quality_level;
uniform int tquality_level;

const float EarthRadius = 5800000.0;
const float terminator_width = 200000.0;

float alt;
float eShade;
float yprime_alt;
float mie_angle;

float Noise2D(in vec2 coord, in float wavelength);
float Noise3D(in vec3 coord, in float wavelength);

float fog_func (in float targ, in float alt);
vec3 get_hazeColor(in float light_arg);





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


  vec3 shadedFogColor = vec3(0.55, 0.67, 0.88);
// this is taken from default.frag
    vec3 n;
    float NdotL, NdotHV, fogFactor;
    vec4 color = gl_Color;
    color.a = 1.0;
    vec3 lightDir = gl_LightSource[0].position.xyz;
    vec3 halfVector = gl_LightSource[0].halfVector.xyz;
    //vec3 halfVector = normalize(normalize(lightDir) + normalize(ecViewdir));
    vec4 texel;
    vec4 snow_texel;
    vec4 detail_texel;
    vec4 mix_texel;
    vec4 fragColor;
    vec4 specular = vec4(0.0);
    float intensity;
    

// get noise at different wavelengths

// used:	5m, 5m gradient, 10m, 10m gradient: heightmap of the closeup terrain, 10m also snow
//		50m: detail texel
//		250m: detail texel
//		500m: distortion and overlay
// 		1500m: overlay, detail, dust, fog
//		2000m: overlay, detail, snow, fog

float noise_10m; 
float noise_5m;  
noise_10m = Noise2D(rawPos.xy, 10.0);
noise_5m = Noise2D(rawPos.xy ,5.0);

float noisegrad_10m;
float noisegrad_5m;

float noise_50m = Noise2D(rawPos.xy, 50.0);; 


float noise_250m = Noise3D(worldPos.xyz,250.0);
float noise_500m = Noise3D(worldPos.xyz, 500.0);
float noise_1500m = Noise3D(worldPos.xyz, 1500.0);
float noise_2000m = Noise3D(worldPos.xyz, 2000.0);



//


// get the texels

    texel = texture2D(texture, gl_TexCoord[0].st);
    float local_autumn_factor = texel.a;

    float distortion_factor = 1.0;
    vec2 stprime;
    int flag = 1;
    int mix_flag = 1;
    float noise_term;
    float snow_alpha;


        

    //float view_angle = abs(dot(normal, normalize(ecViewdir)));

    if ((quality_level > 3)&&(relPos.z + eye_alt +500.0 > snowlevel))
	{
	float sfactor;
	snow_texel = vec4 (0.95, 0.95, 0.95, 1.0) * (0.9 + 0.1* noise_500m + 0.1* (1.0 - noise_10m) );
	snow_texel.r = snow_texel.r * (0.9 + 0.05 * (noise_10m + noise_5m));
	snow_texel.g = snow_texel.g * (0.9 + 0.05 * (noise_10m + noise_5m));
	snow_texel.a = 1.0;
	noise_term = 0.1 * (noise_500m-0.5);
	sfactor = sqrt(2.0 * (1.0-steepness)/0.03) + abs(ct)/0.15;
	noise_term = noise_term + 0.2 * (noise_50m -0.5) * (1.0 - smoothstep(18000.0*sfactor, 40000.0*sfactor, dist)  ) ;
	noise_term = noise_term + 0.3 * (noise_10m -0.5) * (1.0 - smoothstep(4000.0 * sfactor, 8000.0 * sfactor, dist)  ) ;
	if (dist < 3000.0*sfactor){ noise_term = noise_term + 0.3 * (noise_5m -0.5) * (1.0 - smoothstep(1000.0 * sfactor, 3000.0 *sfactor, dist)  );}
	snow_texel.a = snow_texel.a * 0.2+0.8* smoothstep(0.2,0.8, 0.3 +noise_term + snow_thickness_factor +0.0001*(relPos.z +eye_alt -snowlevel) );
   	
	}

    if (tquality_level > 2)
	{
	mix_texel = texture2D(mix_texture, gl_TexCoord[0].st * 1.3);
	if (mix_texel.a <0.1) {mix_flag = 0;}
 	}


    if (tquality_level > 3)  
	{
	stprime = vec2 (0.86*gl_TexCoord[0].s + 0.5*gl_TexCoord[0].t, 0.5*gl_TexCoord[0].s - 0.86*gl_TexCoord[0].t);
    	//distortion_factor = 0.9375 + (1.0 * nvL[2]);
	distortion_factor = 0.97 + 0.06 * noise_500m;
	stprime = stprime * distortion_factor * 15.0;
	if (quality_level > 4)
		{
		stprime = stprime + normalize(relPos).xy * 0.02 * (noise_10m + 0.5 * noise_5m - 0.75);
		}
    	detail_texel = texture2D(detail_texture, stprime);
	if (detail_texel.a <0.1) {flag = 0;}
	}


// texture preparation according to detail level

// mix in hires texture patches

float dist_fact; 
float nSum;
float mix_factor;

if (tquality_level > 2)
   {
   // first the second texture overlay
   // transition model 0: random patch overlay without any gradient information
   // transition model 1: only gradient-driven transitions, no randomness
   
   
   if (mix_flag == 1)
	{
	nSum =  0.18 * (2.0 * noise_2000m + 2.0 * noise_1500m + noise_500m);
	nSum = mix(nSum, 0.5, max(0.0, 2.0 * (transition_model - 0.5)));
	nSum = nSum + 0.4 * (1.0 -smoothstep(0.9,0.95, abs(steepness)+ 0.05 * (noise_50m - 0.5))) * min(1.0, 2.0 * transition_model);
	mix_factor = smoothstep(0.5, 0.54, nSum);
        texel = mix(texel, mix_texel, mix_factor);
        local_autumn_factor = texel.a;
	}
   
   // then the detail texture overlay	
  }

if (tquality_level > 3)
     {	
   if (dist < 40000.0)
   	{
	if (flag == 1)
		{
		//noise_50m = Noise2D(rawPos.xy, 50.0);
		//noise_250m  = Noise2D(rawPos.xy, 250.0); 
		dist_fact =  0.1 * smoothstep(15000.0,40000.0, dist) - 0.03 * (1.0 - smoothstep(500.0,5000.0, dist));
		nSum = ((1.0 -noise_2000m) + noise_1500m + 2.0 * noise_250m  +noise_50m)/5.0;
        	nSum = nSum - 0.08 * (1.0 -smoothstep(0.9,0.95, abs(steepness)));		
		mix_factor = smoothstep(0.47, 0.54, nSum +hires_overlay_bias - dist_fact);
		if (mix_factor > 0.8) {mix_factor = 0.8;}
		texel =  mix(texel, detail_texel,mix_factor);
		local_autumn_factor = texel.a;				
		}
	}
   }



// autumn colors

float autumn_factor = season * 2.0 * (1.0 - local_autumn_factor) ;


texel.r = min(1.0, (1.0 + 2.5 * autumn_factor) * texel.r);
texel.g = texel.g;
texel.b = max(0.0, (1.0 - 4.0 * autumn_factor) *  texel.b);


if (local_autumn_factor < 1.0)
	{
	intensity = length(texel.rgb) * (1.0 - 0.5 * smoothstep(1.1,2.0,season));
	texel.rgb = intensity * normalize(mix(texel.rgb, vec3(0.23,0.17,0.08), smoothstep(1.1,2.0, season)));
	}



const vec4 dust_color  = vec4 (0.76, 0.71, 0.56, 1.0);
const vec4 lichen_color = vec4 (0.17, 0.20, 0.06, 1.0);;
//float snow_alpha;

if (quality_level > 3)
	{

	// mix vegetation
	texel = mix(texel, lichen_color, 0.4 * lichen_cover_factor + 0.8 * lichen_cover_factor * 0.5 * (noise_10m + (1.0 - noise_5m))  );
	// mix dust
	texel = mix(texel, dust_color, clamp(0.5 * dust_cover_factor + 3.0 * dust_cover_factor * (((noise_1500m - 0.5) * 0.125)+0.125 ),0.0, 1.0) );
	
    	// mix snow
	if (relPos.z + eye_alt +500.0 > snowlevel)
		{
   		snow_alpha = smoothstep(0.75, 0.85, abs(steepness));
		//texel = mix(texel, snow_texel, texel_snow_fraction);
		texel = mix(texel, snow_texel, snow_texel.a* smoothstep(snowlevel, snowlevel+200.0,  snow_alpha * (relPos.z + eye_alt)+ (noise_2000m + 0.1 * noise_10m -0.55) *400.0));
		}
	}



// get distribution of water when terrain is wet

float water_threshold1;
float water_threshold2;
float water_factor =0.0;


if ((dist < 5000.0)&& (quality_level > 3) && (wetness>0.0))
		{
		water_threshold1 = 1.0-0.5* wetness;
		water_threshold2 = 1.0 - 0.3 * wetness;
		water_factor = smoothstep(water_threshold1, water_threshold2 ,   (0.3 * (2.0 * (1.0-noise_10m) + (1.0 -noise_5m)) *   (1.0 - smoothstep(2000.0, 5000.0, dist))) - 5.0 * (1.0 -steepness));
	}

// darken wet terrain

    texel.rgb = texel.rgb * (1.0 - 0.6 * wetness);


// light computations


    vec4 light_specular = gl_LightSource[0].specular;

    // If gl_Color.a == 0, this is a back-facing polygon and the
    // normal should be reversed.
    //n = (2.0 * gl_Color.a - 1.0) * normal;
    n = normal;//vec3 (nvec.x, nvec.y, sqrt(1.0 -pow(nvec.x,2.0) - pow(nvec.y,2.0) ));
    n = normalize(n);

    NdotL = dot(n, lightDir);
    if ((tquality_level > 3) && (mix_flag ==1)&& (dist < 2000.0) && (quality_level > 4)) 
	{
	noisegrad_10m = (noise_10m - Noise2D(rawPos.xy+ 0.05 * normalize(lightDir.xy),10.0))/0.05;
	noisegrad_5m = (noise_5m - Noise2D(rawPos.xy+ 0.05 * normalize(lightDir.xy),5.0))/0.05;
	NdotL = NdotL + 1.0 * (noisegrad_10m + 0.5* noisegrad_5m) * mix_factor/0.8 *  (1.0 - smoothstep(1000.0, 2000.0, dist));
	}
    if (NdotL > 0.0) {
        color += diffuse_term * NdotL;
        NdotHV = max(dot(n, halfVector), 0.0);
        if (gl_FrontMaterial.shininess > 0.0)
            specular.rgb = ((gl_FrontMaterial.specular.rgb * 0.1 + (water_factor * vec3 (1.0, 1.0, 1.0)))
                            * light_specular.rgb
                            * pow(NdotHV, gl_FrontMaterial.shininess + (20.0 * water_factor)));
    }
    color.a = 1.0;//diffuse_term.a;
    // This shouldn't be necessary, but our lighting becomes very
    // saturated. Clamping the color before modulating by the texture
    // is closer to what the OpenGL fixed function pipeline does.
    color = clamp(color, 0.0, 1.0);




    fragColor = color * texel + specular;

// here comes the terrain haze model


float delta_z = hazeLayerAltitude - eye_alt;

if (dist > 0.04 * min(visibility,avisibility)) 
//if ((gl_FragCoord.y > ylimit) || (gl_FragCoord.x < zlimit1) || (gl_FragCoord.x > zlimit2))
//if (dist > 40.0)
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
		vAltitude = min(distance_in_layer,min(visibility, avisibility)) * ct;
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
	

// ground haze cannot be thinner than aloft visibility in the model,
// so we need to use aloft visibility otherwise


transmission_arg = (dist-distance_in_layer)/avisibility;


float eqColorFactor;



if (visibility < avisibility)
	{
	if (quality_level > 3)
		{
		transmission_arg = transmission_arg + (distance_in_layer/(1.0 * visibility + 1.0 * visibility * fogstructure * 0.06 * (noise_1500m + noise_2000m -1.0) ));

		}
	else
		{
		transmission_arg = transmission_arg + (distance_in_layer/visibility);
		}
	// this combines the Weber-Fechner intensity
	eqColorFactor = 1.0 - 0.1 * delta_zv/visibility - (1.0 - effective_scattering);

	}
else 
	{
	if (quality_level > 3)
		{
		transmission_arg = transmission_arg + (distance_in_layer/(1.0 * avisibility + 1.0 * avisibility * fogstructure * 0.06 * (noise_1500m + noise_2000m  - 1.0) ));
		}
	else
		{
		transmission_arg = transmission_arg + (distance_in_layer/avisibility);
		}
	// this combines the Weber-Fechner intensity
	eqColorFactor = 1.0 - 0.1 * delta_zv/avisibility - (1.0 - effective_scattering);
	}



transmission =  fog_func(transmission_arg, alt);

// there's always residual intensity, we should never be driven to zero
if (eqColorFactor < 0.2) eqColorFactor = 0.2;


float lightArg = (terminator-yprime_alt)/100000.0;
vec3 hazeColor = get_hazeColor(lightArg);




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

	// don't let the light fade out too rapidly
	lightArg = (terminator + 200000.0)/100000.0;
	float minLightIntensity = min(0.2,0.16 * lightArg + 0.5);
	vec3 minLight = minLightIntensity * vec3 (0.2, 0.3, 0.4);

	hazeColor *= eqColorFactor * eShade;
	hazeColor.rgb = max(hazeColor.rgb, minLight.rgb);

	}




fragColor.rgb = mix(clamp(hazeColor,0.0,1.0) , clamp(fragColor.rgb,0.0,1.0),transmission);

}

gl_FragColor = fragColor;


}

