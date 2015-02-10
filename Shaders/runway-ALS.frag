// -*-C++-*-

// written by Thorsten Renk, Oct 2011, based on default.frag
// Ambient term comes in gl_Color.rgb.
varying vec4 diffuse_term;
varying vec3 normal;
varying vec3 relPos;
varying vec2 rawPos;
varying vec3 worldPos;
varying vec3 ecViewdir;


uniform sampler2D texture;
uniform sampler2D NormalTex;

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
uniform float rain_norm;
uniform float fogstructure;
uniform float snow_thickness_factor;
uniform float cloud_self_shading;
uniform float uvstretch;
uniform float landing_light1_offset;
uniform float landing_light2_offset;
uniform float air_pollution;
uniform float osg_SimulationTime;

uniform int quality_level;
uniform int tquality_level;
uniform int cloud_shadow_flag;
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
float DotNoise2D(in vec2 coord, in float wavelength, in float fractionalMaxDotSize, in float dot_density);
float fog_func (in float targ, in float alt);
float alt_factor(in float eye_alt, in float vertex_alt);
float light_distance_fading(in float dist);
float fog_backscatter(in float avisibility);
float rayleigh_in_func(in float dist, in float air_pollution, in float avisibility, in float eye_alt, in float vertex_alt);

vec3 searchlight();
vec3 landing_light(in float offset);
vec3 rayleigh_out_shift(in vec3 color, in float outscatter);
vec3 get_hazeColor(in float light_arg);



