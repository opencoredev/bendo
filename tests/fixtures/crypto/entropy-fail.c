/* Test-only fault injection: verify the native Base entropy error reaches callers. */
#include <errno.h>
#include <stddef.h>
#include <sys/types.h>
ssize_t getrandom(void *buffer, size_t length, unsigned int flags) {
  (void)buffer;
  (void)length;
  (void)flags;
  errno = EIO;
  return -1;
}
