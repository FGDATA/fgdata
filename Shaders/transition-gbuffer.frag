// -*-C++-*-
// Texture switching based on face slope and snow level
// based on earlier work by Frederic Bouvier, Tim Moore, and Yves Sablonier.
// � Emilian Huminiuc 2011


varying float	RawPosZ;
varying vec3	WorldPos;
varying vec3	normal;
varying vec3    Vnormal;

uniform float	SnowLevel;
uniform float   Transitions;
uniform float   InverseSlope;
uniform float   RainNorm;

uniform float	CloudCover0;
uniform float	CloudCover1;
uniform float	CloudCover2;
uniform float	CloudCover3;
uniform float	CloudCover4;

uniform sampler2D BaseTex;
uniform sampler2D SecondTex;
uniform sampler2D ThirdTex;
uniform sampler2D SnowTex;

uniform sampler3D NoiseTex;

// gbuffer function
void encode_gbuffer(vec3 normal, vec3 color, int mId, float specular, float shininess, float emission, float depth);
///////////////////

void main()
    {
    float NdotL;
    float NdotHV;
    float fogFactor;
    float cover;
    float slope;
    float L1;
    float L2;
    float wetness;
	float pf;

    vec3 n;
    vec3 lightDir;
    vec3 halfVector;

    vec4 texel;
    vec4 fragColor;
    vec4 color;
    
    cover = min(min(min(min(CloudCover0, CloudCover1),CloudCover2),CloudCover3),CloudCover4);

    vec4 Noise =  texture3D(NoiseTex, WorldPos.xyz*0.0011);
	vec4 Noise2 = texture3D(NoiseTex, WorldPos.xyz * 0.00008);
    float MixFactor = Noise.r * Noise.g * Noise.b;	//Mixing Factor to create a more organic looking boundary
    float MixFactor2 = Noise2.r * Noise2.g * Noise2.b;
    MixFactor *= 300.0;
	MixFactor2 *= 300.0;
    MixFactor = clamp(MixFactor, 0.0, 1.0);
	MixFactor2 = clamp(MixFactor2, 0.0, 1.0);
    L1 = 0.90 - 0.02 * MixFactor;			//first transition slope
    L2 = 0.78 + 0.04 * MixFactor;			//Second transition slope

    // If gl_Color.a == 0, this is a back-facing polygon and the
    // Vnormal should be reversed.
    n = (2.0 * gl_Color.a - 1.0) * Vnormal;
    n = normalize(n);

	color = vec4(1.0);

    //Select texture based on slope
    slope = normalize(normal).z;

    //pull the texture fetch outside flow control to fix aliasing artefacts :(
    vec4 baseTexel		= texture2D(BaseTex, gl_TexCoord[0].st);
    vec4 secondTexel	= texture2D(SecondTex, gl_TexCoord[0].st);
    vec4 thirdTexel		= texture2D(ThirdTex, gl_TexCoord[0].st);
    vec4 snowTexel		= texture2D(SnowTex, gl_TexCoord[0].st);

    //Normal transition. For more abrupt faces apply another texture (or 2).
    if (InverseSlope == 0.0) {
        //Do we do an intermediate transition
        if (Transitions >= 1.5) {
            if (slope >= L1) {
                texel = baseTexel;
                }
            if (slope >= L2  && slope < L1){
                texel = mix(secondTexel, baseTexel, smoothstep(L2, L1 - 0.06 * MixFactor, slope));
                }
            if (slope < L2){
                texel = mix(thirdTexel, secondTexel, smoothstep(L2 - 0.13 * MixFactor, L2, slope));
                }
            // Just one transition
            } else 	if (Transitions < 1.5) {
                if (slope >= L1) {
                    texel = baseTexel;
                    }
                if (slope < L1) {
                    texel = mix(thirdTexel, baseTexel, smoothstep(L2 - 0.13 * MixFactor, L1, slope));
                    }
            }

        //Invert the transition: keep original texture on abrupt slopes and switch to another on flatter terrain
        } else  if (InverseSlope > 0.0) {
            //Interemdiate transition ?
            if (Transitions >= 1.5) {
                if (slope >= L1 + 0.1) {
                    texel = thirdTexel;
                    }
                if (slope >= L2 && slope < L1 + 0.1){
                    texel = mix(secondTexel, thirdTexel, smoothstep(L2 + 0.06 * MixFactor, L1 + 0.1, slope));
                    }
                if (slope <= L2){
                    texel = mix(baseTexel, secondTexel, smoothstep(L2 - 0.06 * MixFactor, L2, slope));
                    }
                //just one
                } else if (Transitions < 1.5) {
                    if (slope > L1 + 0.1) {
                        texel = thirdTexel;
                        }
                    if (slope <= L1 + 0.1){
                        texel = mix(baseTexel, thirdTexel, smoothstep(L2 - 0.06 * MixFactor, L1 + 0.1, slope));
                        }
                }
        }

    //darken textures with wetness
    wetness = 1.0 - 0.3 * RainNorm;
    texel.rgb = texel.rgb * wetness;

    float altitude = RawPosZ;
    //Snow texture for areas higher than SnowLevel
    if (altitude >= SnowLevel - (1000.0 * slope + 300.0 * MixFactor) && slope > L2 - 0.12) {
        texel = mix( texel,
					mix( texel, snowTexel, smoothstep(L2 - 0.09 * MixFactor, L2, slope) ),
                    smoothstep(SnowLevel - (1000.0 * slope + 300.0 * MixFactor),
                               SnowLevel - (1000.0 * slope - 150.0 * MixFactor),
                               altitude)
                   );
        }

    fragColor = color * texel;

    if(cover >= 2.5){
        fragColor.rgb = fragColor.rgb * 1.2;
        } else {
            fragColor.rg = fragColor.rg * (0.6 + 0.2 * cover);
            fragColor.b = fragColor.b * (0.5 + 0.25 * cover);
        }


	fragColor.rgb *= 1.2 - 0.6 * MixFactor * MixFactor2;

	float specular = dot( gl_FrontMaterial.specular.rgb, vec3( 0.3, 0.59, 0.11 ) );
	float emission = dot( gl_FrontLightModelProduct.sceneColor.rgb + gl_FrontMaterial.emission.rgb,
						  vec3( 0.3, 0.59, 0.11 )
						);

	encode_gbuffer( n, fragColor.rgb, 1, specular, gl_FrontMaterial.shininess, emission, gl_FragCoord.z );
    }
