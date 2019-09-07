#version 330
uniform float albedo_r;
uniform float albedo_g;
uniform float albedo_b;
uniform float ks;

in vec3 view_position;
in vec3 pixel_position;
in vec3 camera_position;
in vec3 normal;

out vec4 frag_color;

void main()
{    
    vec3 light_source = vec3(-3.0, 5.0, 2.0);
    vec4 ambient_light = vec4(0.1, 0.1, 0.1, 0.0);
    vec3 interpolated_normal = normalize(normal);
    
    float red_diffuse = albedo_r / 3.14 * dot(interpolated_normal, light_source);
    float green_diffuse = albedo_g / 3.14 * dot(interpolated_normal, light_source);
    float blue_diffuse = albedo_b / 3.14 * dot(interpolated_normal, light_source);
    
    vec3 reflection_vec = 2.0 * dot(light_source, interpolated_normal) * interpolated_normal - light_source;
    float specular = ks * dot(reflection_vec, normalize(camera_position));
    
    specular = max(0.0, specular);
    red_diffuse = max(0.0, red_diffuse);
    green_diffuse = max(0.0, green_diffuse);
    blue_diffuse = max(0.0, blue_diffuse);
    
    frag_color = vec4(red_diffuse + specular, green_diffuse + specular, blue_diffuse + specular, 1.0) + ambient_light;
}