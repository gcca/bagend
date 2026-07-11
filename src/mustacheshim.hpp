#pragma once

#include <stddef.h>

typedef struct Mustache Mustache;

typedef void (*RenderHandler)(void* ctx, const char* chunk, size_t length);

extern size_t MustacheSize;
extern size_t MustacheAlign;

#ifdef __cplusplus
extern "C" {
#endif

Mustache* mustache_init(void*, const char* s);
void mustache_deinit(Mustache*);
void mustache_render(Mustache*, RenderHandler h, void* p);

#ifdef __cplusplus
}
#endif
