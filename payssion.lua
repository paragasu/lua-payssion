-- lua api for payssion payment gateway
-- Author Jeffry L. <paragasu@gmail.com>
-- reference https://payssion.com/en/docs

local requests = require 'requests'
local md5 = require 'md5'
local i   = require 'inspect'

local Payssion = {}
local api_url = 'https://sandbox.payssion.com/api/v1/payment'
local sandbox = true
local api_key, secret_key, pm_id, order_id, currency, amount, desc
local payment_state = {
  error = 'Some error happens',
  pending = 'The payment has not been paid yet',
  completed = 'The payment has been completed',
  paid_partial = 'The payment was paid in partial',
  awaiting_confirm = 'The payment may have been paid but we have not yet received it',
  failed = 'The payment was failed',
  cancelled = 'The payment has been cancelled',
  cancelled_by_user = 'The payment has been cancelled by the user',
  rejected_by_bank = 'The payment has been rejected by the bank',
  expired = 'The payment has been expired',
  refunded = 'The payment has been refunded',
  refund_pending = 'The refund of this payment has not been completed yet',
  refund_failed = 'Failed to refund this payment',
  chargeback = 'There is a chargeback for this payment' 
}

-- encode string into escaped hexadecimal representation
-- from socket.url implementation
function escape(s)
  return (string.gsub(s, "([^A-Za-z0-9_])", function(c)
    return string.format("%%%02x", string.byte(c))
  end))
end

-- encode url
function encode_url(args)
  local params = {}
  for k, v in pairs(args) do table.insert(params, k .. '=' .. escape(v)) end
  return table.concat(params, "&")
end

-- set configuration
function Payssion:new(config_api_key, config_secret_key, live)
  api_key    = config_api_key
  secret_key = config_secret_key
  if not api_key then error("Not valid payssion api_key") end
  if not secret_key then error("Not valid payssion secret_key") end
  if live then 
    api_url = 'https://www.payssion.com/api/v1/payment' 
    sandbox = false
  end 
  return self
end

-- create payment
function Payssion:create(paymentmethod_id, order_id, amount, currency, desc)
  if not paymentmethod_id then return nil, "Invalid payment method" end
  if not order_id then return nil, "Invalid order id reference" end
  if not amount or amount == 0 then return nil, "Invalid amount" end
  if not currency then return nil, "Missing currency" end
  if not desc then return nil, "Missing description" end
  if sandbox then paymentmethod_id = 'dotpay_pl' end -- dotpay_pl or sofort 
  local sig = self.create_request_signature(paymentmethod_id, amount, currency, order_id)
  local params = {
    api_key  = api_key,
    api_sig  = sig,
    pm_id    = paymentmethod_id,
    order_id = tostring(order_id),
    amount   = tostring(amount),
    currency = currency,
    description = desc  
  }
  local response = requests.post({
      url  = api_url .. '/create', 
      data = encode_url(params),
      headers = { ["Content-Type"] = "application/x-www-form-urlencoded" }
  })
  local body, err = response.json()
  if not err and body.result_code == 200 then
    return {
      order_id = body.transaction.order_id,
      redirect_url   = body.redirect_url, 
      transaction_id = body.transaction.transaction_id,
      amount = body.transaction.amount,
      currency = body.transaction.currency,
      state = body.transaction.state
    }
  else
    return nil, body.description or err
  end
end

-- get payment details
function Payssion:details(transaction_id, order_id)
  local response = requests.post(api_url .. '/details', {
    api_key = api_key,
    transaction_id = transaction_id,
    order_id = order_id,
    api_sig = self.create_details_signature(transaction_id, order_id) 
  })
  local body, err = response.json()
  if not err and body.result_code == 200 then
    return body.transaction.state 
  end
end

-- check notification signature
function Payssion:check_signature(transaction_id, order_id, notify_sig)
  local valid_signature = Payssion.create_notify_signature(transaction_id, order_id)
  return valid_signature  == notify_sig
end

-- generate request signature
function Payssion.create_request_signature(pm_id, amount, currency, order_id)
  return md5.sumhexa(table.concat({ api_key, pm_id, amount, currency, order_id, secret_key}, '|'))
end

-- generate notify signature
function Payssion.create_notify_signature(transaction_id, order_id)
  return md5.sumhexa(table.concat({ api_key, transaction_id, order_id, secret_key}, '|'))
end

-- generate detail signature
function Payssion.create_notify_signature(pm_id, amount, currency, order_id, state)
  return md5.sumhexa(table.concat({ api_key, pm_id, amount, currency, order_id, state, secret_key}, '|'))
end

return Payssion
