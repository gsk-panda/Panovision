import http from 'http';
import https from 'https';
import fs from 'fs';
import { URL } from 'url';
import crypto from 'crypto';

const API_KEY_FILE = '/etc/panovision/api-key';
const PANORAMA_CONFIG_FILE = '/etc/panovision/panorama-config';

let panoramaUrl = 'https://panorama.example.com';
let apiKey = '';

function loadConfig() {
  try {
    if (fs.existsSync(API_KEY_FILE)) {
      apiKey = fs.readFileSync(API_KEY_FILE, 'utf8').trim();
      // Remove any trailing newlines, carriage returns, or other whitespace
      apiKey = apiKey.replace(/[\r\n]+/g, '').trim();
      if (!apiKey) {
        console.error('Warning: API key file exists but is empty');
      } else {
        console.log(`API key loaded: ${apiKey.length} characters`);
        // Log first and last few characters for debugging (without exposing full key)
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
  } catch (error) {
    console.error('Error loading config:', error);
    console.error('Stack trace:', error.stack);
    // Don't exit immediately - let systemd handle restart
    // process.exit(1);
  }
}

loadConfig();

const server = http.createServer((req, res) => {
  try {
    if (req.method !== 'GET') {
      res.writeHead(405, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ error: 'Method not allowed' }));
      return;
    }

    const requestUrl = new URL(req.url, `http://${req.headers.host || 'localhost'}`);
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
      rejectUnauthorized: false,
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

