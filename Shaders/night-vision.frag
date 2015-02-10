// Night vision effect inspired by http://www.geeks3d.com/20091009/shader-library-night-vision-post-processing-filter-glsl/

uniform sampler2D color_tex;
uniform sampler2D lighting_tex;
uniform sampler2D bloom_tex;
uniform sampler2D spec_emis_tex;
uniform sampler2D noise_tex;

uniform bool bloomEnabled;
uniform float bloomStrength;
uniform bool bloomBuffers;

uniform vec2 fg_BufferSize;
uniform float osg_SimulationTime;

void main() {
    vec2 coords = gl_TexCoord[0].xy;
    vec4 color;
	vec2 uv;           
	uv.x = 0.4*sin(osg_SimulationTime*50.0);                                 
	uv.y = 0.4*cos(osg_SimulationTime*50.0);
	vec3 n = texture2D(noise_tex, (coords*3.5) + uv).rgb;
	
	vec2 c1 = coords + (n.xy*0.005);
	color = texture2D( lighting_tex, c1 );
	if (bloomEnabled && bloomBuffers)
		color = color + bloomStrength * texture2D( bloom_tex, c1 );

	float lum = dot(color.rgb, vec3(.3, .59, .11));
	color.rgb *= (4.0 - 3.0*smoothstep(0.2, 0.3, lum));

	// color.rgb += texture2D( spec_emis_tex, c1 ).b;
	// color.rgb += texture2D( bloom_tex, c1 ).rgb;
	color.rgb = (color.rgb + (n*0.2)) * vec3(0.1, 0.95, 0.2);

	vec2 c = 2.0 * coords - vec2(1.,1.);
	c = c * vec2( 1.0, fg_BufferSize.y / fg_BufferSize.x );
	float l = length(c);
	float f = smoothstep( 0.7, 1.1, l );
	color.rgb = (1 - f) * color.rgb;
    gl_FragColor = color;
}
