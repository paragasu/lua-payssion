local payssion = dofile('payssion.lua')
local i = require 'inspect'

local api_key = '2b9718d91eb66a8d'
local secret_key = 'ae717c0794362fee0288a3ab0b31d8dc'
local pay = payssion:new(api_key, secret_key, true)

describe('Payssion', function()
  it('Generate request signature', function()
    local sig = pay.create_request_signature('maybank2u_my', 28, 10.10, 'MYR', 'test')   
    assert(type(sig), 'string')
  end)

  it('create api', function()
    local res, err = payssion:create('maybank2u_my', 28, 10, 'MYR', 'api test')
    print(i(res))
    print(i(err))
  end)
end)
