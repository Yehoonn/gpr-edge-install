server:
  host: "0.0.0.0"
  port: {{GPR_API_PORT}}

robot:
  enabled: true
  base_url: "http://{{ROBOT_IP}}:{{ROBOT_API_PORT}}"
  status_endpoint: "/api/gpr/status"
  timeout_seconds: 60
  retry_count: 3
  retry_delay_seconds: 1.0

gpr:
  driver: "serial"
  serial:
    port: "{{SERIAL_PORT}}"
    baudrate: 115200
  sample_interval_seconds: 0.5

storage:
  data_dir: "/var/lib/gpr-edge/data"
  archive_after_transfer: true

logging:
  dir: "/var/lib/gpr-edge/log"
  level: "INFO"
  console_enabled: true
  file_enabled: true
  max_bytes: 10485760
  backup_count: 5
