# Solidus-Adyen [![Build Status](https://travis-ci.org/StemboltHQ/solidus-adyen.svg)](https://travis-ci.org/StemboltHQ/solidus-adyen)

**NOTICE** From July 2016 Adyen will no longer support SHA1 HPP's, this extension is _not_ only compatible with the SHA256 skins.

Adds support for Adyen Hosted Payment Page payments to Solidus stores using the
[Adyen](https://github.com/wvanbergen/adyen/) gem.

Due to the way Adyen's payment API works, the payments created using the
AdyenHPP method's behavior differ significantly from normal payments.

Adyen's API is totally asynchronous, Solidus makes a request to modify a
payment, and some time in the future Adyen responds to a specified endpoint
with the result of the action. After capture/refund/cancellation the payment
will move to a `processing` state, and will be change to the new state after the
notification is received from Adyen.

# Installation
Add this line to your application's Gemfile:
```ruby
gem 'solidus-adyen', '~> 1.0.0'
```

Then run:
```bash
$ bundle install
$ bundle exec rake spree_adyen:install:migrations
$ bundle exec rake db:migrate
```

# Usage

To integrate with Adyen payments you'll need to request API credentials by
signing up at Adyen's [website](https://www.adyen.com/).

This gem only supports Adyen HPP payment methods. At this time there are no plans
to support the direct payment methods.

A payment method called `AdyenHPP` added to the list of available payment methods 
allowing stores to authorize payments using Adyen Hosted Payments Page solution. This works much
like paypal and similar services where the customer is redirected to Adyen at
the payment step, and is redirected back to your store after they have
completed payment.

Please look into the Adyen gem wiki https://github.com/wvanbergen/adyen/wiki and
Adyen Integration Manual for further info https://www.adyen.com/developers/api/

# Configuration
## Application Server
Define two environment variables `$ADYEN_NOTIFY_USER` and `$ADYEN_NOTIFY_PASSWD`
that are available to the rails server. These will be used Adyen to authenticate
with the application server when it `POST`'s notifications which will update
the state of a payment.

Obviously these should be kept secret as they will be used to update the state
of payments.

## Server Communication
To receive notifications from Adyen about the outcome of payment modifications
(authorization, capture, refund, cancellation) you will need to configure your merchant
account with Adyen with the proper url to the
`Spree::AdyenNotifications#notify` action.
```bash
$ rake routes | grep spree/adyen_notifications#notify
  adyen_notify POST /adyen/notify(.:format) spree/adyen_notifications#notify
```
is the default path for the endpoint.

It is worth noting that Adyen will only issue notifications to servers that
are running on standard HTTP ports, so your rails server must be accessible on
port 80, 8080, [or some other http-alternative
port](https://en.wikipedia.org/wiki/List_of_TCP_and_UDP_port_numbers).

Visit [Settings > Server
Communication](https://ca-test.adyen.com/ca/ca/config/configurethirdparty.shtml)
and click 'edit & test' for 'Standard Notification', the other notifications
are not used by this integration and may cause undefined behavior if enabled.

Use the following configuration:

Field                       | Value
----------------------------|---------------------------------------------------
URL                         | http://your.server/adyen/notify *or whatever you have changed the previous path to*
SSL Version                 | SSL
Active                      | checked
Service Version             | 1
Method                      | HTTP POST
Populate SOAP Action header | unchecked
User name                   | $ADYEN_NOTIFY_USER
Password                    | $ADYEN_NOTIFY_PASSWD

Save your changes and click 'Test Configuration', everything should be successful.

If you get errors saying that it was unauthorized you forgot to set the username
and password environment variables on the server.

## Skin
A skin defines the look, feel, and behavior of the hosted payment page.

To set one up visit [Skins](https://ca-test.adyen.com/ca/ca/skin/skins.shtml)
and edit an existing skin or create a new one.

Fill in

field       | Test platform                           | Live platform
------------|-----------------------------------------|-------------------------
HMAC Keys   | *some secure key*                       | *some secure key*
Result URLs | http://your.site/checkout/payment/adyen | http://your.site/checkout/payment/adyen

Write down the values you use for HMAC keys as you'll be using them later when
your create the payment method.

## AdyenHPP Payment Method
In the Solidus admin, go to your payment methods and create a new payment method
using the `Spree::Gateway::AdyenHPP` provider.

It is *very* important to note if any of the following values entered have any
trailing or leading whitespace everything will break.

Use the following config

Field        | Value
-------------|------------------------------------------------------------------
Server       | test
Auto Capture | false
Environment  | Development
Display      | Front End
Active       | Yes

Fill in `Api username`, `Api password`, `Merchant Account`, `Shared
  Secret`, and `Skin Code` with the values found using the steps below.

To find your `Api Username` and `Api password`:
+ Log into your Adyen account
+ Click [Settings > Users](https://ca-test.adyen.com/ca/ca/config/users.shtml)
  from the left hand navigation
+ In the table, change the filter by selecting `System` from the select on
  the left hand side of table header (`Customer` is highlighted by default)
+ Click the linked value in the `Name` column you wish to use.
+ Under the `User Account Details` fieldset the value of `User Name` is
  your `Api Username` and the value of `Password` will be your `Api
  Password`

To find your `Merchant Account`:
+ Log into your Adyen account
+ In the top navigation bar beside the magnifying class click on the box that's text
  is the same as your username
+ In the table, under the column called `Account Code` is your `merchant
  account` name

To find your `Skin Code` and `Shared Secret`:
+ Log into your Adyen account
+ click [Skins](https://ca-test.adyen.com/ca/ca/skin/skins.shtml) from the left hand nav
+ Click the link under the `skin code` column whose value for the column `valid
  accounts` matches your `Merchant Account`
+ Within the `Skin details` field-set
  + The value for `Skin Code` is the value of text input with the same name
  + The value for `Shared Secret` is the value of text input labeled `HMAC Keys`

To verify that your payment method is configured properly:
+ Go to your Solidus store's homepage
+ Add an item to cart
+ Click Check out
+ Enter an Address
+ On the Payment step, select your Adyen payment method, and then 'pay with
  Adyen'
  *if no payment methods show up here check your server logs, you likely don't
  have the payment method configured properly.*
+ You should be redirected to Adyen's portal
+ Congratulations!

# HPP Directory Lookup
This gem supports [adyen directory look ups](https://docs.adyen.com/display/TD/Directory+lookup+-+Skip+HPP).
The [default checkout view](../master/app/views/spree/checkout/payment/_adyen.html.erb#L10-L13)
does provide the functionality to asynchronously load the payment methods, but
if you want to include this feature in your own custom checkout views you can
follow the instructions below.

Include [spree/checkout/payment/adyen.js](../master/app/assets/javascripts/spree/checkout/payment/adyen.js)
on your checkout page. Add an element that has an id of `adyen-hpp-details` and 
has

```ruby
data: {
  url: directory_adyen_hpp_path(
    order_id: @order.id,
    payment_method_id: payment_method.id)}
```

You can also skip using the provided js if you really want to! Important
thing here is just to make a `get` to `directory_adyen_hpp_path` with the `order_id`
and `payment_method_id` and then insert the resultant html somewhere in the DOM.
This will then make the request to adyen to get a list of payment methods that
are supported and then render the payment links.

If you just want to style the list of Adyen payment methods, just override the
[spree/adyen/hpps/directory](../master/app/views/spree/adyen/hpps/directory.html.erb)
view. Take a look at the existing version to get an idea of what is available
in the view.

# Testing
```bash
$ DB=postgres bundle exec rake test_app
$ rspec
$ cd spec/dummy
$ rake solidus-adyen:factory_girl:lint
```

# Development
My prefered method of setting up a sandbox is with
```bash
$ ./bin/bootstrap.sh
$ ./spec/dummy/bin/rails s
```
You will need to reverse tunnel or make your server publicly available by some
other means - and update the server communication as well as the skin's url
with the proper end point to receive notifications.

# Test Credit Card Info

https://docs.adyen.com/support/integration#testcardnumbers

# Terminology and other API information
[More info about Adyen can be found here](https://docs.adyen.com/display/TD/3D+Secure).
Includes information about the adyen soap api and the parameters that it accepts.

**e.g.**
> paRequest, md, issuerUrl, resultCode, PaReq, MD, TermUrL, etc.

If you find some variable that is not documented in the gem, it's likely
defined here.

# Contributing

1. Fork it
2. Create your feature branch (`git checkout -b feature/bug/refactor-thing`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
