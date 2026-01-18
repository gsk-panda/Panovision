import React, { useState, useEffect, useMemo, useRef } from 'react';
import { TrafficLog, ColumnDef, SearchParams, AuthUser, LogStats } from './types';
import { fetchLogs, ApiError } from './services/panoramaService';
import { getCurrentAccount, getUserInfo, handleRedirectPromise, logout as msalLogout } from './services/authService';
import { isOidcEnabled } from './services/authConfig';
import SearchHeader from './components/SearchHeader';
import ColumnCustomizer from './components/ColumnCustomizer';
import StatsWidget from './components/StatsWidget';
import LoginPage from './components/LoginPage';
import LogDetailModal from './components/LogDetailModal';
import ErrorDiagnosisModal from './components/ErrorDiagnosisModal';
import Logo from './components/Logo';
import { Settings, AlertCircle, LogOut, User, ArrowDown, ArrowUp, Search, GripVertical, Loader2, Database, FileSearch, ChevronDown, ChevronUp } from 'lucide-react';

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
  const [isInitializing, setIsInitializing] = useState(true);
  
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
  const [apiError, setApiError] = useState<ApiError | null>(null);
  const [isStatsExpanded, setIsStatsExpanded] = useState(true);
  
  // Drag and Drop state
  const [draggedColId, setDraggedColId] = useState<string | null>(null);
  
  const tableContainerRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const initializeAuth = async () => {
      try {
        if (isOidcEnabled()) {
          await handleRedirectPromise();
          const account = getCurrentAccount();
          if (account) {
            const userInfo = await getUserInfo();
            if (userInfo) {
              setUser(userInfo);
            }
          }
        } else {
          setUser({
            id: 'anonymous',
            name: 'Anonymous User',
            email: 'anonymous@local',
          });
        }
      } catch (error) {
        console.error('Auth initialization error:', error);
      } finally {
        setIsInitializing(false);
      }
    };

    initializeAuth();
  }, []);

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
    setApiError(null);
    try {
      const data = await fetchLogs(params);
      setLogs(data);
    } catch (error: any) {
      console.error('API Error:', error);
      if (error.statusCode || error.message || error.timestamp) {
        setApiError(error as ApiError);
      } else {
        setApiError({
          message: error.message || 'Unknown error occurred',
          timestamp: new Date().toISOString(),
        });
      }
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

  const currentPath = typeof window !== 'undefined' ? window.location.pathname : '/';
  const currentUrl = typeof window !== 'undefined' ? window.location.href : '';
  const isLogsPage = currentPath === '/logs' || currentPath === '/' || currentUrl.includes('/logs');
  const isChangesPage = currentPath === '/changes' || currentUrl.includes('/changes');

  if (isInitializing) {
    return (
      <div className="min-h-screen bg-slate-950 flex items-center justify-center">
        <div className="text-center">
          <Loader2 className="animate-spin h-8 w-8 text-brand-500 mx-auto mb-4" />
          <p className="text-slate-400">Initializing...</p>
        </div>
      </div>
    );
  }

  if (!user) {
    return <LoginPage onLoginSuccess={setUser} />;
  }

  return (
    <div className="min-h-screen bg-slate-950 text-slate-200 flex font-sans">
      {/* Left Sidebar */}
      <aside className="w-64 bg-slate-900/50 border-r border-slate-800 flex flex-col sticky top-0 h-screen">
        <div className="p-6 border-b border-slate-800">
          <Logo className="h-8 w-auto" showTagline={false} />
        </div>
        <nav className="flex-1 p-4">
          <div className="mb-6">
            <h2 className="text-xs font-semibold text-slate-500 uppercase tracking-wider mb-3 px-3">OVERVIEW</h2>
            <div className="space-y-1">
              <a
                href="/changes"
                className={`flex items-center gap-3 px-3 py-2.5 text-sm font-medium rounded-lg transition-all ${
                  isChangesPage
                    ? 'bg-brand-500/20 text-brand-400 border-l-2 border-brand-500'
                    : 'text-slate-400 hover:bg-slate-800/50 hover:text-slate-200'
                }`}
              >
                <Database className={`h-5 w-5 ${isChangesPage ? 'text-brand-400' : 'text-slate-500'}`} />
                Change Database
              </a>
              <a
                href="/logs"
                className={`flex items-center gap-3 px-3 py-2.5 text-sm font-medium rounded-lg transition-all ${
                  isLogsPage
                    ? 'bg-brand-500/20 text-brand-400 border-l-2 border-brand-500'
                    : 'text-slate-400 hover:bg-slate-800/50 hover:text-slate-200'
                }`}
              >
                <FileSearch className={`h-5 w-5 ${isLogsPage ? 'text-brand-400' : 'text-slate-500'}`} />
                Log Search
              </a>
            </div>
          </div>
        </nav>
        <div className="p-4 border-t border-slate-800">
          {isOidcEnabled() && (
            <button
              onClick={async () => {
                await msalLogout();
                setUser(null);
              }}
              className="w-full flex items-center gap-3 px-3 py-2.5 text-sm font-medium text-slate-400 hover:bg-slate-800/50 hover:text-red-400 rounded-lg transition-all"
            >
              <LogOut className="h-5 w-5" />
              Logout
            </button>
          )}
        </div>
      </aside>

      {/* Main Content Area */}
      <div className="flex-1 flex flex-col min-w-0">
        {/* Top Navigation */}
        <header className="bg-white/95 backdrop-blur border-b border-slate-200 sticky top-0 z-50">
          <div className="max-w-[1920px] mx-auto w-full px-4 md:px-6 py-3 flex items-center justify-between">
            <div className="flex items-center gap-6">
            </div>
            <div className="flex items-center gap-4">
              <div className="hidden md:flex flex-col items-end">
                <span className="text-sm font-semibold text-slate-800">{user.name}</span>
                <span className="text-xs text-slate-500">{user.email}</span>
              </div>
              <div className="h-8 w-8 bg-slate-100 rounded-full flex items-center justify-center text-slate-600 border border-slate-200">
                <User className="h-4 w-4" />
              </div>
            </div>
          </div>
        </header>

        {/* Query Bar */}
        <SearchHeader onSearch={handleSearch} isSearching={isSearching} />

      {/* Main Content */}
      <main className="flex-1 p-4 md:p-6 overflow-hidden flex flex-col max-w-[1920px] mx-auto w-full">
        <div className="flex justify-between items-center mb-4">
            <button
              onClick={() => setIsStatsExpanded(!isStatsExpanded)}
              className="text-lg font-semibold text-slate-400 uppercase tracking-wider flex items-center gap-2 hover:text-slate-300 transition-colors cursor-pointer"
            >
                <div className="w-2 h-2 rounded-full bg-brand-500 animate-pulse"></div>
                Traffic Activity
                {isStatsExpanded ? (
                  <ChevronUp className="h-4 w-4" />
                ) : (
                  <ChevronDown className="h-4 w-4" />
                )}
            </button>
            <button 
                onClick={() => setShowColumnCustomizer(true)} 
                className="flex items-center gap-2 px-3 py-1.5 text-sm font-medium text-slate-300 bg-slate-800 border border-slate-700 rounded-md hover:bg-slate-700 transition-colors"
            >
                <Settings className="h-4 w-4" />
                Customize View
            </button>
        </div>

        {/* Error Banner */}
        {apiError && (
          <div className="mb-4 bg-red-950/50 border border-red-500/30 rounded-lg p-4 flex items-center justify-between">
            <div className="flex items-center gap-3">
              <AlertCircle className="h-5 w-5 text-red-400 flex-shrink-0" />
              <div>
                <p className="text-sm font-medium text-red-400">API Error: {apiError.message}</p>
                <p className="text-xs text-slate-400 mt-1">Click to view detailed diagnosis</p>
              </div>
            </div>
            <button
              onClick={() => setApiError(apiError)}
              className="px-4 py-2 text-sm font-medium text-white bg-red-600 hover:bg-red-500 rounded-md transition-colors"
            >
              View Details
            </button>
          </div>
        )}

        {/* Stats */}
        {logs.length > 0 && isStatsExpanded && <StatsWidget stats={stats} />}

        {/* Data Table */}
        <div className="flex-1 bg-slate-900 border border-slate-800 rounded-xl flex flex-col overflow-hidden relative shadow-lg shadow-black/20">
          <div ref={tableContainerRef} className="absolute inset-0 overflow-y-scroll overflow-x-auto custom-scrollbar">
            <table className="min-w-full divide-y divide-slate-800 table-fixed w-full">
              <thead className="bg-slate-950/50 backdrop-blur sticky top-0 z-20">
                <tr>
                  {/* Action Column for Magnifying Glass */}
                  <th className="w-12 px-6 py-4"></th>
                  {columns.filter(c => c.visible).map(c => (
                    <th 
                        key={c.id}
                        draggable
                        onDragStart={(e) => handleDragStart(e, c.id as string)}
                        onDragOver={handleDragOver}
                        onDrop={(e) => handleDrop(e, c.id as string)}
                        onDragEnd={() => setDraggedColId(null)}
                        className={`px-6 py-4 text-left text-[11px] font-bold text-slate-500 uppercase tracking-widest cursor-pointer hover:text-slate-400 transition-colors select-none group relative ${draggedColId === c.id ? 'opacity-40 border-2 border-dashed border-brand-500/50 bg-slate-900' : ''}`}
                        onClick={() => { setSortCol(c.id); setSortDir(sortCol === c.id && sortDir === 'asc' ? 'desc' : 'asc'); }}
                        style={{width: c.width}}
                    >
                        <div className="flex items-center gap-1.5">
                            <span 
                                title="Drag to reorder"
                                className="cursor-grab active:cursor-grabbing text-slate-600 hover:text-slate-400 transition-colors -ml-1"
                                onClick={(e) => e.stopPropagation()}
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
              <tbody className="bg-slate-900 divide-y divide-slate-800">
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
                        <td className={`px-6 py-4 whitespace-nowrap text-center`}>
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
                            let cellClass = `px-6 py-4 whitespace-nowrap ${isDenyOrDrop ? 'text-red-100' : 'text-slate-300'}`;
                            
                            // Stylized Cells
                            if (col.isMono) cellClass += " font-mono text-sm";
                            else cellClass += " text-sm";
                            if (col.id === 'action') {
                                const color = 
                                    content === 'allow' ? 'bg-emerald-500/10 text-emerald-400 border-emerald-500/20' : 
                                    content === 'deny' ? 'bg-red-500/10 text-red-400 border-red-500/20' : 
                                    content === 'drop' ? 'bg-red-500/10 text-red-400 border-red-500/20' :
                                    'bg-blue-500/10 text-blue-400 border-blue-500/20';
                                return (
                                    <td key={`${log.id}-${col.id}`} className={`px-6 py-4 whitespace-nowrap text-right`}>
                                        <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-semibold border ${color}`}>{content}</span>
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
                                        <span className={`text-sm ${reasonColor}`}>{content}</span>
                                    </td>
                                );
                            }

                            return (
                                <td key={`${log.id}-${col.id}`} className={cellClass}>
                                    <span className="text-sm">{content}</span>
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
      </div>

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

      {apiError && (
        <ErrorDiagnosisModal 
            error={apiError} 
            onClose={() => setApiError(null)} 
        />
      )}
    </div>
  );
}

export default App;