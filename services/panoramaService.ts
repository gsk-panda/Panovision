import { TrafficLog, SearchParams } from '../types';

const PANORAMA_SERVER = 'https://panorama.officeours.com';
const PANORAMA_API_KEY = 'LUFRPT0xQ0JKa2YrR1hFcVdra1pjL2Q2V2w0eXo0bmc9dzczNHg3T0VsRS9yYmFMcEpWdXBWdnF3cEQ2OTduSU9yRTlqQmJEbyt1bDY0NlR1VUhrNlkybGRRTHJ0Y2ZIdw==';

export interface ApiError {
  message: string;
  statusCode?: number;
  statusText?: string;
  responseBody?: string;
  url?: string;
  timestamp: string;
}

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

const pollJob = async (serverUrl: string, apiKey: string, jobId: string): Promise<TrafficLog[]> => {
  const pollUrl = `${serverUrl}/api/?type=log&action=get&job-id=${jobId}&key=${encodeURIComponent(apiKey)}`;
  
  for (let i = 0; i < 40; i++) {
    await new Promise(r => setTimeout(r, 1000));
    try {
      const resp = await fetch(pollUrl);
      if (!resp.ok) {
        const error: ApiError = {
          message: `Job polling failed: ${resp.status} ${resp.statusText}`,
          statusCode: resp.status,
          statusText: resp.statusText,
          url: pollUrl.replace(apiKey, '***REDACTED***'),
          timestamp: new Date().toISOString(),
        };
        throw error;
      }
      
      const text = await resp.text();
      
      if (text.includes('<status>FIN</status>')) {
        return parsePaloAltoXML(text);
      }
      
      if (text.includes('status="error"') || text.includes('<msg>')) {
        const parser = new DOMParser();
        const xmlDoc = parser.parseFromString(text, 'text/xml');
        const errorMsg = xmlDoc.getElementsByTagName('msg')[0]?.textContent || 'Unknown job error';
        const error: ApiError = {
          message: `Job failed: ${errorMsg}`,
          responseBody: text,
          url: pollUrl.replace(apiKey, '***REDACTED***'),
          timestamp: new Date().toISOString(),
        };
        throw error;
      }
    } catch (e: any) {
      if (e.statusCode || e.message?.includes('Job')) {
        throw e;
      }
    }
  }
  
  const timeoutError: ApiError = {
    message: `Timeout polling job ${jobId} after 40 seconds`,
    url: pollUrl.replace(apiKey, '***REDACTED***'),
    timestamp: new Date().toISOString(),
  };
  throw timeoutError;
};

const buildTimeRange = (params: SearchParams): string => {
  if (params.timeRange === 'custom' && params.startTime && params.endTime) {
    const start = new Date(params.startTime).toISOString().replace(/[-:]/g, '').split('.')[0];
    const end = new Date(params.endTime).toISOString().replace(/[-:]/g, '').split('.')[0];
    return `${start}-${end}`;
  }
  
  const timeRanges: Record<string, string> = {
    'last-15-minutes': 'last-15-minutes',
    'last-60-minutes': 'last-60-minutes',
    'last-6-hrs': 'last-6-hours',
    'last-24-hrs': 'last-24-hours',
  };
  
  return timeRanges[params.timeRange] || 'last-15-minutes';
};

export const fetchLogs = async (params: SearchParams): Promise<TrafficLog[]> => {
  const query = buildPaloAltoQuery(params);
  const val = Number(params.limit);
  const limitVal = isNaN(val) ? 50 : val;
  const limit = Math.min(limitVal, 5000);
  const timeRange = buildTimeRange(params);
  
  const urlParams: string[] = [
    `type=log`,
    `log-type=traffic`,
    `key=${encodeURIComponent(PANORAMA_API_KEY)}`,
    `nlogs=${limit}`,
  ];
  
  if (query) {
    urlParams.push(`query=${encodeURIComponent(query)}`);
  }
  
  if (timeRange) {
    urlParams.push(`time-range=${encodeURIComponent(timeRange)}`);
  }
  
  const url = `${PANORAMA_SERVER}/api/?${urlParams.join('&')}`;
  
  try {
    const response = await fetch(url, {
      method: 'GET',
      headers: {
        'Accept': 'application/xml',
      },
    });
    
    if (!response.ok) {
      const responseText = await response.text();
      const error: ApiError = {
        message: `Panorama API request failed: ${response.status} ${response.statusText}`,
        statusCode: response.status,
        statusText: response.statusText,
        responseBody: responseText,
        url: url.replace(PANORAMA_API_KEY, '***REDACTED***'),
        timestamp: new Date().toISOString(),
      };
      throw error;
    }
    
    const xmlText = await response.text();
    
    if (xmlText.includes('<job>')) {
      const parser = new DOMParser();
      const xmlDoc = parser.parseFromString(xmlText, 'text/xml');
      const jobId = xmlDoc.getElementsByTagName('job')[0]?.textContent;
      if (jobId) {
        return await pollJob(PANORAMA_SERVER, PANORAMA_API_KEY, jobId);
      }
    }
    
    if (xmlText.includes('status="error"') || xmlText.includes('<msg>')) {
      const parser = new DOMParser();
      const xmlDoc = parser.parseFromString(xmlText, 'text/xml');
      const errorMsg = xmlDoc.getElementsByTagName('msg')[0]?.textContent || 'Unknown API error';
      const error: ApiError = {
        message: `Panorama API error: ${errorMsg}`,
        statusCode: response.status,
        responseBody: xmlText,
        url: url.replace(PANORAMA_API_KEY, '***REDACTED***'),
        timestamp: new Date().toISOString(),
      };
      throw error;
    }
    
    return parsePaloAltoXML(xmlText);
    
  } catch (error: any) {
    if (error.statusCode || error.message?.includes('Panorama')) {
      throw error;
    }
    
    const apiError: ApiError = {
      message: error.message || 'Network error connecting to Panorama',
      responseBody: error.toString(),
      url: url.replace(PANORAMA_API_KEY, '***REDACTED***'),
      timestamp: new Date().toISOString(),
    };
    throw apiError;
  }
};