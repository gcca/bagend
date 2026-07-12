#pragma once

#include <stddef.h>

typedef struct Server Server;
typedef struct Request Request;
typedef struct Response Response;

typedef void (*Handler)(const Request* req, Response* res);

#ifdef __cplusplus
extern "C" {
#endif

Server* server_create(void);
void server_destroy(Server*);
void server_get(Server*, const char* pattern, Handler handler);
void server_post(Server*, const char* pattern, Handler handler);
void server_put(Server*, const char* pattern, Handler handler);
void server_delete(Server*, const char* pattern, Handler handler);
void server_listen(Server*, const char* host, int port);

void response_set_redirect(Response*, const char* url);
void response_set_content(Response*,
                          const char* s,
                          size_t n,
                          const char* content_type);

#ifdef __cplusplus
}
#endif
