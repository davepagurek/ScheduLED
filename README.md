# ScheduLED
Shows your Google Calendar schedule on an LED strip

<img src="https://github.com/davepagurek/ScheduLED/blob/master/preview.png?raw=true" />

## Setup
Create a Google Calendar API project here: https://console.developers.google.com/start/api?id=calendar

Go to the **Credentials** tab and create an **OAuth Client ID** with the application type **Other**. Then, download the credentials JSON file into `client_secret.json`.

Then:
```sh
bundle install
```

## Usage
```ruby
strip_maker = CalendarLightStrip.new("dave")

# The first time you run this, it will give you a URL to open in your browser.
# After authing, enter the resulting code into STDIN. It will not prompt
# again for the same name passed into `CalendarLightStrip.new`
strip = strip_maker.strip(Time.parse("2017-01-04 07:15:00 -0500"), 18.hours)

# Generate an HTML preview to see what the array of Color::RGB objects looks like
strip_maker.preview(strip)
```
