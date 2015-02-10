// -*- mode: C; -*-
// Licence: GPL v2
// Author: Frederic Bouvier.
//  Adapted from the paper by F. Policarpo et al. : Real-time Relief Mapping on Arbitrary Polygonal Surfaces
//  Adapted from the paper and sources by M. Drobot in GPU Pro : Quadtree Displacement Mapping with Height Blending

#version 120

#extension GL_ATI_shader_texture_lod : enable
#extension GL_ARB_shader_texture_lod : enable

#define TEXTURE_MIP_LEVELS 10
#define TEXTURE_PIX_COUNT  1024 //pow(2,TEXTURE_MIP_LEVELS)
#define BINARY_SEARCH_COUNT 10
#define BILINEAR_SMOOTH_FACTOR 2.0

varying vec4  rawpos;
varying vec4  ecPosition;
varying vec3  VNormal;
varying vec3  VTangent;
varying vec3  VBinormal;
varying vec3  Normal;
varying vec4  constantColor;
varying vec4  specular;

uniform sampler3D NoiseTex;
uniform sampler2D BaseTex;
uniform sampler2D NormalTex;
uniform sampler2D QDMTex;
uniform float depth_factor;
uniform float tile_size;
uniform float quality_level;
uniform float snowlevel;
uniform bool random_buildings;

const float scale = 1.0;
int linear_search_steps = 10;
int GlobalIterationCount = 0;
int gIterationCap = 64;

void encode_gbuffer(vec3 normal, vec3 color, int mId, float specular, float shininess, float emission, float depth);

void QDM(inout vec3 p, inout vec3 v)
{
    const int MAX_LEVEL = TEXTURE_MIP_LEVELS;
    const float NODE_COUNT = TEXTURE_PIX_COUNT;
    const float TEXEL_SPAN_HALF = 1.0 / NODE_COUNT / 2.0;

    float fDeltaNC = TEXEL_SPAN_HALF * depth_factor;

    vec3 p2 = p;
    float level = MAX_LEVEL;
    vec2 dirSign = (sign(v.xy) + 1.0) * 0.5;
    GlobalIterationCount = 0;
    float d = 0.0;

    while (level >= 0.0 && GlobalIterationCount < gIterationCap)
    {
        vec4 uv = vec4(p2.xyz, level);
        d = texture2DLod(QDMTex, uv.xy, uv.w).w;

        if (d > p2.z)
        {
            //predictive point of ray traversal
            vec3 tmpP2 = p + v * d;

            //current node count
            float nodeCount = pow(2.0, (MAX_LEVEL - level));
            //current and predictive node ID
            vec4 nodeID = floor(vec4(p2.xy, tmpP2.xy)*nodeCount);

            //check if we are crossing the current cell
            if (nodeID.x != nodeID.z || nodeID.y != nodeID.w)
            {
                //calculate distance to nearest bound
                vec2 a = p2.xy - p.xy;
                vec2 p3 = (nodeID.xy + dirSign) / nodeCount;
                vec2 b = p3.xy - p.xy;

                vec2 dNC = (b.xy * p2.z) / a.xy;
                //take the nearest cell
                d = min(d,min(dNC.x, dNC.y))+fDeltaNC;

                level++;

            }
            p2 = p + v * d;
        }
        level--;
        GlobalIterationCount++;
    }

    //
    // Manual Bilinear filtering
    //
    float rayLength =  length(p2.xy - p.xy) + fDeltaNC;

    float dA = p2.z * (rayLength - BILINEAR_SMOOTH_FACTOR * TEXEL_SPAN_HALF) / rayLength;
    float dB = p2.z * (rayLength + BILINEAR_SMOOTH_FACTOR * TEXEL_SPAN_HALF) / rayLength;

    vec4 p2a = vec4(p + v * dA, 0.0);
    vec4 p2b = vec4(p + v * dB, 0.0);
    dA = texture2DLod(NormalTex, p2a.xy, p2a.w).w;
    dB = texture2DLod(NormalTex, p2b.xy, p2b.w).w;

    dA = abs(p2a.z - dA);
    dB = abs(p2b.z - dB);

    p2 = mix(p2a.xyz, p2b.xyz, dA / (dA + dB));

    p = p2;
}

