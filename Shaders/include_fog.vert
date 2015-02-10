//varying float fogCoord;
varying vec3 PointPos;
//varying vec4 EyePos;

void fog_Func(int type)
{
    PointPos = (gl_ModelViewMatrix * gl_Vertex).xyz;
    //PointPos = gl_Vertex;
    //EyePos = gl_ModelViewMatrixInverse * vec4(0.0,0.0,0.0,1.0);
		//fogCoord = abs(ecPosition.z);
}
