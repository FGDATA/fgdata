#version 120

// "landmass" effect with forest construction using a geometry
// shader. The landmass effect includes a bumpmap effect as well as
// variation by altitude.
//
// The fragment shader needs position and normals in model and eye
// coordinates. This vertex shader calculates the positions and
// normals of the forest polygons so the geometry shader can do as
// little as possible.

// Input for the geometry shader. "raw" means terrain model
// coordinates; that's a tile-local coordinate system, with z as local
// up. "ec" means eye coordinates.

// model position of original terrain poly; the bottom of the forest.
varying vec4 rawposIn;
// model normal
varying vec3 NormalIn;
varying vec4 ecPosIn;
varying vec3 ecNormalIn;
// eye spacce tangent and binormal
varying vec3 VTangentIn;
varying vec3 VBinormalIn;
// screen-space position of top
// constant color component
varying vec4 constantColorIn;

attribute vec3 tangent;
attribute vec3 binormal;

uniform float canopy_height;

////fog "include"////////
// uniform int fogType;
//
// void fog_Func(int type);
/////////////////////////

void main(void)
    {
    rawposIn = gl_Vertex;
    ecPosIn = gl_ModelViewMatrix * gl_Vertex;
    NormalIn = normalize(gl_Normal);
    //rawTopIn = rawposIn + vec4(0.0, 0.0, canopy_height, 0.0);
    //ecTopIn = gl_ModelViewMatrix * rawTopIn;
    ecNormalIn = gl_NormalMatrix * NormalIn;
    VTangentIn = gl_NormalMatrix * tangent;
    VBinormalIn = gl_NormalMatrix * binormal;

    gl_FrontColor = gl_Color;
    gl_Position = ftransform();
    //positionTopIn = gl_ModelViewProjectionMatrix * rawTopIn;
    gl_TexCoord[0] = gl_TextureMatrix[0] * gl_MultiTexCoord0;
    constantColorIn = gl_FrontMaterial.emission
        + gl_Color * (gl_LightModel.ambient + gl_LightSource[0].ambient);

//     fog_Func(fogType);
    }
