// -*-C++-*-

// Ambient term comes in gl_Color.rgb.
//
// See http://wiki.flightgear.org/index.php/Howto:_Lightmap for details on
// how to use it.

varying vec4 diffuse_term;
varying vec3 normal;
//varying float fogCoord;

uniform sampler2D texture;

// lightmap options
uniform float condition;
uniform float lightmap_factor;
uniform sampler2D lightmap_texture;

////fog "include" /////
uniform int fogType;

vec3 fog_Func(vec3 color, int type);
//////////////////////


float luminance(vec3 color)
{
    return dot(vec3(0.212671, 0.715160, 0.072169), color);
}

void main()
{
    vec3 n, halfV;
    float NdotL, NdotHV, fogFactor;
    vec4 color = gl_Color;
    vec3 lightDir = gl_LightSource[0].position.xyz;
    vec3 halfVector = gl_LightSource[0].halfVector.xyz;
    vec4 texel;
    vec4 fragColor;
    vec4 specular = vec4(0.0);
    n = normalize(normal);
    // If gl_Color.a == 0, this is a back-facing polygon and the
    // normal should be reversed.

    n = (2.0 * gl_Color.a - 1.0) * n;
    NdotL = max(dot(n, lightDir), 0.0);
    if (NdotL > 0.0) {
        color += diffuse_term * NdotL;
        halfV = halfVector;
        NdotHV = max(dot(n, halfV), 0.0);
        if (gl_FrontMaterial.shininess > 0.0)
            specular.rgb = (gl_FrontMaterial.specular.rgb
                            * gl_LightSource[0].specular.rgb
                            * pow(NdotHV, gl_FrontMaterial.shininess));
    }
    color.a = diffuse_term.a;
    // This shouldn't be necessary, but our lighting becomes very
    // saturated. Clamping the color before modulating by the texture
    // is closer to what the OpenGL fixed function pipeline does.
    color = clamp(color, 0.0, 1.0);
    texel = texture2D(texture, gl_TexCoord[0].st);
    fragColor = color * texel + specular;

	// The lightmap function
	if ( condition >= 1.0 ) {
		vec3 lightmapTexel = texture2D(lightmap_texture, gl_TexCoord[0].st).rgb * lightmap_factor;
		fragColor.rgb = max(fragColor.rgb, lightmapTexel * gl_FrontMaterial.diffuse.rgb * texel.rgb);
		}

   // fogFactor = exp(-gl_Fog.density * gl_Fog.density * fogCoord * fogCoord);
   // gl_FragColor = mix(gl_Fog.color, fragColor, fogFactor);
   fragColor.rgb = fog_Func(fragColor.rgb, fogType);
	 gl_FragColor = fragColor;
}