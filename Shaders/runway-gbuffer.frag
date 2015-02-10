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

void encode_gbuffer(vec3 normal, vec3 color, int mId, float specular, float shininess, float emission, float depth);

void main (void)
{

    vec4 texel = texture2D(BaseTex, gl_TexCoord[0].st);
    vec4 nmap  = texture2D(NormalTex, gl_TexCoord[0].st * 8.0);
    vec4 map   = texture2D(Map, gl_TexCoord[0].st * 8.0);
    vec4 specNoise = texture3D(Noise, rawpos.xyz * 0.0045);
    vec4 noisevec = texture3D(Noise, rawpos.xyz);
    vec3 ambient = vec3(0.85,0.85,0.9);//placeholder for sun ambient
    vec3 N;
    float emission = dot( gl_FrontLightModelProduct.sceneColor.rgb + gl_FrontMaterial.emission.rgb,
                          vec3( 0.3, 0.59, 0.11 ) );

    N = nmap.rgb * 2.0 - 1.0;
    N = normalize(N.x * VTangent + N.y * VBinormal + N.z * VNormal);
    if (normalmap_dds > 0)
        N = -N;

    float nFactor = 1.0 - N.z;
    float lightness = dot(texel.rgb, vec3( 0.3, 0.59, 0.11 ));

    // calculate the specular light
    float refl_correction = spec_adjust * 2.5 - 1.0;
    float shininess = max (0.35, refl_correction) * nmap.a * nFactor;


    float specular = dot(vec3(1.0) * lightness , vec3( 0.3, 0.59, 0.11 )) * nFactor;

    vec4 color = vec4(1.0);

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

    reflFactor = max(map.a * (texel.r + texel.g), 1.0 - MixFactor)  * nFactor  + transparency_offset ;
    reflFactor =0.75 * smoothstep(0.05, 1.0, reflFactor);

    // set ambient adjustment to remove bluiness with user input
    float ambient_offset = clamp(ambient_correction, -1.0, 1.0);
    vec3 ambient_Correction = vec3(ambient.rg, ambient.b * 0.6) * ambient_offset;
    ambient_Correction = clamp(ambient_Correction, -1.0, 1.0);

    // add fringing fresnel and rainbow effects and modulate by reflection
    vec4 reflcolor = mix(reflection, rainbow, rainbowiness * v);

    vec4 reflfrescolor = mix(reflcolor, fresnel, fresneliness * v);
    vec4 noisecolor = mix(reflfrescolor, noisevec, noisiness);
    vec4 raincolor = vec4(noisecolor.rgb * reflFactor, 1.0) * nFactor;
    vec4 mixedcolor = mix(texel, raincolor * (1.0 - refl_correction * (1.0 - lightness)), reflFactor);

    // the final reflection
    vec4 fragColor = vec4(color.rgb * mixedcolor.rgb  + ambient_Correction * nFactor, color.a);
    float doWater = step(0.1,  reflFactor);
    int matIndex = int(doWater) * 253 + 1;
    shininess += doWater * reflFactor * 240.0;

    encode_gbuffer(N, fragColor.rgb, matIndex, specular, shininess, emission, gl_FragCoord.z);
}
