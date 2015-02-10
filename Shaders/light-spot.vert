varying vec4 ecPosition;

void main() {
    ecPosition = gl_ModelViewMatrix * gl_Vertex;
    gl_Position = ftransform();
}
