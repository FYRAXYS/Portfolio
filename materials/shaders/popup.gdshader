// Shader pour flouter l'arrière-plan (effet "verre dépoli") - CORRIGÉ Godot 4.x
shader_type canvas_item;

// CORRECTION ICI : Déclaration de SCREEN_TEXTURE comme requis
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

// Couleur du "verre" (blanc semi-transparent par défaut)
uniform vec4 glass_color : source_color = vec4(1.0, 1.0, 1.0, 0.3);

// Intensité du flou
uniform float blur_size : hint_range(0.0, 10.0) = 2.0;

void fragment() {
    // Variable pour stocker la couleur floutée
    vec4 blurred_color = vec4(0.0);

    // Taille d'un pixel sur l'écran
    vec2 pixel_size = SCREEN_PIXEL_SIZE;

    // Boucle pour faire un flou simple (Box Blur 9-tap)
    for (int x = -1; x <= 1; x++) {
        for (int y = -1; y <= 1; y++) {
            vec2 offset = vec2(float(x), float(y)) * pixel_size * blur_size;
            // On utilise SCREEN_TEXTURE (maintenant qu'il est déclaré)
            blurred_color += texture(SCREEN_TEXTURE, SCREEN_UV + offset);
        }
    }

    // On fait la moyenne des 9 pixels
    blurred_color /= 9.0;

    // On mélange la couleur floutée avec la couleur de notre "verre"
    COLOR = mix(blurred_color, glass_color, glass_color.a);
}