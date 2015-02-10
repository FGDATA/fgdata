#version 120

varying vec4 rawpos;
varying vec4 ecPosition;
varying vec3 VNormal;
varying vec3 Normal;
varying vec4 constantColor;

void main(void)
{
	gl_TexCoord[0]  = gl_MultiTexCoord0;

	rawpos = gl_Vertex;
	ecPosition = gl_ModelViewMatrix * gl_Vertex;
	VNormal = normalize(gl_NormalMatrix * gl_Normal);
	Normal = normalize(gl_Normal);
	
	gl_FrontColor = gl_Color;
	
	constantColor = gl_FrontMaterial.emission
		+ gl_Color * (gl_LightModel.ambient + gl_LightSource[0].ambient);
	
	gl_Position = ftransform();
}