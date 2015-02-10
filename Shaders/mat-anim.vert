// -*-C++-*-

// Shader that uses OpenGL state values to do per-pixel lighting
//
// The only light used is gl_LightSource[0], which is assumed to be
// directional.
//
// Diffuse colors come from the gl_Color, ambient from the material. This is
// equivalent to osg::Material::DIFFUSE.
vec4 ambientColor();
vec4 diffuseColor();
vec4 specularColor();
vec4 emissionColor();

varying vec4 diffuse, constantColor, matSpecular;
varying vec3 normal;
//varying float alpha, fogCoord;
varying float alpha;

void main()
{
    //vec4 ecPosition = gl_ModelViewMatrix * gl_Vertex;
    //vec3 ecPosition3 = vec3(gl_ModelViewMatrix * gl_Vertex) / ecPosition.w;
    gl_Position = ftransform();
    gl_TexCoord[0] = gl_TextureMatrix[0] * gl_MultiTexCoord0;
    normal = gl_NormalMatrix * gl_Normal;
    diffuse = diffuseColor() * gl_LightSource[0].diffuse;
    // Super hack: if diffuse material alpha is less than 1, assume a
    // transparency animation is at work
    if (gl_FrontMaterial.diffuse.a < 1.0)
        alpha = gl_FrontMaterial.diffuse.a;
    else
        alpha = diffuse.a;
    constantColor =  emissionColor()
        + ambientColor() * (gl_LightModel.ambient + gl_LightSource[0].ambient);
    //fogCoord = abs(ecPosition3.z);
    matSpecular = specularColor();
}
