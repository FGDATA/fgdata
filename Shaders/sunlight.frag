#version 120
uniform mat4 fg_ViewMatrix;
uniform sampler2D depth_tex;
uniform sampler2D normal_tex;
uniform sampler2D color_tex;
uniform sampler2D spec_emis_tex;
uniform sampler2DShadow shadow_tex;
uniform vec4 fg_SunDiffuseColor;
uniform vec4 fg_SunSpecularColor;
uniform vec3 fg_SunDirection;
uniform vec3 fg_Planes;
uniform int fg_ShadowNumber;
uniform vec4 fg_ShadowDistances;

uniform mat4 fg_ShadowMatrix_0;
uniform mat4 fg_ShadowMatrix_1;
uniform mat4 fg_ShadowMatrix_2;
uniform mat4 fg_ShadowMatrix_3;

uniform int filtering;
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
    float shadow = 0.0;
    if (filtering == 1) {
        shadow = shadow2DProj( shadow_tex, DynamicShadow( vec4( pos, 1.0 ), tint ) ).r;
    } else if (filtering == 2) {
        shadow += 0.333 * shadow2DProj( shadow_tex, DynamicShadow( vec4(pos, 1.0), tint ) ).r;
        shadow += 0.166 * shadow2DProj( shadow_tex, DynamicShadow( vec4(pos + vec3(-0.003 * pos.z, -0.002 * pos.z, 0), 1.0), tint ) ).r;
        shadow += 0.166 * shadow2DProj( shadow_tex, DynamicShadow( vec4(pos + vec3( 0.003 * pos.z,  0.002 * pos.z, 0), 1.0), tint ) ).r;
        shadow += 0.166 * shadow2DProj( shadow_tex, DynamicShadow( vec4(pos + vec3(-0.003 * pos.z,  0.002 * pos.z, 0), 1.0), tint ) ).r;
        shadow += 0.166 * shadow2DProj( shadow_tex, DynamicShadow( vec4(pos + vec3( 0.003 * pos.z, -0.002 * pos.z, 0), 1.0), tint ) ).r;
    } else {
        float kernel[9] = float[9]( 36/256.0, 24/256.0, 6/256.0,
                               24/256.0, 16/256.0, 4/256.0,
                               6/256.0,  4/256.0, 1/256.0 );
        for( int x = -2; x <= 2; ++x )
          for( int y = -2; y <= 2; ++y )
            shadow += kernel[int(abs(float(x))*3 + abs(float(y)))] * shadow2DProj( shadow_tex, DynamicShadow( vec4(pos + vec3(-0.0025 * x * pos.z, -0.0025 * y * pos.z, 0), 1.0), tint ) ).r;
    }
    vec3 lightDir = (fg_ViewMatrix * vec4( fg_SunDirection, 0.0 )).xyz;
    lightDir = normalize( lightDir );
    vec4 color_material = texture2D( color_tex, coords );
    vec3 color = color_material.rgb;
    vec3 Idiff = clamp( dot( lightDir, normal ), 0.0, 1.0 ) * color * fg_SunDiffuseColor.rgb;
    vec3 halfDir = normalize( lightDir - viewDir );
    vec3 Ispec = vec3(0.0);
    vec3 Iemis = spec_emis.z * color;

    float cosAngIncidence = clamp(dot(normal, lightDir), 0.0, 1.0);
    float blinnTerm = clamp( dot( halfDir, normal ), 0.0, 1.0 );

    if (cosAngIncidence > 0.0)
        Ispec = pow( blinnTerm, spec_emis.y * 128.0 ) * spec_emis.x * fg_SunSpecularColor.rgb;

    float matID = color_material.a * 255.0;
    if (matID >= 254.0) // 254: Water, 255: Ubershader
        Idiff += Ispec * spec_emis.x;

    gl_FragColor = vec4(mix(vec3(0.0), Idiff + Ispec, shadow) + Iemis, 1.0);
//    gl_FragColor = mix(tint, vec4(mix(vec3(0.0), Idiff + Ispec, shadow) + Iemis, 1.0), 0.92);
}
