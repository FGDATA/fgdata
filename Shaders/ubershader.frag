// -*- mode: C; -*-
// Licence: GPL v2
// Authors: Frederic Bouvier and Gijs de Rooy
// with major additions and revisions by
// Emilian Huminiuc and Vivian Meazza 2011
#version 120

varying	vec3 	VBinormal;
varying	vec3 	VNormal;
varying	vec3 	VTangent;
varying	vec3 	rawpos;
varying	vec3 	reflVec;
varying	vec3 	vViewVec;

varying	float	alpha;

uniform sampler2D BaseTex;
uniform sampler2D LightMapTex;
uniform sampler2D NormalTex;
uniform sampler2D ReflGradientsTex;
uniform sampler2D ReflMapTex;
uniform sampler3D ReflNoiseTex;
uniform samplerCube Environment;

uniform int dirt_enabled;
uniform int dirt_multi;
uniform int lightmap_enabled;
uniform int lightmap_multi;
uniform int nmap_dds;
uniform int nmap_enabled;
uniform int refl_enabled;
uniform int refl_map;

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

uniform vec3 lightmap_r_color;
uniform vec3 lightmap_g_color;
uniform vec3 lightmap_b_color;
uniform vec3 lightmap_a_color;

uniform vec3 dirt_r_color;
uniform vec3 dirt_g_color;
uniform vec3 dirt_b_color;

///fog include//////////////////////
uniform int fogType;
vec3 fog_Func(vec3 color, int type);
////////////////////////////////////

void main (void)
{
	vec4 texel      = texture2D(BaseTex, gl_TexCoord[0].st);
	vec4 nmap       = texture2D(NormalTex, gl_TexCoord[0].st * nmap_tile);
	vec4 reflmap    = texture2D(ReflMapTex, gl_TexCoord[0].st);
	vec4 noisevec   = texture3D(ReflNoiseTex, rawpos.xyz);
	vec4 lightmapTexel = texture2D(LightMapTex, gl_TexCoord[0].st);

	vec3 mixedcolor;
	vec3 N = vec3(0.0,0.0,1.0);
	float pf = 0.0;

///BEGIN bump
 	if (nmap_enabled > 0 ){
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

	if (nDotVP == 0.0)
		pf = 0.0;
	else
		pf = pow(nDotHV, gl_FrontMaterial.shininess);

	vec4 Diffuse  = gl_LightSource[0].diffuse * nDotVP;
	vec4 Specular = gl_FrontMaterial.specular * gl_LightSource[0].diffuse * pf;

	vec4 color = gl_Color + Diffuse * gl_FrontMaterial.diffuse;
	color = clamp( color, 0.0, 1.0 );

////////////////////////////////////////////////////////////////////
//BEGIN reflect
////////////////////////////////////////////////////////////////////
	if (refl_enabled > 0 ){
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
		vec4 reflfrescolor = mix(reflcolor, fresnel, refl_fresnel  * v);
		vec4 noisecolor = mix(reflfrescolor, noisevec, refl_noise);
		vec4 raincolor = vec4(noisecolor.rgb * reflFactor, 1.0);
		raincolor += Specular;
		raincolor *= gl_LightSource[0].diffuse;
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


	// set ambient adjustment to remove bluiness with user input
	float ambient_offset = clamp(amb_correction, -1.0, 1.0);
	vec4 ambient = gl_LightModel.ambient + gl_LightSource[0].ambient;
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

	fragColor.rgb = fog_Func(fragColor.rgb, fogType);
	gl_FragColor = fragColor;
}
