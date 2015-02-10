// -*-C++-*-
#version 120

varying float fogFactor;

//attribute vec3 usrAttr3;
//attribute vec3 usrAttr4;

//float textureIndexX = usrAttr3.r;
//float textureIndexY = usrAttr3.g;
//float wScale = usrAttr3.b;
//float hScale = usrAttr4.r;
//float shade = usrAttr4.g;
//float cloud_height = usrAttr4.b;

//float shade = usrAttr3.r;
//float cloud_height = usrAttr3.g;
//float scale = usrAttr3.b;

float shading;

float shade = 0.3;
float cloud_height = 1000.0;
float scale = 0.5;

void main(void)
{
  //shade = 0.1 * shade;
  //scale = 0.1 * scale;
 
  gl_TexCoord[0] = gl_TextureMatrix[0] * gl_MultiTexCoord0;
  vec4 ep = gl_ModelViewMatrixInverse * vec4(0.0,0.0,0.0,1.0);
  vec4 l  = gl_ModelViewMatrixInverse * vec4(0.0,0.0,1.0,1.0);
  vec3 view = normalize(ep.xyz - l.xyz);

  vec4 posh = gl_ModelViewMatrixInverse * normalize(vec4(gl_Vertex.x,gl_Vertex.y,gl_Vertex.z,1.0));
  vec3 pos = normalize(ep.xyz - posh.xyz);

  mat4 sprime = mat4(1.0,0.0,0.0,0.0,0.0,0.5,0.0,0.0,0.0,0.0,1.0,0.0,0.0,0.0,0.0,1.0); 
  mat4 scale = gl_ModelViewMatrix * sprime * gl_ModelViewMatrixInverse;  

  float dist = sqrt(gl_Vertex.x * gl_Vertex.x + gl_Vertex.y * gl_Vertex.y + gl_Vertex.z * gl_Vertex.z);
  //vec3 u = normalize(smoothstep(500.0, 1500.0, dist) * pos + (1.0 - smoothstep(500.0, 1500.0, dist)) * view);
  //vec3 u = normalize(mix(pos, view, smoothstep(500.0,1500.0,dist)));
  vec3 u = view;

  // Find a rotation matrix that rotates 1,0,0 into u. u, r and w are
  // the columns of that matrix.
  vec3 absu = abs(u);
  vec3 r = normalize(vec3(-u.y, u.x, 0.0));
  vec3 w = cross(u, r);

  // Do the matrix multiplication by [ u r w pos]. Assume no
  // scaling in the homogeneous component of pos.
  gl_Position = vec4(0.0, 0.0, 0.0, 1.0);
  gl_Position.xyz = gl_Vertex.x * u;
  gl_Position.xyz += gl_Vertex.y * r * 1.0;
  gl_Position.xyz += gl_Vertex.z * w * scale;
  //gl_Position.xyz += gl_Vertex.y * r * wScale;
  //gl_Position.xyz += gl_Vertex.z * w  * hScale;
  gl_Position.xyz += gl_Color.xyz;

  // Determine a lighting normal based on the vertex position from the
  // center of the cloud, so that sprite on the opposite side of the cloud to the sun are darker.
  float n = dot(normalize(-gl_LightSource[0].position.xyz),
                normalize(mat3x3(gl_ModelViewMatrix) * (- gl_Position.xyz)));;

  // Determine the position - used for fog and shading calculations
  vec3 ecPosition = vec3(gl_ModelViewMatrix * gl_Position);
  float fogCoord = abs(ecPosition.z);
  float fract = smoothstep(0.0, cloud_height, gl_Position.z + cloud_height);

  // Final position of the sprite
  gl_Position = gl_ModelViewProjectionMatrix * gl_Position;

// Determine the shading of the sprite based on its vertical position and position relative to the sun.
  n = min(smoothstep(-0.5, 0.0, n), fract);
// Determine the shading based on a mixture from the backlight to the front
  vec4 backlight = gl_LightSource[0].diffuse * shade;

  gl_FrontColor = mix(backlight, gl_LightSource[0].diffuse, n);
  gl_FrontColor += gl_FrontLightModelProduct.sceneColor;

  // As we get within 100m of the sprite, it is faded out. Equally at large distances it also fades out.
  gl_FrontColor.a = min(smoothstep(10.0, 100.0, fogCoord), 1.0 - smoothstep(15000.0, 20000.0, fogCoord));
  gl_BackColor = gl_FrontColor;

  // Fog doesn't affect clouds as much as other objects.
  fogFactor = exp( -gl_Fog.density * fogCoord * 0.2);
  fogFactor = clamp(fogFactor, 0.0, 1.0);
}
