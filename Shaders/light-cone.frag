#version 120
//varying float fogCoord;
////fog "include" /////
uniform int fogType;

vec3 fog_Func(vec3 color, int type);
//////////////////////

void main()
{
    vec4 fragColor = gl_FrontMaterial.ambient;
//    float fogFactor = exp(-gl_Fog.density * gl_Fog.density * fogCoord * fogCoord);
//    gl_FragColor = mix(gl_Fog.color, fragColor, fogFactor);
    gl_FragColor = fragColor;
}
