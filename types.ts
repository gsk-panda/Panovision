
export interface TrafficLog {
  id: string;
  receive_time: string;
  serial: string;
  device_name: string;
  type: 'TRAFFIC';
  subtype: 'start' | 'end' | 'drop' | 'deny';
  src_ip: string;
  dst_ip: string;
  src_port: number;
  dst_port: number;
  protocol: string;
  ip_protocol: string; // Added field
  app: string;
  action: 'allow' | 'deny' | 'drop' | 'reset-server' | 'reset-client';
  rule: string;
  session_id: string;
  session_end_reason: string; // Added field
  bytes: number;
  packets: number;
  packets_sent: number;
  packets_received: number;
  src_zone: string;
  dst_zone: string;
  ingress_interface: string; // Added field
  egress_interface: string; // Added field
  duration: number;
}

export interface SearchParams {
  srcIp: string;
  dstIp: string;
  srcZone: string;
  dstZone: string;
  dstPort: string;
  action: string;
  timeRange: string;
  startTime: string;
  endTime: string;
  limit: number | string;
  // Negation flags
  isNotSrcIp?: boolean;
  isNotDstIp?: boolean;
  isNotDstPort?: boolean;
}

export interface ColumnDef {
  id: keyof TrafficLog;
  label: string;
  visible: boolean;
  width?: number;
  isMono?: boolean;
}

export interface LogStats {
  totalBytes: number;
  totalPackets: number;
  actionDistribution: { name: string; count: number }[];
}

export interface AuthUser {
  id: string;
  name: string;
  email: string;
}