// Tree instance scheme:
// vertex - local position of quad vertex.
// normal - x y scaling, z number of varieties
// fog coord - rotation
// color - xyz of tree quad origin, replicated 4 times.
#version 120
//varying float fogCoord;
// varying vec3 PointPos;
//varying vec4 EyePos;
// ////fog "include"////////
// uniform int fogType;
//
// void fog_Func(int type);
// /////////////////////////
uniform float season;

void main(void)
{
  float numVarieties = gl_Normal.z;
  float texFract = floor(fract(gl_MultiTexCoord0.x) * numVarieties) / numVarieties;
  texFract += floor(gl_MultiTexCoord0.x) / numVarieties;
  
  // Determine the rotation for the tree.  The Fog Coordinate provides rotation information
  // to rotate one of the quands by 90 degrees.  We then apply an additional position seed
  // so that trees aren't all oriented N/S
  float sr = sin(gl_FogCoord + gl_Color.x);
  float cr = cos(gl_FogCoord + gl_Color.x);
  gl_TexCoord[0] = vec4(texFract, gl_MultiTexCoord0.y, 0.0, 0.0);
  gl_TexCoord[0].y =  gl_TexCoord[0].y + 0.5 * season;

  // scaling
  vec3 position = gl_Vertex.xyz * gl_Normal.xxy;

  // Rotation of the generic quad to specific one for the tree.
  position.xy = vec2(dot(position.xy, vec2(cr, sr)), dot(position.xy, vec2(-sr, cr)));
  position = position + gl_Color.xyz;
  gl_Position   = gl_ModelViewProjectionMatrix * vec4(position,1.0);
  vec3 ecPosition = vec3(gl_ModelViewMatrix * vec4(position, 1.0));

  float n = dot(normalize(gl_LightSource[0].position.xyz), normalize(-ecPosition));

  vec3 diffuse = gl_FrontMaterial.diffuse.rgb * max(0.1, n);
  vec4 ambientColor = gl_FrontLightModelProduct.sceneColor + gl_LightSource[0].ambient * gl_FrontMaterial.ambient;
  gl_FrontColor = ambientColor + gl_LightSource[0].diffuse * vec4(diffuse, 1.0);

  //fogCoord = abs(ecPosition.z);
  //fogFactor = exp( -gl_Fog.density * gl_Fog.density * fogCoord * fogCoord);
  //fogFactor = clamp(fogFactor, 0.0, 1.0);
//	fog_Func(fogType);
// 	PointPos = ecPosition;
	//EyePos = gl_ModelViewMatrixInverse * vec4(0.0,0.0,0.0,1.0);
}
