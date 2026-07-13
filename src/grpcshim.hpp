#pragma once

#include <stddef.h>

typedef struct GrpcAuthClient GrpcAuthClient;

typedef struct GrpcBuffer {
  unsigned char* data;
  size_t len;
} GrpcBuffer;

#ifdef __cplusplus
extern "C" {
#endif

GrpcAuthClient* grpc_auth_client_create(const char* target);
void grpc_auth_client_destroy(GrpcAuthClient* client);
const char* grpc_auth_client_last_error(GrpcAuthClient* client);

GrpcBuffer grpc_auth_client_unary(GrpcAuthClient* client,
                                  const char* method,
                                  const unsigned char* request,
                                  size_t request_len,
                                  int timeout_ms);

void grpc_buffer_destroy(GrpcBuffer buffer);

#ifdef __cplusplus
}
#endif
