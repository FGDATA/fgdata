// -*- mode: C; -*-
// Licence: GPL v2
// Author: Frederic Bouvier

//varying float fogCoord;
varying vec3 VNormal;
varying vec3 VTangent;
varying vec3 VBinormal;

attribute vec3 tangent;
attribute vec3 binormal;

void main (void)
{
//	vec4 pos = gl_ModelViewMatrix * gl_Vertex;
//        fogCoord = pos.z / pos.w;

	VNormal = normalize(gl_NormalMatrix * gl_Normal);
	VTangent = normalize(gl_NormalMatrix * tangent);
	VBinormal = normalize(gl_NormalMatrix * binormal);

	gl_FrontColor = gl_FrontLightModelProduct.sceneColor + gl_LightSource[0].ambient * gl_FrontMaterial.ambient;
	gl_TexCoord[0] = gl_MultiTexCoord0;
	gl_Position = ftransform();
}
