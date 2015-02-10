// -*- mode: C; -*-
// Licence: GPL v2
// Author: Frederic Bouvier.
//  Adapted from the paper by F. Policarpo et al. : Real-time Relief Mapping on Arbitrary Polygonal Surfaces
//  Adapted from the paper and sources by M. Drobot in GPU Pro : Quadtree Displacement Mapping with Height Blending

#version 120

#extension GL_ATI_shader_texture_lod : enable
#extension GL_ARB_shader_texture_lod : enable

#define TEXTURE_MIP_LEVELS 10
#define TEXTURE_PIX_COUNT  1024 //pow(2,TEXTURE_MIP_LEVELS)
#define BINARY_SEARCH_COUNT 10
#define BILINEAR_SMOOTH_FACTOR 2.0

varying vec3  worldPos;
varying vec4  ecPosition;
varying vec3  VNormal;
varying vec3  VTangent;
varying vec4  constantColor;
varying vec3  light_diffuse;
varying vec3 relPos;

varying float yprime_alt;
varying float mie_angle;

uniform sampler2D BaseTex;
uniform sampler2D NormalTex;
uniform sampler2D QDMTex;
uniform float depth_factor;
uniform float tile_size;
uniform float quality_level;
uniform float visibility;
uniform float avisibility;
uniform float scattering;
uniform float terminator;
uniform float terrain_alt;
uniform float hazeLayerAltitude;
uniform float overcast;
uniform float eye_alt;
uniform float mysnowlevel;
uniform float dust_cover_factor;
uniform float wetness;
uniform float fogstructure;
uniform float cloud_self_shading;
uniform float air_pollution;
uniform float landing_light1_offset;
uniform float landing_light2_offset;


uniform vec3 night_color;

uniform bool random_buildings;

uniform int cloud_shadow_flag;
uniform int use_searchlight;
uniform int use_landing_light;
uniform int use_alt_landing_light;
uniform int gquality_level;
uniform int tquality_level;

const float scale = 1.0;
int linear_search_steps = 10;
int GlobalIterationCount = 0;
int gIterationCap = 64;

const float EarthRadius = 5800000.0;
const float terminator_width = 200000.0;

float alt;
float eShade;

float shadow_func (in float x, in float y, in float noise, in float dist);
float Noise2D(in vec2 coord, in float wavelength);
float Noise3D(in vec3 coord, in float wavelength);
float fog_func (in float targ, in float alt);
float rayleigh_in_func(in float dist, in float air_pollution, in float avisibility, in float eye_alt, in float vertex_alt);
float alt_factor(in float eye_alt, in float vertex_alt);
float light_distance_fading(in float dist);
float fog_backscatter(in float avisibility);

vec3 rayleigh_out_shift(in vec3 color, in float outscatter);
vec3 get_hazeColor(in float light_arg);
vec3 searchlight();
vec3 landing_light(in float offset);



void QDM(inout vec3 p, inout vec3 v)
{
    const int MAX_LEVEL = TEXTURE_MIP_LEVELS;
    const float NODE_COUNT = TEXTURE_PIX_COUNT;
    const float TEXEL_SPAN_HALF = 1.0 / NODE_COUNT / 2.0;

    float fDeltaNC = TEXEL_SPAN_HALF * depth_factor;

    vec3 p2 = p;
    float level = MAX_LEVEL;
    vec2 dirSign = (sign(v.xy) + 1.0) * 0.5;
    GlobalIterationCount = 0;
    float d = 0.0;

    while (level >= 0.0 && GlobalIterationCount < gIterationCap)
    {
        vec4 uv = vec4(p2.xyz, level);
        d = texture2DLod(QDMTex, uv.xy, uv.w).w;

        if (d > p2.z)
        {
            //predictive point of ray traversal
            vec3 tmpP2 = p + v * d;

            //current node count
            float nodeCount = pow(2.0, (MAX_LEVEL - level));
            //current and predictive node ID
            vec4 nodeID = floor(vec4(p2.xy, tmpP2.xy)*nodeCount);

            //check if we are crossing the current cell
            if (nodeID.x != nodeID.z || nodeID.y != nodeID.w)
            {
                //calculate distance to nearest bound
                vec2 a = p2.xy - p.xy;
                vec2 p3 = (nodeID.xy + dirSign) / nodeCount;
                vec2 b = p3.xy - p.xy;

                vec2 dNC = (b.xy * p2.z) / a.xy;
                //take the nearest cell
                d = min(d,min(dNC.x, dNC.y))+fDeltaNC;

                level++;
            }
            p2 = p + v * d;
        }
        level--;
        GlobalIterationCount++;
    }

    //
    // Manual Bilinear filtering
    //
    float rayLength =  length(p2.xy - p.xy) + fDeltaNC;

    float dA = p2.z * (rayLength - BILINEAR_SMOOTH_FACTOR * TEXEL_SPAN_HALF) / rayLength;
    float dB = p2.z * (rayLength + BILINEAR_SMOOTH_FACTOR * TEXEL_SPAN_HALF) / rayLength;

    vec4 p2a = vec4(p + v * dA, 0.0);
    vec4 p2b = vec4(p + v * dB, 0.0);
    dA = texture2DLod(NormalTex, p2a.xy, p2a.w).w;
    dB = texture2DLod(NormalTex, p2b.xy, p2b.w).w;

    dA = abs(p2a.z - dA);
    dB = abs(p2b.z - dB);

    p2 = mix(p2a.xyz, p2b.xyz, dA / (dA + dB));

    p = p2;
}

