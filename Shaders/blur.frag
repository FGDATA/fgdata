#version 120
uniform sampler2D input_tex;
uniform vec2 fg_BufferSize;
uniform float blurOffset_x;
uniform float blurOffset_y;
const float f[5] = float[](0.0, 1.0, 2.0, 3.0, 4.0);
const float w[5] = float[](0.2270270270, 0.1945945946, 0.1216216216, 0.0540540541, 0.0162162162 );
void main() {
	vec2 blurOffset = vec2(blurOffset_x, blurOffset_y) / fg_BufferSize;
    vec2 coords = gl_TexCoord[0].xy;
    vec4 color = vec4( texture2D( input_tex, coords + f[0] * blurOffset ).rgb * w[0], 1.0 );
    for (int i=1; i<5; ++i ) {
        color.rgb += texture2D( input_tex, coords - f[i] * blurOffset ).rgb * w[i];
        color.rgb += texture2D( input_tex, coords + f[i] * blurOffset ).rgb * w[i];
    }
    gl_FragColor = color;
}
