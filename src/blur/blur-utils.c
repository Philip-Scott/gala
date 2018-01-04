#include "blur-utils.h"
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <locale.h>
#include <glib.h>
#include <math.h>

char *build_shader(int direction, int radius, float* offsets, float *weight)
{
    GString *sbuf = g_string_sized_new(4096);
    if (!sbuf) {
        return NULL;
    }

    char *orig_lc_num = g_strdup(setlocale(LC_NUMERIC, NULL));

    setlocale(LC_NUMERIC, "POSIX");

    if (direction == VERTICAL) {
        g_string_append_printf(sbuf, "vec2 tc = cogl_tex_coord.st;\n"
                "cogl_texel = texture2D(cogl_sampler, tc) * %f;\n",
                weight[0]);

        for (int i = 1; i < radius; i++) {
            g_string_append_printf(sbuf, 
                    "cogl_texel += texture2D(cogl_sampler, tc - vec2(0.0, %f/resolution.y)) * %f; \n"
                    "cogl_texel += texture2D(cogl_sampler, tc + vec2(0.0, %f/resolution.y)) * %f; \n",
                    offsets[i], weight[i],
                    offsets[i], weight[i]);
        }
    } else {

        g_string_append_printf(sbuf,
                "vec2 tc = vec2(cogl_tex_coord.s, 1.0 - cogl_tex_coord.t); \n"
                "cogl_texel = texture2D(cogl_sampler, tc) * %f;\n",
                weight[0]);

        for (int i = 1; i < radius; i++) {
            g_string_append_printf(sbuf, 
                    "cogl_texel += texture2D(cogl_sampler, tc - vec2(%f/resolution.x, 0.0)) * %f; \n"
                    "cogl_texel += texture2D(cogl_sampler, tc + vec2(%f/resolution.x, 0.0)) * %f; \n",
                    offsets[i], weight[i],
                    offsets[i], weight[i]);
        }
    }
    
    setlocale(LC_NUMERIC, orig_lc_num);
    g_clear_pointer (&orig_lc_num, g_free);
    return g_string_free(sbuf, FALSE);
}

