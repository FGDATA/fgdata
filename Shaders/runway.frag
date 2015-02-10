// -*- mode: C; -*-
// Licence: GPL v2
// © Emilian Huminiuc and Vivian Meazza 2011

#version 120

varying vec3  rawpos;
varying vec3  VNormal;
varying vec3  VTangent;
varying vec3  VBinormal;
varying vec3  vViewVec;
varying vec3  reflVec;

varying vec4 Diffuse;
varying float alpha;
//varying float fogCoord;

uniform samplerCube Environment;
uniform sampler2D Rainbow;
uniform sampler2D BaseTex;
uniform sampler2D Fresnel;
uniform sampler2D Map;
uniform sampler2D NormalTex;
uniform sampler3D Noise;

uniform float spec_adjust;
uniform float rainbowiness;
uniform float fresneliness;
uniform float noisiness;
uniform float ambient_correction;
uniform float normalmap_dds;

//uniform int fogType;

////fog "include" /////
uniform int fogType;

vec3 fog_Func(vec3 color, int type);
//////////////////////

void main (void)
{
    //vec3 halfV;
    //float NdotL, NdotHV;

    vec4 texel = texture2D(BaseTex, gl_TexCoord[0].st);
    vec4 nmap  = texture2D(NormalTex, gl_TexCoord[0].st * 8.0);
    vec4 map   = texture2D(Map, gl_TexCoord[0].st * 8.0);
    vec4 specNoise = texture3D(Noise, rawpos.xyz * 0.0045);
    vec4 noisevec = texture3D(Noise, rawpos.xyz);

    vec3 lightDir = gl_LightSource[0].position.xyz;
    vec3 halfVector = gl_LightSource[0].halfVector.xyz;
    vec3 N;
    float pf;

    N = nmap.rgb * 2.0 - 1.0;
    N = normalize(N.x * VTangent + N.y * VBinormal + N.z * VNormal);
    if (normalmap_dds > 0)
        N = -N;

	float lightness = dot(texel.rgb, vec3( 0.3, 0.59, 0.11 ));
    // calculate the specular light
    float refl_correction = spec_adjust * 2.5 - 1.0;
    float shininess = max (0.35, refl_correction);
    float nDotVP = max(0.0, dot(N, normalize(gl_LightSource[0].position.xyz)));
    float nDotHV = max(0.0, dot(N, normalize(gl_LightSource[0].halfVector.xyz)));

    if (nDotVP == 0.0)
        pf = 0.0;
    else
        pf = pow(nDotHV, /*gl_FrontMaterial.*/shininess);

    vec4 Diffuse  = gl_LightSource[0].diffuse * nDotVP;
    //vec4 Specular = vec4(vec3(0.5*shininess), 1.0)* gl_LightSource[0].specular * pf;
	vec4 Specular = vec4(1.0)* lightness * gl_LightSource[0].specular * pf;

    vec4 color = gl_Color + Diffuse * gl_FrontMaterial.diffuse;
    //color += Specular * vec4(vec3(0.5*shininess), 1.0) * nmap.a;
	float nFactor = 1.0 - N.z;
	color += Specular * vec4(1.0) * nmap.a * nFactor;
    color.a = texel.a * alpha;
    color = clamp(color, 0.0, 1.0);

    vec3 viewVec = normalize(vViewVec);

    // Map a rainbowish color
    float v = abs(dot(viewVec, normalize(VNormal)));
    vec4 rainbow = texture2D(Rainbow, vec2(v, 0.0));

    // Map a fresnel effect
    vec4 fresnel = texture2D(Fresnel, vec2(v, 0.0));

    // map the refection of the environment
    vec4 reflection = textureCube(Environment, reflVec * dot(N,VNormal));


    // set the user shininess offset
    float transparency_offset = clamp(refl_correction, -1.0, 1.0);
    float reflFactor = 0.0;

    float MixFactor = specNoise.r * specNoise.g * specNoise.b * 350.0;

    MixFactor = 0.75 * smoothstep(0.0, 1.0, MixFactor);

    reflFactor = max(map.a * (texel.r + texel.g), 1.0 - MixFactor)  * (1.0- N.z)  + transparency_offset ;

    reflFactor =0.75 * smoothstep(0.05, 1.0, reflFactor);

    // set ambient adjustment to remove bluiness with user input
    float ambient_offset = clamp(ambient_correction, -1.0, 1.0);
    vec4 ambient_Correction = vec4(gl_LightSource[0].ambient.rg, gl_LightSource[0].ambient.b * 0.6, 0.5) * ambient_offset ;
    ambient_Correction = clamp(ambient_Correction, -1.0, 1.0);

    // add fringing fresnel and rainbow effects and modulate by reflection
    vec4 reflcolor = mix(reflection, rainbow, rainbowiness * v);
    reflcolor += Specular * nmap.a * nFactor;
    vec4 reflfrescolor = mix(reflcolor, fresnel, fresneliness * v);
    vec4 noisecolor = mix(reflfrescolor, noisevec, noisiness);
    vec4 raincolor = vec4(noisecolor.rgb * reflFactor, 1.0);
    raincolor += Specular * nmap.a * nFactor;


	vec4 mixedcolor = mix(texel, raincolor * (1.0 - refl_correction * (1.0 - lightness)), reflFactor);  //* (1.0 - 0.5 * transparency_offset )

    // the final reflection
    vec4 fragColor = vec4(color.rgb * mixedcolor.rgb  + ambient_Correction.rgb * (1.0 - refl_correction * (1.0 - 0.8 * lightness)) * nFactor, color.a);
	fragColor += Specular * nmap.a * nFactor;

    fragColor.rgb = fog_Func(fragColor.rgb, fogType);
    gl_FragColor = fragColor;
}