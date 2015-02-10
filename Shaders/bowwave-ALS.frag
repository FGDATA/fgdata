// This shader is mostly an adaptation of the shader found at
//  http://www.bonzaisoftware.com/water_tut.html and its glsl conversion
//  available at http://forum.bonzaisoftware.com/viewthread.php?tid=10
//  © Michael Horsch - 2005
//  Major update and revisions - 2011-10-07
//  © Emilian Huminiuc and Vivian Meazza
//  Optimisation - 2012-5-05
//  © Emilian Huminiuc and Vivian Meazza
//  Ported to the Atmospheric Light Scattering Framework
//  by Thorsten Renk, Aug. 2013

#version 120
#define fps2kts 0.5925

uniform sampler2D water_normalmap;
uniform sampler2D water_reflection;
uniform sampler2D water_dudvmap;
uniform sampler2D water_reflection_grey;
uniform sampler2D sea_foam;
uniform sampler2D alpha_tex;
uniform sampler2D bowwave_nmap;

uniform float saturation, Overcast, WindE, WindN, spd, hdg;
uniform float CloudCover0, CloudCover1, CloudCover2, CloudCover3, CloudCover4;
uniform int 	Status;

uniform float hazeLayerAltitude;
uniform float terminator;
uniform float terrain_alt; 
uniform float avisibility;
uniform float visibility;
uniform float overcast;
uniform float scattering;
uniform float ground_scattering;
uniform float cloud_self_shading;
uniform float eye_alt;
uniform float fogstructure;
uniform float ice_cover;
uniform float sea_r;
uniform float sea_g;
uniform float sea_b;

uniform int quality_level;


varying vec4 waterTex1; //moving texcoords
varying vec4 waterTex2; //moving texcoords
varying vec3 viewerdir;
varying vec3 lightdir;
varying vec3 normal;
varying vec3 relPos;
varying float earthShade;
varying float yprime_alt;
varying float mie_angle;
varying float steepness;

vec3 specular_light;

float fog_func (in float targ, in float alt);

vec3 get_hazeColor(in float light_arg);

const float terminator_width = 200000.0;
const float EarthRadius = 5800000.0;


/////// functions /////////

float normalize_range(float _val)
    {
    if (_val > 180.0)
        return _val - 360.0;
    else
        return _val;
    }


void relWind(out float rel_wind_speed_kts, out float rel_wind_from_rad)
    {
    //calculate the carrier speed north and east in kts
    float speed_north_kts = cos(radians(hdg)) * spd ;
    float speed_east_kts  = sin(radians(hdg)) * spd ;

    //calculate the relative wind speed north and east in kts
    float rel_wind_speed_from_east_kts = WindE*fps2kts + speed_east_kts;
    float rel_wind_speed_from_north_kts = WindN*fps2kts + speed_north_kts;

    //combine relative speeds north and east to get relative windspeed in kts
    rel_wind_speed_kts = sqrt(rel_wind_speed_from_east_kts*rel_wind_speed_from_east_kts
        + rel_wind_speed_from_north_kts*rel_wind_speed_from_north_kts);

    //calculate the relative wind direction
    float rel_wind_from_deg = degrees(atan(rel_wind_speed_from_east_kts, rel_wind_speed_from_north_kts));
    // rel_wind_from_rad = atan(rel_wind_speed_from_east_kts, rel_wind_speed_from_north_kts);
    float rel_wind = rel_wind_from_deg - hdg;
    rel_wind = normalize_range(rel_wind);
    rel_wind_from_rad = radians(rel_wind);
    }

void rotationmatrix(in float angle, out mat4 rotmat)
    {
    rotmat = mat4( cos( angle ), -sin( angle ), 0.0, 0.0,
        sin( angle ),  cos( angle ), 0.0, 0.0,
        0.0         ,  0.0         , 1.0, 0.0,
        0.0         ,  0.0         , 0.0, 1.0 );
    }

	
float light_func (in float x, in float a, in float b, in float c, in float d, in float e)
{
x = x - 0.5;

// use the asymptotics to shorten computations
if (x > 30.0) {return e;}
if (x < -15.0) {return 0.0;}

return e / pow((1.0 + a * exp(-b * (x-c)) ),(1.0/d));
}

// this determines how light is attenuated in the distance
// physically this should be exp(-arg) but for technical reasons we use a sharper cutoff
// for distance > visibility


	
//////////////////////

