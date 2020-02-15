/*
Copyright (c) 2018-2020 Timur Gafarov

Boost Software License - Version 1.0 - August 17th, 2003
Permission is hereby granted, free of charge, to any person or organization
obtaining a copy of the software and accompanying documentation covered by
this license (the "Software") to use, reproduce, display, distribute,
execute, and transmit the Software, and to prepare derivative works of the
Software, and to permit third-parties to whom the Software is furnished to
do so, all subject to the following:

The copyright notices in the Software and this entire statement, including
the above license grant, this restriction and the following disclaimer,
must be included in all copies of the Software, in whole or in part, and
all derivative works of the Software, unless such copies or derivative
works are solely in the form of machine-executable object code generated by
a source language processor.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE, TITLE AND NON-INFRINGEMENT. IN NO EVENT
SHALL THE COPYRIGHT HOLDERS OR ANYONE DISTRIBUTING THE SOFTWARE BE LIABLE
FOR ANY DAMAGES OR OTHER LIABILITY, WHETHER IN CONTRACT, TORT OR OTHERWISE,
ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
DEALINGS IN THE SOFTWARE.
*/

module dagon.special.water;

import std.stdio;
import std.math;

import dlib.core.memory;
import dlib.core.ownership;
import dlib.math.vector;
import dlib.math.matrix;
import dlib.math.transformation;
import dlib.math.interpolation;
import dlib.image.color;
import dlib.text.unmanagedstring;

import dagon.core.bindings;
import dagon.graphics.material;
import dagon.graphics.texture;
import dagon.graphics.shader;
import dagon.graphics.state;
import dagon.graphics.cubemap;
import dagon.graphics.csm;
import dagon.render.gbuffer;
import dagon.resource.asset;
import dagon.resource.texture;

// TODO: move to dlib.math.utils
real frac(real v)
{
    real intpart;
    return modf(v, intpart);
}

class WaterShader: Shader
{
    String vs, fs;

    GBuffer gbuffer;
    Texture rippleTexture;
    
    Matrix4x4f defaultShadowMatrix;
    GLuint defaultShadowTexture;

    this(GBuffer gbuffer, AssetManager assetManager, Owner owner)
    {
        vs = Shader.load("data/__internal/shaders/Water/Water.vert.glsl");
        fs = Shader.load("data/__internal/shaders/Water/Water.frag.glsl");
        
        auto prog = New!ShaderProgram(vs, fs, this);
        super(prog, owner);
        
        this.gbuffer = gbuffer;

        TextureAsset rippleTextureAsset = textureAsset(assetManager, "data/__internal/ripples.png");
        rippleTexture = rippleTextureAsset.texture;
        
        defaultShadowMatrix = Matrix4x4f.identity;

        glGenTextures(1, &defaultShadowTexture);
        glActiveTexture(GL_TEXTURE0);
        glBindTexture(GL_TEXTURE_2D_ARRAY, defaultShadowTexture);
        glTexImage3D(GL_TEXTURE_2D_ARRAY, 0, GL_DEPTH_COMPONENT24, 1, 1, 3, 0, GL_DEPTH_COMPONENT, GL_FLOAT, null);
        glTexParameteri(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_COMPARE_MODE, GL_COMPARE_REF_TO_TEXTURE);
	    glTexParameteri(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_COMPARE_FUNC, GL_LEQUAL);
        glBindTexture(GL_TEXTURE_2D_ARRAY, 0);
    }
    
    ~this()
    {
        if (glIsFramebuffer(defaultShadowTexture))
            glDeleteFramebuffers(1, &defaultShadowTexture);
        
        vs.free();
        fs.free();
    }

