import React from 'react';
import { LogStats } from '../types';
import { Activity, Shield, Box } from 'lucide-react';
import { Tooltip, ResponsiveContainer, Cell, PieChart, Pie } from 'recharts';

const ACTION_COLORS: Record<string, string> = {
    'allow': '#22c55e', // green
    'deny': '#ef4444', // red
    'drop': '#b91c1c', // dark red
    'reset-server': '#f59e0b', // amber
    'reset-client': '#d97706' // amber
};

const StatsWidget: React.FC<{ stats: LogStats }> = ({ stats }) => {
  const formatBytes = (bytes: number) => {
    if (bytes === 0) return '0 B';
    const k = 1024;
    const sizes = ['B', 'KB', 'MB', 'GB', 'TB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
  };

  return (
    <div className="grid grid-cols-1 md:grid-cols-3 gap-4 mb-6">
      {/* Metric Cards - Expanded Width */}
      <div className="md:col-span-2 grid grid-cols-2 gap-4">
        <div className="bg-slate-900 border border-slate-800 rounded-lg p-6 flex justify-between items-center shadow-sm">
            <div>
                <p className="text-xs font-medium text-slate-500 uppercase tracking-wider">Total Data</p>
                <h3 className="text-2xl font-bold text-white mt-1">{formatBytes(stats.totalBytes)}</h3>
            </div>
            <div className="p-3 bg-slate-800 rounded-lg">
                <Activity className="h-6 w-6 text-brand-500" />
            </div>
        </div>
        <div className="bg-slate-900 border border-slate-800 rounded-lg p-6 flex justify-between items-center shadow-sm">
            <div>
                <p className="text-xs font-medium text-slate-500 uppercase tracking-wider">Total Packets</p>
                <h3 className="text-2xl font-bold text-white mt-1">{stats.totalPackets.toLocaleString()}</h3>
            </div>
            <div className="p-3 bg-slate-800 rounded-lg">
                <Box className="h-6 w-6 text-blue-500" />
            </div>
        </div>
      </div>

      {/* Actions Pie Chart */}
      <div className="bg-slate-900 border border-slate-800 rounded-lg p-4 shadow-sm md:col-span-1">
        <div className="flex items-center gap-2 mb-2">
            <Shield className="h-4 w-4 text-slate-400" />
            <h4 className="text-sm font-medium text-slate-300">Action Distribution</h4>
        </div>
        <div className="h-28 w-full flex items-center justify-between">
             <div className="h-full flex-1">
                 <ResponsiveContainer width="100%" height="100%">
                    <PieChart>
                        <Pie
                            data={stats.actionDistribution}
                            cx="50%"
                            cy="50%"
                            innerRadius={25}
                            outerRadius={45}
                            paddingAngle={5}
                            dataKey="count"
                            stroke="none"
                        >
                            {stats.actionDistribution.map((entry, index) => (
                                <Cell key={`cell-${index}`} fill={ACTION_COLORS[entry.name] || '#94a3b8'} />
                            ))}
                        </Pie>
                        <Tooltip 
                             contentStyle={{ backgroundColor: '#0f172a', borderColor: '#1e293b', color: '#ffffff' }}
                             itemStyle={{ color: '#ffffff' }}
                        />
                    </PieChart>
                 </ResponsiveContainer>
             </div>
             <div className="text-xs space-y-1 ml-4 min-w-[100px] flex flex-col justify-center">
                {stats.actionDistribution.map(action => (
                    <div key={action.name} className="flex items-center gap-2">
                        <div className="w-2 h-2 min-w-[8px] rounded-full" style={{background: ACTION_COLORS[action.name] || '#94a3b8'}}></div>
                        <span className="text-slate-400 capitalize whitespace-nowrap">{action.name}</span>
                    </div>
                ))}
             </div>
        </div>
      </div>
    </div>
  );
};

export default StatsWidget;