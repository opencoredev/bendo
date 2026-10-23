import Base
import ../../../src/data/form.bend as Form
import ../../../src/data/multipart.bend as M

def parse(ct: String, body: List<&2, U32>, limits: M.Limits) -> Result<&2, &2, M.Error, List<&2, M.Part>>:
  Form.parse_body_with_limits(ct, body, limits)
