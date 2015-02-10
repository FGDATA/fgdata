// -*-C++-*-

// Shader that uses OpenGL state values to do per-pixel lighting

uniform float size;
uniform float max_size;


uniform bool is_directional;

varying vec3 relPos;
varying vec2 rawPos;
varying float pixelSize;

bool light_directional = true;

void main()
{
    gl_FrontColor= gl_Color;
    gl_Position = ftransform();

    vec4 ep = gl_ModelViewMatrixInverse * vec4(0.0,0.0,0.0,1.0);
    relPos = gl_Vertex.xyz - ep.xyz;
    rawPos = gl_Vertex.xy;
    float dist = length(relPos);
    float angular_fade = 1.0;
    //if (length(gl_Normal)> 0.0)
    if (is_directional)
	{
	angular_fade = 2.0 * max(0.0,-dot(normalize(gl_Normal), normalize(relPos)));
	}
    float lightScale = size * size * size * size * size/ 500.0 *angular_fade;
    pixelSize = min(size * size/25.0,lightScale/dist) ;
    pixelSize = min(pixelSize, max_size);
    gl_PointSize = 2.0 * pixelSize;
}
