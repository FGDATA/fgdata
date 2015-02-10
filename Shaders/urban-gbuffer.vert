// -*- mode: C; -*-
// Licence: GPL v2
// Author: Frederic Bouvier

varying vec4  rawpos;
varying vec4  ecPosition;
varying vec3  VNormal;
varying vec3  Normal;
varying vec3  VTangent;
varying vec3  VBinormal;
varying vec4  constantColor;
varying vec4  specular;

attribute vec3 tangent, binormal;

void main(void)
{
    rawpos     = gl_Vertex;
    ecPosition = gl_ModelViewMatrix * gl_Vertex;
    VNormal = normalize(gl_NormalMatrix * gl_Normal);
    Normal = normalize(gl_Normal);
    VTangent  = gl_NormalMatrix * tangent;
    VBinormal = gl_NormalMatrix * binormal;
    gl_FrontColor = gl_Color;
    constantColor = gl_FrontMaterial.emission
        + gl_Color * (gl_LightModel.ambient + gl_LightSource[0].ambient);  
    gl_Position = ftransform();
    gl_TexCoord[0] = gl_TextureMatrix[0] * gl_MultiTexCoord0;
	specular = vec4( gl_FrontMaterial.specular.rgb, gl_FrontMaterial.shininess );
}
