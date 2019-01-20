# lua-payssion
LUA api for payssion.com payment gateway. 

Payssion is payment gateway provider based in HK. What make payssion
attractive compare to paypal or stripe is that it support wide range of online banking payment, which is more popular
in SEA where credit card ownership is a luxury.

# Installation

    #luarocks install lua-payssion 

# API

### **new** _(api\_key, api\_secret, sandboxed)_
  create new payssion object
  param
  - api\_key string from payssion account
  - secret\_key string from payssion account
  - sandboxed sandbox or live, default true


### **create** _(pm\_id, order\_id, amount, currency, desc)_
  submit new payment request for processing
  param
  - pm_id payment method as provided by payssion
  - order\_id unique string to refer to transaction
  - amount total amount charged
  - currency abbr of currency
  - desc description of the transaction


### **details** _(transaction\_id, order\_id)_
  Get the transaction details
  params
  - transaction_id payssion transaction\_id
  - order_id payment ref


### **get_transaction_state** _(transaction\_id, order\_id)_
  Get the transaction details
  params
  - transaction_id payssion transaction\_id
  - order_id payment ref


### **check_signature** _(transaction\_id, order\_id, notify\_sig)_
  validate the notification message
  params
  - transaction\_id payssion transaction\_id
  - order\_id order id
  - notify\_sig signature passed by payssion


# Example usage

```lua
  local payssion = require 'payssion'
  local pay = payssion({
    api_key = 'xxx',
    secret_key = 'xxx'
  })

  -- create payment
  local res, err = pay:create(pm_id, order_id, amount, currency, desc)
  if res not nil then
    -- save res.order_id
    -- redirect to res.redirect_url
  end

  -- alternatively using params as documented in https://payssion.com/en/docs/#api-reference-payment-request
  local res, err = pay:create({
    pm_id = pm_id,
    amount = amount,
    currency = 'MYR',
    description = 'My test order'
  })

  if res not nil then
    -- save res.order_id
    -- redirect to res.redirect_url
  end

  -- process payment notification
  if pay:check_signature(trans_id, order_id, notify_sig) then
    -- update payment status
  end

  -- get payment details
  local info = pay:get_transaction_state(transaction_id, order_id)
  if info then
    -- show payment info
  end
  
```

# Reference
[Payssion API](https://payssion.com/en/docs)
