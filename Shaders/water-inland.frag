// This shader is mostly an adaptation of the shader found at
//  http://www.bonzaisoftware.com/water_tut.html and its glsl conversion
//  available at http://forum.bonzaisoftware.com/viewthread.php?tid=10
//  © Michael Horsch - 2005

#version 120
uniform sampler2D water_normalmap;
uniform sampler2D water_reflection;
uniform sampler2D water_dudvmap;
uniform sampler2D water_reflection_grey;

uniform float saturation;
uniform float CloudCover0, CloudCover1, CloudCover2, CloudCover3, CloudCover4;

varying vec4 waterTex1; //moving texcoords
varying vec4 waterTex2; //moving texcoords
varying vec4 waterTex4; //viewts
//varying vec4 ecPosition;
varying vec3 viewerdir;
varying vec3 lightdir;
varying vec3 normal;

////fog "include" /////
uniform int fogType;

vec3 fog_Func(vec3 color, int type);
//////////////////////

void main(void)
{
    const vec4 sca = vec4(0.005, 0.005, 0.005, 0.005);
    const vec4 sca2 = vec4(0.02, 0.02, 0.02, 0.02);
    const vec4 tscale = vec4(0.25, 0.25, 0.25, 0.25);

    // compute direction to viewer
    vec3 E = normalize(viewerdir);

    // compute direction to light source
    vec3 L = normalize(lightdir);

    // half vector
    vec3 H = normalize(L + E);

    const float water_shininess = 240.0;

    // approximate cloud cover
    float cover = 0.0;
    cover = min(min(min(min(CloudCover0, CloudCover1),CloudCover2),CloudCover3),CloudCover4);

    vec4 viewt = normalize(waterTex4);

    vec4 disdis = texture2D(water_dudvmap, vec2(waterTex2 * tscale)) * 2.0 - 1.0;
    vec4 dist = texture2D(water_dudvmap, vec2(waterTex1 + disdis*sca2)) * 2.0 - 1.0;
    vec4 fdist = normalize(dist);
    fdist *= sca;

    //normalmap
    vec4 nmap0 = texture2D(water_normalmap, vec2(waterTex1+ disdis*sca2)) * 2.0 - 1.0;
    vec4 nmap2 = texture2D(water_normalmap, vec2(waterTex2 * tscale)) * 2.0 - 1.0;
    vec4 vNorm = normalize(nmap0 + nmap2);

    //load reflection
    vec4 tmp = vec4(lightdir, 0.0);
    vec4 refTex;
    vec4 baseTex;
    vec4 greyTex;
    vec4 refl;
    vec4 base;
    vec4 grey;

    baseTex = texture2D(water_reflection, vec2(tmp));
    base = normalize(baseTex);
    greyTex = texture2D(water_reflection_grey, vec2(tmp));
    grey = normalize(greyTex);

    //cover = 3;

    if(cover >= 1.5){
        refl = mix(base, grey, 0.35);
        refl.r *= (0.93);
        refl.g *= (0.95);
        refl.b *= (1.0);
        refl.a  *= 1.0;

    } else {
        refl = mix(base, grey, 0.45);
        refl.r *= (0.70 + 0.15 * cover);
        refl.g *= (0.80 + 0.15 * cover);
        refl.b *= (0.85 + 0.125 * cover);
        refl.a  *= 1.0;
    }

    vec3 N0 = vec3(texture2D(water_normalmap, vec2(waterTex1+ disdis*sca2)) * 2.0 - 1.0);
    vec3 N1 = vec3(texture2D(water_normalmap, vec2(waterTex2 * tscale)) * 2.0 - 1.0);
    vec3 N = normalize(normal+N0+N1);

    // specular
    vec3 specular_color = vec3(gl_LightSource[0].diffuse)
        * pow(max(0.0, dot(N, H)), water_shininess) * 6.0;
    vec4 specular = vec4(specular_color, 0.5);
    specular = specular * saturation;

    //calculate fresnel
    vec4 invfres = vec4( dot(vNorm, viewt) );
    vec4 fres = vec4(1.0) + invfres;
    refl *= fres;

    //calculate the fog factor
//     float fogFactor;
//     float fogCoord = ecPosition.z;
//     const float LOG2 = 1.442695;
//     fogFactor = exp2(-gl_Fog.density * gl_Fog.density * fogCoord * fogCoord * LOG2);
//
//     if(gl_Fog.density == 1.0)
//         fogFactor=1.0;

    //calculate final colour
    vec4 ambient_light = gl_LightSource[0].diffuse;
    vec4 finalColor;

        //cover = 3;

    if(cover >= 1.5){
        finalColor = refl + specular;
    } else {
        finalColor = refl;
    }

    finalColor *= ambient_light;

//     gl_FragColor = mix(gl_Fog.color, finalColor, fogFactor);
		finalColor.rgb = fog_Func(finalColor.rgb, fogType);
		gl_FragColor = finalColor;
}
