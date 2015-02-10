uniform sampler2D color_tex;
uniform sampler2D ao_tex;
uniform sampler2D normal_tex;
uniform sampler2D spec_emis_tex;
uniform vec4 fg_SunAmbientColor;
uniform bool ambientOcclusion;
uniform float ambientOcclusionStrength;

void main() {
    vec2 coords = gl_TexCoord[0].xy;
    float initialized = texture2D( spec_emis_tex, coords ).a;
    if ( initialized < 0.1 )
        discard;
    vec3 tcolor = texture2D( color_tex, coords ).rgb;
    float ao = 1.0;
    if (ambientOcclusion) {
        ao = 1.0 - ambientOcclusionStrength * (1.0 - texture2D( ao_tex, coords ).r);
    }
    gl_FragColor = vec4(tcolor * fg_SunAmbientColor.rgb * ao, 1.0);
}
