// BND-93 test resolver, loaded with LD_PRELOAD into a native or Bun process
// (Bun's dns.lookup calls getaddrinfo too). Two names are answered here and
// every other one goes to the real getaddrinfo:
// - a name ending in ".slow.bendo.test" waits until BENDO_FAKE_DNS_HOLD_MS
//   (default 2000) after the first such lookup, then does not resolve. Every
//   held lookup ends at that one instant, however many threads the resolver
//   uses.
// - "mixed.bendo.test" answers 16 IPv6 loopback addresses and then 127.0.0.1,
//   so only a dialer that keeps the IPv4 answer reaches it.
#define _GNU_SOURCE
#include <dlfcn.h>
#include <netdb.h>
#include <netinet/in.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <time.h>
#include <unistd.h>

typedef int (*Lookup)(const char*, const char*, const struct addrinfo*, struct addrinfo**);

static int64_t now_ms(void) {
  struct timespec t;
  clock_gettime(CLOCK_MONOTONIC, &t);
  return (int64_t)t.tv_sec * 1000 + t.tv_nsec / 1000000;
}

static int ends_with(const char* s, const char* suffix) {
  size_t n = strlen(s), m = strlen(suffix);
  return n >= m && strcmp(s + n - m, suffix) == 0;
}

static int64_t release_at(void) {
  static int64_t at;
  const char*    hold = getenv("BENDO_FAKE_DNS_HOLD_MS");
  int64_t        want = now_ms() + (hold != NULL ? atoll(hold) : 2000);
  int64_t        none = 0;
  __atomic_compare_exchange_n(&at, &none, want, 0, __ATOMIC_ACQ_REL, __ATOMIC_ACQUIRE);
  return __atomic_load_n(&at, __ATOMIC_ACQUIRE);
}

// One addrinfo and its address in a single block, as glibc's freeaddrinfo
// expects: it frees the canonical name and the node, never ai_addr itself.
static struct addrinfo* entry(int family, struct addrinfo* next) {
  size_t           size = family == AF_INET ? sizeof(struct sockaddr_in) : sizeof(struct sockaddr_in6);
  struct addrinfo* a    = calloc(1, sizeof(struct addrinfo) + size);
  a->ai_family          = family;
  a->ai_socktype        = SOCK_STREAM;
  a->ai_protocol        = IPPROTO_TCP;
  a->ai_addrlen         = (socklen_t)size;
  a->ai_addr            = (struct sockaddr*)(a + 1);
  a->ai_next            = next;
  if (family == AF_INET) {
    struct sockaddr_in* v4 = (struct sockaddr_in*)a->ai_addr;
    v4->sin_family         = AF_INET;
    v4->sin_addr.s_addr    = htonl(INADDR_LOOPBACK);
  } else {
    struct sockaddr_in6* v6 = (struct sockaddr_in6*)a->ai_addr;
    v6->sin6_family         = AF_INET6;
    v6->sin6_addr           = in6addr_loopback;
  }
  return a;
}

int getaddrinfo(const char* node, const char* service, const struct addrinfo* hints, struct addrinfo** res) {
  if (node != NULL && ends_with(node, ".slow.bendo.test")) {
    int64_t until = release_at();
    while (now_ms() < until) {
      usleep(5000);
    }
    return EAI_NONAME;
  }
  if (node != NULL && strcmp(node, "mixed.bendo.test") == 0) {
    struct addrinfo* list = entry(AF_INET, NULL);
    for (int i = 0; i < 16; i += 1) {
      list = entry(AF_INET6, list);
    }
    *res = list;
    return 0;
  }
  Lookup next = (Lookup)dlsym(RTLD_NEXT, "getaddrinfo");
  return next(node, service, hints, res);
}
