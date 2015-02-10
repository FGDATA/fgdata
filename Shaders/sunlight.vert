//uniform mat4 fg_ViewMatrixInverse;
uniform mat4 fg_ProjectionMatrixInverse;
varying vec3 ray;
void main() {
    gl_Position = gl_Vertex;
    gl_TexCoord[0] = gl_MultiTexCoord0;
//    ray = (fg_ViewMatrixInverse * vec4((fg_ProjectionMatrixInverse * gl_Vertex).xyz, 0.0)).xyz;
    ray = (fg_ProjectionMatrixInverse * gl_Vertex).xyz;
}
