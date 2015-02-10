#version 120
uniform sampler2D baseTexture;
//varying float fogFactor;
//varying vec4 PointPos;
//varying vec4 EyePos;

////fog "include" /////
uniform int fogType;

vec3 fog_Func(vec3 color, int type);
//////////////////////

void main(void)
{
  vec4 base = texture2D( baseTexture, gl_TexCoord[0].st);
	if (base.a <= 0.01)
		discard;
	vec4 fragColor = base * gl_Color;
	//gl_FragColor = vec4(mix(gl_Fog.color.rgb, finalColor.rgb, fogFactor ), finalColor.a);
	fragColor.rgb = fog_Func(fragColor.rgb, fogType);
	gl_FragColor = fragColor;
}
