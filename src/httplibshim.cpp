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

void server_get(Server* server, const char* pattern, Handler handler) {
  server->server.Get(
      pattern, [handler](const httplib::Request& req, httplib::Response& res) {
        Request shimreq{req};
        Response shimres{res};
        handler(&shimreq, &shimres);
      });
}

void server_post(Server* server, const char* pattern, Handler handler) {
  server->server.Post(
      pattern, [handler](const httplib::Request& req, httplib::Response& res) {
        Request shimreq{req};
        Response shimres{res};
        handler(&shimreq, &shimres);
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
