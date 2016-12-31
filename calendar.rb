class CalendarLightStrip
  require 'google/apis/calendar_v3'
  require 'googleauth'
  require 'googleauth/stores/file_token_store'

  require 'fileutils'
  require 'active_support'
  require 'active_support/core_ext'
  require 'color'

  OOB_URI = 'urn:ietf:wg:oauth:2.0:oob'
  APPLICATION_NAME = 'Calendar Light Strip'
  CLIENT_SECRETS_PATH = 'client_secret.json' # JSON saved from the Google API website
  CREDENTIALS_PATH = 
  SCOPE = Google::Apis::CalendarV3::AUTH_CALENDAR_READONLY

  attr_reader :account_name
  attr_accessor :morning_color, :evening_color, :secondary_angle, :background_angle, :background_dim

  def initialize(account_name, morning_color: "#68D7FC", evening_color: "#1ECA2F", secondary_angle: 40, background_angle: 180, background_dim: 25)
    @account_name = account_name
    @morning_color = Color::RGB.from_html(morning_color) # color for calendar events in the morning
    @evening_color = Color::RGB.from_html(evening_color) # color for calendar events in the evening
    @secondary_angle = secondary_angle # hue shift when two events are right next to each other
    @background_angle = background_angle # hue shift when there is no event (180 makes a complementary color scheme)
    @background_dim = background_dim # saturation/luminosity dim when there is no event
  end

  def strip(start = Time.now, duration = 24.hours, length = 30)
    events = upcoming_events(start, duration)
    increment = duration / length

    events = length.times.map do |i|
      events.find do |event|
        event.start.date_time <= start + i*increment &&
          event.end.date_time >= start + i*increment
      end
    end

    ([events.first, nil] + events[1..-1].zip(events[0..-2])).reduce([]) do |colors, (event, prev)|
      if event
        if colors.empty?
          colors.push(color_primary(start))
        elsif event == prev
          colors.push(colors.last)
        elsif prev.nil?
          colors.push(color_primary(start))
        else
          colors.push(colors.last == color_primary(start) ? color_secondary(start) : color_primary(start))
        end
      else
        colors.push(color_background(start))
      end
    end
  end

  def preview(strip, preview_file = "preview.html")
    body = strip
      .map do |color|
        "<div class='light' style='background-color: #{color.html}'></div>"
      end
      .join("\n")

    css = <<-CSS
      body {
        background-color: #000;
        display: flex;
        align-items: center;
        justify-content: center;
      }
      .lights {
        display: flex;
      }
      .light {
        width: 15px;
        height: 15px;
        border-radius: 50%;
        filter: blur(2px);
        margin: 2px;
      }
    CSS

  html = "<html><head><style>#{css}</style></head><body><div class='lights'>#{body}</div></body></html>"

  File.write(preview_file, html)
  `open #{preview_file}`
  end

  def color_primary(time)
    fraction_of_day = (time - time.beginning_of_day - 7.hours) / 1.day
    fraction_of_day -= 1 while fraction_of_day > 1
    fraction_of_day += 1 while fraction_of_day < 0

    if fraction_of_day < 0.5
      evening_color.mix_with(morning_color, fraction_of_day * 2)
    else
      morning_color.mix_with(evening_color, (fraction_of_day - 0.5) * 2)
    end
  end

  def color_secondary(time)
    color_primary(time).to_hsl.tap do |color|
      color.hue += secondary_angle
    end.to_rgb
  end

  def color_background(time)
    color_primary(time).to_hsl.tap do |color|
      color.hue += background_angle
      color.saturation -= background_dim
      color.luminosity -= background_dim/4
    end.to_rgb
  end

  private

  def credentials_path
    File.join(Dir.home, '.credentials', "calendar-light-strip-credentials-#{account_name}.yaml")
  end

  def make_credentials
    FileUtils.mkdir_p(File.dirname(CREDENTIALS_PATH))

    client_id = Google::Auth::ClientId.from_file(CLIENT_SECRETS_PATH)
    token_store = Google::Auth::Stores::FileTokenStore.new(file: credentials_path)
    authorizer = Google::Auth::UserAuthorizer.new(client_id, SCOPE, token_store)
    user_id = 'default'
    credentials = authorizer.get_credentials(user_id)
    if credentials.nil?
      url = authorizer.get_authorization_url(base_url: OOB_URI)
      puts "Open the following URL in the browser and enter the resulting code after authorization."
      puts url
      code = gets
      credentials = authorizer.get_and_store_credentials_from_code(
        user_id: user_id, code: code, base_url: OOB_URI
      )
    end
    credentials
  end

  def service
    @service ||=
      begin
        service = Google::Apis::CalendarV3::CalendarService.new
        service.client_options.application_name = APPLICATION_NAME
        service.authorization = make_credentials
        service
      end
  end

  def upcoming_events(start, duration)
    service.list_calendar_lists
      .items
      .reduce([]) do |items, calendar|
        items + service.list_events(
          calendar.id,
          max_results: 10,
          single_events: true,
          order_by: 'startTime',
          time_min: start.iso8601,
          time_max: (start + duration).iso8601
        ).items
      end
      .select { |event| event.start.date_time } # Exclude full-day events
      .sort_by { |event| event.start.date_time || DateTime.now }
  end
end
