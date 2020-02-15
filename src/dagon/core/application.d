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

/++
    Base class to inherit Dagon applications from.
+/
module dagon.core.application;

import std.stdio;
import std.conv;
import std.getopt;
import std.string;
import std.file;
import std.algorithm: canFind;
import core.stdc.stdlib;

import dlib.core.memory;
import dagon.core.bindings;
import dagon.core.event;
import dagon.core.time;

void exitWithError(string message)
{
    writeln(message);
    core.stdc.stdlib.exit(1);
}

enum DagonEvent
{
    Exit = -1
}

enum string[GLenum] GLErrorStrings = [
    GL_NO_ERROR: "GL_NO_ERROR",
    GL_INVALID_ENUM: "GL_INVALID_ENUM",
    GL_INVALID_VALUE: "GL_INVALID_VALUE",
    GL_INVALID_OPERATION: "GL_INVALID_OPERATION",
    GL_INVALID_FRAMEBUFFER_OPERATION: "GL_INVALID_FRAMEBUFFER_OPERATION",
    GL_OUT_OF_MEMORY: "GL_OUT_OF_MEMORY"
];

extern(System) nothrow void messageCallback(
    GLenum source,
    GLenum type,
    GLuint id,
    GLenum severity,
    GLsizei length,
    const GLchar* message,
    const GLvoid* userParam)
{
    string msg = "%stype = 0x%x, severity = 0x%x, message = %s\n";
    string err = "OpenGL error: ";
    string empty = "";
    if (severity != GL_DEBUG_SEVERITY_NOTIFICATION)
        printf(msg.ptr, (type == GL_DEBUG_TYPE_ERROR ? err.ptr : empty.ptr), type, severity, message);
}

private
{
    __gshared int[] compressedTextureFormats;

    void enumerateCompressedTextureFormats()
    {
        int numCompressedFormats = 0;
        glGetIntegerv(GL_NUM_COMPRESSED_TEXTURE_FORMATS, &numCompressedFormats);
        if (numCompressedFormats)
        {
            compressedTextureFormats = New!(int[])(numCompressedFormats);
            glGetIntegerv(GL_COMPRESSED_TEXTURE_FORMATS, compressedTextureFormats.ptr);
        }
    }

    void releaseCompressedTextureFormats()
    {
        if (compressedTextureFormats.length)
            Delete(compressedTextureFormats);
    }
}

bool compressedTextureFormatSupported(GLenum format)
{
    if (compressedTextureFormats.length)
        return compressedTextureFormats.canFind(format);
    else
        return false;
}

/++
    Base class to inherit Dagon applications from.
    `Application` wraps SDL2 window, loads dynamic link libraries using Derelict,
    is responsible for initializing OpenGL context and doing main game loop.
+/
class Application: EventListener
{
    uint width;
    uint height;
    SDL_Window* window = null;
    SDL_GLContext glcontext;
    private EventManager _eventManager;

