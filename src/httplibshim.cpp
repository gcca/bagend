#include "httplibshim.hpp"

#include "../3rdparty/httplib.h"

struct Server {
  httplib::Server server;
};

struct Request {
  const httplib::Request& request;
};

struct Response {
  httplib::Response& response;
};

Server* server_create(void) {
  return new (std::nothrow) Server();
}

void server_destroy(Server* server) {
  delete server;
}

void server_get(Server* s, const char* p, Handler h) {
  s->server.Get(p, [h](const httplib::Request& rq, httplib::Response& rs) {
    Request srq{rq};
    Response srs{rs};
    h(&srq, &srs);
  });
}

void server_post(Server* s, const char* p, Handler h) {
  s->server.Post(p, [h](const httplib::Request& rq, httplib::Response& rs) {
    Request srq{rq};
    Response srs{rs};
    h(&srq, &srs);
  });
}

void server_put(Server* s, const char* p, Handler h) {
  s->server.Put(p, [h](const httplib::Request& rq, httplib::Response& rs) {
    Request srq{rq};
    Response srs{rs};
    h(&srq, &srs);
  });
}

void server_delete(Server* s, const char* p, Handler h) {
  s->server.Delete(p, [h](const httplib::Request& rq, httplib::Response& rs) {
    Request srq{rq};
    Response srs{rs};
    h(&srq, &srs);
  });
}

void server_listen(Server* server, const char* host, const int port) {
  server->server.listen(host, port);
}

void response_set_redirect(Response* r, const char* url) {
  r->response.set_redirect(url);
}

void response_set_content(Response* r,
                          const char* s,
                          size_t n,
                          const char* content_type) {
  r->response.set_content(s, n, content_type);
}
