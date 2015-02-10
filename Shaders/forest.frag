#version 120

varying vec4 rawpos;
varying vec4 ecPosition;
varying vec3 VTangent;
varying vec3 VBinormal;
varying vec3 VNormal;
varying vec3 Normal;

uniform sampler3D NoiseTex;
uniform sampler2D SampleTex;
uniform sampler1D ColorsTex;
uniform sampler2D SampleTex2;
uniform sampler2D NormalTex;
uniform float depth_factor;

uniform float red, green, blue, alpha;

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

	if ( quality_level >= 3.5 ) {
		linear_search_steps = 20;
	}
	vec2 uv, dp, ds;
	vec3 N;
	float d;
	if ( bump > 0.9 && quality_level >= 2.0 )
	{
		vec3 V = normalize(ecPosition.xyz);
		float a = dot(VNormal, -V);
		vec2 s = vec2(dot(V, VTangent), dot(V, VBinormal));
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


	vec4 basecolor = texture2D(SampleTex, rawpos.xy*0.000344);
	vec4 basecolor2 = texture2D(SampleTex2, rawpos.xy*0.000144);

	basecolor = texture1D(ColorsTex, basecolor.r+0.0);

	vec4 noisevec   = texture3D(NoiseTex, (rawpos.xyz)*0.01*scale);

	vec4 nvL   = texture3D(NoiseTex, (rawpos.xyz)*0.00066*scale);

	float vegetationlevel = (rawpos.z)+nvL[2]*3000.0;

	const float LOG2 = 1.442695;
        float fogCoord = abs(ecPosition.z / ecPosition.w);
	float fogFactor = exp(-gl_Fog.density * gl_Fog.density * fogCoord * fogCoord);
	float biasFactor = exp2(-0.00000002 * fogCoord * fogCoord * LOG2);

	float n = 0.06;
	n += nvL[0]*0.4;
	n += nvL[1]*0.6;
	n += nvL[2]*2.0;
	n += nvL[3]*4.0;
	n += noisevec[0]*0.1;
	n += noisevec[1]*0.4;

	n += noisevec[2]*0.8;
	n += noisevec[3]*2.1;

	//very low n/biasFactor mix, to keep forest color
	n = mix(0.05, n, biasFactor);

	vec4 c1;
	c1 = basecolor * vec4(smoothstep(-1.3, 0.5, n), smoothstep(-1.3, 0.5, n), smoothstep(-2.0, 0.9, n), 0.0);

	vec4 c2;
	c2 = basecolor2 * vec4(smoothstep(-1.3, 0.5, n), smoothstep(-1.3, 0.5, n), smoothstep(-2.0, 0.9, n), 0.0);

	N = normalize(N.x * VTangent + N.y * VBinormal + N.z * VNormal);
	vec3 l = gl_LightSource[0].position.xyz;
	vec3 diffuse;

	//draw floor where !steep, and another blurb for smoothing transitions
	vec4 c3, c4, c5, c3a, c4a, c5a;
	float subred = 1.0 - red; float subgreen = 1.0 - green; float subblue = 1.0 - blue;
	c3 = mix(vec4(n-subred, n-subgreen, -n-subblue, 0.0), c1, smoothstep(0.990, 0.970, abs(normalize(Normal).z)+nvL[2]*1.3));
	c4 = mix(vec4(n-subred, n-subgreen-0.6, -n-subblue, 0.0), c1, smoothstep(0.990, 0.890, abs(normalize(Normal).z)+nvL[2]*0.9));
	c4a = mix(vec4(n-subred+0.12, n-subgreen-0.52, -n-subblue, 0.3), c1, smoothstep(0.990, 0.970, abs(normalize(Normal).z)+nvL[2]*1.32));
	c5 = mix(c3, c4, 1.0);
	c5a = mix(c3, c4a, 1.0);


	if (vegetationlevel <= 2200.0) {
	c1 = mix(c2, c5, clamp(0.65, n*0.1, 0.5));
	diffuse = gl_Color.rgb * max(0.7, dot(N, l)) * max(0.9, dot(VNormal, gl_LightSource[0].position.xyz));
	}

	if (vegetationlevel > 2200.0 && vegetationlevel < 2300.0) {
	c1 = mix(c2, c5, clamp(0.65, n*0.5, 0.35));
	diffuse = gl_Color.rgb * max(0.7, dot(N, l)) * max(0.9, dot(VNormal, gl_LightSource[0].position.xyz));
	}

	if (vegetationlevel >= 2300.0 && vegetationlevel < 2480.0) {
	c1 = mix(c2, c5a, clamp(0.65, n*0.5, 0.30));
	diffuse = gl_Color.rgb * max(0.85, dot(N, l)) * max(0.9, dot(VNormal, gl_LightSource[0].position.xyz));
	}

	if (vegetationlevel >= 2480.0 && vegetationlevel < 2530.0) {
	c1 = mix(c2, c5a, clamp(0.65, n*0.5, 0.20));
	diffuse = gl_Color.rgb * max(0.85, dot(N, l)) * max(0.9, dot(VNormal, gl_LightSource[0].position.xyz));
	}

	if (vegetationlevel >= 2530.0 && vegetationlevel < 2670.0) {
	c1 = mix(c2, c5, clamp(0.65, n*0.5, 0.10));
	diffuse = gl_Color.rgb * max(0.85, dot(N, l)) * max(0.9, dot(VNormal, gl_LightSource[0].position.xyz));
	}

	if (vegetationlevel >= 2670.0) {
	c1 = mix(c2, c5, clamp(0.0, n*0.1, 0.4));
	diffuse = gl_Color.rgb * max(0.85, dot(N, l)) * max(0.9, dot(VNormal, gl_LightSource[0].position.xyz));
	}


	//adding snow and permanent snow/glacier
	if (vegetationlevel > snowlevel) {
	c3 = mix(vec4(n+1.0, n+1.0, n+1.0, 0.0), c1, smoothstep(0.990, 0.965, abs(normalize(Normal).z)+nvL[2]*1.3));
	c4 = mix(vec4(n+1.0, n+1.0, n+1.0, 0.0), c1, smoothstep(0.990, 0.965, abs(normalize(Normal).z)+nvL[2]*0.9));
	c5 = mix(c3, c4, 1.0);
	c1 = mix(c1, c5, clamp(0.65, n*0.5, 0.6));
	diffuse = gl_Color.rgb * max(0.8, dot(N, l)) * max(0.9, dot(VNormal, gl_LightSource[0].position.xyz));
	}

    vec4 ambient_light = gl_LightSource[0].diffuse * vec4(diffuse, 0.0);

	c1 *= ambient_light;
	vec4 finalColor = c1;

	finalColor.rgb = fog_Func(finalColor.rgb, fogType);
	gl_FragColor = finalColor;
}
