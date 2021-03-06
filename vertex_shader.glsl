#version 330
uniform mat4 model_transform;
uniform mat4 camera;
uniform mat4 projection;
uniform vec3 camera_pos_input;

uniform float albedo_r;
uniform float albedo_g;
uniform float albedo_b;
uniform float ks;

in vec3 position;
in vec3 vertex_normal;

out vec3 view_position;
out vec3 pixel_position;
out vec3 world_position;
out vec3 camera_position;
out vec3 normal;

void main()
{
    gl_Position = projection * camera * model_transform * vec4(position, 1.0);
    view_position = gl_Position.xyz;
    pixel_position = position;
    world_position = (model_transform * vec4(position, 1.0)).xyz;
    camera_position = camera_pos_input;
    normal = normalize(vertex_normal);
}