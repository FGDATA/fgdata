#version 120
uniform sampler2D baseTexture;


void main(void)
{
  vec4 base = texture2D( baseTexture, gl_TexCoord[0].st);
	if (base.a <= 0.01)
		discard;
	
	gl_FragColor = vec4 (1.0, 1.0, 1.0, 1.0);
}
