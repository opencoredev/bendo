/* Test-only send fault (BND-106). Whenever a parser reply (a 431, 413 or
 * 100 Continue status line) is sent, first fill the socket's send buffer with
 * filler octets until the kernel takes no more, then report EAGAIN. That is
 * the state an earlier response leaves behind on a keep-alive connection
 * whose client stopped reading, kept up even when the kernel later frees a
 * little room: the reply never gets out, so a server that holds the socket
 * past its write deadline keeps the connection open. */
#define _GNU_SOURCE
#include <dlfcn.h>
#include <errno.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/types.h>

static int parser_reply(const char *data, size_t size) {
  static const char *prefixes[] = {"HTTP/1.1 431 ", "HTTP/1.1 413 ", "HTTP/1.1 100 "};
  for (size_t i = 0; i < sizeof prefixes / sizeof *prefixes; i++) {
    size_t n = strlen(prefixes[i]);
    if (size >= n && memcmp(data, prefixes[i], n) == 0) return 1;
  }
  return 0;
}

ssize_t send(int fd, const void *data, size_t size, int flags) {
  ssize_t (*real_send)(int, const void *, size_t, int) = dlsym(RTLD_NEXT, "send");
  if (!parser_reply(data, size)) return real_send(fd, data, size, flags);
  static char filler[65536];
  memset(filler, 'x', sizeof filler);
  while (real_send(fd, filler, sizeof filler, flags | MSG_DONTWAIT) > 0) {
  }
  errno = EAGAIN;
  return -1;
}
