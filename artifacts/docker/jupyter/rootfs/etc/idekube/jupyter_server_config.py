# Jupyter Server Configuration
c.ServerApp.ip = '0.0.0.0'
c.ServerApp.port = 8888
c.ServerApp.open_browser = False
c.ServerApp.allow_root = True
c.ServerApp.token = ''
c.ServerApp.password = ''
c.ServerApp.base_url = '/jupyter'
c.ServerApp.allow_origin = '*'
c.ServerApp.disable_check_xsrf = True

# Allow embedding in iframe
c.ServerApp.tornado_settings = {
    "headers": {
        "Content-Security-Policy": "frame-ancestors 'self' *",
        "X-Frame-Options": "ALLOWALL"
    }
}
