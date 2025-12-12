const http = require('http');
const https = require('https');
const fs = require('fs');
const { URL } = require('url');
const crypto = require('crypto');

const API_KEY_FILE = '/etc/panovision/api-key';
const PANORAMA_CONFIG_FILE = '/etc/panovision/panorama-config';

let panoramaUrl = 'https://panorama.example.com';
let apiKey = '';

function loadConfig() {
  try {
    if (fs.existsSync(API_KEY_FILE)) {
      apiKey = fs.readFileSync(API_KEY_FILE, 'utf8').trim();
    }
    if (fs.existsSync(PANORAMA_CONFIG_FILE)) {
      const config = fs.readFileSync(PANORAMA_CONFIG_FILE, 'utf8');
      const urlMatch = config.match(/PANORAMA_URL=(.+)/);
      if (urlMatch) {
        panoramaUrl = urlMatch[1].trim();
      }
    }
  } catch (error) {
    console.error('Error loading config:', error);
  }
}

loadConfig();

const server = http.createServer((req, res) => {
  if (req.method !== 'GET') {
    res.writeHead(405, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ error: 'Method not allowed' }));
    return;
  }

  const requestUrl = new URL(req.url, `http://${req.headers.host}`);
  const queryParams = requestUrl.searchParams;

  if (!apiKey) {
    res.writeHead(500, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ error: 'API key not configured' }));
    return;
  }

  queryParams.set('key', apiKey);

  const panoramaUrlObj = new URL(panoramaUrl);
  let targetPath = requestUrl.pathname;
  if (targetPath.startsWith('/api/panorama')) {
    targetPath = targetPath.replace('/api/panorama', '/api');
  } else if (!targetPath.startsWith('/api')) {
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
    console.error('Proxy error:', error);
    res.writeHead(502, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ error: 'Proxy error', message: error.message }));
  });

  req.pipe(proxyReq);
});

const PORT = 3001;
server.listen(PORT, '127.0.0.1', () => {
  console.log(`API Proxy server running on http://127.0.0.1:${PORT}`);
});

process.on('SIGTERM', () => {
  server.close(() => {
    process.exit(0);
  });
});

