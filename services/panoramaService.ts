import { TrafficLog, SearchParams } from '../types';

// In a real scenario, these would come from the backend or environment variables
const PROXY_PANORAMA = '/api/panorama';
const MOCK_DELAY = 800;

// Helper to format date as yyyy-mm-dd hh:mm:ss
const formatDate = (date: Date): string => {
  const pad = (n: number) => n.toString().padStart(2, '0');
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())} ${pad(date.getHours())}:${pad(date.getMinutes())}:${pad(date.getSeconds())}`;
};

// Helper to generate mock data if the backend is unreachable (for UI demonstration)
const generateMockLogs = (count: number): TrafficLog[] => {
  const actions = ['allow', 'deny', 'drop', 'reset-server'];
  const apps = ['ssl', 'web-browsing', 'dns', 'ssh', 'office365', 'unknown-tcp'];
  const zones = ['Trust', 'Untrust', 'DMZ', 'Guest'];
  const interfaces = ['ethernet1/1', 'ethernet1/2', 'ethernet1/3', 'tunnel.1', 'vlan.10'];
  const endReasons = ['tcp-fin', 'aged-out', 'tcp-rst-from-client', 'tcp-rst-from-server', 'policy-deny'];
  
  return Array.from({ length: count }).map(() => {
    const isAllow = Math.random() > 0.3;
    const action = isAllow ? 'allow' : actions[Math.floor(Math.random() * (actions.length - 1)) + 1] as any;
    const protocol = 'tcp';
    
    // Determine end reason based on action
    let endReason = 'tcp-fin';
    if (action === 'deny' || action === 'drop') endReason = 'policy-deny';
    else if (action === 'reset-server') endReason = 'tcp-rst-from-server';
    else endReason = endReasons[Math.floor(Math.random() * endReasons.length)];

    return {
      id: crypto.randomUUID(),
      receive_time: formatDate(new Date(Date.now() - Math.floor(Math.random() * 10000000))),
      serial: '001801000' + Math.floor(Math.random() * 999),
      device_name: 'PA-5220-Headquarters',
      type: 'TRAFFIC',
      subtype: 'end',
      src_ip: `10.10.${Math.floor(Math.random() * 255)}.${Math.floor(Math.random() * 255)}`,
      dst_ip: `172.16.${Math.floor(Math.random() * 255)}.${Math.floor(Math.random() * 255)}`,
      src_port: Math.floor(Math.random() * 60000) + 1024,
      dst_port: [80, 443, 53, 22, 8080][Math.floor(Math.random() * 5)],
      protocol: protocol,
      ip_protocol: protocol,
      app: apps[Math.floor(Math.random() * apps.length)],
      action,
      rule: isAllow ? 'Allow-Internet' : 'Default-Deny',
      session_id: Math.floor(Math.random() * 100000).toString(),
      session_end_reason: endReason,
      bytes: Math.floor(Math.random() * 50000),
      packets: Math.floor(Math.random() * 1000),
      packets_sent: Math.floor(Math.random() * 500),
      packets_received: Math.floor(Math.random() * 500),
      src_zone: zones[Math.floor(Math.random() * zones.length)],
      dst_zone: 'Untrust',
      ingress_interface: interfaces[Math.floor(Math.random() * interfaces.length)],
      egress_interface: interfaces[Math.floor(Math.random() * interfaces.length)],
      duration: Math.floor(Math.random() * 60),
    };
  });
};

const buildPaloAltoQuery = (params: SearchParams): string => {
  const parts: string[] = [];
  
  // Enforce showing only logs with subtype 'end'
  parts.push(`(subtype eq 'end')`);

  if (params.srcIp) {
      const op = params.isNotSrcIp ? 'neq' : 'eq';
      parts.push(`(addr.src ${op} '${params.srcIp}')`);
  }
  if (params.dstIp) {
      const op = params.isNotDstIp ? 'neq' : 'eq';
      parts.push(`(addr.dst ${op} '${params.dstIp}')`);
  }
  if (params.srcZone) parts.push(`(zone.src eq '${params.srcZone}')`);
  if (params.dstZone) parts.push(`(zone.dst eq '${params.dstZone}')`);
  if (params.dstPort) {
      const op = params.isNotDstPort ? 'neq' : 'eq';
      parts.push(`(port.dst ${op} ${params.dstPort})`);
  }
  if (params.action && params.action !== 'all') {
    if (params.action === 'deny_drop') parts.push(`(action neq 'allow')`);
    else parts.push(`(action eq '${params.action}')`);
  }
  if (params.timeRange && params.timeRange !== 'custom') {
    parts.push(`(receive_time in ${params.timeRange})`);
  }
  return parts.length > 0 ? parts.join(' and ') : '';
};

const parsePaloAltoXML = (xmlString: string): TrafficLog[] => {
  const parser = new DOMParser();
  const xmlDoc = parser.parseFromString(xmlString, "text/xml");
  const entries = xmlDoc.getElementsByTagName("entry");
  const logs: TrafficLog[] = [];
  
  for (let i = 0; i < entries.length; i++) {
    const entry = entries[i];
    const getVal = (tag: string) => entry.getElementsByTagName(tag)[0]?.textContent || '';
    if (!entry.getElementsByTagName('receive_time').length) continue;
    
    const rawTime = getVal('receive_time');
    // Normalize time to yyyy-mm-dd hh:mm:ss
    // Typical Raw: 2023/10/25 14:30:00 or 2023-10-25T14:30:00
    const formattedTime = rawTime.replace(/\//g, '-').replace('T', ' ');

    try {
      logs.push({
        id: crypto.randomUUID(),
        receive_time: formattedTime,
        serial: getVal('serial'),
        device_name: getVal('device_name') || 'Panorama', 
        type: 'TRAFFIC',
        subtype: (getVal('subtype') as any) || 'end',
        src_ip: getVal('src'),
        dst_ip: getVal('dst'),
        src_port: parseInt(getVal('sport')) || 0,
        dst_port: parseInt(getVal('dport')) || 0,
        protocol: getVal('proto'),
        ip_protocol: getVal('proto'),
        app: getVal('app'),
        action: (getVal('action') as any) || 'allow',
        rule: getVal('rule'),
        session_id: getVal('sessionid'),
        session_end_reason: getVal('session_end_reason') || 'unknown',
        bytes: parseInt(getVal('bytes')) || 0,
        packets: parseInt(getVal('packets')) || 0,
        packets_sent: parseInt(getVal('pkts_sent')) || 0,
        packets_received: parseInt(getVal('pkts_received')) || 0,
        src_zone: getVal('from'),
        dst_zone: getVal('to'),
        ingress_interface: getVal('ingress_interface'),
        egress_interface: getVal('egress_interface'),
        duration: parseInt(getVal('elapsed')) || 0,
      });
    } catch (e) {
      console.warn('Failed to parse log entry', e);
    }
  }
  return logs;
};

// Poll for job completion if Panorama returns a job ID (async query)
const pollJob = async (proxyUrl: string, apiKey: string, jobId: string): Promise<TrafficLog[]> => {
  const pollUrl = `${proxyUrl}/?type=log&action=get&job-id=${jobId}&key=${encodeURIComponent(apiKey)}`;
  for (let i = 0; i < 40; i++) {
    await new Promise(r => setTimeout(r, 1000));
    try {
      const resp = await fetch(pollUrl);
      const text = await resp.text();
      if (text.includes('<status>FIN</status>')) return parsePaloAltoXML(text);
      if (text.includes('status="error"')) throw new Error(`Async Job Failed: ${text}`);
    } catch (e) { 
      // Continue polling on transient errors
    }
  }
  throw new Error(`Timeout polling job ${jobId}`);
};

export const fetchLogs = async (params: SearchParams): Promise<TrafficLog[]> => {
  const query = buildPaloAltoQuery(params);
  
  // Safe parsing of limit which can be string or number
  const val = Number(params.limit);
  const limitVal = isNaN(val) ? 50 : val;
  const limit = limitVal ? Math.min(limitVal * 2, 5000) : 100; 
  
  try {
    // Attempt to hit the backend
    // NOTE: In the preview environment, this fetch will likely fail (404/Network Error).
    // We catch this and return MOCK data to demonstrate the UI capabilities.
    
    // Check if we are in a production environment with the API key
    // For this demo code, we assume if fetch fails, use mock.
    
    // Intentionally mocking for this specific demonstration code since the backend server isn't running
    await new Promise(resolve => setTimeout(resolve, MOCK_DELAY));
    return generateMockLogs(limitVal || 50);

  } catch (error: any) {
    console.error("Panorama API Error, falling back to mock:", error);
    // Fallback for demo purposes
    return generateMockLogs(limitVal || 50);
  }
};