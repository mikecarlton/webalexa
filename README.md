
# Web Alexa
Issue pre-defined commands to alexa from a web page.
Motivated by needs of disabled users.

## Setup
We will run this on Heroku in their free tier.

### Get the source
`git clone git@github.com:mikecarlton/webalexa.git`

### Create Our App
`heroku apps:create webalexa`

### Get AVS Credentials
We need to obtain a set of credentials from Amazon to use the Alexa Voice service. Login at http://developer.amazon.com and goto Alexa then Alexa Voice Service.

This link may take you there directly: https://developer.amazon.com/avs/home.html#/avs/home

You need to create a new product type as an Application, for the ID use something like *webalexa*, create a new security profile and under the web settings:

* allowed origins: https://webalexa.herokuapp.com/
* allowed return urls: https://webalexa.herokuapp.com/code

You'll need to save *client_id* and *client_secret*.

Set the credentials for Heroku:

```
heroku config:set CLIENT_ID=amzn1.application-oa2-client.<secret>
heroku config:set CLIENT_SECRET=<secret>
```

If you want to make them available for local use:

```
heroku config:get CLIENT_ID -s  >> .env
heroku config:get CLIENT_SECRET -s  >> .env
```

And make sure you don't commit them:
`echo .env >> .gitignore`

## Build the App and Run
`git push heroku master`
then
`heroku open`

## Run the App Locally
`heroku local`

