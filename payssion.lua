-- lua api for payssion payment gateway
-- Author Jeffry L. <paragasu@gmail.com>
-- reference https://payssion.com/en/docs

local requests = require 'requests'
local md5 = require 'md5'

local Payssion = {}
local api_url = 'https://sandbox.payssion.com/api/v1/payment'
local api_key, secret_key, pm_id, order_id, currency, amount, desc
local error_code = {
  200 = 'Success',
  400 = 'Invalid parameter',
  401 = 'Invalid merchant_id',
  402 = 'Invalid api signature',
  403 = 'Invalid app name',
  405 = 'Invalid payment method',
  406 = 'Invalid currency',
  407 = 'Invalid amount',
  408 = 'Invalid language',
  409 = 'Invalid url',
  411 = 'Invalid secret key',
  412 = 'Invalid transaction id',
  413 = 'Repeated order',
  414 = 'Invalid country',
  415 = 'Invalid payment type',
  420 = 'Invalid request method',
  441 = 'The app is inactive',
  500 = 'Server error',
  501 = 'Server busy',
  502 = 'The third party error',
  503 = 'Service not found' 
}

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

-- set configuration
function Payssion:new(api_key, secret_key, live=false)
  api_key    = api_key
  secret_key = secret_key
  if live then api_url = 'https://www.payssion.com/api/v1/payment' end 
end

-- create payment
function Payssion:create(paymentmethod_id, order_id, amount, currency, desc)
  local sig = self.create_request_signature(paymentmethod_id, amount, currency, order_id)
  local response = requests.post(api_url + '/create', {
    api_key  = api_key,
    api_sig  = sig,
    pm_id    = paymentmethod_id,
    order_id = order_id,
    currency = currency,
    amount   = amount,
    description = desc  
  })
  local body, err = response.json()
  if not err and body.result_code == 200 then
    return body.redirect_url, body.transaction.transaction_id  
  else
    return nil, error_code[body.result_code] or err
  end
end

-- get payment details
function Payssion:details(transaction_id, order_id)
  local response = requests.post(api_url + '/details', {
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
  return md5(table.concat({ api_secret, pm_id, amount, currency, order_id, secret_key}, '|'))
end

-- generate notify signature
function Payssion.create_notify_signature(transaction_id, order_id)
  return md5(table.concat({ api_secret, transaction_id, order_id, secret_key}, '|'))
end

-- generate detail signature
function Payssion.create_notify_signature(pm_id, amount, currency, order_id, state)
  return md5(table.concat({ api_secret, pm_id, amount, currency, order_id, state, secret_key}, '|'))
end

return Payssion
