local payssion = dofile('payssion.lua')

local pay = payssion:new('xx', 'xx', false)

describe('Payssion', function()
  it('Generate request signature', function()
    local sig = pay.create_request_signature('maybank2u_my', 28, 10.10, 'MYR', 'test')   
    assert(type(sig), 'string')
  end)
end)
