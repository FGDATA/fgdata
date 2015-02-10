// -*- mode: C; -*-
// Licence: GPL v2
// © Emilian Huminiuc and Vivian Meazza 2011

varying vec3  rawpos;
varying float fogCoord;
varying vec3  VNormal;
varying vec3  VTangent;
varying vec3  VBinormal;
varying vec3  Normal;
varying vec3 vViewVec;
varying vec3 reflVec;

varying vec4 Diffuse;
varying float alpha;

uniform mat4 osg_ViewMatrixInverse;

attribute vec3 tangent;
attribute vec3 binormal;

////fog "include"////////
// uniform int fogType;
//
// void fog_Func(int type);
/////////////////////////

void main(void)
{
    rawpos     = gl_Vertex.xyz / gl_Vertex.w;
    vec4 ecPosition = gl_ModelViewMatrix * gl_Vertex;
    ecPosition.xyz = ecPosition.xyz / ecPosition.w;
    //fogCoord = ecPosition.z;
    //fog_Func(fogType);

    vec3 n = normalize(gl_Normal);
    vec3 t = cross(gl_Normal, vec3(1.0,0.0,0.0));
    vec3 b = cross(n,t);

    VNormal = normalize(gl_NormalMatrix * gl_Normal);
    VTangent = normalize(gl_NormalMatrix * tangent);
    VBinormal = normalize(gl_NormalMatrix * binormal);
    Normal = normalize(gl_Normal);

    Diffuse = gl_Color * gl_LightSource[0].diffuse;
    //Diffuse= gl_Color.rgb * max(0.0, dot(normalize(VNormal), gl_LightSource[0].position.xyz));

    // Super hack: if diffuse material alpha is less than 1, assume a
    // transparency animation is at work
    if (gl_FrontMaterial.diffuse.a < 1.0)
        alpha = gl_FrontMaterial.diffuse.a;
    else
        alpha = gl_Color.a;

    // Vertex in eye coordinates
    vec3 vertVec = ecPosition.xyz;

    vViewVec.x = dot(t, vertVec);
    vViewVec.y = dot(b, vertVec);
    vViewVec.z = dot(n, vertVec);

    // calculate the reflection vector
    vec4 reflect_eye = vec4(reflect(vertVec, VNormal), 0.0);
    reflVec = normalize(gl_ModelViewMatrixInverse * reflect_eye).xyz;

    gl_FrontColor = gl_FrontMaterial.emission + gl_Color * (gl_LightModel.ambient + gl_LightSource[0].ambient);

    gl_Position = ftransform();
    gl_TexCoord[0] = gl_TextureMatrix[0] * gl_MultiTexCoord0;
}
