#include "grpcshim.hpp"

#include <chrono>
#include <cstdlib>
#include <cstring>
#include <memory>
#include <string>
#include <vector>

#include <grpcpp/create_channel.h>
#include <grpcpp/generic/generic_stub.h>
#include <grpcpp/security/credentials.h>
#include <grpcpp/support/byte_buffer.h>
#include <grpcpp/support/slice.h>
#include <grpcpp/support/status.h>

struct GrpcAuthClient {
  std::shared_ptr<grpc::Channel> channel;
  std::unique_ptr<grpc::GenericStub> stub;
  std::string last_error;
};

GrpcAuthClient* grpc_auth_client_create(const char* target) {
  auto* client = new GrpcAuthClient;
  client->channel =
      grpc::CreateChannel(target, grpc::InsecureChannelCredentials());
  client->stub = std::make_unique<grpc::GenericStub>(client->channel);
  return client;
}

void grpc_auth_client_destroy(GrpcAuthClient* client) {
  delete client;
}

const char* grpc_auth_client_last_error(GrpcAuthClient* client) {
  if (client == nullptr)
    return "grpc client is null";
  return client->last_error.c_str();
}

GrpcBuffer grpc_auth_client_unary(GrpcAuthClient* client,
                                  const char* method,
                                  const unsigned char* request,
                                  size_t request_len,
                                  int timeout_ms) {
  GrpcBuffer empty = {nullptr, 0};

  if (client == nullptr)
    return empty;
  client->last_error.clear();

  grpc::ClientContext context;
  if (timeout_ms > 0) {
    context.set_deadline(std::chrono::system_clock::now() +
                         std::chrono::milliseconds(timeout_ms));
  }

  grpc::Slice request_slice(request, request_len);
  grpc::ByteBuffer request_buffer(&request_slice, 1);
  grpc::ByteBuffer response_buffer;
  grpc::CompletionQueue queue;

  auto rpc =
      client->stub->PrepareUnaryCall(&context, method, request_buffer, &queue);
  if (!rpc) {
    client->last_error = "failed to prepare unary grpc call";
    queue.Shutdown();
    void* tag = nullptr;
    bool ok = false;
    while (queue.Next(&tag, &ok)) {
    }
    return empty;
  }

  grpc::Status status;
  rpc->StartCall();
  rpc->Finish(&response_buffer, &status, reinterpret_cast<void*>(1));

  void* tag = nullptr;
  bool ok = false;
  const bool queued = queue.Next(&tag, &ok);
  queue.Shutdown();
  while (queue.Next(&tag, &ok)) {
  }

  if (!queued || tag != reinterpret_cast<void*>(1) || !ok) {
    client->last_error = "grpc completion queue failed";
    return empty;
  }

  if (!status.ok()) {
    client->last_error = status.error_message();
    if (client->last_error.empty()) {
      client->last_error =
          "grpc status code " +
          std::to_string(static_cast<int>(status.error_code()));
    }
    return empty;
  }

  std::vector<grpc::Slice> slices;
  grpc::Status dump_status = response_buffer.Dump(&slices);
  if (!dump_status.ok()) {
    client->last_error = dump_status.error_message();
    if (client->last_error.empty())
      client->last_error = "failed to read grpc response bytes";
    return empty;
  }

  size_t total_len = 0;
  for (const auto& slice : slices)
    total_len += slice.size();

  auto* data =
      static_cast<unsigned char*>(std::malloc(total_len == 0 ? 1 : total_len));
  if (data == nullptr) {
    client->last_error = "failed to allocate grpc response";
    return empty;
  }

  size_t offset = 0;
  for (const auto& slice : slices) {
    std::memcpy(data + offset, slice.begin(), slice.size());
    offset += slice.size();
  }

  return {data, total_len};
}

void grpc_buffer_destroy(GrpcBuffer buffer) {
  std::free(buffer.data);
}
