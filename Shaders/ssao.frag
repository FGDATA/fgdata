#version 120
#extension GL_EXT_gpu_shader4 : enable
uniform sampler2D normal_tex;
uniform sampler2D depth_tex;
uniform sampler2D spec_emis_tex;
uniform sampler3D noise_tex;
uniform vec2 fg_BufferSize;
uniform vec3 fg_Planes;
uniform vec4 fg_du;
uniform vec4 fg_dv;
uniform float g_scale;
uniform float g_bias;
uniform float g_intensity;
uniform float g_sample_rad;
uniform float random_size;
uniform float osg_SimulationTime;

varying vec4 ray;

const vec2 v[4] = vec2[](vec2(1.0,0.0),vec2(-1.0,0.0),vec2(0.0,1.0),vec2(0.0,-1.0));

vec3 position( vec3 viewDir, vec2 coords, sampler2D depth_tex );
vec3 normal_decode(vec2 enc);

vec2 getRandom( in vec2 uv ) {
    float level = osg_SimulationTime - float(int(osg_SimulationTime));
    return normalize( texture3D( noise_tex, vec3(uv*50.0, level) ).xy * 0.14 - 0.07 );
}
vec3 getPosition(in vec2 uv, in vec2 uv0, in vec4 ray0) {
    vec2 duv = uv - uv0;
    vec4 ray = ray0 + fg_du * duv.x + fg_dv * duv.y;
    vec3 viewDir = normalize( ray.xyz );
    return position(viewDir, uv, depth_tex);
}
float doAmbientOcclusion(in vec2 tcoord, in vec2 uv, in vec3 p, in vec3 cnorm, in vec4 ray) {
    vec3 diff = getPosition(tcoord+uv,tcoord,ray)-p;
    float d = length(diff);
    vec3 v = diff / d;
    d *= g_scale;
    return max(0.0, dot( cnorm,v ) - g_bias) * (1.0/(1.0+d)) * g_intensity;
}
void main() {
    vec2 coords = gl_TexCoord[0].xy;
    float initialized = texture2D( spec_emis_tex, coords ).a;
    if ( initialized < 0.1 )
        discard;
    vec3 normal = normal_decode(texture2D( normal_tex, coords ).rg);
    vec3 viewDir = normalize(ray.xyz);
    vec3 pos = position(viewDir, coords, depth_tex);
    vec2 rand = getRandom(coords);
    float ao = 0.0;
    float rad = g_sample_rad;
    int iterations = 4;
    for (int j = 0; j < 1; ++j ) {
        vec2 coord1 = reflect( v[j], rand ) * rad;
        vec2 coord2 = vec2( coord1.x*0.707 - coord1.y*0.707, coord1.x*0.707 + coord1.y*0.707 );
        ao += doAmbientOcclusion(coords,coord1*0.25,pos,normal,ray);
        ao += doAmbientOcclusion(coords,coord2*0.5,pos,normal,ray);
        ao += doAmbientOcclusion(coords,coord1*0.75,pos,normal,ray);
        ao += doAmbientOcclusion(coords,coord2,pos,normal,ray);
    }
    ao /= 16.0;
    gl_FragColor = vec4( vec3(1.0 - ao), 1.0 );
}
