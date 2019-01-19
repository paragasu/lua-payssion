-- lua api for payssion payment gateway
-- Author Jeffry L. <paragasu@gmail.com>
-- reference https://payssion.com/en/docs

local http = require 'resty.http'
local md5  = require 'md5'
local json = require 'cjson'
local inspect = require 'inspect'

local Payssion = {}
local sandbox_url = 'https://sandbox.payssion.com/api/v1/payment'
local api_url = 'https://www.payssion.com/api/v1/payment' 
local api_key, secret_key, pm_id, order_id, currency, amount, desc
local sandbox = true

-- encode string into escaped hexadecimal representation
-- from socket.url implementation
function escape(s)
  return (string.gsub(s, "([^A-Za-z0-9_])", function(c)
    return string.format("%%%02x", string.byte(c))
  end))
end

-- encode url / convert table to url string args
-- @param args table of request params
-- @return string
function encode_url(args)
  local params = {}
  for k, v in pairs(args) do table.insert(params, k .. '=' .. escape(v)) end
  return table.concat(params, "&")
end

-- http post request
-- @param path 
-- @param data table of params 
-- @param header table of headers
-- @return httpc request result
function post(path, data)
  local httpc = http.new()
  return httpc:request_uri(url, {
    method  = "POST", 
    headers = { ["Content-Type"] = "application/x-www-form-urlencoded" },
    body    = encode_url(args.data),
    ssl_verify = false
  })
end

-- payssion constructor
-- @param payssion_api payssion api key
-- @param payssion_secret secret key
-- @param mode
function Payssion:new(payssion_api, payssin_secret, live)
  api_key = payssion_api
  secret_key = payssion_secret
  sandbox = live or false
  if not api_key then error("Not valid payssion api_key") end
  if not secret_key then error("Not valid payssion secret_key") end
  return self
end

-- Call payssion /create to initiate payment. 
-- @param pm_id payment method id or table with params as specified in https://www.payssion.com/en/docs/#api-reference-payment-request
-- @param order_id order ref for this transaction
-- @param amount total amount
-- @param currency currency code
-- @param desc transaction description 
-- @return table with order_id, redirect_url, transaction_id, amount, currency & state key
function Payssion:create(pm_id, order_id, amount, currency, desc)
  local args
  if type(pm_id) == 'table' then
    args = pm_id
  else
    args = {
      pm_id = pm_id,
      order_id = tostring(order_id),
      amount = tostring(amount),
      currency = currency,
      description = desc
    }
  end

  if not args.pm_id then return nil, "Invalid payment method" end
  if not args.order_id then return nil, "Invalid order id reference" end
  if not args.amount then return nil, "Invalid amount" end
  if not args.currency then return nil, "Missing currency" end
  if not args.desc then return nil, "Missing description" end
  if sandbox then pm_id = 'dotpay_pl' end -- dotpay_pl or sofort 

  args.api_key = api_key
  args.api_sig = self.create_request_signature(pm_id, amount, currency, order_id)

  local res, err = post('/create', args)

  if not res then return error(err) end
  if res.status ~= 200 then return error("Error processing payment: " .. res.body) end
  local body = json.decode(res.body)

  return {
    order_id = body.transaction.order_id,
    redirect_url   = body.redirect_url, 
    transaction_id = body.transaction.transaction_id,
    amount = body.transaction.amount,
    currency = body.transaction.currency,
    state = body.transaction.state
  }
end

-- get transaction state
-- @param transaction_id
-- @param order_id
-- @return transaction state
function Payssion:get_transaction_state(transaction_id, order_id)
  if not transaction_id then return nil, "Invalid transaction_id" end
  if not order_id then return nil, "Invalid order_id" end
  local res, err = post('/details', {
    api_key = api_key,
    transaction_id = transaction_id,
    order_id = order_id,
    api_sig = self.create_details_signature(transaction_id, order_id) 
  })
  if not err and res.status == 200 then
    local body = json.decode(res.body)
    return body.transaction.state 
  end
end

-- depreciated api call
function Payssion:details(transaction_id, order_id)
  return Payssion:get_transaction_state(transaction_id, order_id)
end

-- check notification signature
-- @param req table from payssion callback params. Req params should have
--        pm_id, state, amount, currency and order_id key
function Payssion.check_signature(req)
  if not req.pm_id  then return nil, "Invalid pm_id" end
  if not req.state  then return nil, "Invalid state" end
  if not req.amount then return nil, "Invalid amount" end
  if not req.currency then return nil, "Invalid currency" end
  if not req.order_id then return nil, "Invalid order_id" end
  local valid_signature = Payssion.create_notify_signature(req.pm_id, req.amount, req.currency, req.order_id, req.state)
  return valid_signature  == req.notify_sig
end

-- generate request signature
-- @param pm_id payment method id
-- @param amount transcation amount
-- @param currency
-- @param order_id payment ref
function Payssion.create_request_signature(pm_id, amount, currency, order_id)
  return md5.sumhexa(table.concat({ api_key, pm_id, amount, currency, order_id, secret_key}, '|'))
end

-- generate notify signature
-- @param transaction_id
-- @param order_id
function Payssion.create_detail_signature(transaction_id, order_id)
  return md5.sumhexa(table.concat({ api_key, transaction_id, order_id, secret_key}, '|'))
end

-- generate detail signature
-- @param pm_id payment method
-- @param amount payment amount
-- @param currency
-- @param order_id payment ref
-- @param state transaction state
function Payssion.create_notify_signature(pm_id, amount, currency, order_id, state)
  return md5.sumhexa(table.concat({ api_key, pm_id, amount, currency, order_id, state, secret_key}, '|'))
end

return Payssion
