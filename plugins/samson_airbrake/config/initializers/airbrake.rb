# frozen_string_literal: true

if key = ENV['AIRBRAKE_API_KEY']
  Airbrake.user_information = # replaces <!-- AIRBRAKE ERROR --> on 500 pages
    "<br/><br/>Error number: <a href='https://airbrake.io/locate/{{error_id}}'>{{error_id}}</a>" +
      ((link = ENV['HELP_LINK']) ? "<br/><br/>#{link}" : "")

  Airbrake.configure do |config|
    config.project_id = ENV.fetch('AIRBRAKE_PROJECT_ID')
    config.project_key = key

    config.blacklist_keys = Rails.application.config.filter_parameters + ['HTTP_AUTHORIZATION']

    # send correct errors even when something blows up during initialization
    config.environment = 'staging'
    config.ignore_environments = [:test, :development]
    config.root_directory = Bundler.root.realpath # can be removed after https://github.com/airbrake/airbrake-ruby/pull/180

    # report in development:
    # - add AIRBRAKE_API_KEY to ENV
    # - add AIRBRAKE_PROJECT_ID to ENV
    # - set consider_all_requests_local = false in development.rb
    # - comment out add_filter below
    # - uncomment
    # config.ignore_environments = [:test]
  end

  # Ignore errors based on result of hook, so other parts of the code can interact with errors
  Airbrake.add_filter do |notice|
    notice.ignore! if notice[:errors].any? { |e| Samson::Hooks.fire(:ignore_error, e[:type]).any? }
  end
end