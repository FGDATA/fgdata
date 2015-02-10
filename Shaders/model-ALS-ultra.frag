// -*- mode: C; -*-
// Licence: GPL v2
// Authors: Frederic Bouvier and Gijs de Rooy
// with major additions and revisions by
// Emilian Huminiuc and Vivian Meazza 2011
// ported to Atmospheric Light Scattering 
// by Thorsten Renk, 2013
#version 120

varying	vec3 	VBinormal;
varying	vec3 	VNormal;
varying	vec3 	VTangent;
varying	vec3 	rawpos;
varying	vec3 	reflVec;
varying	vec3 	vViewVec;
varying vec3	vertVec;

varying	float	alpha;

uniform sampler2D BaseTex;
uniform sampler2D LightMapTex;
uniform sampler2D NormalTex;
uniform sampler2D ReflMapTex;
uniform sampler2D ReflGradientsTex;
uniform sampler3D ReflNoiseTex;
uniform samplerCube Environment;
uniform sampler2D GrainTex;

uniform int dirt_enabled;
uniform int dirt_multi;
uniform int lightmap_enabled;
uniform int lightmap_multi;
uniform int nmap_dds;
uniform int nmap_enabled;
uniform int refl_enabled;
uniform int refl_map;
uniform int grain_texture_enabled;
uniform int rain_enabled;
uniform int cloud_shadow_flag;
uniform int use_searchlight;
uniform int use_landing_light;
uniform int use_alt_landing_light;

uniform float amb_correction;
uniform float dirt_b_factor;
uniform float dirt_g_factor;
uniform float dirt_r_factor;
uniform float lightmap_a_factor;
uniform float lightmap_b_factor;
uniform float lightmap_g_factor;
uniform float lightmap_r_factor;
uniform float nmap_tile;
uniform float refl_correction;
uniform float refl_fresnel;
uniform float refl_noise;
uniform float refl_rainbow;
uniform float grain_magnification;
uniform float wetness;
uniform float rain_norm;

uniform float avisibility;
uniform float cloud_self_shading;
uniform float eye_alt;
uniform float ground_scattering;
uniform float hazeLayerAltitude;
uniform float moonlight;
uniform float overcast;
uniform float scattering;
uniform float terminator;
uniform float terrain_alt;
uniform float visibility;
uniform float air_pollution;

uniform float osg_SimulationTime;

uniform float landing_light1_offset;
uniform float landing_light2_offset;

// constants needed by the light and fog computations ###################################################

const float EarthRadius = 5800000.0;
const float terminator_width = 200000.0;

uniform vec3 lightmap_r_color;
uniform vec3 lightmap_g_color;
uniform vec3 lightmap_b_color;
uniform vec3 lightmap_a_color;

uniform vec3 dirt_r_color;
uniform vec3 dirt_g_color;
uniform vec3 dirt_b_color;

float DotNoise2D(in vec2 coord, in float wavelength, in float fractionalMaxDotSize, in float dot_density);
float shadow_func (in float x, in float y, in float noise, in float dist);
float fog_func (in float targ, in float altitude);
float rayleigh_in_func(in float dist, in float air_pollution, in float avisibility, in float eye_alt, in float vertex_alt);
float alt_factor(in float eye_alt, in float vertex_alt);
float light_distance_fading(in float dist);
float fog_backscatter(in float avisibility);

vec3 rayleigh_out_shift(in vec3 color, in float outscatter);
vec3 get_hazeColor(in float lightArg);
vec3 searchlight();
vec3 landing_light(in float offset);



float light_func (in float x, in float a, in float b, in float c, in float d, in float e)
    {
    if (x > 30.0) {return e;}
    if (x < -15.0) {return 0.0;}
    return e / pow((1.0 + a * exp(-b * (x-c)) ),(1.0/d));
    }


   


