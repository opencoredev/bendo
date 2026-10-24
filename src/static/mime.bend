# Content-Type by file extension (BND-45). Pure. Text types carry
# charset=utf-8; unknown extensions are application/octet-stream.
import Base

type Entry is Data:
  Entry{extension: String, media: String}

def text(+extension: String, media: String) -> Entry:
  Entry{extension, media ++ "; charset=utf-8"}

def table() -> List<&2, Entry>:
  [
    text("html", "text/html"), text("htm", "text/html"),
    text("css", "text/css"),
    text("js", "text/javascript"), text("mjs", "text/javascript"), text("cjs", "text/javascript"),
    text("json", "application/json"), text("map", "application/json"),
    text("webmanifest", "application/manifest+json"),
    text("txt", "text/plain"), text("md", "text/markdown"), text("csv", "text/csv"),
    text("xml", "application/xml"), text("svg", "image/svg+xml"),
    Entry{"png", "image/png"}, Entry{"jpg", "image/jpeg"}, Entry{"jpeg", "image/jpeg"},
    Entry{"gif", "image/gif"}, Entry{"webp", "image/webp"}, Entry{"avif", "image/avif"},
    Entry{"ico", "image/x-icon"},
    Entry{"woff", "font/woff"}, Entry{"woff2", "font/woff2"}, Entry{"ttf", "font/ttf"}, Entry{"otf", "font/otf"},
    Entry{"wasm", "application/wasm"}, Entry{"pdf", "application/pdf"}, Entry{"zip", "application/zip"},
    Entry{"gz", "application/gzip"},
    Entry{"mp4", "video/mp4"}, Entry{"webm", "video/webm"},
    Entry{"mp3", "audio/mpeg"}, Entry{"wav", "audio/wav"}, Entry{"ogg", "audio/ogg"}
  ]

def found(media: String, rest: Maybe<&2, String>, same: Bool) -> Maybe<&2, String>:
  match same:
    case True{}: Some{media}
    case False{}: rest

def lookup(entries: List<&2, Entry>, +extension: String) -> Maybe<&2, String>:
  match entries:
    case Nil{}: None{}
    case Entry{e, media} <> t: found(media, lookup(t, extension), String.eq(e, extension))

def last_of(xs: List<&2, String>) -> String:
  Maybe.default(&2, String, List.last(&2, String, xs), "")

def extension_of(parts: List<&2, String>) -> String:
  match parts:
    case Nil{}: ""
    case h <> Nil{}: ""
    case h <> t: last_of(t)

# The lowercase text after the last '.' of the file name, or "".
def extension(path: String) -> String:
  extension_of(String.split(String.to_lower(last_of(String.split(path, '/'))), '.'))

def content_type(path: String) -> String:
  Maybe.default(&2, String, lookup(table(), extension(path)), "application/octet-stream")