void main(void)
    {
    const vec4 sca = vec4(0.005, 0.005, 0.005, 0.005);
    const vec4 sca2 = vec4(0.02, 0.02, 0.02, 0.02);
    const vec4 tscale = vec4(0.25, 0.25, 0.25, 0.25);

    mat4 RotationMatrix;

    float relWindspd=0;
    float relWinddir=0;

	float dist = length(relPos);
	vec3 shadedFogColor = vec3(0.55, 0.67, 0.88);
	float effective_scattering = min(scattering, cloud_self_shading);

    // compute relative wind speed and direction
    relWind (relWindspd, relWinddir);

    rotationmatrix(relWinddir, RotationMatrix);

    // compute direction to viewer
    vec3 E = normalize(viewerdir);

    // compute direction to light source
    vec3 L = normalize(lightdir);

    // half vector
    vec3 H = normalize(L + E);

    const float water_shininess = 240.0;
    // approximate cloud cover
    float cover = 0.0;
    //bool Status = true;

    float windEffect = relWindspd;                                              //wind speed in kt
    //    float windEffect = sqrt(pow(abs(WindE),2)+pow(abs(WindN),2)) * 0.6;       //wind speed in kt
    float windScale = 15.0/(5.0 + windEffect);                                  //wave scale
    float waveRoughness = 0.05 + smoothstep(0.0, 50.0, windEffect);             //wave roughness filter


    if (Status == 1){
        cover = min(min(min(min(CloudCover0, CloudCover1),CloudCover2),CloudCover3),CloudCover4);
        } else {
            // hack to allow for Overcast not to be set by Local Weather

            if (Overcast == 0){
                cover = 5;
                } else {
                    cover = Overcast * 5;
                }

        }

    //vec4 viewt = normalize(waterTex4);
    vec4 viewt = vec4(-E, 0.0) * 0.6;

    vec4 disdis = texture2D(water_dudvmap, vec2(waterTex2 * tscale)* windScale * 2.0) * 2.0 - 1.0;
    vec4 dist1   = texture2D(water_dudvmap, vec2(waterTex1 + disdis*sca2)* windScale * 2.0) * 2.0 - 1.0;
    vec4 fdist  = normalize(dist1);
    fdist = -fdist;
    fdist *= sca;

    //normalmap
    rotationmatrix(-relWinddir, RotationMatrix);

    vec4 nmap0 = texture2D(water_normalmap, vec2((waterTex1 + disdis*sca2) * RotationMatrix ) * windScale * 2.0) * 2.0 - 1.0;
    vec4 nmap2 = texture2D(water_normalmap, vec2(waterTex2 * tscale * RotationMatrix ) * windScale * 2.0) * 2.0 - 1.0;
    vec4 nmap3 = texture2D(bowwave_nmap, gl_TexCoord[0].st) * 2.0 - 1.0;
    vec4 vNorm = normalize(mix(nmap3, nmap0 + nmap2, 0.3 )* waveRoughness);
    vNorm = -vNorm;

	//load reflection
    vec4 tmp = vec4(lightdir, 0.0);
    vec4 refTex = texture2D(water_reflection, vec2(tmp + waterTex1) * 32.0) ;
    vec4 refTexGrey = texture2D(water_reflection_grey, vec2(tmp + waterTex1) * 32.0) ;
    vec4 refl ;
	//    cover = 0;

	/*if(cover >= 1.5){
		refl= normalize(refTex);
		} 
	else
		{
		refl = normalize(refTexGrey);
		refl.r *= (0.75 + 0.15 * cover);
		refl.g *= (0.80 + 0.15 * cover);
		refl.b *= (0.875 + 0.125 * cover);
		refl.a  *= 1.0;
		}
	*/
	
	refl.r = sea_r;
	refl.g = sea_g;
	refl.b = sea_b;
	refl.a = 1.0; 
	

	float intensity;
	// de-saturate for reduced light
	refl.rgb = mix(refl.rgb,  vec3 (0.248, 0.248, 0.248), 1.0 - smoothstep(0.1, 0.8, ground_scattering)); 

  	// de-saturate light for overcast haze
	intensity = length(refl.rgb);
	refl.rgb = mix(refl.rgb,  intensity * vec3 (1.0, 1.0, 1.0), 0.5 * smoothstep(0.1, 0.9, overcast));

    vec3 N0 = vec3(texture2D(water_normalmap, vec2((waterTex1 + disdis*sca2)* RotationMatrix) * windScale * 2.0) * 2.0 - 1.0); 
    vec3 N1 = vec3(texture2D(water_normalmap, vec2(waterTex2 * tscale * RotationMatrix ) * windScale * 2.0) * 2.0 - 1.0);
    vec3 N2 = vec3(texture2D(bowwave_nmap, gl_TexCoord[0].st)*2.0-1.0);
    //vec3 Nf = normalize((normal+N0+N1)*waveRoughness);
    vec3 N  = normalize(mix(normal+N2, normal+N0+N1, 0.3)* waveRoughness);
    N  = -N;

    // specular
	
	specular_light = gl_Color.rgb;

    vec3 specular_color = vec3(specular_light)
        * pow(max(0.0, dot(N, H)), water_shininess) * 6.0;
    vec4 specular = vec4(specular_color, 0.5);

    specular = specular * saturation * 0.3;

    //calculate fresnel
    vec4 invfres = vec4( dot(vNorm, viewt) );
    vec4 fres = vec4(1.0) + invfres;
    refl *= fres;

    vec4 alpha0 = texture2D(alpha_tex, gl_TexCoord[0].st);

    //calculate final colour
    vec4 ambient_light; 
	ambient_light.rgb = max(specular_light.rgb, vec3(0.1, 0.1, 0.1));
   	ambient_light.a = 1.0;
    vec4 finalColor;

	finalColor = refl + specular * smoothstep(0.3, 0.6, ground_scattering);

    //add foam

    float foamSlope = 0.05 + 0.01 * windScale;
    //float waveSlope = mix(N0.g, N1.g, 0.25);

    vec4 foam_texel = texture2D(sea_foam, vec2(waterTex2 * tscale) * 50.0);
    float waveSlope = N.g; 

    if (windEffect >= 12.0)
        if (waveSlope >= foamSlope){
            finalColor = mix(finalColor, max(finalColor, finalColor + foam_texel), smoothstep(foamSlope, 0.5, N.g));
            }
            
    //generate final colour
        finalColor *= ambient_light;//+ alpha0 * 0.35;
        
		
		
float delta_z = hazeLayerAltitude - eye_alt;


if (dist > 40.0)
{


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
		vAltitude = min(distance_in_layer,min(visibility,avisibility)) * ct;
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
		transmission_arg = transmission_arg + (distance_in_layer/(1.0 * visibility  ));
		}
	else
		{
		transmission_arg = transmission_arg + (distance_in_layer/visibility);
		}
	// this combines the Weber-Fechner intensity
	eqColorFactor = 1.0 - 0.1 * delta_zv/visibility - (1.0 -effective_scattering);
	}