    override void bindParameters(GraphicsState* state)
    {
        auto itextureScale = "textureScale" in state.material.inputs;
        auto ishadeless = "shadeless" in state.material.inputs;
        
        setParameter("modelViewMatrix", state.modelViewMatrix);
        setParameter("projectionMatrix", state.projectionMatrix);
        setParameter("invProjectionMatrix", state.invProjectionMatrix);
        setParameter("normalMatrix", state.normalMatrix);
        setParameter("viewMatrix", state.viewMatrix);
        setParameter("invViewMatrix", state.invViewMatrix);
        setParameter("prevModelViewMatrix", state.prevModelViewMatrix);

        setParameter("textureScale", itextureScale.asVector2f);
        
        setParameter("viewSize", state.resolution);
        
        // Sun
        Vector3f sunDirection = Vector3f(0.0f, 0.0f, 1.0f);
        Color4f sunColor = Color4f(1.0f, 1.0f, 1.0f, 1.0f);
        float sunEnergy = 1.0f;
        bool sunScatteringEnabled = false;
        float sunScatteringG = 0.0f;
        float sunScatteringDensity = 1.0f;
        int sunScatteringSamples = 1;
        float sunScatteringMaxRandomStepOffset = 0.0f;
        bool shaded = !ishadeless.asBool;
        if (state.material.sun)
        {
            auto sun = state.material.sun;
            sunDirection = sun.directionAbsolute;
            sunColor = sun.color;
            sunEnergy = sun.energy;
            sunScatteringG = 1.0f - sun.scattering;
            sunScatteringDensity = sun.mediumDensity;
            sunScatteringEnabled = sun.scatteringEnabled;
        }
        Vector4f sunDirHg = Vector4f(sunDirection);
        sunDirHg.w = 0.0;
        setParameter("sunDirection", (sunDirHg * state.viewMatrix).xyz);
        setParameter("sunColor", sunColor);
        setParameter("sunEnergy", sunEnergy);
        setParameter("sunScatteringG", sunScatteringG);
        setParameter("sunScatteringDensity", sunScatteringDensity);
        setParameter("sunScattering", sunScatteringEnabled);
        setParameter("sunScatteringSamples", sunScatteringSamples);
        setParameter("sunScatteringMaxRandomStepOffset", sunScatteringMaxRandomStepOffset);
        setParameter("shaded", shaded);
        
        // Texture 0 - depth texture (for smooth coast transparency)
        glActiveTexture(GL_TEXTURE0);
        glBindTexture(GL_TEXTURE_2D, gbuffer.depthTexture);
        setParameter("depthBuffer", 0);
        
        // Ripple parameters
        glActiveTexture(GL_TEXTURE1);
        rippleTexture.bind();
        setParameter("rippleTexture", 1);

        float rippleTimesX = frac((state.time.elapsed) * 1.6);
        float rippleTimesY = frac((state.time.elapsed * 0.85 + 0.2) * 1.6);
        float rippleTimesZ = frac((state.time.elapsed * 0.93 + 0.45) * 1.6);
        float rippleTimesW = frac((state.time.elapsed * 1.13 + 0.7) * 1.6);
        setParameter("rippleTimes", Vector4f(rippleTimesX, rippleTimesY, rippleTimesZ, rippleTimesW));
        
        // Environment
        if (state.environment)
        {
            setParameter("fogColor", state.environment.fogColor);
            setParameter("fogStart", state.environment.fogStart);
            setParameter("fogEnd", state.environment.fogEnd);
            setParameter("ambientEnergy", state.environment.ambientEnergy);

            if (state.environment.ambientMap)
            {
                glActiveTexture(GL_TEXTURE2);
                state.environment.ambientMap.bind();
                if (cast(Cubemap)state.environment.ambientMap)
                {
                    setParameter("ambientTextureCube", 2);
                    setParameterSubroutine("ambient", ShaderType.Fragment, "ambientCubemap");
                }
                else
                {
                    setParameter("ambientTexture", 2);
                    setParameterSubroutine("ambient", ShaderType.Fragment, "ambientEquirectangularMap");
                }
            }
            else
            {
                setParameter("ambientVector", state.environment.ambientColor);
                setParameterSubroutine("ambient", ShaderType.Fragment, "ambientColor");
            }
        }
        else
        {
            setParameter("fogColor", Color4f(0.5f, 0.5f, 0.5f, 1.0f));
            setParameter("fogStart", 0.0f);
            setParameter("fogEnd", 1000.0f);
            setParameter("ambientEnergy", 1.0f);
            setParameter("ambientVector", Color4f(0.5f, 0.5f, 0.5f, 1.0f));
            setParameterSubroutine("ambient", ShaderType.Fragment, "ambientColor");
        }
        
        // Shadow map
        if (state.material.sun)
        {
            if (state.material.sun.shadowEnabled)
            {
                CascadedShadowMap csm = cast(CascadedShadowMap)state.material.sun.shadowMap;

                glActiveTexture(GL_TEXTURE3);
                glBindTexture(GL_TEXTURE_2D_ARRAY, csm.depthTexture);
                setParameter("shadowTextureArray", 3);
                setParameter("shadowResolution", cast(float)csm.resolution);
                setParameter("shadowMatrix1", csm.area1.shadowMatrix);
                setParameter("shadowMatrix2", csm.area2.shadowMatrix);
                setParameter("shadowMatrix3", csm.area3.shadowMatrix);
                setParameterSubroutine("shadowMap", ShaderType.Fragment, "shadowMapCascaded");
            }
            else
            {
                glActiveTexture(GL_TEXTURE3);
                glBindTexture(GL_TEXTURE_2D_ARRAY, defaultShadowTexture);
                setParameter("shadowTextureArray", 3);
                setParameter("shadowMatrix1", defaultShadowMatrix);
                setParameter("shadowMatrix2", defaultShadowMatrix);
                setParameter("shadowMatrix3", defaultShadowMatrix);
                setParameterSubroutine("shadowMap", ShaderType.Fragment, "shadowMapNone");
            }
        }
        else
        {
            glActiveTexture(GL_TEXTURE3);
            glBindTexture(GL_TEXTURE_2D_ARRAY, defaultShadowTexture);
            setParameter("shadowTextureArray", 3);
            setParameter("shadowMatrix1", defaultShadowMatrix);
            setParameter("shadowMatrix2", defaultShadowMatrix);
            setParameter("shadowMatrix3", defaultShadowMatrix);
            setParameterSubroutine("shadowMap", ShaderType.Fragment, "shadowMapNone");
        }

        super.bindParameters(state);
    }

    override void unbindParameters(GraphicsState* state)
    {
        super.unbindParameters(state);
        
        glActiveTexture(GL_TEXTURE0);
        glBindTexture(GL_TEXTURE_2D, 0);

        glActiveTexture(GL_TEXTURE1);
        glBindTexture(GL_TEXTURE_2D, 0);
        
        glActiveTexture(GL_TEXTURE2);
        glBindTexture(GL_TEXTURE_2D, 0);
        glBindTexture(GL_TEXTURE_CUBE_MAP, 0);
        
        glActiveTexture(GL_TEXTURE3);
        glBindTexture(GL_TEXTURE_2D, 0);
        
        glActiveTexture(GL_TEXTURE0);
    }
}
