import Config

log_level =
  case config_env() do
    :prod -> :info
    _env -> :debug
  end

config :logger, level: log_level
