import React, { useState, useEffect, useMemo, useRef } from 'react';
import { TrafficLog, ColumnDef, SearchParams, AuthUser, LogStats } from './types';
import { fetchLogs } from './services/panoramaService';
import SearchHeader from './components/SearchHeader';
import ColumnCustomizer from './components/ColumnCustomizer';
import StatsWidget from './components/StatsWidget';
import LoginPage from './components/LoginPage';
import LogDetailModal from './components/LogDetailModal';
import Logo from './components/Logo';
import { Settings, AlertCircle, LogOut, User, ArrowDown, ArrowUp, Search, GripVertical } from 'lucide-react';

const INITIAL_COLUMNS: ColumnDef[] = [
  { id: 'receive_time', label: 'Receive Time', visible: true, width: 180 },
  { id: 'device_name', label: 'Device', visible: true, width: 200 },
  { id: 'src_zone', label: 'Source Zone', visible: true, width: 120 },
  { id: 'src_ip', label: 'Source IP', visible: true, width: 140, isMono: true },
  { id: 'src_port', label: 'Src Port', visible: false, width: 90, isMono: true },
  { id: 'dst_zone', label: 'Dest Zone', visible: true, width: 120 },
  { id: 'dst_ip', label: 'Dest IP', visible: true, width: 140, isMono: true },
  { id: 'dst_port', label: '# Dst Port', visible: true, width: 90, isMono: true },
  { id: 'app', label: 'Application', visible: true, width: 130 },
  { id: 'ip_protocol', label: 'IP Proto', visible: true, width: 80 },
  { id: 'action', label: 'Action', visible: true, width: 150 },
  { id: 'session_end_reason', label: 'End Reason', visible: true, width: 140 },
  { id: 'rule', label: 'Rule', visible: true, width: 150 },
  { id: 'bytes', label: 'Bytes', visible: true, width: 100 },
  { id: 'packets', label: 'Packets', visible: true, width: 100 },
  { id: 'ingress_interface', label: 'Ingress Int', visible: false, width: 140 },
  { id: 'egress_interface', label: 'Egress Int', visible: false, width: 140 },
  { id: 'packets_sent', label: 'Pkts Sent', visible: false, width: 100 },
  { id: 'packets_received', label: 'Pkts Rcvd', visible: false, width: 100 },
];

// Updated storage key to invalidate old column configs (missing session_end_reason)
const STORAGE_KEY = 'panoVision_columnPrefs_v3';

function calculateLocalStats(logs: TrafficLog[]): LogStats {
  const totalBytes = logs.reduce((acc, log) => acc + log.bytes, 0);
  const totalPackets = logs.reduce((acc, log) => acc + log.packets, 0);
  const actionCounts: Record<string, number> = {};
  
  logs.forEach(log => {
    actionCounts[log.action] = (actionCounts[log.action] || 0) + 1;
  });
  
  return { 
    totalBytes,
    totalPackets,
    actionDistribution: Object.entries(actionCounts)
      .map(([name, count]) => ({ name, count })) 
  };
}

