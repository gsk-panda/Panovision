import React from 'react';
import { TrafficLog } from '../types';
import { X, Shield, Clock, Monitor, Network, FileText, Hash, Server, Activity } from 'lucide-react';

interface Props {
  log: TrafficLog;
  onClose: () => void;
}

const LogDetailModal: React.FC<Props> = ({ log, onClose }) => {
  // Helper to render a detail row
  const DetailRow = ({ label, value, icon: Icon, isMono = false, colorClass = "text-slate-300" }: any) => (
    <div className="flex flex-col space-y-1 p-3 rounded-lg bg-slate-950/50 border border-slate-800/50 hover:border-slate-700 transition-colors">
      <div className="flex items-center gap-2 text-xs font-medium text-slate-500 uppercase tracking-wider">
        {Icon && <Icon className="w-3 h-3 text-slate-600" />}
        {label}
      </div>
      <div className={`text-sm break-all ${isMono ? 'font-mono' : ''} ${colorClass}`}>
        {value}
      </div>
    </div>
  );

  return (
    <div className="fixed inset-0 bg-slate-950/80 backdrop-blur-sm flex items-center justify-center z-[60] p-4" onClick={(e) => e.target === e.currentTarget && onClose()}>
      <div className="bg-slate-900 border border-slate-700 rounded-xl shadow-2xl w-full max-w-4xl flex flex-col max-h-[90vh] animate-in fade-in zoom-in duration-200">
        
        {/* Header */}
        <div className="flex items-center justify-between p-5 border-b border-slate-800 bg-slate-900 rounded-t-xl">
          <div className="flex items-center gap-4">
             <div className="p-3 bg-brand-500/10 rounded-xl border border-brand-500/20">
                <FileText className="h-6 w-6 text-brand-400" />
             </div>
             <div>
                <h3 className="text-xl font-bold text-white tracking-tight">Log Details</h3>
                <div className="flex items-center gap-2 mt-1">
                    <span className="text-xs text-slate-500 font-mono bg-slate-800 px-2 py-0.5 rounded border border-slate-700">{log.id}</span>
                </div>
             </div>
          </div>
          <button onClick={onClose} className="p-2 text-slate-400 hover:text-white hover:bg-slate-800 rounded-lg transition-colors">
            <X className="h-6 w-6" />
          </button>
        </div>

        {/* Scrollable Content */}
        <div className="p-6 overflow-y-auto custom-scrollbar flex-1">
            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                
                {/* Section: General */}
                <div className="md:col-span-2">
                    <h4 className="text-sm font-semibold text-white mb-3 flex items-center gap-2">
                        <span className="w-1 h-4 bg-brand-500 rounded-full"></span>
                        General Information
                    </h4>
                    <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-3">
                        <DetailRow label="Time" value={log.receive_time} icon={Clock} />
                        <DetailRow label="Action" value={log.action} icon={Shield} 
                            colorClass={`font-bold uppercase text-xs px-2 py-1 rounded inline-block w-fit mt-1 ${
                                log.action === 'allow' ? 'bg-green-500/10 text-green-400 border border-green-500/20' : 
                                log.action.includes('deny') || log.action.includes('drop') ? 'bg-red-500/10 text-red-400 border border-red-500/20' : 'bg-amber-500/10 text-amber-400 border border-amber-500/20'
                            }`} 
                        />
                        <DetailRow label="End Reason" value={log.session_end_reason} />
                        <DetailRow label="Device" value={log.device_name} icon={Server} />
                        <DetailRow label="Serial" value={log.serial} isMono />
                    </div>
                </div>

                {/* Section: Source */}
                <div className="space-y-3">
                    <h4 className="text-sm font-semibold text-brand-400 mb-3 border-b border-slate-800 pb-2">Source</h4>
                    <div className="grid grid-cols-1 gap-3">
                        <DetailRow label="Source IP" value={log.src_ip} icon={Monitor} isMono />
                        <div className="grid grid-cols-2 gap-3">
                            <DetailRow label="Source Port" value={log.src_port} isMono />
                            <DetailRow label="Source Zone" value={log.src_zone} />
                        </div>
                         <DetailRow label="Ingress Interface" value={log.ingress_interface || 'N/A'} isMono />
                    </div>
                </div>

                 {/* Section: Destination */}
                <div className="space-y-3">
                    <h4 className="text-sm font-semibold text-blue-400 mb-3 border-b border-slate-800 pb-2">Destination</h4>
                    <div className="grid grid-cols-1 gap-3">
                        <DetailRow label="Dest IP" value={log.dst_ip} icon={Network} isMono />
                         <div className="grid grid-cols-2 gap-3">
                            <DetailRow label="Dest Port" value={log.dst_port} isMono />
                            <DetailRow label="Dest Zone" value={log.dst_zone} />
                        </div>
                        <DetailRow label="Egress Interface" value={log.egress_interface || 'N/A'} isMono />
                    </div>
                </div>

                 {/* Section: Details */}
                 <div className="md:col-span-2 pt-4 border-t border-slate-800">
                    <h4 className="text-sm font-semibold text-white mb-3 flex items-center gap-2">
                        <span className="w-1 h-4 bg-blue-500 rounded-full"></span>
                        Traffic Metadata
                    </h4>
                    <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
                        <DetailRow label="Application" value={log.app} />
                        <DetailRow label="IP Protocol" value={log.ip_protocol} icon={Activity} />
                        <DetailRow label="Rule" value={log.rule} />
                        <DetailRow label="Session ID" value={log.session_id} isMono />
                    </div>
                    <div className="grid grid-cols-2 md:grid-cols-4 gap-3 mt-3">
                         <DetailRow label="Bytes" value={log.bytes.toLocaleString()} icon={Hash} />
                         <DetailRow label="Packets" value={log.packets.toLocaleString()} icon={Hash} />
                         <DetailRow label="Pkts Sent" value={log.packets_sent.toLocaleString()} icon={Hash} />
                         <DetailRow label="Pkts Rcvd" value={log.packets_received.toLocaleString()} icon={Hash} />
                         <DetailRow label="Type" value={log.type} />
                         <DetailRow label="Subtype" value={log.subtype} />
                         <DetailRow label="Duration (sec)" value={log.duration} icon={Clock} />
                    </div>
                 </div>

            </div>
        </div>

        {/* Footer */}
        <div className="p-4 border-t border-slate-800 bg-slate-900/50 rounded-b-xl flex justify-end">
          <button 
            onClick={onClose} 
            className="px-5 py-2.5 bg-slate-800 hover:bg-slate-700 text-white text-sm font-medium rounded-lg transition-colors border border-slate-700 shadow-lg"
          >
            Close
          </button>
        </div>
      </div>
    </div>
  );
};

export default LogDetailModal;