    /++
        Constructor.
        * `winWidth` - window width
        * `winHeight` - window height
        * `fullscreen` - if true, the application will run in fullscreen mode
        * `windowTitle` - window title
        * `args` - command line arguments
    +/
    this(uint winWidth, uint winHeight, bool fullscreen, string windowTitle, string[] args)
    {
        SDLSupport sdlsup = loadSDL();
        if (sdlsup != sdlSupport)
        {
            if (sdlsup == SDLSupport.badLibrary)
                writeln("Warning: failed to load some SDL functions. It seems that you have an old version of SDL. Dagon will try to use it, but it is recommended to install SDL 2.0.5 or higher");
            else
                exitWithError("Error: SDL library is not found. Please, install SDL 2.0.5");
        }

        if (SDL_Init(SDL_INIT_EVERYTHING) == -1)
            exitWithError("Error: failed to init SDL: " ~ to!string(SDL_GetError()));

        width = winWidth;
        height = winHeight;

        SDL_GL_SetAttribute(SDL_GL_ACCELERATED_VISUAL, 1);
        SDL_GL_SetAttribute(SDL_GL_CONTEXT_PROFILE_MASK, SDL_GL_CONTEXT_PROFILE_CORE);
        SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 4);
        SDL_GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, 0);
        SDL_GL_SetAttribute(SDL_GL_CONTEXT_FLAGS, SDL_GL_CONTEXT_FORWARD_COMPATIBLE_FLAG);
        SDL_GL_SetAttribute(SDL_GL_DOUBLEBUFFER, 1);
        SDL_GL_SetAttribute(SDL_GL_DEPTH_SIZE, 24);
        SDL_GL_SetAttribute(SDL_GL_STENCIL_SIZE, 8);

        window = SDL_CreateWindow(toStringz(windowTitle),
            SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED, width, height, SDL_WINDOW_SHOWN | SDL_WINDOW_OPENGL | SDL_WINDOW_RESIZABLE);
        if (window is null)
            exitWithError("Error: failed to create window: " ~ to!string(SDL_GetError()));

        SDL_GL_SetSwapInterval(1);

        glcontext = SDL_GL_CreateContext(window);
        if (glcontext is null)
            exitWithError("Error: failed to create OpenGL context: " ~ to!string(SDL_GetError()));

        SDL_GL_MakeCurrent(window, glcontext);

        GLSupport glsup = loadOpenGL();
        if (isOpenGLLoaded())
        {
            if (glsup < GLSupport.gl40)
            {
                exitWithError("Error: Dagon requires OpenGL 4.0, but it seems that your graphics card does not support it");
            }
        }
        else
        {
            exitWithError("Error: failed to load OpenGL functions. Please, update graphics card driver and make sure it supports OpenGL 4.0");
        }

        if (fullscreen)
            SDL_SetWindowFullscreen(window, SDL_WINDOW_FULLSCREEN);

        _eventManager = New!EventManager(window, width, height);
        super(_eventManager, null);

        // Initialize OpenGL
        glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
        glClearDepth(1.0);
        glEnable(GL_SCISSOR_TEST);
        glDepthFunc(GL_LESS);
        glEnable(GL_DEPTH_TEST);
        glEnable(GL_POLYGON_OFFSET_FILL);
        glCullFace(GL_BACK);
        glEnable(GL_TEXTURE_CUBE_MAP_SEAMLESS);

        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
        SDL_GL_SwapWindow(window);

        enumerateCompressedTextureFormats();

        // Debug output
        debug
        {
            if (hasKHRDebug)
            {
                glEnable(GL_DEBUG_OUTPUT);
                glDebugMessageCallback(&messageCallback, null);
            }
            else
            {
                writeln("GL_KHR_debug is not supported, debug output is not available");
            }
        }
    }

    ~this()
    {
        releaseCompressedTextureFormats();

        SDL_GL_DeleteContext(glcontext);
        SDL_DestroyWindow(window);
        SDL_Quit();
        Delete(_eventManager);
    }

    void maximizeWindow()
    {
        SDL_MaximizeWindow(window);
    }

    override void onUserEvent(int code)
    {
        if (code == DagonEvent.Exit)
        {
            exit();
        }
    }

    void onUpdate(Time t)
    {
        // Override me
    }

    void onRender()
    {
        // Override me
    }

    void checkGLError()
    {
        GLenum error = GL_NO_ERROR;
        error = glGetError();
        if (error != GL_NO_ERROR)
        {
            writefln("OpenGL error %s: %s", error, GLErrorStrings[error]);
        }
    }

    void run()
    {
        Time t = Time(0.0, 0.0);
        while(eventManager.running)
        {
            eventManager.update();
            processEvents();

            t.delta = eventManager.deltaTime;
            onUpdate(t);
            t.elapsed += t.delta;
            onRender();

            debug checkGLError();

            SDL_GL_SwapWindow(window);
        }
    }

    void exit()
    {
        eventManager.exit();
    }
}
