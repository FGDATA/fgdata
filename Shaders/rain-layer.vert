// -*-C++-*-
#version 120

varying float fogFactor;

uniform float range; // From /sim/rendering/clouds3d-vis-range

float shade = 0.8;
float cloud_height = 1000.0;

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


  gl_Position = gl_ModelViewProjectionMatrix * gl_Position;

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
  fogFactor = exp( -gl_Fog.density * fogCoord * 0.4);
  fogFactor = clamp(fogFactor, 0.0, 1.0);
}
