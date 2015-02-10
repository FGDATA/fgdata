#version 120
#extension GL_EXT_geometry_shader4 : enable

// Geometry shader that creates a prism from a terrain triangle,
// resulting in a forest effect.
//
// A geometry shader should do as little computation as possible.

// See landmass-g.vert for a description of the inputs.
varying in vec4 rawposIn[3];
varying in vec3 NormalIn[3];
varying in vec4 ecPosIn[3];
varying in vec3 ecNormalIn[3];
varying in vec3 VTangentIn[3];
varying in vec3 VBinormalIn[3];
varying in vec4 constantColorIn[3];

uniform float canopy_height;

// model position
varying out vec4 rawpos;
// eye position
varying out vec4 ecPosition;
// eye space surface matrix
varying out vec3 VNormal;
varying out vec3 VTangent;
varying out vec3 VBinormal;
// model normal
varying out vec3 Normal;
varying out vec4 constantColor;
varying out float bump;

// Emit one vertex of the forest geometry.
// parameters:
// i - index into original terrain triangle
void doVertex(in int i, in vec4 pos, in vec4 ecpos, in vec4 screenpos,
              in vec3 rawNormal, in vec3 normal, in float s)
{
        rawpos = pos;
        ecPosition = ecpos;
        Normal = rawNormal;
        VNormal = normal;
        VTangent  = VTangentIn[i];
	VBinormal = VBinormalIn[i];
	bump = s;

	gl_FrontColor = gl_FrontColorIn[i];
	constantColor = constantColorIn[i];
	gl_Position = screenpos;
	gl_TexCoord[0] = gl_TexCoordIn[i][0];
	EmitVertex();
}

vec3 rawSideNormal[3];
vec3 sideNormal[3];

// Emit a vertex for a forest side triangle
void doSideVertex(in int vertIdx, in int sideIdx, vec4 pos, in vec4 ecpos,
                  in vec4 screenpos)
{
        doVertex(vertIdx, pos, ecpos, screenpos, rawSideNormal[sideIdx],
                 sideNormal[sideIdx], 0.0);
}

void main(void)
{
        vec4 rawTopDisp = vec4(0.0, 0.0, canopy_height, 0.0);
        vec4 ecTopDisp = gl_ModelViewMatrix * rawTopDisp;
        vec4 mvpTopDisp = gl_ModelViewProjectionMatrix * rawTopDisp;
        // model forest top        
        vec4 rawTopIn[3];
        vec4 ecTopIn[3];
        vec4 positionTopIn[3];
        rawSideNormal[0] = normalize(cross((rawposIn[1] - rawposIn[0]).xyz,
                                           NormalIn[0]));
        rawSideNormal[1] = normalize(cross((rawposIn[2] - rawposIn[1]).xyz,
                                           NormalIn[1]));
        rawSideNormal[2] = normalize(cross((rawposIn[0] - rawposIn[2]).xyz, 
                                           NormalIn[2]));
        for (int i = 0; i < 3; ++i) {
                sideNormal[i] = gl_NormalMatrix * rawSideNormal[i];
                rawTopIn[i] = rawposIn[i] + rawTopDisp;
                ecTopIn[i] = ecPosIn[i] + ecTopDisp;
                positionTopIn[i] = gl_PositionIn[i] + mvpTopDisp;
        }
        if (canopy_height > 0.01) {
                // Sides
                doSideVertex(0, 0, rawTopIn[0], ecTopIn[0], positionTopIn[0]);
                doSideVertex(0, 0, rawposIn[0], ecPosIn[0], gl_PositionIn[0]);
                doSideVertex(1, 0, rawTopIn[1], ecTopIn[1], positionTopIn[1]);
                doSideVertex(1, 0, rawposIn[1], ecPosIn[1], gl_PositionIn[1]);

                doSideVertex(2, 1, rawTopIn[2], ecTopIn[2], positionTopIn[2]);
                doSideVertex(2, 1, rawposIn[2], ecPosIn[2], gl_PositionIn[2]);
        
                doSideVertex(0, 2, rawTopIn[0], ecTopIn[0], positionTopIn[0]);
                doSideVertex(0, 2, rawposIn[0], ecPosIn[0], gl_PositionIn[0]);
                // Degenerate triangles; avoids EndPrimitive()
                doSideVertex(0, 2, rawposIn[0], ecPosIn[0], gl_PositionIn[0]);
                doVertex(0, rawTopIn[0], ecTopIn[0], positionTopIn[0], NormalIn[0],
                         ecNormalIn[0], 1.0);
        // Top
        }
        doVertex(0, rawTopIn[0], ecTopIn[0], positionTopIn[0], NormalIn[0],
                 ecNormalIn[0], 1.0);
        doVertex(1, rawTopIn[1], ecTopIn[1], positionTopIn[1], NormalIn[1],
                 ecNormalIn[1], 1.0);
        doVertex(2, rawTopIn[2], ecTopIn[2], positionTopIn[2], NormalIn[2],
                 ecNormalIn[2], 1.0);
        // Don't render "bottom" triangle for now; it's hidden.
#if 0
        // degenerate
        doVertex(2, rawTopIn[2], ecTopIn[2], positionTopIn[2], NormalIn[2],
                 ecNormalIn[2], 1.0);
        // bottom
        doVertex(0, rawposIn[0], ecPosIn[0], gl_PositionIn[0], NormalIn[0],
                 ecNormalIn[0], 1.0);
        doVertex(1, rawposIn[1], ecPosIn[1], gl_PositionIn[1], NormalIn[1],
                 ecNormalIn[1], 1.0);
        doVertex(2, rawposIn[2], ecPosIn[2], gl_PositionIn[2], NormalIn[2],
                 ecNormalIn[2], 1.0);
#endif
        EndPrimitive();
}
