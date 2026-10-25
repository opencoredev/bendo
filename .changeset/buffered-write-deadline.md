---
"bendo": minor
"create-bendo": minor
"vite-plugin-bendo": minor
---

Buffered responses now have a write deadline. The server config gains a `write_timeout_ms` field (default 30,000 ms) after `body_timeout_ms`: a client that accepts no bytes for a whole window is disconnected and the response's after-response hooks run once. The server's own 400, 408, 413 and 431 replies and `100 Continue` use the same deadline. Code that builds `Config.Config` positionally needs the new field.
