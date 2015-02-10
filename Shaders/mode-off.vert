// -*-C++-*-
#version 120

vec4 ambientColor()
{
    return gl_FrontMaterial.ambient;
}

vec4 diffuseColor()
{
    return gl_FrontMaterial.diffuse;
}

vec4 specularColor()
{
    return gl_FrontMaterial.specular;
}

vec4 emissionColor()
{
    return gl_FrontMaterial.emission;
}
