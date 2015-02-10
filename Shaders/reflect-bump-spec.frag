// -*- mode: C; -*-
// Licence: GPL v2
// Author: Vivian Meazza.

#version 120

varying vec3  rawpos;
varying vec3  VNormal;
varying vec3  VTangent;
varying vec3  VBinormal;
varying vec3  Normal;
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

uniform float refl_correction;
uniform float rainbowiness;
uniform float fresneliness;
uniform float noisiness;
uniform float ambient_correction;
uniform float reflect_map;
uniform float normalmap_dds;

////fog "include" /////
uniform int fogType;

vec3 fog_Func(vec3 color, int type);
//////////////////////

void main (void)
{
    vec3 halfV;
    float NdotL, NdotHV;

    vec3 lightDir = gl_LightSource[0].position.xyz;
    vec3 halfVector = gl_LightSource[0].halfVector.xyz;


    vec4 color = gl_Color;
    vec4 specular = vec4(0.0);
    vec4 ns = texture2D(NormalTex, gl_TexCoord[0].st);
    vec3 n = ns.rgb * 2.0 - 1.0;
    n = normalize(n.x * VTangent + n.y * VBinormal + n.z * VNormal);

    //fix dds normal
    if (normalmap_dds > 0.0) {
    n = -n;
    }

    NdotL = max(0.0, dot(n, lightDir));

    // calculate the specular light
    if (NdotL > 0.0) {
        color += Diffuse * NdotL;
        halfV = normalize(halfVector);
        NdotHV = max(dot(n, halfV), 0.0);
        if (gl_FrontMaterial.shininess > 0.0)
            specular.rgb = (gl_FrontMaterial.specular.rgb * ns.a
            * gl_LightSource[0].specular.rgb
            * pow(NdotHV, gl_FrontMaterial.shininess));
    }

    //color.a = alpha;
    vec4 texel = texture2D(BaseTex, gl_TexCoord[0].st);
    //vec4 texelcolor = color * texel + specular;
    color.a = texel.a * alpha;
    color = clamp(color, 0.0, 1.0);

    // calculate the fog factor
//     const float LOG2 = 1.442695;
//     float fogFactor = exp2(-gl_Fog.density * gl_Fog.density * fogCoord * fogCoord * LOG2);
//     fogFactor = clamp(fogFactor, 0.0, 1.0);
//
//     if(gl_Fog.density == 1.0)
//         fogFactor=1.0;

    vec3 normal = normalize(VNormal);
    vec3 viewVec = normalize(vViewVec);

    // Map a rainbowish color
    float v = dot(viewVec, normal);
    vec4 rainbow = texture2D(Rainbow, vec2(v, 0.0));

    // Map a fresnel effect
    vec4 fresnel = texture2D(Fresnel, vec2(v, 0.0));

    // map the refection of the environment
    vec4 reflection = textureCube(Environment, reflVec);

    // set the user shininess offse
    float transparency_offset = clamp(refl_correction, -1.0, 1.0);
    float reflFactor = 0.0;

    if(reflect_map > 0.0){
        // map the shininess of the object with user input
        vec4 map = texture2D(Map, gl_TexCoord[0].st);
        //float pam = (map.a * -2) + 1; //reverse map
        reflFactor = map.a + transparency_offset;
    } else {
        // set the reflectivity proportional to shininess with user input
        reflFactor = (gl_FrontMaterial.shininess / 128.0) * ns.a + transparency_offset;
    }

    reflFactor = clamp(reflFactor, 0.0, 1.0);

    // set ambient adjustment to remove bluiness with user input
    float ambient_offset = clamp(ambient_correction, -1.0, 1.0);
    vec4 ambient_Correction = vec4(gl_LightSource[0].ambient.rg, gl_LightSource[0].ambient.b * 0.6, 0.5) * ambient_offset ;
    ambient_Correction = clamp(ambient_Correction, -1.0, 1.0);

    // map noise vector
    vec4 noisevec = texture3D(Noise, rawpos.xyz);

    // add fringing fresnel and rainbow effects and modulate by reflection
    vec4 reflcolor = mix(reflection, rainbow, rainbowiness * v);
    vec4 reflfrescolor = mix(reflcolor, fresnel, fresneliness * v);
    vec4 noisecolor = mix(reflfrescolor, noisevec, noisiness);
    vec4 raincolor = vec4(noisecolor.rgb * reflFactor, 1.0);

    vec4 mixedcolor = mix(texel, raincolor, reflFactor);

    // the final reflection
    vec4 reflColor = vec4(color.rgb * mixedcolor.rgb + specular.rgb + ambient_Correction.rgb, color.a);

    reflColor = clamp(reflColor, 0.0, 1.0);

//     gl_FragColor = mix(gl_Fog.color, reflColor, fogFactor);
		reflColor.rgb = fog_Func(reflColor.rgb, fogType);
		gl_FragColor = reflColor;
}