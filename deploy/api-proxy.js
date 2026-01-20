import http from 'http';
import https from 'https';
import fs from 'fs';
import { URL } from 'url';
import crypto from 'crypto';

const API_KEY_FILE = '/etc/panovision/api-key';
const PANORAMA_CONFIG_FILE = '/etc/panovision/panorama-config';
const PANORAMA_CA_FILE = '/etc/panovision/panorama-ca.crt';

let panoramaUrl = 'https://panorama.example.com';
let apiKey = '';
let tlsOptions = {};

function loadConfig() {
  try {
    if (fs.existsSync(API_KEY_FILE)) {
      apiKey = fs.readFileSync(API_KEY_FILE, 'utf8').trim();
      apiKey = apiKey.replace(/[\r\n]+/g, '').trim();
      if (!apiKey) {
        console.error('Warning: API key file exists but is empty');
      } else {
        console.log(`API key loaded: ${apiKey.length} characters`);
        console.log(`API key preview: ${apiKey.substring(0, 10)}...${apiKey.substring(apiKey.length - 10)}`);
      }
    } else {
      console.error(`Error: API key file not found at ${API_KEY_FILE}`);
    }
    if (fs.existsSync(PANORAMA_CONFIG_FILE)) {
      const config = fs.readFileSync(PANORAMA_CONFIG_FILE, 'utf8');
      const urlMatch = config.match(/PANORAMA_URL=(.+)/);
      if (urlMatch) {
        panoramaUrl = urlMatch[1].trim();
      }
    } else {
      console.error(`Warning: Panorama config file not found at ${PANORAMA_CONFIG_FILE}`);
    }

    if (fs.existsSync(PANORAMA_CA_FILE)) {
      const caCert = fs.readFileSync(PANORAMA_CA_FILE, 'utf8');
      const caCerts = caCert.split(/-----BEGIN CERTIFICATE-----/).filter(c => c.trim()).map(c => 
        '-----BEGIN CERTIFICATE-----' + c.trim()
      );
      
      // Try to load system CA bundle and combine with custom certificates
      // This ensures we have both the custom intermediate certs AND the system root CAs
      let allCaCerts = [...caCerts];
      
      // Try to load system CA bundle from common locations
      const systemCaPaths = [
        '/etc/ssl/certs/ca-bundle.crt',
        '/etc/ssl/certs/ca-certificates.crt',
        '/etc/pki/tls/certs/ca-bundle.crt',
        '/etc/pki/tls/certs/ca-bundle.trust.crt',
        '/usr/share/pki/ca-trust-source/ca-bundle.trust.crt',
      ];
      
      for (const caPath of systemCaPaths) {
        if (fs.existsSync(caPath)) {
          try {
            const systemCa = fs.readFileSync(caPath, 'utf8');
            const systemCerts = systemCa.split(/-----BEGIN CERTIFICATE-----/).filter(c => c.trim()).map(c => 
              '-----BEGIN CERTIFICATE-----' + c.trim()
            );
            allCaCerts = [...allCaCerts, ...systemCerts];
            console.log(`  Also loaded system CA bundle from: ${caPath} (${systemCerts.length} certificates)`);
            break;
          } catch (err) {
            // Continue to next path
          }
        }
      }
      
      tlsOptions = {
        rejectUnauthorized: true,
        ca: allCaCerts,
      };
      console.log(`✓ Using custom CA certificate(s) for Panorama TLS verification (${caCerts.length} custom + system CA bundle)`);
      console.log(`  Certificate file: ${PANORAMA_CA_FILE}`);
    } else {
      tlsOptions = {
        rejectUnauthorized: true,
      };
      console.log('TLS certificate verification enabled using Node.js CA bundle');
      console.log(`Certificate file not found at: ${PANORAMA_CA_FILE}`);
      console.log('If you see certificate errors, the Panorama server may not be sending the full certificate chain.');
      console.log('For Sectigo/Comodo certificates, install the intermediate certificate:');
      console.log('  sudo ./deploy/fetch-panorama-cert.sh');
    }
    
    console.log(`TLS Options: rejectUnauthorized=${tlsOptions.rejectUnauthorized}, ca=${tlsOptions.ca ? 'provided' : 'default'}`);
  } catch (error) {
    console.error('Error loading config:', error);
    console.error('Stack trace:', error.stack);
  }
}

