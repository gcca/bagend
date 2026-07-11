#include "mustacheshim.hpp"

#include "../3rdparty/mustache.hpp"

struct Mustache {
  kainjow::mustache::mustache mustache;
};

size_t MustacheSize = sizeof(Mustache);
size_t MustacheAlign = alignof(Mustache);

Mustache* mustache_init(void* m, const char* s) {
  return new (m) Mustache{kainjow::mustache::mustache{s}};
}

void mustache_deinit(Mustache* mustache) {
  mustache->~Mustache();
}

void mustache_render(Mustache* mustache, RenderHandler h, void* p) {
  mustache->mustache.render(
      kainjow::mustache::data{},
      [h, p](const std::string& chk) { h(p, chk.data(), chk.size()); });
}
