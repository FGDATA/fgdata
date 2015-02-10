//  FRAGMENT SHADER
//  This shader is mostly an adaptation of the shader found at
//  http://www.bonzaisoftware.com/water_tut.html and its glsl conversion
//  available at http://forum.bonzaisoftware.com/viewthread.php?tid=10
//  ©Michael Horsch - 2005
//  Major update and revisions - 2011-10-07
//  ©Emilian Huminiuc and Vivian Meazza
//  Optimisation - 2012-5-05
//  Based on ideas by Thorsten Renk
//  ©Emilian Huminiuc and Vivian Meazza

#version 120

varying vec2    TopoUV;
varying vec3    WorldPos;
varying vec3    lightdir;
varying vec3    normal;
varying vec3    viewerdir;
varying vec4    waterTex1;                                  //moving texcoords
varying vec4    waterTex2;                                  //moving texcoords

uniform sampler2D   perlin_normalmap;
uniform sampler2D   sea_foam;
uniform sampler2D   topo_map;
uniform sampler2D   water_dudvmap;
uniform sampler2D   water_normalmap;
uniform sampler2D   water_reflection;
uniform sampler2D   water_reflection_grey;
uniform sampler3D   Noise;

uniform float   CloudCover0;
uniform float   CloudCover1;
uniform float   CloudCover2;
uniform float   CloudCover3;
uniform float   CloudCover4;
uniform float   Overcast;
uniform float   WindE;
uniform float   WindN;
uniform float   osg_SimulationTime;
uniform float   saturation;
uniform int     Status;

uniform float   WaveAmp;
uniform float   WaveAngle;
uniform float   WaveDAngle;
uniform float   WaveFactor;
uniform float   WaveFreq;
uniform float   WaveSharp;
uniform float   normalmap_dds;

////fog "include" /////
uniform int fogType;

vec3 fog_Func(vec3 color, int type);
//////////////////////

const vec4 AllOnes = vec4(1.0);
const vec4 sca = vec4(0.005, 0.005, 0.005, 0.005);
const vec4 sca2 = vec4(0.02, 0.02, 0.02, 0.02);
const vec4 tscale = vec4(0.25, 0.25, 0.25, 0.25);
const float water_shininess = 240.0;

/////// functions /////////

void rotationmatrix(in float angle, out mat4 rotmat)
{
    rotmat = mat4( cos( angle ), -sin( angle ), 0.0, 0.0,
                   sin( angle ),  cos( angle ), 0.0, 0.0,
                   0.0         ,  0.0         , 1.0, 0.0,
                   0.0         ,  0.0         , 0.0, 1.0 );
}

// wave functions ///////////////////////

struct Wave {
    float freq;  // 2*PI / wavelength
    float amp;   // amplitude
    float phase; // speed * 2*PI / wavelength
    vec2 dir;
};

Wave wave0 = Wave(1.0, 1.0, 0.5, vec2(0.97, 0.25));
Wave wave1 = Wave(2.0, 0.5, 1.3, vec2(0.97, -0.25));
Wave wave2 = Wave(1.0, 1.0, 0.6, vec2(0.95, -0.3));
Wave wave3 = Wave(2.0, 0.5, 1.4, vec2(0.99, 0.1));

float evaluateWave(in Wave w, vec2 pos, float t)
{
    return w.amp * sin( dot(w.dir, pos) * w.freq + t * w.phase);
}

// derivative of wave function
float evaluateWaveDeriv(Wave w, vec2 pos, float t)
{
    return w.freq * w.amp * cos( dot(w.dir, pos)*w.freq + t*w.phase);
}

// sharp wave functions
float evaluateWaveSharp(Wave w, vec2 pos, float t, float k)
{
    return w.amp * pow(sin( dot(w.dir, pos)*w.freq + t*w.phase)* 0.5 + 0.5 , k);
}

float evaluateWaveDerivSharp(Wave w, vec2 pos, float t, float k)
{
    return k*w.freq*w.amp * pow(sin( dot(w.dir, pos)*w.freq + t*w.phase)* 0.5 + 0.5 , k - 1.0) * cos( dot(w.dir, pos)*w.freq + t*w.phase);
}

