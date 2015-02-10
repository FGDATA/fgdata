uniform mat4 fg_ViewMatrix;
uniform sampler2D depth_tex;
uniform sampler2D normal_tex;
uniform sampler2D color_tex;
uniform sampler2D spec_emis_tex;
uniform sampler2DShadow shadow_tex;
uniform vec4 fg_SunDiffuseColor;
uniform vec4 fg_SunSpecularColor;
uniform vec4 fg_SunAmbientColor;
uniform vec3 fg_SunDirection;
uniform vec3 fg_Planes;
uniform int fg_ShadowNumber;
uniform vec4 fg_ShadowDistances;

uniform mat4 fg_ShadowMatrix_0;
uniform mat4 fg_ShadowMatrix_1;
uniform mat4 fg_ShadowMatrix_2;
uniform mat4 fg_ShadowMatrix_3;

varying vec3 ray;

vec3 position( vec3 viewDir, vec2 coords, sampler2D depth_tex );
vec3 normal_decode(vec2 enc);

vec4 DynamicShadow( in vec4 ecPosition, out vec4 tint )
{
    vec4 coords;
    vec2 shift = vec2( 0.0 );
    int index = 4;
    float factor = 0.5;
    if (ecPosition.z > -fg_ShadowDistances.x) {
        index = 1;
        if (fg_ShadowNumber == 1)
            factor = 1.0;
        tint = vec4(0.0,1.0,0.0,1.0);
        coords = fg_ShadowMatrix_0 * ecPosition;
    } else if (ecPosition.z > -fg_ShadowDistances.y && fg_ShadowNumber > 1) {
        index = 2;
        shift = vec2( 0.0, 0.5 );
        tint = vec4(0.0,0.0,1.0,1.0);
        coords = fg_ShadowMatrix_1 * ecPosition;
    } else if (ecPosition.z > -fg_ShadowDistances.z && fg_ShadowNumber > 2) {
        index = 3;
        shift = vec2( 0.5, 0.0 );
        tint = vec4(1.0,1.0,0.0,1.0);
        coords = fg_ShadowMatrix_2 * ecPosition;
    } else if (ecPosition.z > -fg_ShadowDistances.w && fg_ShadowNumber > 3) {
        shift = vec2( 0.5, 0.5 );
        tint = vec4(1.0,0.0,0.0,1.0);
        coords = fg_ShadowMatrix_3 * ecPosition;
    } else {
        return vec4(1.1,1.1,0.0,1.0); // outside, clamp to border
    }
    coords.st *= factor;
    coords.st += shift;
    return coords;
}
void main() {
    vec2 coords = gl_TexCoord[0].xy;
    vec4 spec_emis = texture2D( spec_emis_tex, coords );
    if ( spec_emis.a < 0.1 )
        discard;
    vec3 normal = normal_decode(texture2D( normal_tex, coords ).rg);
    vec3 viewDir = normalize(ray);
    vec3 pos = position( viewDir, coords, depth_tex );

    vec4 tint;
    float shadow = shadow2DProj( shadow_tex, DynamicShadow( vec4( pos, 1.0 ), tint ) ).r;
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

    gl_FragColor = vec4(mix(vec3(0.0), Idiff + Ispec, shadow) + Iemis, 1.0);
//    gl_FragColor = mix(tint, vec4(mix(vec3(0.0), Idiff + Ispec, shadow) + Iemis, 1.0), 0.92);
}
