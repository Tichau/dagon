#version 400 core

layout (location = 0) in vec3 va_Vertex;
layout (location = 1) in vec3 va_Normal;
layout (location = 2) in vec2 va_Texcoord;

uniform mat4 modelViewMatrix;
uniform mat4 normalMatrix;
uniform mat4 projectionMatrix;
uniform mat4 invViewMatrix;

uniform mat4 prevModelViewProjMatrix;
uniform mat4 blurModelViewProjMatrix;

out vec3 eyePosition;
out vec3 eyeNormal;
out vec2 texCoord;
out vec4 blurPosition;
out vec4 prevPosition;
out vec3 worldView;

void main()
{
    vec4 pos = modelViewMatrix * vec4(va_Vertex, 1.0);
    eyePosition = pos.xyz;
    eyeNormal = (normalMatrix * vec4(va_Normal, 0.0)).xyz;
    texCoord = va_Texcoord;
    
    vec3 worldPosition = (invViewMatrix * pos).xyz;
    vec3 worldCamPos = (invViewMatrix[3]).xyz;
    worldView = worldPosition - worldCamPos;
    
    blurPosition = blurModelViewProjMatrix * vec4(va_Vertex, 1.0);
    prevPosition = prevModelViewProjMatrix * vec4(va_Vertex, 1.0);
    gl_Position = projectionMatrix * pos;
}
