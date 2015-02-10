uniform sampler2D baseTexture;
varying float fogFactor;
varying vec4  cloudColor;

void main(void)
{
      vec4 base = texture2D( baseTexture, gl_TexCoord[0].st);
      if (base.a < 0.02)
        discard;

      vec4 finalColor = base * cloudColor;
      gl_FragColor.rgb = mix(gl_Fog.color.rgb, finalColor.rgb, fogFactor );
      gl_FragColor.a = finalColor.a;
}

