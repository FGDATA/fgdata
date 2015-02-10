uniform sampler2D color_tex;
uniform sampler2D spec_emis_tex;
void main() {
    vec2 coords = gl_TexCoord[0].xy;
    vec4 spec_emis = texture2D( spec_emis_tex, coords );
    if ( spec_emis.a < 0.1 )
        spec_emis.z = 0.0;
    vec3 tcolor = texture2D( color_tex, coords ).rgb;
	gl_FragColor = vec4(tcolor * spec_emis.z, 1.0);
}
