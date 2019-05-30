/*
Copyright (c) 2017-2019 Timur Gafarov

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

module dagon;

public
{
    import dlib;

    import dagon.core.application;
    import dagon.core.bindings;
    import dagon.core.config;
    import dagon.core.event;
    import dagon.core.input;
    import dagon.core.keycodes;
    import dagon.core.locale;
    import dagon.core.props;
    import dagon.core.time;
    import dagon.core.vfs;
    
    import dagon.game.deferredrenderer;
    import dagon.game.game;
    import dagon.game.hudrenderer;
    import dagon.game.postprocrenderer;
    import dagon.game.presentrenderer;
    import dagon.game.renderer;

    import dagon.graphics.camera;
    import dagon.graphics.csm;
    import dagon.graphics.cubemap;
    import dagon.graphics.drawable;
    import dagon.graphics.entity;
    import dagon.graphics.environment;
    import dagon.graphics.heightmap;
    import dagon.graphics.light;
    import dagon.graphics.material;
    import dagon.graphics.mesh;
    import dagon.graphics.opensimplex;
    import dagon.graphics.screensurface;
    import dagon.graphics.shader;
    import dagon.graphics.shaderloader;
    import dagon.graphics.shadowmap;
    import dagon.graphics.shapes;
    import dagon.graphics.state;
    import dagon.graphics.terrain;
    import dagon.graphics.texture;
    import dagon.graphics.updateable;
    
    import dagon.postproc.blurstage;
    import dagon.postproc.filterstage;
    import dagon.postproc.presentstage;
    import dagon.postproc.shaders.blur;
    import dagon.postproc.shaders.brightpass;
    import dagon.postproc.shaders.fxaa;
    import dagon.postproc.shaders.glow;
    import dagon.postproc.shaders.present;
    import dagon.postproc.shaders.tonemap;
    
    import dagon.render.deferred;
    import dagon.render.framebuffer;
    import dagon.render.framebuffer_r8;
    import dagon.render.framebuffer_rgba8;
    import dagon.render.framebuffer_rgba16f;
    import dagon.render.gbuffer;
    import dagon.render.pipeline;
    import dagon.render.shadowstage;
    import dagon.render.stage;
    import dagon.render.view;
    import dagon.render.shaders;
    
    import dagon.resource.asset;
    import dagon.resource.binary;
    import dagon.resource.boxfs;
    import dagon.resource.font;
    import dagon.resource.image;
    import dagon.resource.obj;
    import dagon.resource.scene;
    import dagon.resource.text;
    import dagon.resource.texture;
    
    import dagon.ui.font;
    import dagon.ui.freeview;
    import dagon.ui.ftfont;
    import dagon.ui.nuklear;
    import dagon.ui.textline;
}
