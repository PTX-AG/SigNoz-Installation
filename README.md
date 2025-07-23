# SigNoz Installation Script

This repository contains a Bash script to automate the installation and setup of SigNoz, an open-source application performance monitoring and observability platform. The script installs and configures all necessary dependencies including ClickHouse, Zookeeper, and SigNoz itself on a Debian-based Linux system.

**Note:** The original SigNoz installation did not include ClickHouse setup. This script adds ClickHouse installation and configuration, providing a streamlined, one-click solution for deploying SigNoz and its dependencies.


---

## Features

- Updates system packages
- Installs ClickHouse server and client with secure password setup
- Installs and configures Apache Zookeeper as a service
- Configures ClickHouse to use Zookeeper for distributed setups
- Runs SigNoz database schema migrations
- Installs SigNoz binaries and configures it as a systemd service
- Provides verification instructions for installed services
- Cleans up temporary installation files

---

## Prerequisites

- A Debian-based Linux system (e.g., Ubuntu)
- `sudo` privileges
- Internet access to download packages and binaries

---

## Usage

You can run the installation script directly from your terminal using the following command:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/PTX-AG/SigNoz-Installation/refs/heads/main/signoz-install.sh)"
```

This command downloads and executes the script in one step.

---

## Default Credentials and Access

- SigNoz UI will be accessible at: `http://localhost:3301` (or your server IP on port 3301)
- Default login credentials:
  - Email: `admin@signoz.io`
  - Password: `SigNozPassword`

**Important:** For production environments, it is highly recommended to change the default ClickHouse password and SigNoz JWT secret for security.

---

## License

MIT License

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

---

## Disclaimer

This installation script is provided as-is. The author(s) and contributors are not responsible for any damages, data loss, or other issues that may arise from using this script. Use it at your own risk. Always review scripts before running them on your system.

---

## Verification

After running the script, verify that the services are running correctly:

```bash
sudo systemctl status clickhouse-server.service
sudo systemctl status zookeeper.service
sudo systemctl status signoz.service
```

---

## Contact and Documentation

For more information about SigNoz, visit the official documentation: [https://signoz.io/docs](https://signoz.io/docs)

---
