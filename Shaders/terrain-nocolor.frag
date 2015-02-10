// -*-C++-*-
uniform sampler2D texture;

////fog "include" /////
uniform int fogType;

vec3 fog_Func(vec3 color, int type);
//////////////////////


void main()
{
    vec4 color = vec4(1.0, 1.0, 1.0, 1.0);
    vec4 texel;
    vec4 fragColor;
    vec4 finalColor;

    texel = texture2D(texture, gl_TexCoord[0].st);
    fragColor = color * texel;

    finalColor.rgb = fog_Func(fragColor.rgb, fogType);
    gl_FragColor = finalColor;

}