float ray_intersect_QDM(vec2 dp, vec2 ds)
{
    vec3 p = vec3( dp, 0.0 );
    vec3 v = vec3( ds, 1.0 );
    QDM( p, v );
    return p.z;
}

float ray_intersect_relief(vec2 dp, vec2 ds)
{
    float size = 1.0 / float(linear_search_steps);
    float depth = 0.0;
    float best_depth = 1.0;

    for(int i = 0; i < linear_search_steps - 1; ++i)
    {
        depth += size;
        float t = step(0.95, texture2D(NormalTex, dp + ds * depth).a);
        if(best_depth > 0.996)
            if(depth >= t)
                best_depth = depth;
    }
    depth = best_depth;

    const int binary_search_steps = 5;

    for(int i = 0; i < binary_search_steps; ++i)
    {
        size *= 0.5;
        float t = step(0.95, texture2D(NormalTex, dp + ds * depth).a);
        if(depth >= t)
        {
            best_depth = depth;
            depth -= 2.0 * size;
        }
        depth += size;
    }

    return(best_depth);
}

float ray_intersect(vec2 dp, vec2 ds)
{
    if ( random_buildings )
        return 0.0;
    else if ( quality_level >= 4.0 )
        return ray_intersect_QDM( dp, ds );
    else
        return ray_intersect_relief( dp, ds );
}

