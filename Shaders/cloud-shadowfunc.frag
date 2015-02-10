#version 120
uniform float cloudpos1_x;
uniform float cloudpos1_y;
uniform float cloudpos2_x;
uniform float cloudpos2_y;
uniform float cloudpos3_x;
uniform float cloudpos3_y;
uniform float cloudpos4_x;
uniform float cloudpos4_y;
uniform float cloudpos5_x;
uniform float cloudpos5_y;
uniform float cloudpos6_x;
uniform float cloudpos6_y;
uniform float cloudpos7_x;
uniform float cloudpos7_y;
uniform float cloudpos8_x;
uniform float cloudpos8_y;
uniform float cloudpos9_x;
uniform float cloudpos9_y;
uniform float cloudpos10_x;
uniform float cloudpos10_y;
uniform float cloudpos11_x;
uniform float cloudpos11_y;
uniform float cloudpos12_x;
uniform float cloudpos12_y;
uniform float cloudpos13_x;
uniform float cloudpos13_y;
uniform float cloudpos14_x;
uniform float cloudpos14_y;
uniform float cloudpos15_x;
uniform float cloudpos15_y;
uniform float cloudpos16_x;
uniform float cloudpos16_y;
uniform float cloudpos17_x;
uniform float cloudpos17_y;
uniform float cloudpos18_x;
uniform float cloudpos18_y;
uniform float cloudpos19_x;
uniform float cloudpos19_y;
uniform float cloudpos20_x;
uniform float cloudpos20_y;

float shadow_func (in float x, in float y, in float noise, in float dist)
{

if (dist > 30000.0) {return 1.0;}

float width =  fract((cloudpos1_x)) * 5000.0;
float strength = fract((cloudpos1_y));


float dlength = length( vec2 (x - cloudpos1_x, y - cloudpos1_y));
float shadeValue = strength * (1.0-smoothstep(width * 0.5, width, dlength));

dlength = length ( vec2 (x - cloudpos2_x, y - cloudpos2_y));
width = fract((cloudpos2_x)) * 5000.0; strength = fract((cloudpos2_y));
shadeValue = shadeValue + strength * (1.0-smoothstep(width * 0.5, width, dlength));

dlength = length ( vec2 (x - cloudpos3_x, y - cloudpos3_y));
width = fract((cloudpos3_x)) * 5000.0; strength = fract((cloudpos3_y));
shadeValue = shadeValue + strength * (1.0-smoothstep(width * 0.5, width, dlength));

dlength = length ( vec2 (x - cloudpos4_x, y - cloudpos4_y));
width = fract((cloudpos4_x)) * 5000.0; strength = fract((cloudpos4_y));
shadeValue = shadeValue + strength * (1.0-smoothstep(width * 0.5, width, dlength));

dlength = length ( vec2 (x - cloudpos5_x, y - cloudpos5_y));
width = fract((cloudpos5_x)) * 5000.0; strength = fract((cloudpos5_y));
shadeValue = shadeValue + strength * (1.0-smoothstep(width * 0.5, width, dlength));

dlength = length ( vec2 (x - cloudpos6_x, y - cloudpos6_y));
width = fract((cloudpos6_x)) * 5000.0; strength = fract((cloudpos6_y));
shadeValue = shadeValue + strength * (1.0-smoothstep(width * 0.5, width, dlength));

dlength = length ( vec2 (x - cloudpos7_x, y - cloudpos7_y));
width = fract((cloudpos7_x)) * 5000.0; strength = fract((cloudpos7_y));
shadeValue = shadeValue + strength * (1.0-smoothstep(width * 0.5, width, dlength));

dlength = length ( vec2 (x - cloudpos8_x, y - cloudpos8_y));
width = fract((cloudpos8_x)) * 5000.0; strength = fract((cloudpos8_y));
shadeValue = shadeValue + strength * (1.0-smoothstep(width * 0.5, width, dlength));

dlength = length ( vec2 (x - cloudpos9_x, y - cloudpos9_y));
width = fract((cloudpos9_x)) * 5000.0; strength = fract((cloudpos9_y));
shadeValue = shadeValue + strength * (1.0-smoothstep(width * 0.5, width, dlength));

dlength = length ( vec2 (x - cloudpos10_x, y - cloudpos10_y));
width = fract((cloudpos10_x)) * 5000.0; strength = fract((cloudpos10_y));
shadeValue = shadeValue + strength * (1.0-smoothstep(width * 0.5, width, dlength));

dlength = length ( vec2 (x - cloudpos11_x, y - cloudpos11_y));
width = fract((cloudpos11_x)) * 5000.0; strength = fract((cloudpos11_y));
shadeValue = shadeValue + strength * (1.0-smoothstep(width * 0.5, width, dlength));

dlength = length ( vec2 (x - cloudpos12_x, y - cloudpos12_y));
width = fract((cloudpos12_x)) * 5000.0; strength = fract((cloudpos12_y));
shadeValue = shadeValue + strength * (1.0-smoothstep(width * 0.5, width, dlength));

dlength = length ( vec2 (x - cloudpos13_x, y - cloudpos13_y));
width = fract((cloudpos13_x)) * 5000.0; strength = fract((cloudpos13_y));
shadeValue = shadeValue + strength * (1.0-smoothstep(width * 0.5, width, dlength));

dlength = length ( vec2 (x - cloudpos14_x, y - cloudpos14_y));
width = fract((cloudpos14_x)) * 5000.0; strength = fract((cloudpos14_y));
shadeValue = shadeValue + strength * (1.0-smoothstep(width * 0.5, width, dlength));

dlength = length ( vec2 (x - cloudpos15_x, y - cloudpos15_y));
width = fract((cloudpos15_x)) * 5000.0; strength = fract((cloudpos15_y));
shadeValue = shadeValue + strength * (1.0-smoothstep(width * 0.5, width, dlength));

dlength = length ( vec2 (x - cloudpos16_x, y - cloudpos16_y));
width = fract((cloudpos16_x)) * 5000.0; strength = fract((cloudpos16_y));
shadeValue = shadeValue + strength * (1.0-smoothstep(width * 0.5, width, dlength));

dlength = length ( vec2 (x - cloudpos17_x, y - cloudpos17_y));
width = fract((cloudpos17_x)) * 5000.0; strength = fract((cloudpos17_y));
shadeValue = shadeValue + strength * (1.0-smoothstep(width * 0.5, width, dlength));

dlength = length ( vec2 (x - cloudpos18_x, y - cloudpos18_y));
width = fract((cloudpos18_x)) * 5000.0; strength = fract((cloudpos18_y));
shadeValue = shadeValue + strength * (1.0-smoothstep(width * 0.5, width, dlength));

dlength = length ( vec2 (x - cloudpos19_x, y - cloudpos19_y));
width = fract((cloudpos19_x)) * 5000.0; strength = fract((cloudpos19_y));
shadeValue = shadeValue + strength * (1.0-smoothstep(width * 0.5, width, dlength));

dlength = length ( vec2 (x - cloudpos20_x, y - cloudpos20_y));
width = fract((cloudpos20_x)) * 5000.0; strength = fract((cloudpos20_y));
shadeValue = shadeValue + strength * (1.0-smoothstep(width * 0.5, width, dlength));

shadeValue =  shadeValue * (0.8 + 2.0 * shadeValue * smoothstep(0.4,0.6,noise));
shadeValue = clamp(shadeValue,0.0,1.0);
shadeValue = shadeValue * (1.0 - smoothstep(15000.0, 30000.0,dist));

return 1.0 - shadeValue;

}