float ray_intersect_QDM(vec2 dp, vec2 ds)
{
    vec3 p = vec3( dp, 0.0 );
    vec3 v = vec3( ds, 1.0 );
    QDM( p, v );
    return p.z;
}

float ray_intersect_relief(vec2 dp, vec2 ds)
{
    float size = 1.0 / float(linear_search_steps);
    float depth = 0.0;
    float best_depth = 1.0;

    for(int i = 0; i < linear_search_steps - 1; ++i)
    {
        depth += size;
        float t = step(0.95, texture2D(NormalTex, dp + ds * depth).a);
        if(best_depth > 0.996)
            if(depth >= t)
                best_depth = depth;
    }
    depth = best_depth;

    const int binary_search_steps = 5;

    for(int i = 0; i < binary_search_steps; ++i)
    {
        size *= 0.5;
        float t = step(0.95, texture2D(NormalTex, dp + ds * depth).a);
        if(depth >= t)
        {
            best_depth = depth;
            depth -= 2.0 * size;
        }
        depth += size;
    }

    return(best_depth);
}

float ray_intersect(vec2 dp, vec2 ds)
{
    if ( random_buildings )
        return 0.0;
    else if ( quality_level >= 4.0 )
        return ray_intersect_QDM( dp, ds );
    else
        return ray_intersect_relief( dp, ds );
}

void main (void)
{
    if ( quality_level >= 3.0 ) {
        linear_search_steps = 20;
    }

    float depthfactor = depth_factor;
    if ( random_buildings )
        depthfactor = 0.0;

    vec3 normal = normalize(VNormal);
    vec3 tangent = normalize(VTangent);
    vec3 binormal = normalize(VBinormal);
    vec3 ecPos3 = ecPosition.xyz / ecPosition.w;
    vec3 V = normalize(ecPos3);
    vec3 s = vec3(dot(V, tangent), dot(V, binormal), dot(normal, -V));
    vec2 ds = s.xy * depthfactor / s.z;
    vec2 dp = gl_TexCoord[0].st - ds;
    float d = ray_intersect(dp, ds);

    vec2 uv = dp + ds * d;
    vec3 N = texture2D(NormalTex, uv).xyz;
    float emis = N.z;
    N = N * 2.0 - 1.0;


    N.z = sqrt(1.0 - min(1.0,dot(N.xy, N.xy)));
    float Nz = N.z;
    N = normalize(N.x * tangent + N.y * binormal + N.z * normal);

    vec4 ambient_light = constantColor + vec4(gl_Color.rgb, 1.0);

    // vec4 noisevec   = texture3D(NoiseTex, (rawpos.xyz)*0.01*scale);
    // vec4 nvL   = texture3D(NoiseTex, (rawpos.xyz)*0.00066*scale);

    // float n=0.06;
    // n += nvL[0]*0.4;
    // n += nvL[1]*0.6;
    // n += nvL[2]*2.0;
    // n += nvL[3]*4.0;
    // n += noisevec[0]*0.1;
    // n += noisevec[1]*0.4;

    // n += noisevec[2]*0.8;
    // n += noisevec[3]*2.1;
    // n = mix(0.6, n, length(ecPosition.xyz) );

    vec4 finalColor = texture2D(BaseTex, uv);
    // finalColor = mix(finalColor, clamp(n+nvL[2]*4.1+vec4(0.1, 0.1, nvL[2]*2.2, 1.0), 0.7, 1.0),
            // step(0.8,Nz)*(1.0-emis)*smoothstep(snowlevel+300.0, snowlevel+360.0, (rawpos.z)+nvL[1]*3000.0));
    // finalColor *= ambient_light;

    vec4 p = vec4( ecPos3 + tile_size * V * (d-1.0) * depthfactor / s.z, 1.0 );

    if (dot(normal,-V) > 0.1) {
        vec4 iproj = gl_ProjectionMatrix * p;
        iproj /= iproj.w;
        gl_FragDepth = (iproj.z+1.0)/2.0;
    } else {
        gl_FragDepth = gl_FragCoord.z;
    }
    encode_gbuffer(N, finalColor.rgb, 1, dot(specular.xyz,vec3(0.3, 0.59, 0.11 )), specular.w, 0.0, gl_FragDepth);
}
