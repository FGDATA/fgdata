// varying float fogCoord;

void main()
{
//     vec3 ecPosition = vec3(gl_ModelViewMatrix * gl_Vertex);

    gl_Position = ftransform();
//     fogCoord = abs(ecPosition.z);
}
