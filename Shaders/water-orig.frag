#version 120

varying vec4 rawpos;
varying vec4 ecPosition;
varying vec3 VNormal;
varying vec3 Normal;
varying vec3 lightVec;

uniform sampler3D NoiseTex;
uniform float osg_SimulationTime;

//const float scale = 1.0;
////fog "include" /////
uniform int fogType;

vec3 fog_Func(vec3 color, int type);
//////////////////////

void main (void)
{
    vec4 noisevecS   = texture3D(NoiseTex, (rawpos.xyz)*0.0126);
    vec4 nvLS   = texture3D(NoiseTex, (rawpos.xyz)*-0.0003323417);

    vec4 noisevec   = texture3D(NoiseTex, (rawpos.xyz)*0.00423+vec3(0.0,0.0,osg_SimulationTime*0.035217));
    vec4 nvL   = texture3D(NoiseTex, (rawpos.xyz)*0.001223417+(0.0,0.0,osg_SimulationTime*-0.0212));

//     float fogFactor;
//     if (gl_Fog.density == 1.0)
//     {
//        fogFactor=1.0;
//     }
//     else
//     {
//         float fogCoord = ecPosition.z;
//         const float LOG2 = 1.442695;
//         fogFactor = exp2(-gl_Fog.density * gl_Fog.density * fogCoord * fogCoord * LOG2);
//         fogFactor = clamp(fogFactor, 0.0, 1.0);
//     }

    float a=1.0;
    float n=0.00;
    n += nvLS[0]*a;
    a/=2.0;
    n += nvLS[1]*a;
    a/=2.0;
    n += nvLS[2]*a;
    a/=2.0;
    n += nvLS[3]*a;

    a=4.0;
    float na=n;
    na += nvL[0]*1.1;
    a*=1.2;
    na += nvL[1]*a;
    a*=1.2;
    na += nvL[2]*a;
    a*=1.2;
    na += nvL[3]*a;
    a=2.0;
    na += noisevec[0]*a*0.2;
    a*=1.2;
    na += noisevec[1]*a;
    a*=1.2;
    na += noisevec[2]*a;
    a*=1.2;
    na += noisevec[3]*a;

    vec4 c1;
    c1 = asin(vec4(smoothstep(0.0, 2.2, n), smoothstep(-0.1, 2.10, n), smoothstep(-0.2, 2.0, n), 1.0));

    vec3 Eye = normalize(-ecPosition.xyz);
    vec3 Reflected = normalize(reflect(-normalize(lightVec), normalize(VNormal+vec3(0.0,0.0,na*0.10-0.24))));

    vec3 bump = normalize(VNormal+vec3(0.0, 0.0, na)-0.9);
    vec3 bumped = max(normalize(refract(lightVec, normalize(bump), 0.16)), 0.0);

    vec4 ambientColor = gl_LightSource[0].ambient;
    vec4 light = ambientColor;
    c1 *= light;

    float bumpFact = (bumped.r+bumped.g+bumped.b);
    float ReflectedEye = max(dot(Reflected, Eye), 0.0);
    float eyeFact = pow(ReflectedEye, 20.0);
    c1 += 0.3 * gl_LightSource[0].diffuse * (1.0-eyeFact) * bumpFact*bumpFact;
    c1 += 0.4 * gl_LightSource[0].diffuse * eyeFact * 3.0*bumpFact;
    eyeFact = pow(eyeFact, 20.0);
    c1 += gl_LightSource[0].specular * eyeFact * 4.0*bumpFact;

    vec4 finalColor = c1;
//     gl_FragColor = mix(gl_Fog.color, finalColor, fogFactor);
		finalColor.rgb = fog_Func(finalColor.rgb, fogType);
		gl_FragColor = finalColor;
}
