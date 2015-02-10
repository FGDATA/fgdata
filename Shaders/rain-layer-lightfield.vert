// -*-C++-*-
#version 120

varying float fogFactor;
varying vec3 hazeColor;

uniform float range; // From /sim/rendering/clouds3d-vis-range
uniform float scattering;
uniform float terminator;
uniform float altitude;


float shade = 0.8;
float cloud_height = 1000.0;
const float EarthRadius = 5800000.0;

// light_func is a generalized logistic function fit to the light intensity as a function
// of scaled terminator position obtained from Flightgear core

float light_func (in float x, in float a, in float b, in float c, in float d, in float e)
{
x = x-0.5;
return e / pow((1.0 + a * exp(-b * (x-c)) ),(1.0/d));
}

void main(void)
{	

  gl_TexCoord[0] = gl_TextureMatrix[0] * gl_MultiTexCoord0;
  //gl_TexCoord[0] = gl_MultiTexCoord0 + vec4(textureIndexX, textureIndexY, 0.0, 0.0);
  vec4 ep = gl_ModelViewMatrixInverse * vec4(0.0,0.0,0.0,1.0);
  vec4 l  = gl_ModelViewMatrixInverse * vec4(0.0,0.0,1.0,1.0);
  vec3 u = normalize(ep.xyz - l.xyz);

  gl_Position = vec4(0.0, 0.0, 0.0, 1.0);
  gl_Position.x = gl_Vertex.x;
  gl_Position.y += gl_Vertex.y;
  gl_Position.z += gl_Vertex.z;
  gl_Position.xyz += gl_Color.xyz;



  // Determine a lighting normal based on the vertex position from the
  // center of the cloud, so that sprite on the opposite side of the cloud to the sun are darker.
  float n = dot(normalize(-gl_LightSource[0].position.xyz),
                normalize(mat3x3(gl_ModelViewMatrix) * (- gl_Position.xyz)));;

  // Determine the position - used for fog and shading calculations
  vec3 ecPosition = vec3(gl_ModelViewMatrix * gl_Position);
  float fogCoord = abs(ecPosition.z);
  float fract = smoothstep(0.0, cloud_height, gl_Position.z + cloud_height);

  vec3 relVector = gl_Position.xyz - ep.xyz;
  gl_Position = gl_ModelViewProjectionMatrix * gl_Position;


// Light at the final position

 // first obtain normal to sun position

  vec3 lightFull = (gl_ModelViewMatrixInverse * gl_LightSource[0].position).xyz;
  vec3 lightHorizon = normalize(vec3(lightFull.x,lightFull.y, 0.0));

 // yprime is the distance of the vertex into sun direction, corrected for altitude
  float vertex_alt = max(altitude * 0.30480 + relVector.z,100.0); 
  float yprime = -dot(relVector, lightHorizon);
  float yprime_alt = yprime -sqrt(2.0 * EarthRadius * vertex_alt);

  // compute the light at the position
  vec4 light_diffuse;
  
  float lightArg = (terminator-yprime_alt)/100000.0;

  light_diffuse.b = light_func(lightArg, 1.330e-05, 0.264, 2.827, 1.08e-05, 1.0);
  light_diffuse.g = light_func(lightArg, 3.931e-06, 0.264, 3.827, 7.93e-06, 1.0);
  light_diffuse.r = light_func(lightArg, 8.305e-06, 0.161, 3.827, 3.04e-05, 1.0);
  light_diffuse.a = 0.0;
  
  //light_diffuse = light_diffuse * scattering;
  float intensity = length(light_diffuse);
  light_diffuse = intensity * normalize(mix(light_diffuse, 2.0*vec4 (0.55, 0.6, 0.8, 1.0), (1.0 - smoothstep(0.3,0.8, scattering))));   

// Determine the shading of the sprite based on its vertical position and position relative to the sun.
  n = min(smoothstep(-0.5, 0.0, n), fract);
// Determine the shading based on a mixture from the backlight to the front
  vec4 backlight = gl_LightSource[0].diffuse * shade;

  gl_FrontColor = mix(backlight, gl_LightSource[0].diffuse, n);
  gl_FrontColor += gl_FrontLightModelProduct.sceneColor;

  // As we get within 100m of the sprite, it is faded out. Equally at large distances it also fades out.
  gl_FrontColor.a = min(smoothstep(100.0, 250.0, fogCoord), 1.0 - smoothstep(range*0.9, range, fogCoord));
  gl_BackColor = gl_FrontColor;

  // Fog doesn't affect rain as much as other objects.
  //fogFactor = exp( -gl_Fog.density * fogCoord * 0.4);
  //fogFactor = clamp(fogFactor, 0.0, 1.0);

float fadeScale = 0.05 + 0.2 * log(fogCoord/1000.0);
  if (fadeScale < 0.05) fadeScale = 0.05;
  fogFactor = exp( -gl_Fog.density * 1.0 * fogCoord * fadeScale);

  hazeColor = light_diffuse.xyz;
  hazeColor.x = hazeColor.x * 0.83;
  hazeColor.y = hazeColor.y * 0.9; 
  hazeColor = hazeColor * scattering;

// change haze color to blue hue for strong fogging
  intensity = length(hazeColor);
  hazeColor = intensity * normalize(mix(hazeColor,  2.0 * vec3 (0.55, 0.6, 0.8), (1.0-smoothstep(0.3,0.8,scattering)))); 

 // two times terminator width governs how quickly light fades into shadow
  float terminator_width = 200000.0;

  // now dim the light
  float earthShade = 0.9 * smoothstep(terminator_width+ terminator, -terminator_width + terminator, yprime_alt) + 0.1;

  hazeColor = hazeColor * earthShade;
  gl_FrontColor.xyz = gl_FrontColor.xyz * earthShade;
  gl_BackColor = gl_FrontColor;

}
