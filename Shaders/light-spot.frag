uniform vec2 fg_BufferSize;
uniform vec3 fg_Planes;

uniform sampler2D depth_tex;
uniform sampler2D normal_tex;
uniform sampler2D color_tex;
uniform sampler2D spec_emis_tex;
uniform vec4 LightPosition;
uniform vec4 LightDirection;
uniform vec4 Ambient;
uniform vec4 Diffuse;
uniform vec4 Specular;
uniform vec3 Attenuation;
uniform float Exponent;
uniform float Cutoff;
uniform float CosCutoff;
uniform float Near;
uniform float Far;

varying vec4 ecPosition;

vec3 position( vec3 viewDir, vec2 coords, sampler2D depth_tex );
vec3 normal_decode(vec2 enc);

void main() {
    vec3 ray = ecPosition.xyz / ecPosition.w;
    vec3 ecPos3 = ray;
    vec3 viewDir = normalize(ray);
    vec2 coords = gl_FragCoord.xy / fg_BufferSize;

    vec3 normal = normal_decode(texture2D( normal_tex, coords ).rg);
    vec4 spec_emis = texture2D( spec_emis_tex, coords );

    vec3 pos = position(viewDir, coords, depth_tex);

    if ( pos.z < ecPos3.z ) // Negative direction in z
        discard; // Don't light surface outside the light volume

    vec3 VP = LightPosition.xyz - pos;
    if ( dot( VP, VP ) > ( Far * Far ) )
        discard; // Don't light surface outside the light volume

    float d = length( VP );
    VP /= d;

    vec3 halfVector = normalize(VP - viewDir);

    float att = 1.0 / (Attenuation.x + Attenuation.y * d + Attenuation.z *d*d);
    float spotDot = dot(-VP, normalize(LightDirection.xyz));

    float spotAttenuation = 0.0;
    if (spotDot < CosCutoff)
        spotAttenuation = 0.0;
    else
        spotAttenuation = pow(spotDot, Exponent);
    att *= spotAttenuation;

    float cosAngIncidence = clamp(dot(normal, VP), 0.0, 1.0);

    float nDotVP = max(0.0, dot(normal, VP));
    float nDotHV = max(0.0, dot(normal, halfVector));

    vec4 color_material = texture2D( color_tex, coords );
    vec3 color = color_material.rgb;
    vec3 Iamb = Ambient.rgb * color * att;
    vec3 Idiff = Diffuse.rgb * color * att * nDotVP;

    float matID = color_material.a * 255.0;
    float spec_intensity = spec_emis.x;
    float spec_att = att;
    if (matID == 254.0) { // 254: water, 255: Ubershader
        spec_intensity = 1.0; // spec_color shouldn't depend on cloud cover when rendering spot light
        spec_att = min(10.0 * att, 1.0); // specular attenuation reduced on water
    }

    vec3 Ispec = vec3(0.0);
    if (cosAngIncidence > 0.0)
        Ispec = pow( nDotHV, spec_emis.y * 128.0 ) * spec_intensity * spec_att * Specular.rgb;

    if (matID >= 254.0)
        Idiff += Ispec * spec_emis.x;

    gl_FragColor = vec4(Iamb + Idiff + Ispec, 1.0);
}