void main (void)
    {
    vec4 texel      = texture2D(BaseTex, gl_TexCoord[0].st);
    vec4 nmap       = texture2D(NormalTex, gl_TexCoord[0].st * nmap_tile);
    vec4 reflmap    = texture2D(ReflMapTex, gl_TexCoord[0].st);
    vec4 noisevec   = texture3D(ReflNoiseTex, rawpos.xyz);
    vec4 lightmapTexel = texture2D(LightMapTex, gl_TexCoord[0].st);

    vec4 grainTexel; 

    vec3 mixedcolor;
    vec3 N = vec3(0.0,0.0,1.0);
    float pf = 0.0;
    float pf1 = 0.0;
    ///some generic light scattering parameters 
    vec3 shadedFogColor = vec3(0.55, 0.67, 0.88);
    vec3 moonLightColor = vec3 (0.095, 0.095, 0.15) * moonlight;
    float alt = eye_alt; 					
    float effective_scattering = min(scattering, cloud_self_shading);


    /// BEGIN geometry for light

    vec3 up = (gl_ModelViewMatrix * vec4(0.0,0.0,1.0,0.0)).xyz;
    //vec4 worldPos3D = (osg_ViewMatrixInverse * vec4 (0.0,0.0,0.0, 1.0));
    //worldPos3D.a = 0.0;
    //vec3 up = (osg_ViewMatrix * worldPos3D).xyz;
    float dist = length(vertVec);
    float vertex_alt = max(100.0,dot(up, vertVec) + alt);
    float vertex_scattering = ground_scattering + (1.0 - ground_scattering) * smoothstep(hazeLayerAltitude -100.0, hazeLayerAltitude + 100.0, vertex_alt); 


    vec3 lightHorizon = gl_LightSource[0].position.xyz - up * dot(up,gl_LightSource[0].position.xyz);
    float yprime = -dot(vertVec, lightHorizon);
    float yprime_alt = yprime - sqrt(2.0 * EarthRadius * vertex_alt);
    float lightArg = (terminator-yprime_alt)/100000.0;

    float earthShade = 0.6 * (1.0 - smoothstep(-terminator_width+ terminator, terminator_width + terminator, yprime_alt)) + 0.4;

    float mie_angle;
    if (lightArg < 10.0)
        {mie_angle = (0.5 *  dot(normalize(vertVec), normalize(gl_LightSource[0].position.xyz)) ) + 0.5;}
    else 
        {mie_angle = 1.0;}

    float fog_vertex_alt = max(vertex_alt,hazeLayerAltitude);
    float fog_yprime_alt = yprime_alt;
    if (fog_vertex_alt > hazeLayerAltitude)
        {
        if (dist > 0.8 * avisibility)
            {
            fog_vertex_alt = mix(fog_vertex_alt, hazeLayerAltitude, smoothstep(0.8*avisibility, avisibility, dist));
            fog_yprime_alt = yprime -sqrt(2.0 * EarthRadius * fog_vertex_alt);
            }
        }
    else
        {
        fog_vertex_alt = hazeLayerAltitude;
        fog_yprime_alt = yprime -sqrt(2.0 * EarthRadius * fog_vertex_alt);
        }

    float fog_lightArg = (terminator-fog_yprime_alt)/100000.0;
    float fog_earthShade = 0.9 * smoothstep(terminator_width+ terminator, -terminator_width + terminator, fog_yprime_alt) + 0.1;

    float ct = dot(normalize(up), normalize(vertVec));

    /// END geometry for light


    /// BEGIN light
    vec4 light_diffuse;
    vec4 light_ambient;
    float intensity;

    light_diffuse.b = light_func(lightArg, 1.330e-05, 0.264, 3.827, 1.08e-05, 1.0);
    light_diffuse.g = light_func(lightArg, 3.931e-06, 0.264, 3.827, 7.93e-06, 1.0);
    light_diffuse.r = light_func(lightArg, 8.305e-06, 0.161, 3.827, 3.04e-05, 1.0);
    light_diffuse.a = 1.0;
    light_diffuse = light_diffuse * vertex_scattering;

    light_ambient.r = light_func(lightArg, 0.236, 0.253, 1.073, 0.572, 0.33);
    light_ambient.g = light_ambient.r * 0.4/0.33; 
    light_ambient.b = light_ambient.r * 0.5/0.33; 
    light_ambient.a = 1.0;

    if (earthShade < 0.5)
        {
        intensity = length(light_ambient.rgb); 
        light_ambient.rgb = intensity * normalize(mix(light_ambient.rgb,  shadedFogColor, 1.0 -smoothstep(0.1, 0.8,earthShade) ));
        light_ambient.rgb = light_ambient.rgb +   moonLightColor *  (1.0 - smoothstep(0.4, 0.5, earthShade));

        intensity = length(light_diffuse.rgb); 
        light_diffuse.rgb = intensity * normalize(mix(light_diffuse.rgb,  shadedFogColor, 1.0 -smoothstep(0.1, 0.7,earthShade) ));
        }


    /// END light

    /// BEGIN grain overlay
    if (grain_texture_enabled ==1)
        {
        grainTexel = texture2D(GrainTex, gl_TexCoord[0].st * grain_magnification);
        texel.rgb = mix(texel.rgb, grainTexel.rgb,  grainTexel.a );
        }
   else if (grain_texture_enabled == 2)
	{
        grainTexel = texture2D(GrainTex, rawpos.xy * grain_magnification);
        texel.rgb = mix(texel.rgb, grainTexel.rgb,  grainTexel.a );
	}

    /// END grain overlay

    ///BEGIN bump
    if (nmap_enabled > 0){
        N = nmap.rgb * 2.0 - 1.0;
        N = normalize(N.x * VTangent + N.y * VBinormal + N.z * VNormal);
        if (nmap_dds > 0)
            N = -N;
        } else {
            N = normalize(VNormal);
        }
    ///END bump
    vec4 reflection = textureCube(Environment, reflVec * dot(N,VNormal));
    vec3 viewVec = normalize(vViewVec);
    float v      = abs(dot(viewVec, normalize(VNormal)));// Map a rainbowish color
    vec4 fresnel = texture2D(ReflGradientsTex, vec2(v, 0.75));
    vec4 rainbow = texture2D(ReflGradientsTex, vec2(v, 0.25));

    float nDotVP = max(0.0, dot(N, normalize(gl_LightSource[0].position.xyz)));
    float nDotHV = max(0.0, dot(N, normalize(gl_LightSource[0].halfVector.xyz)));
    //glare on the backside of tranparent objects
    if ((gl_FrontMaterial.diffuse.a < 1.0 || texel.a < 1.0)
        && dot(N, normalize(gl_LightSource[0].position.xyz)) < 0.0) {
            nDotVP = max(0.0, dot(-N, normalize(gl_LightSource[0].position.xyz)));
            nDotHV = max(0.0, dot(-N, normalize(gl_LightSource[0].halfVector.xyz)));
        }

    float nDotVP1 = 0.0;
    float nDotHV1 = 0.0;

        
    // try specular reflection of sky irradiance
    nDotVP1 = max(0.0, dot(N, up));
    nDotHV1 = max(0.0, dot(N, normalize(normalize(up) + normalize(-vertVec))));
	

    if (nDotVP == 0.0)
	{pf = 0.0;}
    else
        {pf = pow(nDotHV, gl_FrontMaterial.shininess);}
   
   if (nDotVP1 == 0.0)
	{pf1 = 0.0;}
    else
        {pf1 = pow(nDotHV1, 0.5*gl_FrontMaterial.shininess);}
  

    vec3 relPos = (gl_ModelViewMatrixInverse * vec4 (vertVec,0.0)).xyz;		
    if (cloud_shadow_flag == 1) 
	{
	light_diffuse = light_diffuse * shadow_func(relPos.x, relPos.y, 1.0, dist);
	}
 
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


    vec4 Diffuse  = light_diffuse * nDotVP;
    Diffuse.rgb += secondary_light * light_distance_fading(dist);
    vec4 Specular = gl_FrontMaterial.specular * light_diffuse * pf + gl_FrontMaterial.specular * light_ambient * pf1;
    Specular+=  gl_FrontMaterial.specular * pow(max(0.0,-dot(N,normalize(vertVec))),gl_FrontMaterial.shininess) * vec4(secondary_light,1.0);

    vec4 color = gl_Color + Diffuse * gl_FrontMaterial.diffuse;
    color = clamp( color, 0.0, 1.0 );

    ////////////////////////////////////////////////////////////////////
    //BEGIN reflect
    ////////////////////////////////////////////////////////////////////
    if (refl_enabled > 0){
        float reflFactor = 0.0;
        float transparency_offset = clamp(refl_correction, -1.0, 1.0);// set the user shininess offset

        if(refl_map > 0){
            // map the shininess of the object with user input
            //float pam = (map.a * -2) + 1; //reverse map
            reflFactor = reflmap.a + transparency_offset;
            } else if (nmap_enabled > 0) {
                // set the reflectivity proportional to shininess with user input
                reflFactor = gl_FrontMaterial.shininess * 0.0078125 * nmap.a + transparency_offset;
            } else {
                reflFactor = gl_FrontMaterial.shininess* 0.0078125 + transparency_offset;
                }
            reflFactor = clamp(reflFactor, 0.0, 1.0);

            // add fringing fresnel and rainbow effects and modulate by reflection
            vec4 reflcolor = mix(reflection, rainbow, refl_rainbow * v);
            //vec4 reflcolor = reflection;
            vec4 reflfrescolor = mix(reflcolor, fresnel, refl_fresnel  * v);
            vec4 noisecolor = mix(reflfrescolor, noisevec, refl_noise);
            vec4 raincolor = vec4(noisecolor.rgb * reflFactor, 1.0);
            raincolor += Specular;
            raincolor *= light_diffuse;
            mixedcolor = mix(texel, raincolor, reflFactor).rgb;
        } else {
            mixedcolor = texel.rgb;
        }
    /////////////////////////////////////////////////////////////////////
    //END reflect
    /////////////////////////////////////////////////////////////////////

    //////////////////////////////////////////////////////////////////////
    //begin DIRT
    //////////////////////////////////////////////////////////////////////
    if (dirt_enabled >= 1){
        vec3 dirtFactorIn = vec3 (dirt_r_factor, dirt_g_factor, dirt_b_factor);
        vec3 dirtFactor = reflmap.rgb * dirtFactorIn.rgb;
        //dirtFactor.r = smoothstep(0.0, 1.0, dirtFactor.r);
        mixedcolor.rgb = mix(mixedcolor.rgb, dirt_r_color, smoothstep(0.0, 1.0, dirtFactor.r));
        if (dirt_multi > 0) {
            //dirtFactor.g = smoothstep(0.0, 1.0, dirtFactor.g);
            //dirtFactor.b = smoothstep(0.0, 1.0, dirtFactor.b);
            mixedcolor.rgb = mix(mixedcolor.rgb, dirt_g_color, smoothstep(0.0, 1.0, dirtFactor.g));
            mixedcolor.rgb = mix(mixedcolor.rgb, dirt_b_color, smoothstep(0.0, 1.0, dirtFactor.b));
            }
        }
    //////////////////////////////////////////////////////////////////////
    //END Dirt
    //////////////////////////////////////////////////////////////////////

    //////////////////////////////////////////////////////////////////////
    //begin WETNESS
    //////////////////////////////////////////////////////////////////////

    if (rain_enabled >0.0)
	{
    	texel.rgb = texel.rgb * (1.0 - 0.6 * wetness);
    	float rain_factor = 0.0;
    	if (rain_norm > 0.0)
		{
    		rain_factor += DotNoise2D(rawpos.xy, 0.2 ,0.5, rain_norm) * abs(sin(6.0*osg_SimulationTime));
    		rain_factor += DotNoise2D(rawpos.xy, 0.3 ,0.4, rain_norm) * abs(sin(6.0*osg_SimulationTime + 2.094));
    		rain_factor += DotNoise2D(rawpos.xy, 0.4 ,0.3, rain_norm)* abs(sin(6.0*osg_SimulationTime + 4.188));
		}

    	// secondary reflection of sky irradiance in water film
    	float fresnelW =  ((0.8 * wetness) ) *  (1.0-smoothstep(0.0,0.4, dot(N,-normalize(vertVec)) * 1.0 - 0.2 * rain_factor * wetness));
    	float sky_factor = (1.0-ct*ct);
    	vec3 sky_light = vec3 (1.0,1.0,1.0) * length(light_diffuse.rgb) * (1.0-effective_scattering);
    	Specular.rgb += sky_factor * fresnelW  * sky_light;
	}
    /////////////////////////////////////////////////////////////////////
    //end WETNESS
    //////////////////////////////////////////////////////////////////////


    // set ambient adjustment to remove bluiness with user input
    float ambient_offset = clamp(amb_correction, -1.0, 1.0);
    //vec4 ambient = gl_LightModel.ambient + gl_LightSource[0].ambient;
    vec4 ambient = gl_LightModel.ambient + light_ambient;
    vec4 ambient_Correction = vec4(ambient.rg, ambient.b * 0.6, 1.0)
        * ambient_offset ;
    ambient_Correction = clamp(ambient_Correction, -1.0, 1.0);

    color.a = texel.a * alpha;
    vec4 fragColor = vec4(color.rgb * mixedcolor + ambient_Correction.rgb, color.a);

    fragColor += Specular * nmap.a;

    //////////////////////////////////////////////////////////////////////
    // BEGIN lightmap
    //////////////////////////////////////////////////////////////////////
    if ( lightmap_enabled >= 1 ) {
        vec3 lightmapcolor = vec3(0.0);
        vec4 lightmapFactor = vec4(lightmap_r_factor, lightmap_g_factor,
            lightmap_b_factor, lightmap_a_factor);
        lightmapFactor = lightmapFactor * lightmapTexel;
        if (lightmap_multi > 0 ){
            lightmapcolor = lightmap_r_color * lightmapFactor.r +
                lightmap_g_color * lightmapFactor.g +
                lightmap_b_color * lightmapFactor.b +
                lightmap_a_color * lightmapFactor.a ;
            } else {
                lightmapcolor = lightmapTexel.rgb * lightmap_r_color * lightmapFactor.r;
            }
        fragColor.rgb = max(fragColor.rgb, lightmapcolor * gl_FrontMaterial.diffuse.rgb * smoothstep(0.0, 1.0, mixedcolor*.5 + lightmapcolor*.5));
        }
    //////////////////////////////////////////////////////////////////////
    // END lightmap
    /////////////////////////////////////////////////////////////////////


    /// BEGIN fog amount

    float transmission;
    float vAltitude;
    float delta_zv;
    float H;
    float distance_in_layer;
    float transmission_arg;
    float eqColorFactor;

    float delta_z = hazeLayerAltitude - eye_alt;
    float mvisibility = min(visibility, avisibility);

    if (dist >  0.04 * mvisibility) 
        {
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

        transmission_arg = (dist-distance_in_layer)/avisibility;


        if (visibility < avisibility)
            {
            transmission_arg = transmission_arg + (distance_in_layer/visibility);
            eqColorFactor = 1.0 - 0.1 * delta_zv/visibility - (1.0 -effective_scattering);
            }
        else 
            {
            transmission_arg = transmission_arg + (distance_in_layer/avisibility);
            eqColorFactor = 1.0 - 0.1 * delta_zv/avisibility - (1.0 -effective_scattering);
            }
        transmission =  fog_func(transmission_arg, alt);
        if (eqColorFactor < 0.2) eqColorFactor = 0.2;
        }
    else
        {
        eqColorFactor = 1.0;
        transmission = 1.0;
        }

    /// END fog amount

    /// BEGIN fog color

    vec3 hazeColor = get_hazeColor(fog_lightArg);

	float rShade = 1.0 - 0.9 * smoothstep(-terminator_width+ terminator, terminator_width + terminator, yprime_alt + 420000.0);
	float lightIntensity = length(hazeColor * effective_scattering) * rShade;

    if (transmission<  1.0)
        {

        

        if (fog_lightArg < 10.0)
            {
            intensity = length(hazeColor);
            float mie_magnitude = 0.5 * smoothstep(350000.0, 150000.0, terminator-sqrt(2.0 * EarthRadius * terrain_alt));
            hazeColor = intensity * ((1.0 - mie_magnitude) + mie_magnitude * mie_angle) * normalize(mix(hazeColor,  vec3 (0.5, 0.58, 0.65), mie_magnitude * (0.5 - 0.5 * mie_angle)) ); 
            }

        intensity = length(hazeColor);
        hazeColor = intensity * normalize (mix(hazeColor, intensity * vec3 (1.0,1.0,1.0), 0.7* smoothstep(5000.0, 50000.0, alt)));

        hazeColor.r = hazeColor.r * 0.83;
        hazeColor.g = hazeColor.g * 0.9; 

        float fade_out = max(0.65 - 0.3 *overcast, 0.45);
        intensity = length(hazeColor);
        hazeColor = intensity * normalize(mix(hazeColor,  1.5* shadedFogColor, 1.0 -smoothstep(0.25, fade_out,fog_earthShade) )); 
        hazeColor = intensity * normalize(mix(hazeColor,  shadedFogColor, (1.0-smoothstep(0.5,0.9,eqColorFactor)))); 

        float shadow = mix( min(1.0 + dot(VNormal,gl_LightSource[0].position.xyz),1.0), 1.0, 1.0-smoothstep(0.1, 0.4, transmission));
        hazeColor = mix(shadow * hazeColor, hazeColor, 0.3 + 0.7* smoothstep(250000.0, 400000.0, terminator));
        }
    else
        {
        hazeColor = vec3 (1.0, 1.0, 1.0);
        }


    /// END fog color
	fragColor = clamp(fragColor, 0.0, 1.0);
    	//hazeColor = clamp(hazeColor, 0.0, 1.0);

    ///BEGIN Rayleigh fog ///

    	// Rayleigh color shift due to out-scattering
    	float rayleigh_length = 0.5 * avisibility * (2.5 - 1.9 * air_pollution)/alt_factor(eye_alt, eye_alt+relPos.z);
    	float outscatter = 1.0-exp(-dist/rayleigh_length);
    	fragColor.rgb = rayleigh_out_shift(fragColor.rgb,outscatter);

	vec3 rayleighColor = vec3 (0.17, 0.52, 0.87) * lightIntensity;
   	float rayleighStrength = rayleigh_in_func(dist, air_pollution, avisibility/max(lightIntensity,0.05), eye_alt, eye_alt + relPos.z);
  	fragColor.rgb = mix(fragColor.rgb, rayleighColor,rayleighStrength);

    /// END Rayleigh fog

    // don't let the light fade out too rapidly
	lightArg = (terminator + 200000.0)/100000.0;
	float minLightIntensity = min(0.2,0.16 * lightArg + 0.5);
	vec3 minLight = minLightIntensity * vec3 (0.2, 0.3, 0.4);
	hazeColor *= eqColorFactor * fog_earthShade;
	hazeColor.rgb = max(hazeColor.rgb, minLight.rgb);


      fragColor.rgb = mix(hazeColor +secondary_light * fog_backscatter(mvisibility), fragColor.rgb,transmission);
    gl_FragColor = fragColor;
    }
