# PanoVision

A modern web application for searching and analyzing Palo Alto Networks Panorama traffic logs. PanoVision provides an intuitive interface for querying firewall logs with advanced filtering, column customization, and real-time statistics.

## Features

- **Advanced Log Search**: Query Panorama traffic logs with flexible filtering options
- **Column Customization**: Show/hide and reorder table columns to match your workflow
- **Real-time Statistics**: View total data, packets, and action distribution
- **OIDC Authentication**: Optional Azure AD/Entra ID integration for secure access
- **Responsive Design**: Modern UI built with React and Tailwind CSS
- **API Proxy**: Secure backend proxy for Panorama API communication

## Technology Stack

- **Frontend**: React 18, TypeScript, Vite, Tailwind CSS
- **Backend**: Node.js API proxy service
- **Web Server**: Apache HTTP Server with SSL/TLS
- **Authentication**: Azure MSAL (Microsoft Authentication Library)
- **Charts**: Recharts

## Prerequisites

- **Server**: RHEL 9.7 or compatible Linux distribution
- **Node.js**: 18+ (installed automatically by installation script)
- **Apache**: HTTP Server with mod_ssl (installed automatically)
- **Panorama Access**: Valid Panorama API key and network connectivity
- **DNS**: Domain name configured (optional, can use IP address)

## Quick Start

### Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/gsk-panda/Panovision.git
   cd Panovision
   ```

2. **Run the installation script:**
   ```bash
   sudo chmod +x deploy/install.sh
   sudo ./deploy/install.sh
   ```

3. **Follow the prompts:**
   - Enter your server URL or IP address
   - Enter your Panorama server URL
   - Enter your Panorama API key
   - Choose Node.js installation method (JFrog or NodeSource)
   - Configure OIDC authentication (optional)

4. **Access the application:**
   ```
   https://your-server-url/logs
   ```

For detailed installation instructions, see [INSTALLATION_GUIDE.md](INSTALLATION_GUIDE.md).

## Project Structure

```
Panovision/
├── components/          # React components
│   ├── ApiUrlModal.tsx
│   ├── ColumnCustomizer.tsx
│   ├── ErrorDiagnosisModal.tsx
│   ├── LogDetailModal.tsx
│   ├── LoginPage.tsx
│   ├── Logo.tsx
│   ├── SearchHeader.tsx
│   └── StatsWidget.tsx
├── services/           # Service layer
│   ├── authConfig.ts   # OIDC configuration
│   ├── authService.ts  # Authentication service
│   └── panoramaService.ts  # Panorama API client
├── deploy/             # Deployment scripts and configs
│   ├── install.sh     # Main installation script
│   ├── apache-panovision.conf  # Apache configuration
│   ├── api-proxy.js   # API proxy service
│   └── api-proxy.service  # Systemd service file
├── App.tsx             # Main application component
├── types.ts            # TypeScript type definitions
└── package.json        # Node.js dependencies
```

## Configuration

### Panorama API

The Panorama API key and URL are configured during installation and stored securely:
- API Key: `/etc/panovision/api-key` (640 permissions, root:panovision)
- Configuration: `/etc/panovision/panorama-config`

### OIDC Authentication

OIDC authentication is configured during installation. To set up Azure AD:

1. Create an App Registration in Azure Portal
2. Configure redirect URI: `https://your-server-url`
3. Provide Client ID and Authority during installation

For detailed OIDC setup, see [AZURE_OIDC_SETUP.md](AZURE_OIDC_SETUP.md).

### SSL Certificates

The installation script creates a self-signed certificate by default. For production:

1. **Generate a CSR:**
   ```bash
   sudo ./deploy/generate-apache-csr.sh
   ```

2. **Install your certificate:**
   ```bash
   sudo ./deploy/install-apache-ssl-cert.sh
   ```

See [deploy/APACHE_SSL_CSR.md](deploy/APACHE_SSL_CSR.md) and [deploy/APACHE_SSL_INSTALL.md](deploy/APACHE_SSL_INSTALL.md) for details.

## Development

### Local Development

1. **Install dependencies:**
   ```bash
   npm install
   ```

2. **Create environment file:**
   ```bash
   cp .env.example .env
   # Edit .env with your configuration
   ```

3. **Run development server:**
   ```bash
   npm run dev
   ```

4. **Build for production:**
   ```bash
   export NODE_OPTIONS="--openssl-legacy-provider"
   npm run build
   ```

### Environment Variables

- `VITE_PANORAMA_SERVER`: Panorama server URL
- `VITE_OIDC_ENABLED`: Enable/disable OIDC (true/false)
- `VITE_AZURE_CLIENT_ID`: Azure AD Client ID
- `VITE_AZURE_AUTHORITY`: Azure AD Authority URL
- `VITE_AZURE_REDIRECT_URI`: OIDC redirect URI

## Deployment

### Updating the Application

After making changes:

```bash
cd /opt/Panovision
git pull
npm install
export NODE_OPTIONS="--openssl-legacy-provider"
npm run build
rsync -av --delete dist/ /var/www/panovision/
sudo systemctl reload httpd
```

### Service Management

```bash
# Check Apache status
sudo systemctl status httpd

# Check API proxy status
sudo systemctl status api-proxy

# View logs
sudo tail -f /var/log/httpd/panovision-error.log
sudo journalctl -u api-proxy -f
```

## Troubleshooting

### Common Issues

**Application not loading:**
- Check Apache status: `systemctl status httpd`
- Check error logs: `tail -f /var/log/httpd/panovision-error.log`
- Verify files deployed: `ls -la /var/www/panovision/`

**API proxy not working:**
- Check service status: `systemctl status api-proxy`
- View logs: `journalctl -u api-proxy -n 50`
- Verify Panorama certificate: `ls -la /etc/panovision/panorama-ca.crt`

**SSL certificate errors:**
- For Panorama: Run `sudo ./deploy/fetch-panorama-cert.sh`
- For web server: Install proper SSL certificate (see SSL documentation)

**Port conflicts:**
- Check what's using ports 80/443: `ss -tlnp | grep -E ':80|:443'`
- Stop conflicting services before installation

For more troubleshooting help, see [deploy/README.md](deploy/README.md).

## Security Considerations

1. **SSL/TLS**: Always use HTTPS in production
2. **API Key**: Stored securely with restricted permissions
3. **Firewall**: Only ports 80 and 443 should be publicly accessible
4. **OIDC**: Use tenant-specific authority for better security
5. **Updates**: Keep system and dependencies updated

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## License

[Add your license information here]

## Support

For issues or questions:
- Check the [deployment documentation](deploy/README.md)
- Review [installation guide](INSTALLATION_GUIDE.md)
- Check service logs for error messages

## Related Projects

- [PaloChangeLogs](https://github.com/gsk-panda/PaloChangeLogs) - Change database application