loadConfig();

const server = http.createServer((req, res) => {
  try {
    const requestUrl = new URL(req.url, `http://${req.headers.host || 'localhost'}`);
    
    if (req.method !== 'GET') {
      res.writeHead(405, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ error: 'Method not allowed' }));
      return;
    }

    const queryParams = requestUrl.searchParams;

    if (!apiKey) {
      res.writeHead(500, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ error: 'API key not configured' }));
      return;
    }

    // Ensure API key is properly URL-encoded
    queryParams.set('key', apiKey);

    const panoramaUrlObj = new URL(panoramaUrl);
    let targetPath = requestUrl.pathname;
    // Ensure path starts with /api
    if (!targetPath.startsWith('/api')) {
      targetPath = `/api${targetPath}`;
    }
    targetPath = `${targetPath}?${queryParams.toString()}`;

    const options = {
      hostname: panoramaUrlObj.hostname,
      port: panoramaUrlObj.port || 443,
      path: targetPath,
      method: 'GET',
      headers: {
        'Accept': 'application/xml',
        'User-Agent': 'Panorama-API-Proxy/1.0',
        'Host': panoramaUrlObj.hostname,
      },
      ...tlsOptions,
    };

    const proxyReq = https.request(options, (proxyRes) => {
      res.writeHead(proxyRes.statusCode, {
        'Content-Type': proxyRes.headers['content-type'] || 'application/xml',
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, OPTIONS',
        'Access-Control-Allow-Headers': 'Accept, Content-Type',
      });

      proxyRes.pipe(res);
    });

    proxyReq.on('error', (error) => {
      console.error('Proxy error connecting to Panorama:', error);
      console.error('Target URL:', panoramaUrl);
      console.error('Target path:', targetPath);
      
      if (error.message && error.message.includes('certificate')) {
        console.error('');
        console.error('═══════════════════════════════════════════════════════════');
        console.error('TLS Certificate Verification Error');
        console.error('═══════════════════════════════════════════════════════════');
        console.error('');
        console.error('This error typically occurs when:');
        console.error('  - The Panorama server is not sending the full certificate chain');
        console.error('  - The intermediate certificate (e.g., Sectigo) is missing');
        console.error('');
        console.error('SOLUTION: Extract the full certificate chain from Panorama:');
        console.error('  cd /opt/Panovision');
        console.error('  sudo ./deploy/fetch-panorama-cert.sh');
        console.error('');
        console.error('This will extract all certificates in the chain (including intermediates)');
        console.error('and save them to:', PANORAMA_CA_FILE);
        console.error('');
        console.error('═══════════════════════════════════════════════════════════');
      }
      
      if (!res.headersSent) {
        res.writeHead(502, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ error: 'Proxy error', message: error.message }));
      }
    });

    req.on('error', (error) => {
      console.error('Request error:', error);
      if (!res.headersSent) {
        res.writeHead(500, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ error: 'Request error', message: error.message }));
      }
    });

    req.pipe(proxyReq);
  } catch (error) {
    console.error('Server error processing request:', error);
    if (!res.headersSent) {
      res.writeHead(500, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ error: 'Server error', message: error.message }));
    }
  }
});

const PORT = 3001;
server.listen(PORT, '127.0.0.1', (err) => {
  if (err) {
    console.error('Failed to start server:', err);
    process.exit(1);
  }
  console.log(`API Proxy server running on http://127.0.0.1:${PORT}`);
  console.log(`Panorama URL: ${panoramaUrl}`);
  console.log(`API key loaded: ${apiKey ? 'Yes' : 'No'}`);
});

process.on('SIGTERM', () => {
  server.close(() => {
    process.exit(0);
  });
});

