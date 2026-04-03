shader_type spatial;
render_mode unshaded,blend_mix,depth_prepass_alpha,cull_disabled,specular_disabled;

uniform sampler2D sprite_texture : source_color, filter_nearest, repeat_disable;

void fragment() {
	vec4 col = texture(sprite_texture, UV);
	ALBEDO = vec3(0.0, 0.0, 0.0);
	ALPHA = col.a;
}

void vertex() {
    mat4 modified_model_view = VIEW_MATRIX * mat4(
        INV_VIEW_MATRIX[0],
        INV_VIEW_MATRIX[1],
        INV_VIEW_MATRIX[2],
        MODEL_MATRIX[3]
    );
    MODELVIEW_MATRIX = modified_model_view;
}