void main (void)
{
    if ( quality_level >= 3.0 ) {
        linear_search_steps = 20;
    }

    float depthfactor = depth_factor;
    if ( random_buildings )
        depthfactor = 0.0;

    vec3 shadedFogColor = vec3(0.55, 0.67, 0.88);
    float effective_scattering = min(scattering, cloud_self_shading);
    vec3 normal = normalize(VNormal);
    vec3 tangent = normalize(VTangent);
    //vec3 binormal = normalize(VBinormal);
    vec3 binormal = normalize(cross(normal, tangent));
    vec3 ecPos3 = ecPosition.xyz / ecPosition.w;
    vec3 V = normalize(ecPos3);
    vec3 s = vec3(dot(V, tangent), dot(V, binormal), dot(normal, -V));
    vec2 ds = s.xy * depthfactor / s.z;
    vec2 dp = gl_TexCoord[0].st - ds;
    float d = ray_intersect(dp, ds);

    vec2 uv = dp + ds * d;
    vec3 N = texture2D(NormalTex, uv).xyz * 2.0 - 1.0;


    float emis = N.z;
    N.z = sqrt(1.0 - min(1.0,dot(N.xy, N.xy)));
    float Nz = N.z;
    N = normalize(N.x * tangent + N.y * binormal + N.z * normal);

    vec3 l = gl_LightSource[0].position.xyz;
    vec3 diffuse = gl_Color.rgb * max(0.0, dot(N, l));
    
    float dist = length(relPos);
    if (cloud_shadow_flag == 1) 
	{diffuse = diffuse * shadow_func(relPos.x, relPos.y, 1.0, dist);}


    float shadow_factor = 1.0;

    // Shadow
    if ( quality_level >= 2.0 ) {
        dp += ds * d;
        vec3 sl = normalize( vec3( dot( l, tangent ), dot( l, binormal ), dot( -l, normal ) ) );
        ds = sl.xy * depthfactor / sl.z;
        dp -= ds * d;
        float dl = ray_intersect(dp, ds);
        if ( dl < d - 0.05 )
            shadow_factor = dot( constantColor.xyz, vec3( 1.0, 1.0, 1.0 ) ) * 0.25;
    }
    // end shadow

    vec4 ambient_light = constantColor + vec4 (light_diffuse,1.0) * vec4(diffuse, 1.0);
    float reflectance = ambient_light.r * 0.3 + ambient_light.g * 0.59 + ambient_light.b * 0.11;
    if ( shadow_factor < 1.0 )
        ambient_light = constantColor + vec4(light_diffuse,1.0) * shadow_factor * vec4(diffuse, 1.0);
    float emission_factor = (1.0 - smoothstep(0.15, 0.25, reflectance)) * emis;
    vec4 tc = texture2D(BaseTex, uv);
    emission_factor *= 0.5*pow(tc.r+0.8*tc.g+0.2*tc.b, 2.0) -0.2;
    ambient_light += (emission_factor * vec4(night_color, 0.0));



    vec4 finalColor = texture2D(BaseTex, uv);


// texel postprocessing by shader effects


// dust effect

vec4 dust_color;


float noise_1500m = Noise3D(worldPos.xyz,1500.0);
float noise_2000m = Noise3D(worldPos.xyz,2000.0);

if (gquality_level > 2)
	{
	// mix dust
    	dust_color = vec4 (0.76, 0.71, 0.56, 1.0);

    	finalColor = mix(finalColor, dust_color, clamp(0.5 * dust_cover_factor + 3.0 * dust_cover_factor * (((noise_1500m - 0.5) * 0.125)+0.125 ),0.0, 1.0) );
	}


// darken wet terrain

    finalColor.rgb = finalColor.rgb * (1.0 - 0.6 * wetness);

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
    ambient_light = clamp(ambient_light,0.0,1.0);
    ambient_light.rgb +=secondary_light * light_distance_fading(dist);



    finalColor *= ambient_light;

    vec4 p = vec4( ecPos3 + tile_size * V * (d-1.0) * depthfactor / s.z, 1.0 );





float lightArg = (terminator-yprime_alt)/100000.0;

vec3 hazeColor = get_hazeColor(lightArg);



// Rayleigh color shifts 

    if ((gquality_level > 5) && (tquality_level > 5))
    	{
	float rayleigh_length = 0.5 * avisibility * (2.5 - 1.9 * air_pollution)/alt_factor(eye_alt, eye_alt+relPos.z);
	float outscatter = 1.0-exp(-dist/rayleigh_length);
        finalColor.rgb = rayleigh_out_shift(finalColor.rgb,outscatter);
// Rayleigh color shift due to in-scattering
	float rShade = 1.0 - 0.9 * smoothstep(-terminator_width+ terminator, terminator_width + terminator, yprime_alt + 420000.0);
	float lightIntensity = length(hazeColor * effective_scattering) * rShade;
	vec3 rayleighColor = vec3 (0.17, 0.52, 0.87) * lightIntensity;
   	float rayleighStrength = rayleigh_in_func(dist, air_pollution, avisibility/max(lightIntensity,0.05), eye_alt, eye_alt + relPos.z);
  	finalColor.rgb = mix(finalColor.rgb, rayleighColor,rayleighStrength);
	}

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
float intensity;
vec3 lightDir = gl_LightSource[0].position.xyz;

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


// ground haze cannot be thinner than aloft visibility in the model,
// so we need to use aloft visibility otherwise


transmission_arg = (dist-distance_in_layer)/avisibility;


float eqColorFactor;



if (visibility < avisibility)
	{
	if (gquality_level > 3)
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
	if (gquality_level > 3)
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
	// Mie-like factor

	if (lightArg < 10.0)
		{
		float mie_magnitude = 0.5 * smoothstep(350000.0, 150000.0, terminator-sqrt(2.0 * EarthRadius * terrain_alt));
		hazeColor = intensity * ((1.0 - mie_magnitude) + mie_magnitude * mie_angle) * normalize(mix(hazeColor,  vec3 (0.5, 0.58, 0.65), 	mie_magnitude * (0.5 - 0.5 * mie_angle)) );
		}

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

	float shadow = mix( min(1.0 + dot(VNormal,lightDir),1.0), 1.0, 1.0-smoothstep(0.1, 0.4, transmission));
	hazeColor = mix(shadow * hazeColor, hazeColor, 0.3 + 0.7* smoothstep(250000.0, 400000.0, terminator));
	}


// don't let the light fade out too rapidly
lightArg = (terminator + 200000.0)/100000.0;
float minLightIntensity = min(0.2,0.16 * lightArg + 0.5);
vec3 minLight = minLightIntensity * vec3 (0.2, 0.3, 0.4);
hazeColor *= eqColorFactor * eShade;
hazeColor.rgb = max(hazeColor.rgb, minLight.rgb);


finalColor.rgb = mix( hazeColor +secondary_light * fog_backscatter(mvisibility), finalColor.rgb,transmission);

}




gl_FragColor = finalColor;

    if (dot(normal,-V) > 0.1) {
        vec4 iproj = gl_ProjectionMatrix * p;
        iproj /= iproj.w;
        gl_FragDepth = (iproj.z+1.0)/2.0;
    } else {
        gl_FragDepth = gl_FragCoord.z;
    }
}
