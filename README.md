# Solidus Adyen Integration

Easily integrates Adyen payments into a Solidus store. It works as a wrapper
of the [awesome adyen](https://github.com/wvanbergen/adyen/) gem which contains
all basic API calls for Adyen payment services.

## Installation
Add this line to your application's Gemfile:

```ruby
gem 'solidus-adyen', github: 'freerunningtech/solidus-adyen', branch: 'master'
```

Download the gem, install and run migrations provided by this gem. The
solidus-adyen migrations will allow responses from Adyen to be persisted to the
database.

```bash
$ bundle install
$ bundle exec rake spree_adyen:install:migrations
$ bundle exec rake db:migrate
```

## Usage

To integrate with Adyen Payments you'll need to request API credentials by
signing up at Adyen website https://www.adyen.com/.

This extension provides three Payment Methods. In order to use AdyenPayment and
AdyenPaymentEncrypted method you'll need to make sure your account is enabled to
use Adyen API Payments, needed to authorize payments via their SOAP API.

The other payment method, AdyenHPP, allows your store to authorize payments
using Adyen Hosted Payments Page solution. In this case the customer will enter
cc in Adyen website and be redirected back to the store after the payment.

For the AdyenHPP method you'll need to create a skin in your merchant dashboard
and add the skin_code and shared_secret to the payment method on Solidus backend UI.

All subsequent calls, e.g. capture, are done via Adyen SOAP API by both payment
methods.

Make sure that you config your notification settings in Adyen Merchant dashboard.
You need to set URL, choose HTTP POST and set a username and password for
authentication. The username and password need to be set as environment variables
, ADYEN_NOTIFY_USER and ADYEN_NOTIFY_PASSWD, so that notifications can successfully
persist on your application database.

Please look into the adyen gem wiki https://github.com/wvanbergen/adyen/wiki and
Adyen Integration Manual for further info https://www.adyen.com/developers/api/

## Configuring the HPP Payment Method
### Configuring Your Adyen account to respond to the Rails application
The <abbr title="Hosted Payment Page">HPP</abbr> payment-flow requires that at
the payment step of checkout the user is redirected to Adyen's payment portal
and then, once the payment form is completed on Adyen's side, is redirected
back to the http-referrer. Once Adyen processes the payment it will post a
notification to a specified end point (which will be covered later). For this
reason your rails server must be publicly reachable in all environments.

*It is important to note that Adyen will only issue notifications to servers that
are running on standard HTTP ports, so your rails server must be accessible
on port 80, 8080, [or some other http-alternative port](https://en.wikipedia.org/wiki/List_of_TCP_and_UDP_port_numbers).*

If running in a development environment, reverse tunnel your local rails server
to some public IP that you control.

**e.g.**
```bash
$ bundle exec rails server -p 3000 &
$ ssh -N -R 0.0.0.0:8080:localhost:3000 user@myserver.com &
```

Define two environment variables `ADYEN_NOTIFY_USER`, `ADYEN_NOTIFY_PASSWD` on
your rails server. The values chosen can be arbitrary but of course should be
secure as they will be used by Adyen to notify the server that a payment has
been processed. These will be used in the next step so keep the file open.

Next we will configure our Adyen account so that it will be able to authenticate
with solidus-adyen and post notifications about payments. To do do:
1. [Log in to Adyen](https://ca-test.adyen.com/ca/ca/login.shtml)
1. Click `Settings` on the left hand nav.
1. Click the [Server Communication](https://ca-test.adyen.com/ca/ca/config/showthirdparty.shtml)
   tile in the main area.
1. In the first table, click `Edit & Test` in the `Action` column.
1. Within the fielset labeled `Transport`
  + Fill in the field `URL` with `http://myserver.com/adyen/notify` where
    `http://myserver.com` is either your production site with the solidus-adyen
    gem installed, or the ip and port combination you have reverse-forwarded
    your development server to.
  + Choose `HTTP POST` for `Method`.
  + Make sure `Active` is checked.
1. Within the fieldset labeled `Authentication`.
  + Fill in the field `User Name` with the value you used for `ADYEN_NOTIFY_USER`
  + Fill in the field `Password` with the value you used for `ADYEN_NOTIFY_PASSWD`
1. Click `Save Configuration`
1. Make sure your rails server is started and that the env variables are set.
1. Click `Test Configuration`

If all went well then you'll see logging output for Adyen's tests and will
not see any notification of errors at the top of the page.

### Creating and Configuring the AdyenHPP payment method
Next we will create a payment method that will use Adyen's hosted payment
pages. Start by creating a new payment method within solidus (found at
http://yourserver/admin/payment_methods/new).

_It is *very* important to note if any of the following values entered have any
trailing or leading whitespace everything will break._

+ Choose `Spree::Gateway::AdyenHPP` for Provider
+ Set `Server` to `test`
+ Set `Auto Capture` to `false`
+ Set `Environment` to `Development`
+ Set `Display` to `Both`
+ Set `Active` to `Yes`
+ Fill in `Api username`, `Api password`, `Merchant Account`, `Shared
  Secret`, and `Skin Code` with the values found using the steps below.
+ Click `Update` after filling all fields (use the steps provided below to find the values specified in the previous step first).

To find your `Api Username` and `Api password`:
+ Log into your Adyen account
+ Click Settings from the left hand navigation
+ Click [Users](https://ca-test.adyen.com/ca/ca/config/users.shtml)
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
+ You should be redirected to Adyen's portal
+ Congratulations!

## Testing

The extension contains some specs that will reach out Adyen API the first time
you run them. Those are marked with the external tag and they need credentials
so you'll have to set up a config/credentials.yml file. Theres's a helper
`test_crendentials` available on the specs to call each key on that yaml file.
Also it uses VCR to record the requests so you'll need to delete those files
to do a new request.

Required to run specs: create a dummy Rails app as testing environment:

```ruby
bundle exec rake test_app
```

You can run external specs like this:

```ruby
bundle exec rspec spec --tag external
```

## Test Credit Card Info

https://support.adyen.com/index.php?/Knowledgebase/Article/View/11/0/test-card-numbers

## Terminology and other API information
[More info about Adyen can be found here](https://docs.adyen.com/display/TD/3D+Secure).
Includes information about the adyen soap api and the parameters that it accepts.

**e.g.**
> paRequest, md, issuerUrl, resultCode, PaReq, MD, TermUrL, etc.

If you find some variable that is not documented in the gem, it's likely
defined here.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
