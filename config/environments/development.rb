Rails.application.configure do
  host = ENV["APPLICATION_HOST"] || 'localhost'
  config.cache_classes = false
  config.eager_load = false
  config.consider_all_requests_local = true
  config.action_controller.perform_caching = false
  config.action_mailer.perform_deliveries = true
  config.action_mailer.raise_delivery_errors = true
  config.action_mailer.delivery_method = :smtp
  config.action_mailer.smtp_settings =  {
    :address => '127.0.0.1',
    :port    => '25',
    :domain  => host
  }
  config.active_support.deprecation = :log
  config.active_record.migration_error = :page_load
  config.assets.debug = true
  config.assets.digest = true
  config.assets.raise_runtime_errors = true
  config.action_view.raise_on_missing_translations = true
  config.action_mailer.default_url_options = { host: host }

  config.aact = {static_files_directory: "public/static"}
end