function App() {
  const [user, setUser] = useState<AuthUser | null>(null);
  const [logs, setLogs] = useState<TrafficLog[]>([]);
  
  // Load columns from local storage or default to INITIAL_COLUMNS
  const [columns, setColumns] = useState<ColumnDef[]>(() => {
    try {
        const saved = localStorage.getItem(STORAGE_KEY);
        if (saved) {
            const parsed = JSON.parse(saved);
            if (Array.isArray(parsed) && parsed.length > 0) return parsed;
        }
    } catch (e) {
        console.error("Failed to load column preferences", e);
    }
    return INITIAL_COLUMNS;
  });

  const [isSearching, setIsSearching] = useState(false);
  const [showColumnCustomizer, setShowColumnCustomizer] = useState(false);
  const [sortCol, setSortCol] = useState<keyof TrafficLog>('receive_time');
  const [sortDir, setSortDir] = useState<'asc' | 'desc'>('desc');
  const [selectedLog, setSelectedLog] = useState<TrafficLog | null>(null);
  
  // Drag and Drop state
  const [draggedColId, setDraggedColId] = useState<string | null>(null);
  
  const tableContainerRef = useRef<HTMLDivElement>(null);

  // Persist columns to local storage whenever they change
  useEffect(() => {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(columns));
  }, [columns]);

  const handleResetColumns = () => {
    setColumns(INITIAL_COLUMNS);
    localStorage.removeItem(STORAGE_KEY);
  };

  const handleSearch = async (params: SearchParams) => {
    setIsSearching(true);
    setLogs([]);
    try {
      const data = await fetchLogs(params);
      setLogs(data);
    } catch (error) {
      console.error(error);
    } finally {
      setIsSearching(false);
    }
  };

  // Drag Handlers
  const handleDragStart = (e: React.DragEvent<HTMLTableHeaderCellElement>, id: string) => {
    setDraggedColId(id);
    e.dataTransfer.effectAllowed = "move";
    e.dataTransfer.setData("text/plain", id); // For Firefox compatibility
    // Optional: make the drag image cleaner if needed
  };

  const handleDragOver = (e: React.DragEvent<HTMLTableHeaderCellElement>) => {
    e.preventDefault(); // Necessary to allow dropping
    e.dataTransfer.dropEffect = "move";
  };

  const handleDrop = (e: React.DragEvent<HTMLTableHeaderCellElement>, targetId: string) => {
    e.preventDefault();
    if (!draggedColId || draggedColId === targetId) return;

    const newCols = [...columns];
    const dragIndex = newCols.findIndex(c => c.id === draggedColId);
    
    // Calculate insertion point
    // We need to find the target index in the main array
    // Since visual order matches array order (filtered by visibility), finding index in main array works.
    
    if (dragIndex > -1) {
        const [movedItem] = newCols.splice(dragIndex, 1);
        
        // Find where to insert relative to the drop target
        // We calculate mid-point of target to decide if placing before or after
        const rect = e.currentTarget.getBoundingClientRect();
        const midX = rect.left + rect.width / 2;
        const dropAfter = e.clientX > midX;

        let targetIndex = newCols.findIndex(c => c.id === targetId);
        if (dropAfter) targetIndex++;

        // Ensure we don't go out of bounds (though splice handles that fine)
        if (targetIndex < 0) targetIndex = 0;
        
        newCols.splice(targetIndex, 0, movedItem);
        setColumns(newCols);
    }
    setDraggedColId(null);
  };

  const sortedLogs = useMemo(() => {
    return [...logs].sort((a, b) => {
      const valA = a[sortCol];
      const valB = b[sortCol];
      if (valA < valB) return sortDir === 'asc' ? -1 : 1;
      if (valA > valB) return sortDir === 'asc' ? 1 : -1;
      return 0;
    });
  }, [logs, sortCol, sortDir]);

  const stats = useMemo(() => calculateLocalStats(logs), [logs]);

  if (!user) {
    return <LoginPage onLoginSuccess={setUser} />;
  }

  return (
    <div className="min-h-screen bg-slate-950 text-slate-200 flex flex-col font-sans">
      {/* Top Navigation */}
      <header className="bg-white/95 backdrop-blur border-b border-slate-200 sticky top-0 z-50">
         <div className="max-w-[1920px] mx-auto w-full px-4 md:px-6 py-3 flex items-center justify-between">
            <div className="flex items-center gap-6">
                <div className="flex items-center">
                    <Logo className="h-10 w-auto" showTagline={false} />
                </div>
            </div>
            <div className="flex items-center gap-4">
                <div className="hidden md:flex flex-col items-end">
                    <span className="text-sm font-semibold text-slate-800">{user.name}</span>
                    <span className="text-xs text-slate-500">{user.email}</span>
                </div>
                <div className="h-8 w-8 bg-slate-100 rounded-full flex items-center justify-center text-slate-600 border border-slate-200">
                    <User className="h-4 w-4" />
                </div>
                <button 
                  onClick={() => setUser(null)} 
                  className="text-slate-400 hover:text-red-600 ml-2 transition-colors p-2 hover:bg-slate-50 rounded-md"
                  title="Logout"
                >
                    <LogOut className="h-5 w-5" />
                </button>
            </div>
         </div>
      </header>

      {/* Query Bar */}
      <SearchHeader onSearch={handleSearch} isSearching={isSearching} />

      {/* Main Content */}
      <main className="flex-1 p-4 md:p-6 overflow-hidden flex flex-col max-w-[1920px] mx-auto w-full">
        <div className="flex justify-between items-center mb-4">
            <h2 className="text-lg font-semibold text-slate-400 uppercase tracking-wider flex items-center gap-2">
                <div className="w-2 h-2 rounded-full bg-brand-500 animate-pulse"></div>
                Traffic Activity
            </h2>
            <button 
                onClick={() => setShowColumnCustomizer(true)} 
                className="flex items-center gap-2 px-3 py-1.5 text-sm font-medium text-slate-300 bg-slate-800 border border-slate-700 rounded-md hover:bg-slate-700 transition-colors"
            >
                <Settings className="h-4 w-4" />
                Customize View
            </button>
        </div>

        {/* Stats */}
        {logs.length > 0 && <StatsWidget stats={stats} />}

        {/* Data Table */}
        <div className="flex-1 bg-slate-900 border border-slate-800 rounded-xl flex flex-col overflow-hidden relative shadow-inner">
          <div ref={tableContainerRef} className="absolute inset-0 overflow-y-scroll overflow-x-auto custom-scrollbar">
            <table className="w-full text-left border-collapse min-w-max">
              <thead className="bg-slate-950 sticky top-0 z-20 shadow-sm ring-1 ring-slate-800">
                <tr>
                  {/* Action Column for Magnifying Glass */}
                  <th className="w-12 py-3 px-2 border-b border-slate-800 bg-slate-950"></th>
                  {columns.filter(c => c.visible).map(c => (
                    <th 
                        key={c.id}
                        draggable
                        onDragStart={(e) => handleDragStart(e, c.id as string)}
                        onDragOver={handleDragOver}
                        onDrop={(e) => handleDrop(e, c.id as string)}
                        onDragEnd={() => setDraggedColId(null)}
                        className={`py-3 px-4 text-xs font-semibold text-slate-400 uppercase border-b border-slate-800 cursor-pointer bg-slate-950 hover:text-brand-400 transition-colors select-none group relative ${draggedColId === c.id ? 'opacity-40 border-2 border-dashed border-brand-500/50 bg-slate-900' : ''}`}
                        onClick={() => { setSortCol(c.id); setSortDir(sortCol === c.id && sortDir === 'asc' ? 'desc' : 'asc'); }}
                        style={{width: c.width}}
                    >
                        <div className="flex items-center gap-1.5">
                            <span 
                                title="Drag to reorder"
                                className="cursor-grab active:cursor-grabbing text-slate-700 hover:text-slate-400 transition-colors -ml-1"
                                onClick={(e) => e.stopPropagation()} // Prevent sorting when clicking drag handle
                                onMouseDown={(e) => {
                                   // Optional: could initiate drag here if we moved draggable to this icon
                                }}
                            >
                                <GripVertical className="w-3.5 h-3.5" />
                            </span>
                            {c.label}
                            {sortCol === c.id && (
                                sortDir === 'asc' ? <ArrowUp className="w-3 h-3 text-brand-500" /> : <ArrowDown className="w-3 h-3 text-brand-500" />
                            )}
                        </div>
                    </th>
                  ))}
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-800 bg-slate-900">
                {logs.length === 0 ? (
                  <tr>
                    <td colSpan={columns.filter(c=>c.visible).length + 1} className="py-24 text-center text-slate-500">
                      <div className="flex flex-col items-center gap-3">
                        <AlertCircle className="h-10 w-10 opacity-30"/>
                        <p>{isSearching ? 'Fetching logs...' : 'No logs found. Run a search to begin.'}</p>
                      </div>
                    </td>
                  </tr>
                ) : (
                  sortedLogs.map((log, i) => {
                    // Check for deny or drop to highlight row
                    const isDenyOrDrop = log.action === 'deny' || log.action === 'drop';
                    
                    // Row classes: Highlight red if deny/drop, otherwise standard alternating
                    const rowClass = isDenyOrDrop 
                        ? 'bg-red-950/40 hover:bg-red-900/50 transition-colors group' 
                        : `hover:bg-slate-800/50 transition-colors group ${i % 2 === 0 ? 'bg-slate-900' : 'bg-[#101929]'}`;

                    return (
                        <tr key={log.id} className={rowClass}>
                        {/* Details Button Cell */}
                        <td className={`py-2 px-2 border-b ${isDenyOrDrop ? 'border-red-900/30' : 'border-slate-800/50'} text-center`}>
                            <button 
                                onClick={() => setSelectedLog(log)}
                                className={`p-1.5 rounded-md transition-colors ${isDenyOrDrop ? 'text-red-300 hover:bg-red-900/50' : 'text-slate-500 hover:text-brand-400 hover:bg-brand-500/10'}`}
                                title="View Full Details"
                            >
                                <Search className="w-4 h-4" />
                            </button>
                        </td>
                        {columns.filter(c=>c.visible).map(col => {
                            let content = log[col.id];
                            let cellClass = `py-2 px-4 text-sm border-b whitespace-nowrap ${isDenyOrDrop ? 'border-red-900/30 text-red-100' : 'border-slate-800/50 text-slate-300'}`;
                            
                            // Stylized Cells
                            if (col.isMono) cellClass += " font-mono text-xs";
                            if (col.id === 'action') {
                                const color = 
                                    content === 'allow' ? 'text-green-400 bg-green-400/10' : 
                                    content === 'deny' ? 'text-red-400 bg-red-400/20' : 
                                    content === 'drop' ? 'text-red-400 bg-red-400/20' :
                                    'text-amber-400 bg-amber-400/10';
                                return (
                                    <td key={`${log.id}-${col.id}`} className={`py-2 px-4 border-b ${isDenyOrDrop ? 'border-red-900/30' : 'border-slate-800/50'}`}>
                                        <span className={`px-2 py-0.5 rounded text-xs font-medium uppercase ${color}`}>{content}</span>
                                    </td>
                                )
                            }
                            // Stylize session end reason
                            if (col.id === 'session_end_reason') {
                                let reasonColor = 'text-slate-400';
                                if (content === 'tcp-rst-from-server' || content === 'tcp-rst-from-client') reasonColor = 'text-amber-500';
                                if (content === 'aged-out') reasonColor = 'text-slate-500 italic';
                                if (content === 'policy-deny') reasonColor = 'text-red-400';
                                
                                return (
                                    <td key={`${log.id}-${col.id}`} className={cellClass}>
                                        <span className={reasonColor}>{content}</span>
                                    </td>
                                );
                            }

                            return (
                                <td key={`${log.id}-${col.id}`} className={cellClass}>
                                    {content}
                                </td>
                            );
                        })}
                        </tr>
                    );
                  })
                )}
              </tbody>
            </table>
          </div>
        </div>
      </main>

      {/* Modals */}
      {showColumnCustomizer && (
        <ColumnCustomizer 
            columns={columns} 
            setColumns={setColumns} 
            onClose={() => setShowColumnCustomizer(false)}
            onReset={handleResetColumns}
        />
      )}

      {selectedLog && (
        <LogDetailModal 
            log={selectedLog} 
            onClose={() => setSelectedLog(null)} 
        />
      )}
    </div>
  );
}

export default App;