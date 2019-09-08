from OpenGL.GL import *
from OpenGL.GL import shaders
from OpenGL.GLU import *
import pyrr
import glfw
import numpy
import time

class Teapot():
    def __init__(self):
        vertices = []
        faces = []
        # obj loader super simples
        with open('res/teapot.obj', 'r') as obj: # le os vertices e faces do OBJ
            for line in obj.readlines():
                line = line.split(' ')
                if line[0] == 'v':
                    vertices.append([float(line[1])/3, float(line[2])/3, float(line[3])/3])
                elif line[0] == 'f':
                    faces.append([int(line[1])-1, int(line[2])-1, int(line[3])-1])
        
        # calculate vertex normals
        self.vertices = numpy.array(vertices, dtype=numpy.float32)
        self.faces = numpy.array(faces, dtype=numpy.uint32)
        vertex_normals = pyrr.vector3.generate_vertex_normals(self.vertices, self.faces)
        self.vertex_normals = numpy.array(vertex_normals, dtype=numpy.float32).flatten()
        self.vertices = numpy.array(vertices, dtype=numpy.float32).flatten()
        self.faces = numpy.array(faces, dtype=numpy.uint32).flatten()

        self.vao = glGenVertexArrays(1)
        glBindVertexArray(self.vao)

        self.vbo = glGenBuffers(1)
        glBindBuffer(GL_ARRAY_BUFFER, self.vbo)
        glBufferData(GL_ARRAY_BUFFER, len(self.vertices) * 4, self.vertices, GL_STATIC_DRAW)
        self.ebo = glGenBuffers(1)
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, self.ebo)
        glBufferData(GL_ELEMENT_ARRAY_BUFFER, len(self.faces) * 4, self.faces, GL_STATIC_DRAW)
        self.nbo = glGenBuffers(1)
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, self.nbo)
        glBufferData(GL_ELEMENT_ARRAY_BUFFER, len(self.vertex_normals) * 4, self.vertex_normals, GL_STATIC_DRAW)

        # generate noise texture
        self.noise_texture = numpy.random.rand(16, 16)
        self.noise_texture_buffer = glGenTextures(1)
        glBindTexture(GL_TEXTURE_2D, self.noise_texture_buffer)
        glPixelStorei(GL_UNPACK_ALIGNMENT,1)
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST)
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST)
        glTexImage2D(GL_TEXTURE_2D, 0, GL_R32F, 16, 16, 0, GL_RED, GL_FLOAT, self.noise_texture)

        glBindVertexArray(0)

    def render(self, shader):
        glBindVertexArray(self.vao)

        glActiveTexture(GL_TEXTURE0)
        glBindTexture(GL_TEXTURE_2D, self.noise_texture_buffer)

        glBindBuffer(GL_ARRAY_BUFFER, self.vbo)
        position = glGetAttribLocation(shader, 'position')
        glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 0, ctypes.c_void_p(0))
        glEnableVertexAttribArray(0)
        
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, self.nbo)
        vertex_normal = glGetAttribLocation(shader, 'vertex_normal')
        glVertexAttribPointer(1, 3, GL_FLOAT, GL_FALSE, 0, ctypes.c_void_p(0))
        glEnableVertexAttribArray(1)
        
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, self.ebo)
        glDrawElements(GL_TRIANGLES, len(self.faces), GL_UNSIGNED_INT, None)

class Material:
    def __init__(self, shader, albedo_r, albedo_g, albedo_b, specular_constant):
        self.shader = shader
        self.albedo = [albedo_r, albedo_g, albedo_b]
        self.specular_constant = specular_constant

    def set_up_rendering(self):
        glUseProgram(self.shader)
        
        #lighting uniforms
        r = glGetUniformLocation(self.shader, 'albedo_r')
        g = glGetUniformLocation(self.shader, 'albedo_g')
        b = glGetUniformLocation(self.shader, 'albedo_b')
        glUniform1f(r, self.albedo[0])
        glUniform1f(g, self.albedo[1])
        glUniform1f(b, self.albedo[2])
        
        ks = glGetUniformLocation(self.shader, 'ks')
        glUniform1f(ks, self.specular_constant)

class Shape:
    def __init__(self, material):
        self.material = material
        self.teapot = Teapot()
    def render(self):
        self.material.set_up_rendering()
        
        #transformation uniforms
        model_transform = pyrr.Matrix44.identity()
        perspective_transform = pyrr.Matrix44.perspective_projection(45, 4/3, 0.01, 100)
        camera_transform = pyrr.Matrix44.look_at((2, 2, 2), (0, 0, 0), (0, 1, 0))
        
        mt_loc = glGetUniformLocation(self.material.shader, 'model_transform')
        glUniformMatrix4fv(mt_loc, 1, GL_FALSE, model_transform)
        pr_loc = glGetUniformLocation(self.material.shader, 'projection')
        glUniformMatrix4fv(pr_loc, 1, GL_FALSE, perspective_transform)
        cam_loc = glGetUniformLocation(self.material.shader, 'camera')
        glUniformMatrix4fv(cam_loc, 1, GL_FALSE, camera_transform)
        cam_pos_loc = glGetUniformLocation(self.material.shader, 'camera_pos_input')
        glUniform3f(cam_pos_loc, 2, 2, 2)

        self.teapot.render(self.material.shader)

def main():
    if not glfw.init():
        return

    glfw.window_hint(glfw.CONTEXT_VERSION_MAJOR, 4)
    glfw.window_hint(glfw.CONTEXT_VERSION_MINOR, 3)
    glfw.window_hint(glfw.OPENGL_PROFILE, glfw.OPENGL_CORE_PROFILE)
    window = glfw.create_window(1280, 960, 'SH lighting', None, None)
    if not window:
        glfw.terminate()
        return
    
    glfw.make_context_current(window)
    
    glClearColor(0.1, 0.1, 0.1, 1.0)
    glEnable(GL_DEPTH_TEST)
    glCullFace(GL_BACK)

    vertex_shader = ''
    with open("vertex_shader.glsl", "r") as f:
        vertex_shader = f.read()
    
    fragment_shader = ''
    with open("fragment_shader.glsl", "r") as f:
        fragment_shader = f.read()
    
    shader = shaders.compileProgram(shaders.compileShader(vertex_shader, GL_VERTEX_SHADER), shaders.compileShader(fragment_shader, GL_FRAGMENT_SHADER))
    shape = Shape(Material(shader, .0, 1.0, 1.0, 0.05)) # valores default iniciais
    #key_flags = [False, False]
    
    old_time = time.time()
    while not glfw.window_should_close(window):
        glfw.poll_events()
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)
        #get_input(window, shape, key_flags)
        shape.render()
        glfw.swap_buffers(window)
        new_time = time.time() - old_time
        print(1/new_time)
        old_time = time.time()
    glfw.terminate()
    
if __name__ == '__main__':
    main()
