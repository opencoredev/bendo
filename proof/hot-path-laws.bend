# BND-68: each hot-path rewrite equals its retained definition for every
# input, so every earlier law about the original carries over unchanged.
import Base
import ../src/data/utf8.bend as Utf8
import ../src/http/bytes.bend as Bytes
import ../src/http/response.bend as Response
import ../src/app/context.bend as Context
import ../src/data/json.bend as Json

law hot_utf8_encode_char:
  for +c: U32
  {Utf8.encode_char(c) == Utf8.encode_char_spec(c) : List<&2, U32>}

law hot_bytes_tchar:
  for +c: U32
  {Bytes.tchar(c) == Bytes.tchar_spec(c) : Bool}

law hot_response_utf8:
  for +s: String
  {Response.utf8(s) == Response.utf8_spec(s) : List<&2, U32>}

law hot_context_text:
  for -Vars: Data
  for +c: Context.Ctx<Vars>
  for +value: String
  {Context.text(Vars, c, value) == Context.text_spec(Vars, c, value) : Response.Res}

law hot_context_html:
  for -Vars: Data
  for +c: Context.Ctx<Vars>
  for +value: String
  {Context.html(Vars, c, value) == Context.html_spec(Vars, c, value) : Response.Res}

law hot_context_json_result:
  for -Vars: Data
  for +c: Context.Ctx<Vars>
  for +result: Result<&2, &2, Json.Error, String>
  {Context.json_result(Vars, c, result) == Context.json_result_spec(Vars, c, result) : Response.Res}
