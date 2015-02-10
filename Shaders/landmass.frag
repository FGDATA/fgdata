#version 120

varying vec4  rawpos;
varying vec4  ecPosition;
varying vec3  VNormal;
varying vec3  VTangent;
varying vec3  VBinormal;
varying vec3  Normal;
varying vec4  constantColor;

uniform sampler3D NoiseTex;
uniform sampler2D BaseTex;
uniform sampler2D NormalTex;
uniform float depth_factor;
uniform float quality_level; // From /sim/rendering/quality-level
uniform float snowlevel; // From /sim/rendering/snow-level-m

const float scale = 1.0;
int linear_search_steps = 10;

////fog "include" /////
uniform int fogType;

vec3 fog_Func(vec3 color, int type);
//////////////////////

float ray_intersect(sampler2D reliefMap, vec2 dp, vec2 ds)
    {

    float size = 1.0 / float(linear_search_steps);
    float depth = 0.0;
    float best_depth = 1.0;

    for(int i = 0; i < linear_search_steps - 1; ++i)
        {
        depth += size;
        float t = texture2D(reliefMap, dp + ds * depth).a;
        if(best_depth > 0.996)
            if(depth >= t)
                best_depth = depth;
        }
    depth = best_depth;

    const int binary_search_steps = 5;

    for(int i = 0; i < binary_search_steps; ++i)
        {
        size *= 0.5;
        float t = texture2D(reliefMap, dp + ds * depth).a;
        if(depth >= t)
            {
            best_depth = depth;
            depth -= 2.0 * size;
            }
        depth += size;
        }

    return(best_depth);
    }

void main (void)
    {
    float bump = 1.0;

    if ( quality_level >= 3.0 ) {
        linear_search_steps = 20;
        }

    vec2 uv, dp = vec2(0, 0), ds = vec2(0, 0);
    vec3 N;
    float d = 0;
    if ( bump > 0.9 && quality_level > 2.0 && quality_level <= 4.0)
        {
        vec3 V = normalize(ecPosition.xyz);
        float a = dot(VNormal, -V);
        vec2 s = vec2(dot(V, VTangent), dot(V, VBinormal));

        // prevent a divide by zero
        if (a > -1e-3 && a < 1e-3) a = 1e-3;
        s *= depth_factor / a;
        ds = s;
        dp = gl_TexCoord[0].st;
        d = ray_intersect(NormalTex, dp, ds);

        uv = dp + ds * d;
        N = texture2D(NormalTex, uv).xyz * 2.0 - 1.0;
        }
    else
        {
        uv = gl_TexCoord[0].st;
        N = vec3(0.0, 0.0, 1.0);
        }

    vec4 noisevec   = texture3D(NoiseTex, (rawpos.xyz)*0.01*scale);
    vec4 nvL   = texture3D(NoiseTex, (rawpos.xyz)*0.00066*scale);

    float fogFactor;
    float fogCoord = ecPosition.z;
    const float LOG2 = 1.442695;
    fogFactor = exp2(-gl_Fog.density * gl_Fog.density * fogCoord * fogCoord * LOG2);
    float biasFactor = fogFactor = clamp(fogFactor, 0.0, 1.0);

    float n=0.06;
    n += nvL[0]*0.4;
    n += nvL[1]*0.6;
    n += nvL[2]*2.0;
    n += nvL[3]*4.0;
    n += noisevec[0]*0.1;
    n += noisevec[1]*0.4;

    n += noisevec[2]*0.8;
    n += noisevec[3]*2.1;
    n = mix(0.6, n, biasFactor);
    // good
    vec4 c1 = texture2D(BaseTex, uv);
    //brown
    //c1 = mix(c1, vec4(n-0.46, n-0.45, n-0.53, 1.0), smoothstep(0.50, 0.55, nvL[2]*6.6));
    //"steep = gray"
    c1 = mix(vec4(n-0.30, n-0.29, n-0.37, 1.0), c1, smoothstep(0.970, 0.990, abs(normalize(Normal).z)+nvL[2]*1.3));
    //"snow"
    c1 = mix(c1, clamp(n+nvL[2]*4.1+vec4(0.1, 0.1, nvL[2]*2.2, 1.0), 0.7, 1.0), smoothstep(snowlevel+300.0, snowlevel+360.0, (rawpos.z)+nvL[1]*3000.0));

    N = normalize(N.x * VTangent + N.y * VBinormal + N.z * VNormal);
    vec3 l = gl_LightSource[0].position.xyz;
    vec3 diffuse = gl_Color.rgb * max(0.0, dot(N, l));
    float shadow_factor = 1.0;

    // Shadow
    if ( quality_level >= 3.0 ) {
        dp += ds * d;
        vec3 sl = normalize( vec3( dot( l, VTangent ), dot( l, VBinormal ), dot( -l, VNormal ) ) );
        ds = sl.xy * depth_factor / sl.z;
        dp -= ds * d;
        float dl = ray_intersect(NormalTex, dp, ds);
        if ( dl < d - 0.05 )
            shadow_factor = dot( constantColor.xyz, vec3( 1.0, 1.0, 1.0 ) ) * 0.25;
        }
    // end shadow

    vec4 ambient_light = constantColor + gl_LightSource[0].diffuse * shadow_factor * vec4(diffuse, 1.0);

    c1 *= ambient_light;
    vec4 finalColor = c1;

    //if(gl_Fog.density == 1.0)
    //    fogFactor=1.0;

//    gl_FragColor = mix(gl_Fog.color ,finalColor, fogFactor);
    finalColor.rgb = fog_Func(finalColor.rgb, fogType);
    gl_FragColor = finalColor;

    }