else 
	{
	if (quality_level > 3)
		{
		transmission_arg = transmission_arg + (distance_in_layer/(1.0 * avisibility  ));
		}
	else
		{
		transmission_arg = transmission_arg + (distance_in_layer/avisibility);
		}
	// this combines the Weber-Fechner intensity
	eqColorFactor = 1.0 - 0.1 * delta_zv/avisibility - (1.0 -effective_scattering);
	}


transmission =  fog_func(transmission_arg, eye_alt);

// there's always residual intensity, we should never be driven to zero
if (eqColorFactor < 0.2) eqColorFactor = 0.2;


float lightArg = (terminator-yprime_alt)/100000.0;

vec3 hazeColor = get_hazeColor(lightArg);


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


if (intensity > 0.0) // this needs to be a condition, because otherwise hazeColor doesn't come out correctly
	{
	hazeColor = intensity * normalize (mix(hazeColor, intensity * vec3 (1.0,1.0,1.0), 0.7* smoothstep(5000.0, 50000.0, eye_alt)));

	// blue hue of haze
	
	hazeColor.x = hazeColor.x * 0.83;
	hazeColor.y = hazeColor.y * 0.9; 


	// additional blue in indirect light
	float fade_out = max(0.65 - 0.3 *overcast, 0.45);
	intensity = length(hazeColor);
	hazeColor = intensity * normalize(mix(hazeColor,  1.5* shadedFogColor, 1.0 -smoothstep(0.25, fade_out,eShade) )); 

	// change haze color to blue hue for strong fogging
	hazeColor = intensity * normalize(mix(hazeColor,  shadedFogColor, (1.0-smoothstep(0.5,0.9,eqColorFactor)))); 
	}

	

	// don't let the light fade out too rapidly
	lightArg = (terminator + 200000.0)/100000.0;
	float minLightIntensity = min(0.2,0.16 * lightArg + 0.5);
	vec3 minLight = minLightIntensity * vec3 (0.2, 0.3, 0.4);

	hazeColor.rgb *= eqColorFactor * eShade;
	hazeColor.rgb = max(hazeColor.rgb, minLight.rgb);

	finalColor.rgb = mix(hazeColor, finalColor.rgb,transmission);

	
	}
	
	

    gl_FragColor = vec4(finalColor.rgb, alpha0.a * 1.35);


    }
