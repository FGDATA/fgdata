// -*-C++-*-

// Ambient term comes in gl_Color.rgb.
#version 120

varying vec4 diffuse_term;
varying vec3 normal;
varying vec3 ecViewDir;
varying vec3 VTangent;


uniform sampler2D texture;




float luminance(vec3 color)
{
    return dot(vec3(0.212671, 0.715160, 0.072169), color);
}

void main()
{
    vec3 n;
    float NdotL, NdotHV;
    vec4 color = gl_Color;
    vec3 lightDir = gl_LightSource[0].position.xyz;

	vec3 halfVector = normalize(normalize(lightDir) + normalize(ecViewDir));
    vec4 texel;

    vec4 fragColor;
    vec4 specular = vec4(0.0);

    // If gl_Color.a == 0, this is a back-facing polygon and the
    // normal should be reversed.
    n = (2.0 * gl_Color.a - 1.0) * normal;
    n = normalize(n);

	
    vec3 light_specular = vec3 (1.0, 1.0, 1.0);
    NdotL = dot(n, lightDir);

    float intensity = length(diffuse_term);
    vec4 dawn = intensity * normalize (vec4 (1.0,0.4,0.4,1.0));
	
    vec4 diff_term = mix(dawn, diffuse_term, smoothstep(0.0, 0.2, NdotL));

    if (NdotL > 0.0) {
        color += diffuse_term * NdotL ;
        NdotHV = max(dot(n, halfVector), 0.0);
        if (gl_FrontMaterial.shininess > 0.0)
            specular.rgb = (gl_FrontMaterial.specular.rgb
                            * light_specular 
                            * pow(NdotHV, gl_FrontMaterial.shininess));
    }
    color.a = diffuse_term.a;
    // This shouldn't be necessary, but our lighting becomes very
    // saturated. Clamping the color before modulating by the texture
    // is closer to what the OpenGL fixed function pipeline does.
    color = clamp(color, 0.0, 1.0);
    texel = texture2D(texture, gl_TexCoord[0].st);
    fragColor = color * texel + specular;
	
    gl_FragColor = fragColor;
}
