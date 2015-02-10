uniform sampler2D lighting_tex;
uniform sampler2D bloom_tex;

uniform sampler2D bufferNW_tex;
uniform sampler2D bufferNE_tex;
uniform sampler2D bufferSW_tex;
uniform sampler2D bufferSE_tex;

uniform bool showBuffers;

uniform bool bloomEnabled;
uniform float bloomStrength;
uniform bool bloomBuffers;

uniform bool bufferNW_enabled;
uniform bool bufferNE_enabled;
uniform bool bufferSW_enabled;
uniform bool bufferSE_enabled;

void main() {
    vec2 coords = gl_TexCoord[0].xy;
    vec4 color;
    if (showBuffers) {
        if (coords.x < 0.2 && coords.y < 0.2 && bufferSW_enabled) {
            color = texture2D( bufferSW_tex, coords * 5.0 );
        } else if (coords.x >= 0.8 && coords.y >= 0.8 && bufferNE_enabled) {
            color = texture2D( bufferNE_tex, (coords - vec2( 0.8, 0.8 )) * 5.0 );
        } else if (coords.x >= 0.8 && coords.y < 0.2 && bufferSE_enabled) {
            color = texture2D( bufferSE_tex, (coords - vec2( 0.8, 0.0 )) * 5.0 );
        } else if (coords.x < 0.2 && coords.y >= 0.8 && bufferNW_enabled) {
            color = texture2D( bufferNW_tex, (coords - vec2( 0.0, 0.8 )) * 5.0 );
        } else {
            color = texture2D( lighting_tex, coords );
            if (bloomEnabled && bloomBuffers)
                color = color + bloomStrength * texture2D( bloom_tex, coords );
        }
    } else {
        color = texture2D( lighting_tex, coords );
        if (bloomEnabled && bloomBuffers)
            color = color + bloomStrength * texture2D( bloom_tex, coords );
    }
    gl_FragColor = color;
}
