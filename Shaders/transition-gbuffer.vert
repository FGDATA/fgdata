// -*- mode: C; -*-
// Licence: GPL v2
// Authors: Frederic Bouvier, Emilian Huminiuc
//

varying float	RawPosZ;
varying vec3	WorldPos;
varying vec3	normal;
varying vec3	Vnormal;

uniform mat4 osg_ViewMatrixInverse;

void main() {
	RawPosZ = gl_Vertex.z;
	WorldPos = (osg_ViewMatrixInverse *gl_ModelViewMatrix * gl_Vertex).xyz;
	gl_Position = ftransform();
	gl_TexCoord[0] = gl_TextureMatrix[0] * gl_MultiTexCoord0;
	normal = normalize(gl_Normal);
	Vnormal = gl_NormalMatrix * gl_Normal;
}
