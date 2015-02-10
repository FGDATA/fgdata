varying vec4 rawpos;
varying vec4 ecPosition;
varying vec3 VNormal;
varying vec3 Normal;
varying vec3 lightVec;

void main(void)
{
	rawpos     = gl_Vertex;
	ecPosition = gl_ModelViewMatrix * gl_Vertex;
	VNormal = normalize(gl_NormalMatrix * gl_Normal);
	Normal = normalize(gl_Normal);
	lightVec = normalize(gl_LightSource[0].position.xyz/* - ecPosition*/);
	gl_Position = ftransform();
}
