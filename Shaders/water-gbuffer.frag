// This shader is mostly an adaptation of the shader found at
//  http://www.bonzaisoftware.com/water_tut.html and its glsl conversion
//  available at http://forum.bonzaisoftware.com/viewthread.php?tid=10
//  © Michael Horsch - 2005
//  Major update and revisions - 2011-10-07
//  © Emilian Huminiuc and Vivian Meazza
//  Optimisation - 2012-5-05
//  Based on ideas by Thorsten Renk
//  © Emilian Huminiuc and Vivian Meazza

#version 120

uniform sampler2D	water_normalmap;
uniform sampler2D	water_reflection;
uniform sampler2D	water_dudvmap;
uniform sampler2D	water_reflection_grey;
uniform sampler2D	sea_foam;
uniform sampler2D	perlin_normalmap;

uniform float	CloudCover0;
uniform float	CloudCover1;
uniform float	CloudCover2;
uniform float	CloudCover3;
uniform float	CloudCover4;
uniform float	Overcast;
uniform float	WaveAmp;
uniform float	WaveFreq;
uniform float	WaveSharp;
uniform float	WindE;
uniform float	WindN;
uniform float	normalmap_dds;
uniform float	osg_SimulationTime;
uniform float	saturation;

uniform int		Status;

varying vec4	waterTex1; //moving texcoords
varying vec4	waterTex2; //moving texcoords
varying vec3	viewerdir;
varying vec3	normal;
varying vec3	rawNormal;
varying vec3	VTangent;
varying vec3	VBinormal;


/////// functions /////////
void encode_gbuffer(vec3 normal, vec3 color, int mId, float specular, float shininess, float emission, float depth);

void rotationmatrix(in float angle, out mat4 rotmat)
    {
    rotmat = mat4( cos( angle ), -sin( angle ), 0.0, 0.0,
        sin( angle ),  cos( angle ), 0.0, 0.0,
        0.0         ,  0.0         , 1.0, 0.0,
        0.0         ,  0.0         , 0.0, 1.0 );
    }