void main()
{

  yprime_alt = diffuse_term.a;
  mie_angle = gl_Color.a;
  float effective_scattering = min(scattering, cloud_self_shading);

  // distance to fragment
  float dist = length(relPos);
  // angle of view vector with horizon
  float ct = dot(vec3(0.0, 0.0, 1.0), relPos)/dist;


  vec3 shadedFogColor = vec3(0.55, 0.67, 0.88);
// this is taken from default.frag
    vec3 n;
    float NdotL, NdotHV;
    vec4 color = gl_Color;
    color.a = 1.0;
    vec3 lightDir = gl_LightSource[0].position.xyz;
    vec3 E = normalize(ecViewdir);
    vec3 halfVector;
    if (quality_level<6)
	{halfVector = gl_LightSource[0].halfVector.xyz;}
    else
	{halfVector = normalize(normalize(lightDir) + E);}

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

float noise_01m;
float noise_1m = Noise2D(rawPos.xy, 1.0); 
float noise_10m; 
float noise_5m;  
noise_10m = Noise2D(rawPos.xy, 10.0);
noise_5m = Noise2D(rawPos.xy ,5.0);

float noisegrad_10m;
float noisegrad_5m;

float noise_50m = Noise2D(rawPos.xy, 50.0);


float noise_1500m = Noise3D(worldPos.xyz, 1500.0);
float noise_2000m = Noise3D(worldPos.xyz, 2000.0);




//


// get the texels

    texel = texture2D(texture, vec2 (gl_TexCoord[0].s, gl_TexCoord[0].t * uvstretch));
	vec4 nmap  = texture2D(NormalTex, gl_TexCoord[0].st * 8.0);
	vec3 N = nmap.rgb * 2.0 - 1.0;

    float distortion_factor = 1.0;
    vec2 stprime;
    int flag = 1;
    int mix_flag = 1;
    float noise_term;
    float snow_alpha;


    if (quality_level > 3)
	{
	float sfactor;
	noise_01m = Noise2D(rawPos.xy,0.1);
	snow_texel = vec4 (0.95, 0.95, 0.95, 1.0) * (0.9 + 0.1* noise_50m + 0.1* (1.0 - noise_10m) );
	snow_texel.a = 1.0;
	noise_term = 0.1 * (noise_50m-0.5);
	sfactor = 1.0;//sqrt(2.0 * (1.0-steepness)/0.03) + abs(ct)/0.15;
	noise_term = noise_term + 0.2 * (noise_10m -0.5) * (1.0 - smoothstep(10000.0*sfactor, 16000.0*sfactor, dist)  ) ;
	noise_term = noise_term + 0.3 * (noise_5m -0.5) * (1.0 - smoothstep(1200.0 * sfactor, 2000.0 * sfactor, dist)  ) ;
	noise_term = noise_term + 0.3 * (noise_1m -0.5) * (1.0 - smoothstep(500.0 * sfactor, 1000.0 *sfactor, dist)  );
	noise_term = noise_term + 0.3 * (noise_01m -0.5) * (1.0 - smoothstep(20.0 * sfactor, 100.0 *sfactor, dist)  );
	snow_texel.a = snow_texel.a * 0.2+0.8* smoothstep(0.2,0.8, 0.3 +noise_term + 0.2*snow_thickness_factor +0.0001*(relPos.z +eye_alt -snowlevel) );
   	
	}


const vec3 dust_color  = vec3 (0.76, 0.71, 0.56);
const vec3 lichen_color = vec3 (0.17, 0.20, 0.06);
//float snow_alpha;

if (quality_level > 3)
	{

	// mix vegetation
	texel.rgb = mix(texel.rgb, lichen_color, 0.4 * lichen_cover_factor + 0.8 * lichen_cover_factor * 0.5 * (noise_10m + (1.0 - noise_5m))  );
	// mix dust
	texel.rgb = mix(texel.rgb, dust_color, clamp(0.5 * dust_cover_factor + 3.0 * dust_cover_factor * (((noise_1500m - 0.5) * 0.125)+0.125 ),0.0, 1.0) );
	
    	// mix snow
	if (relPos.z + eye_alt +500.0 > snowlevel)
		{
   		snow_alpha = smoothstep(0.75, 0.85, abs(steepness));
		texel.rgb = mix(texel.rgb, snow_texel.rgb, snow_texel.a* smoothstep(snowlevel, snowlevel+200.0,  snow_alpha * (relPos.z + eye_alt)+ (noise_2000m + 0.1 * noise_10m -0.55) *400.0));
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
		water_factor = smoothstep(water_threshold1, water_threshold2 , 0.5 * (noise_5m + (1.0 -noise_1m))) *   (1.0 - smoothstep(1000.0, 3000.0, dist));
	}

// darken wet terrain

    texel.rgb = texel.rgb * (1.0 - 0.6 * wetness - 0.1 * water_factor);


// light computations

    eShade = 1.0 - 0.9 * smoothstep(-terminator_width+ terminator, terminator_width + terminator, yprime_alt);
    vec4 light_specular = gl_LightSource[0].specular * eShade;

    // If gl_Color.a == 0, this is a back-facing polygon and the
    // normal should be reversed.
    n = normal;
    n = normalize(n);

    // primary reflection of the Sun
    float fresnel;
    NdotL = dot(n, lightDir);
    
	if (quality_level > 4)
		{
		NdotL = NdotL + (3.0 * N.r + 0.1 * (noise_01m-0.5))* (1.0 - water_factor) ;
		}
    if (NdotL > 0.0) 
	{
	if (cloud_shadow_flag == 1) 
		{NdotL = NdotL * shadow_func(relPos.x, relPos.y, 1.0, dist);}
        color += diffuse_term * NdotL;
        NdotHV = max(dot(n, halfVector), 0.0);
	fresnel = 1.0 + 5.0 * (1.0-smoothstep(0.0,0.2, dot(E,n)));
        specular.rgb = ((vec3 (0.2,0.2,0.2) * fresnel + (water_factor * vec3 (1.0, 1.0, 1.0)))
                            * light_specular.rgb
                            * pow(NdotHV, max(4.0, (20.0 * water_factor))));
    	}

    // raindrops
    float rain_factor = 0.0;
    if (rain_norm > 0.0)
	{
    	rain_factor += DotNoise2D(rawPos.xy, 0.2 ,0.5, rain_norm) * abs(sin(6.0*osg_SimulationTime));
    	rain_factor += DotNoise2D(rawPos.xy, 0.3 ,0.4, rain_norm) * abs(sin(6.0*osg_SimulationTime + 2.094));
    	rain_factor += DotNoise2D(rawPos.xy, 0.4 ,0.3, rain_norm)* abs(sin(6.0*osg_SimulationTime + 4.188));
	}

    // secondary reflection of sky irradiance
    float fresnelW =  ((0.8 * wetness) + (0.2* water_factor)) *  (1.0-smoothstep(0.0,0.4, dot(E,n) * 1.0 - 0.2 * rain_factor * wetness));
    float sky_factor = (1.0-ct*ct);//mix((1.0 - ct * ct), 1.0-effective_scattering, effective_scattering);
    vec3 sky_light = vec3 (1.0,1.0,1.0) * length(light_specular.rgb) * (1.0-effective_scattering);
    specular.rgb += sky_factor * fresnelW  * sky_light;
 


    //specular.rgb *= 1.0 - 0.2 * dotnoise_02m * wetness;

    color.a = 1.0;//diffuse_term.a;
    // This shouldn't be necessary, but our lighting becomes very
    // saturated. Clamping the color before modulating by the texture
    // is closer to what the OpenGL fixed function pipeline does.
    color = clamp(color, 0.0, 1.0);
    
    vec3 secondary_light = vec3 (0.0,0.0,0.0);

    if (use_searchlight == 1)
	{
	secondary_light.rgb += searchlight();
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


// Rayleigh color shifts 

    if ((quality_level > 5) && (tquality_level > 5))
    	{
	float rayleigh_length = 0.5 * avisibility * (2.5 - 1.9 * air_pollution)/alt_factor(eye_alt, eye_alt+relPos.z);
	float outscatter = 1.0-exp(-dist/rayleigh_length);
        fragColor.rgb = rayleigh_out_shift(fragColor.rgb,outscatter);
// Rayleigh color shift due to in-scattering
	float rShade = 1.0 - 0.9 * smoothstep(-terminator_width+ terminator, terminator_width + terminator, yprime_alt + 420000.0);
	float lightIntensity = length(hazeColor * effective_scattering) * rShade;
	vec3 rayleighColor = vec3 (0.17, 0.52, 0.87) * lightIntensity;
   	float rayleighStrength = rayleigh_in_func(dist, air_pollution, avisibility/max(lightIntensity,0.05), eye_alt, eye_alt + relPos.z);
  	fragColor.rgb = mix(fragColor.rgb, rayleighColor,rayleighStrength);
	}



// here comes the terrain haze model


float delta_z = hazeLayerAltitude - eye_alt;
float mvisibility = min(visibility, avisibility);

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
	eqColorFactor = 1.0 - 0.1 * delta_zv/visibility - (1.0- effective_scattering);

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
//hazeColor = clamp(hazeColor, 0.0, 1.0);

// don't let the light fade out too rapidly
lightArg = (terminator + 200000.0)/100000.0;
float minLightIntensity = min(0.2,0.16 * lightArg + 0.5);
vec3 minLight = minLightIntensity * vec3 (0.2, 0.3, 0.4);

hazeColor.rgb *= eqColorFactor * eShade;
hazeColor.rgb = max(hazeColor.rgb, minLight.rgb);

fragColor.rgb = mix(hazeColor +secondary_light * fog_backscatter(mvisibility), fragColor.rgb,transmission);





}


gl_FragColor = fragColor;

}

