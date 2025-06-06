import Config

frontend_port =
  case System.get_env("FRONTEND_PORT") do
    nil -> 3226
    val -> String.to_integer(val)
  end

config :pleroma, Pleroma.Web.Endpoint,
  url: [host: System.get_env("DOMAIN", "192.168.1.29"), scheme: "http", port: frontend_port],
  http: [ip: {0, 0, 0, 0}, port: 4000],
  session: [secure: false]

config :pleroma, :instance,
  name: System.get_env("INSTANCE_NAME", "Pleroma"),
  email: System.get_env("ADMIN_EMAIL"),
  notify_email: System.get_env("NOTIFY_EMAIL"),
  limit: 5000,
  registrations_open: true,
  federating: true,
  healthcheck: true

config :pleroma, :media_proxy,
  enabled: false,
  redirect_on_failure: true,
  base_url: "https://cache.domain.tld"

db_port =
  case System.get_env("DB_PORT") do
    nil -> 5432
    val -> String.to_integer(val)
  end

config :pleroma, Pleroma.Repo,
  adapter: Ecto.Adapters.Postgres,
  username: System.get_env("DB_USER", "pleroma"),
  password: System.fetch_env!("DB_PASS"),
  database: System.get_env("DB_NAME", "pleroma"),
  hostname: System.get_env("DB_HOST", "pleroma-db"),
  port: db_port,
  pool_size: 10

# Configure web push notifications
config :web_push_encryption, :vapid_details, subject: "mailto:#{System.get_env("NOTIFY_EMAIL")}"

config :pleroma, :database, rum_enabled: false
config :pleroma, :instance, static_dir: "/data/static"
config :pleroma, Pleroma.Uploaders.Local, uploads: "/data/uploads"

# We can't store the secrets in this file, since this is baked into the docker image
if not File.exists?("/data/secret.exs") do
  secret = :crypto.strong_rand_bytes(64) |> Base.encode64() |> binary_part(0, 64)
  signing_salt = :crypto.strong_rand_bytes(8) |> Base.encode64() |> binary_part(0, 8)
  {web_push_public_key, web_push_private_key} = :crypto.generate_key(:ecdh, :prime256v1)

  secret_file =
    EEx.eval_string(
      """
      import Config
      config :pleroma, Pleroma.Web.Endpoint,
        secret_key_base: "<%= secret %>",
        signing_salt: "<%= signing_salt %>"
      config :web_push_encryption, :vapid_details,
        public_key: "<%= web_push_public_key %>",
        private_key: "<%= web_push_private_key %>"
      """,
      secret: secret,
      signing_salt: signing_salt,
      web_push_public_key: Base.url_encode64(web_push_public_key, padding: false),
      web_push_private_key: Base.url_encode64(web_push_private_key, padding: false)
    )

  File.write("/data/secret.exs", secret_file)
end

import_config("/data/secret.exs")

# For additional user config
if File.exists?("/data/config.exs"),
  do: import_config("/data/config.exs"),
  else:
    File.write("/data/config.exs", """
    import Config
    # For additional configuration outside of environmental variables
    """)