void sumWaves(float angle, float dangle, float windScale, float factor, out float ddx, out float ddy)
{
    mat4 RotationMatrix;
    float deriv;
    vec4 P = waterTex1 * 1024.0;

    rotationmatrix(radians(angle + dangle * windScale + 0.6 * sin(P.x * factor)), RotationMatrix);
    P *= RotationMatrix;

    P.y += evaluateWave(wave0, P.xz, osg_SimulationTime);
    deriv = evaluateWaveDeriv(wave0, P.xz, osg_SimulationTime );
    ddx = deriv * wave0.dir.x;
    ddy = deriv * wave0.dir.y;

    P.y += evaluateWave(wave1, P.xz, osg_SimulationTime);
    deriv = evaluateWaveDeriv(wave1, P.xz, osg_SimulationTime);
    ddx += deriv * wave1.dir.x;
    ddy += deriv * wave1.dir.y;

    P.y += evaluateWaveSharp(wave2, P.xz, osg_SimulationTime, WaveSharp);
    deriv = evaluateWaveDerivSharp(wave2, P.xz, osg_SimulationTime, WaveSharp);
    ddx += deriv * wave2.dir.x;
    ddy += deriv * wave2.dir.y;

    P.y += evaluateWaveSharp(wave3, P.xz, osg_SimulationTime, WaveSharp);
    deriv = evaluateWaveDerivSharp(wave3, P.xz, osg_SimulationTime, WaveSharp);
    ddx += deriv * wave3.dir.x;
    ddy += deriv * wave3.dir.y;
}