void main(void)
    {
    const vec4 sca = vec4(0.005, 0.005, 0.005, 0.005);
    const vec4 sca2 = vec4(0.02, 0.02, 0.02, 0.02);
    const vec4 tscale = vec4(0.25, 0.25, 0.25, 0.25);

    mat4 RotationMatrix;
    // compute direction to viewer
    vec3 E = normalize(viewerdir);

    vec3 Normal = normalize(normal);
    vec3 vNormal = normalize(rawNormal);

    const float water_shininess = 240.0;

    // approximate cloud cover
    float cover = 0.0;
    //bool Status = true;


    float windEffect = sqrt( WindE*WindE + WindN*WindN ) * 0.6; 				         //wind speed in kt
    float windScale = 15.0/(3.0 + windEffect);											//wave scale
    float windEffect_low = 0.3 + 0.7 * smoothstep(0.0, 5.0, windEffect);				//low windspeed wave filter
    float waveRoughness = 0.05 + smoothstep(0.0, 20.0, windEffect);						//wave roughness filter

    float mixFactor = 0.75 - 0.15 * smoothstep(0.0, 40.0, windEffect);
    mixFactor = clamp(mixFactor, 0.3, 0.8);

    if (Status == 1){
        cover = min(min(min(min(CloudCover0, CloudCover1),CloudCover2),CloudCover3),CloudCover4);
        } else {
            // hack to allow for Overcast not to be set by Local Weather
            if (Overcast == 0.0){
                cover = 5.0;
                } else {
                    cover = Overcast * 5.0;
                }
        }

    vec4 viewt = vec4(-E, 0.0) * 0.6;

    vec4 disdis = texture2D(water_dudvmap, vec2(waterTex2 * tscale)* windScale) * 2.0 - 1.0;

    vec4 dist   = texture2D(water_dudvmap, vec2(waterTex1 + disdis*sca2)* windScale) * 2.0 - 1.0;
    dist *= (0.6 + 0.5 * smoothstep(0.0, 15.0, windEffect));
    vec4 fdist  = normalize(dist);
    if (normalmap_dds > 0)
        fdist = -fdist; //dds fix
    fdist *= sca;

    //normalmaps
    rotationmatrix(radians(3.0 * windScale + 0.6 * sin(waterTex1.s * 0.2)), RotationMatrix);
    vec4 nmap   = texture2D(water_normalmap, vec2(waterTex1* RotationMatrix + disdis * sca2) * windScale) * 2.0 - 1.0;
    vec4 nmap1  = texture2D(perlin_normalmap, vec2(waterTex1/** RotationMatrix*/ + disdis * sca2) * windScale) * 2.0 - 1.0;

    rotationmatrix(radians(-2.0 * windScale -0.4 * sin(waterTex1.s * 0.32)), RotationMatrix);
    nmap  += texture2D(water_normalmap, vec2(waterTex1* RotationMatrix + disdis * sca2) * windScale * 1.5) * 2.0 - 1.0;
    //nmap1 += texture2D(perlin_normalmap, vec2(waterTex1* RotationMatrix + disdis * sca2) * windScale) * 2.0 - 1.0;
    rotationmatrix(radians(1.5 * windScale + 0.3 * sin(waterTex1.s * 0.16)), RotationMatrix);
    nmap  += texture2D(water_normalmap, vec2(waterTex1* RotationMatrix + disdis * sca2) * windScale * 2.1) * 2.0 - 1.0;
    rotationmatrix(radians(-0.5 * windScale - 0.45 * sin(waterTex1.s * 0.28)), RotationMatrix);
    nmap  += texture2D(water_normalmap, vec2(waterTex1* RotationMatrix + disdis * sca2) * windScale * 0.8) * 2.0 - 1.0;

    rotationmatrix(radians(-1.2 * windScale - 0.35 * sin(waterTex1.s * 0.28)), RotationMatrix);
    nmap  += texture2D(water_normalmap, vec2(waterTex2 * RotationMatrix* tscale) * windScale * 1.7) * 2.0 - 1.0;
    nmap1 += texture2D(perlin_normalmap, vec2(waterTex2/** RotationMatrix*/ * tscale) * windScale) * 2.0 - 1.0;

    nmap  *= windEffect_low;
    nmap1 *= windEffect_low;
    // mix water and noise, modulated by factor
    vec4 vNorm = normalize(mix(nmap, nmap1, mixFactor) * waveRoughness);
    if (normalmap_dds > 0)
        vNorm = -vNorm;		//dds fix

    //load reflection
    //vec4 tmp = vec4(lightdir, 0.0);
    vec4 tmp = vec4(0.0);
    vec4 refTex = texture2D(water_reflection, vec2(tmp + waterTex1) * 32.0) ;
    vec4 refTexGrey = texture2D(water_reflection_grey, vec2(tmp + waterTex1) * 32.0) ;
    vec4 refl ;

    //    cover = 0;

    if(cover >= 1.5){
        refl = normalize(refTex);
        refl.a = 1.0;
        }
    else
        {
        refl = normalize(refTexGrey);
        refl.r *= (0.75 + 0.15 * cover);
        refl.g *= (0.80 + 0.15 * cover);
        refl.b *= (0.875 + 0.125 * cover);
        refl.a  = 1.0;
        }

    rotationmatrix(radians(2.1* windScale + 0.25 * sin(waterTex1.s *0.14)), RotationMatrix);
    vec3 N0 = vec3(texture2D(water_normalmap, vec2(waterTex1* RotationMatrix + disdis * sca2) * windScale * 1.15) * 2.0 - 1.0);
    vec3 N1 = vec3(texture2D(perlin_normalmap, vec2(waterTex1/** RotationMatrix*/ + disdis * sca) * windScale) * 2.0 - 1.0);

    rotationmatrix(radians(-1.5 * windScale -0.32 * sin(waterTex1.s *0.24)), RotationMatrix);
    N0 += vec3(texture2D(water_normalmap, vec2(waterTex2* RotationMatrix  * tscale) * windScale * 1.8) * 2.0 - 1.0);
    N1 += vec3(texture2D(perlin_normalmap, vec2(waterTex2/** RotationMatrix*/ * tscale) * windScale) * 2.0 - 1.0);

    rotationmatrix(radians(3.8 * windScale + 0.45 * sin(waterTex1.s *0.32)), RotationMatrix);
    N0 += vec3(texture2D(water_normalmap, vec2(waterTex2 * RotationMatrix * (tscale + sca2)) * windScale * 0.85) * 2.0 - 1.0);
    N1 += vec3(texture2D(perlin_normalmap, vec2(waterTex2/** RotationMatrix*/ * (tscale + sca2))  * windScale) * 2.0 - 1.0);

    rotationmatrix(radians(-2.8 * windScale - 0.38 * sin(waterTex1.s * 0.26)), RotationMatrix);
    N0 += vec3(texture2D(water_normalmap, vec2(waterTex1 * RotationMatrix + disdis * sca2) * windScale * 2.1) * 2.0 - 1.0);
    N1 += vec3(texture2D(perlin_normalmap, vec2(waterTex1 /** RotationMatrix*/ + disdis * sca) * windScale) * 2.0 - 1.0);

    N0 *= windEffect_low;
    N1 *= windEffect_low;

    vec3 N2 = normalize(mix(N0, N1, mixFactor) * waveRoughness);
    Normal = normalize(N2.x * VTangent + N2.y * VBinormal + N2.z * Normal);
    //vNormal = normalize(mix(vNormal + N0, vNormal + N1, mixFactor) * waveRoughness);
	vNormal = normalize(N2.x * vec3(1.,0.,0.) + N2.y * vec3(0.,1.,0.) + N2.z * vNormal);

    if (normalmap_dds > 0){
        Normal = -Normal; //dds fix
        vNormal = -vNormal;
    }
    // specular
    //vec3 specular_color = vec3(gl_LightSource[0].diffuse)
    //    * pow(max(0.0, dot(N, H)), water_shininess) * 6.0;
    //vec4 specular = vec4(specular_color, 0.5);

    //specular = specular * saturation * 0.3 ;
    //float specular = saturation * 0.3;

    //calculate fresnel
    vec4 invfres = vec4( dot(vNorm, viewt) );
    vec4 fres = vec4(1.0) + invfres;
    refl *= fres;

    //calculate final colour
    //vec4 ambient_light = gl_LightSource[0].diffuse;
    vec4 finalColor = refl;

    float   foamSlope = 0.10 + 0.1 * windScale;
    vec4    foam_texel = texture2D(sea_foam, vec2(waterTex2 * tscale) * 25.0);
    float   waveSlope = vNormal.g;

    if (windEffect >= 8.0)
        if (waveSlope >= foamSlope){
            finalColor = mix(finalColor, max(finalColor, finalColor + foam_texel), smoothstep(0.01, 0.50, vNormal.g));
            }

    float emission = dot( gl_FrontLightModelProduct.sceneColor.rgb + gl_FrontMaterial.emission.rgb,
                          vec3( 0.3, 0.59, 0.11 )
                        );
    float specular = smoothstep(0.0, 3.5, cover);
    encode_gbuffer(Normal, finalColor.rgb, 254, specular, 128.0, emission, gl_FragCoord.z);
    }
