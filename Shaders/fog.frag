uniform sampler2D depth_tex;
uniform sampler2D normal_tex;
uniform sampler2D color_tex;
uniform sampler2D spec_emis_tex;
uniform vec4 fg_FogColor;
uniform float fg_FogDensity;
uniform vec3 fg_Planes;
varying vec3 ray;

vec3 position( vec3 viewDir, vec2 coords, sampler2D depth_tex );

void main() {
    vec2 coords = gl_TexCoord[0].xy;
    float initialized = texture2D( spec_emis_tex, coords ).a;
    if ( initialized < 0.1 )
        discard;
    vec3 normal;
    vec3 pos = position( normalize(ray), coords, depth_tex );

    float fogFactor = 0.0;
    const float LOG2 = 1.442695;
    fogFactor = exp2(-fg_FogDensity * fg_FogDensity * pos.z * pos.z * LOG2);
    fogFactor = clamp(fogFactor, 0.0, 1.0);

    gl_FragColor = vec4(fg_FogColor.rgb, 1.0 - fogFactor);
}