void main(void)
{
    mat4 RotationMatrix;

    // compute direction to viewer
    vec3 E = normalize(viewerdir);

    // compute direction to light source
    vec3 L = normalize(lightdir);

    // half vector
    vec3 H = normalize(L + E);

    vec3 Normal = normalize(normal);

    // approximate cloud cover
    float cover = 0.0;
    //bool Status = true;

//     try some aliasing fix for low angles
//     float viewAngle = smoothstep(0.0,0.5,abs(dot(E,Normal)));

    //  Global bathymetry texture
    vec4    topoTexel = texture2D(topo_map, TopoUV);
    vec4    mixNoise =  texture3D(Noise, WorldPos.xyz * 0.00005);
    vec4    mixNoise1 =  texture3D(Noise, WorldPos.xyz * 0.00008);
    float   mixNoiseFactor = mixNoise.r * mixNoise.g * mixNoise.b;
    float   mixNoise1Factor = mixNoise1.r * mixNoise1.g * mixNoise1.b;
    mixNoiseFactor *= 300.0;
    mixNoise1Factor *= 300.0;
    mixNoiseFactor = 0.8 + 0.2 * smoothstep(0.0,1.0, mixNoiseFactor)* smoothstep(0.0,1.0, mixNoise1Factor);
    float   floorMixFactor = smoothstep(0.3, 0.985, topoTexel.a * mixNoiseFactor);
    vec3    floorColour = mix(topoTexel.rgb, mixNoise.rgb * mixNoise1.rgb, 0.3);

    float windFloorFactor = 1.0 + 0.5 * smoothstep(0.8, 0.985, topoTexel.a);
    float windEffect = sqrt( WindE*WindE + WindN*WindN ) * 0.6;                             //wind speed in kt
    float windFloorEffect = windEffect * windFloorFactor;
    float windScale =  15.0/(3.0 + windEffect);                                             //wave scale
    float windEffect_low = 0.3 + 0.7 * smoothstep(0.0, 5.0, windEffect);                    //low windspeed wave filter
    float waveRoughness = 0.01 + smoothstep(0.0, 40.0, windEffect);                         //wave roughness filter

    float mixFactor = 0.2 + 0.02 * smoothstep(0.0, 50.0, windFloorEffect);
    mixFactor = clamp(mixFactor, 0.3, 0.95);

    // sine waves
    //
    // Test data
    // float WaveFreq =1.0;
    // float WaveAmp = 1000.0;
    // float WaveSharp = 10.0;

    vec4 ddxVec = vec4(0.0);
    vec4 ddyVec = vec4(0.0);

    float ddx  = 0.0, ddy  = 0.0;
    float ddx1 = 0.0, ddy1 = 0.0;
    float ddx2 = 0.0, ddy2 = 0.0;
    float ddx3 = 0.0, ddy3 = 0.0;
    float waveamp;

    float angle = 0.0;
    float WaveAmpFromDepth = WaveAmp * windFloorFactor;
    float phaseFloorFactor = 1.0 - 0.2 * smoothstep(0.8, 0.9, topoTexel.a);
    wave0.freq = WaveFreq; // * (smoothstep(0.8, 0.9, topoTexel.a)*1.5 + 0.25);
    wave0.amp = WaveAmpFromDepth;
    wave0.dir =  vec2(cos(radians(angle)), sin(radians(angle)));
    wave0.phase *= phaseFloorFactor;

    angle -= 45.0;
    wave1.freq = WaveFreq * 2.0 ;
    wave1.amp = WaveAmpFromDepth * 1.25;
    wave1.dir =  vec2(cos(radians(angle)), sin(radians(angle)));
    wave1.phase *= phaseFloorFactor;

    angle += 30.0;
    wave2.freq = WaveFreq * 3.5;
    wave2.amp = WaveAmpFromDepth * 0.75;
    wave2.dir =  vec2(cos(radians(angle)), sin(radians(angle)));
    wave2.phase *= phaseFloorFactor;

    angle -= 50.0;
    wave3.freq = WaveFreq * 3.0 ;
    wave3.amp = WaveAmpFromDepth * 0.75;
    wave3.dir =  vec2(cos(radians(angle)), sin(radians(angle)));
    wave3.phase *= phaseFloorFactor;

    // sum waves
    ddx = 0.0, ddy = 0.0;
    sumWaves(WaveAngle, -1.5, windScale, WaveFactor, ddx, ddy);

    ddx1 = 0.0, ddy1 = 0.0;
    sumWaves(WaveAngle, 1.5, windScale, WaveFactor, ddx1, ddy1);

    //reset the waves
    angle = 0.0;
    waveamp = WaveAmpFromDepth * 0.75;

    wave0.freq = WaveFreq ;
    wave0.amp = waveamp;
    wave0.dir =  vec2(cos(radians(angle)), sin(radians(angle)));

    angle -= 20.0;
    wave1.freq = WaveFreq * 2.0 ;
    wave1.amp = waveamp * 1.25;
    wave1.dir =  vec2(cos(radians(angle)), sin(radians(angle)));

    angle += 35.0;
    wave2.freq = WaveFreq * 3.5;
    wave2.amp = waveamp * 0.75;
    wave2.dir =  vec2(cos(radians(angle)), sin(radians(angle)));

    angle -= 45.0;
    wave3.freq = WaveFreq * 3.0 ;
    wave3.amp = waveamp * 0.75;
    wave3.dir =  vec2(cos(radians(angle)), sin(radians(angle)));

    // sum waves
    ddx2 = 0.0, ddy2 = 0.0;
    sumWaves(WaveAngle + WaveDAngle, -1.5, windScale, WaveFactor, ddx2, ddy2);

    ddx3 = 0.0, ddy3 = 0.0;
    sumWaves(WaveAngle + WaveDAngle, 1.5, windScale, WaveFactor, ddx3, ddy3);

    ddxVec = vec4(ddx, ddx1, ddx2, ddx3);
    ddyVec = vec4(ddy, ddy1, ddy2, ddy3);

    float ddxSum = dot(ddxVec, AllOnes);
    float ddySum = dot(ddyVec, AllOnes);

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

    vec2 uvAnimSca2 = (waterTex1 + disdis * sca2).st * windScale;
    //normalmaps
    vec4 nmap   = texture2D(water_normalmap, uvAnimSca2) * 2.0 - 1.0;
    vec4 nmap1  = texture2D(perlin_normalmap, uvAnimSca2) * 2.0 - 1.0;

    rotationmatrix(radians(3.0 * sin(osg_SimulationTime * 0.0075)), RotationMatrix);
    vec2 uvAnimTscale = (waterTex2 * RotationMatrix * tscale).st * windScale;

    nmap  += texture2D(water_normalmap, uvAnimTscale) * 2.0 - 1.0;
    nmap1 += texture2D(perlin_normalmap, uvAnimTscale) * 2.0 - 1.0;

    nmap  *= windEffect_low;
    nmap1 *= windEffect_low;

    // mix water and noise, modulated by factor
    vec4 vNorm = normalize(mix(nmap, nmap1, mixFactor) * waveRoughness);
    vNorm.r += ddxSum;

    if (normalmap_dds > 0)
        vNorm = -vNorm;		//dds fix

    //load reflection
    vec4 tmp = vec4(lightdir, 0.0);
    vec2 refTexUV = (tmp + waterTex1).st * 32.0;
    vec4 refTex = texture2D(water_reflection, refTexUV) ;
    vec4 refTexGrey = texture2D(water_reflection_grey, refTexUV) ;
    vec4 refl = vec4(0.0,0.0,0.0,1.0) ;

    // Test data
    // cover = 0;

    if(cover >= 1.5){
        refl.rgb = normalize(refTex).rgb;
    }
    else
    {
        refl.rgb = normalize(refTexGrey).rgb;
        refl.r *= (0.75 + 0.15 * cover );
        refl.g *= (0.80 + 0.15 * cover );
        refl.b *= (0.875 + 0.125 * cover);
    }

//     refl.rgb = mix(refl.rgb, floorColour, 0.99 * floorMixFactor);

    vec4 N0 = texture2D(water_normalmap, uvAnimSca2) * 2.0 - 1.0;
    vec4 N1 = texture2D(perlin_normalmap, vec2(waterTex1 + disdis * sca) * windScale) * 2.0 - 1.0;

    N0 += texture2D(water_normalmap, vec2(waterTex1 * tscale) * windScale) * 2.0 - 1.0;
    N1 += texture2D(perlin_normalmap, vec2(waterTex2 * tscale) * windScale) * 2.0 - 1.0;


    rotationmatrix(radians(2.0 * sin(osg_SimulationTime * 0.005)), RotationMatrix);
    vec2 uvAnimTscaleSca2 = (waterTex2 * RotationMatrix * (tscale + sca2)).st * windScale;
    N0 += texture2D(water_normalmap, uvAnimTscaleSca2) * 2.0 - 1.0;
    N1 += texture2D(perlin_normalmap, uvAnimTscaleSca2) * 2.0 - 1.0;

    rotationmatrix(radians(-4.0 * sin(osg_SimulationTime * 0.003)), RotationMatrix);
    N0 += texture2D(water_normalmap, vec2(waterTex1 * RotationMatrix + disdis * sca2) * windScale) * 2.0 - 1.0;
    N1 += texture2D(perlin_normalmap, vec2(waterTex1 * RotationMatrix + disdis * sca) * windScale) * 2.0 - 1.0;

    N0 *= windEffect_low;
    N1 *= windEffect_low;

    N0.r += ddxSum;
    N0.g += ddySum;

    Normal = normalize(mix(Normal + N0.rgb, Normal + N1.rgb, mixFactor) * waveRoughness);

    if (normalmap_dds > 0)
        Normal = -Normal; //dds fix

    float NdotH = max(0.0,  dot(Normal,  H));
    vec3 specular_color = vec3(gl_LightSource[0].diffuse)
                          * pow(NdotH, water_shininess) * 6.0;
    vec4 specular = vec4(specular_color, 0.5);

    specular = specular * saturation * 0.3 ;

    //calculate fresnel
    float vNormDotViewT = dot(vNorm, viewt);
    vec4 invfres = vec4( vNormDotViewT);
    vec4 fres = vec4(1.0) + invfres;
    refl *= fres;

    refl.rgb = mix(refl.rgb, floorColour, floorMixFactor);
    //calculate final colour
    vec4 ambient_light = gl_LightSource[0].diffuse;
    vec4 finalColor;

    finalColor = refl + step(1.5, cover) * specular;

    //add foam
    vec4 foam_texel = texture2D(sea_foam, (waterTex2 * tscale).st * 50.0);
    float foamSlope = 0.1 + 0.1 * windScale;

    float waveSlope1 = Normal.g * windFloorFactor * 0.65;
    float waveSlope2 = vNorm.r * windFloorFactor * 0.3;
    float waveSlope = waveSlope1 + waveSlope2;

    finalColor = mix(finalColor, max(finalColor, finalColor + foam_texel),
                        smoothstep(7.0, 8.0, windFloorEffect)
                         * step(foamSlope, waveSlope)
                         * smoothstep(0.01, 0.50, waveSlope)) ;

    finalColor *= ambient_light ;

    finalColor.rgb = fog_Func(finalColor.rgb, fogType) ;
    gl_FragColor = finalColor ;
}
