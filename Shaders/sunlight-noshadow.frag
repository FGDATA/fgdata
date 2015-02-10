uniform mat4 fg_ViewMatrix;
uniform sampler2D depth_tex;
uniform sampler2D normal_tex;
uniform sampler2D color_tex;
uniform sampler2D spec_emis_tex;
uniform vec4 fg_SunDiffuseColor;
uniform vec4 fg_SunSpecularColor;
uniform vec3 fg_SunDirection;
uniform vec3 fg_Planes;
varying vec3 ray;

vec3 normal_decode(vec2 enc);

void main() {
    vec2 coords = gl_TexCoord[0].xy;
    vec4 spec_emis = texture2D( spec_emis_tex, coords );
    if ( spec_emis.a < 0.1 )
        discard;
    vec3 normal = normal_decode(texture2D( normal_tex, coords ).rg);
    vec3 viewDir = normalize(ray);

    vec3 lightDir = (fg_ViewMatrix * vec4( fg_SunDirection, 0.0 )).xyz;
    lightDir = normalize( lightDir );
    vec3 color = texture2D( color_tex, coords ).rgb;
    vec3 Idiff = clamp( dot( lightDir, normal ), 0.0, 1.0 ) * color * fg_SunDiffuseColor.rgb;
    vec3 halfDir = normalize( lightDir - viewDir );
    vec3 Ispec = vec3(0.0);
    vec3 Iemis = spec_emis.z * color;

    float cosAngIncidence = clamp(dot(normal, lightDir), 0.0, 1.0);
    float blinnTerm = clamp( dot( halfDir, normal ), 0.0, 1.0 );

    if (cosAngIncidence > 0.0)
        Ispec = pow( blinnTerm, spec_emis.y * 128.0 ) * spec_emis.x * fg_SunSpecularColor.rgb;

    float matID = texture2D( color_tex, coords ).a * 255.0;
    if (matID >= 254.0)
        Idiff += Ispec * spec_emis.x;

    gl_FragColor = vec4(Idiff + Ispec + Iemis, 1.0);
}
