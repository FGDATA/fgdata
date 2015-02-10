uniform mat4 fg_ProjectionMatrixInverse;
varying vec4 ray;
void main() {
    gl_Position = gl_Vertex;
    gl_TexCoord[0] = gl_MultiTexCoord0;
    ray = fg_ProjectionMatrixInverse * gl_Vertex;
}
