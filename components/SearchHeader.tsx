import React, { useState } from 'react';
import { Search, RefreshCw, Calendar, Monitor, Shield, Network, ListFilter, Clock, Layers, Info, Hash, Eraser } from 'lucide-react';
import { SearchParams } from '../types';

interface Props {
  onSearch: (p: SearchParams) => void;
  isSearching: boolean;
}

const DEFAULT_PARAMS: SearchParams = {
  srcIp: '',
  dstIp: '',
  srcZone: '',
  dstZone: '',
  dstPort: '',
  action: 'all',
  timeRange: 'last-15-minutes',
  startTime: '',
  endTime: '',
  limit: 50,
  isNotSrcIp: false,
  isNotDstIp: false,
  isNotDstPort: false,
};

const SearchHeader: React.FC<Props> = ({ onSearch, isSearching }) => {
  const [params, setParams] = useState<SearchParams>(DEFAULT_PARAMS);

  const handleChange = (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement>) => {
    const { name, value } = e.target;
    setParams(prev => ({
      ...prev,
      [name]: name === 'limit' ? (value === '' ? '' : parseInt(value)) : value
    }));
  };

  const handleCheckboxChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const { name, checked } = e.target;
    setParams(prev => ({
      ...prev,
      [name]: checked
    }));
  };

  const validateAndSearch = () => {
    // Validation: Ensure fields with "NOT" checked have values
    if (params.isNotSrcIp && !params.srcIp.trim()) {
      alert("Please enter a Source IP to exclude, or uncheck the 'NOT' box.");
      return;
    }
    if (params.isNotDstIp && !params.dstIp.trim()) {
      alert("Please enter a Destination IP to exclude, or uncheck the 'NOT' box.");
      return;
    }
    if (params.isNotDstPort && !params.dstPort.trim()) {
      alert("Please enter a Destination Port to exclude, or uncheck the 'NOT' box.");
      return;
    }

    onSearch(params);
  };

  const handleClear = () => {
    setParams(DEFAULT_PARAMS);
    // Clears fields only, does not trigger search
  };

  return (
    <div className="bg-slate-900 border-b border-slate-800 sticky top-0 z-40 shadow-xl shadow-slate-950/50">
      <div className="max-w-[1920px] mx-auto w-full px-4 md:px-6 py-4">
        <form onSubmit={(e) => { e.preventDefault(); validateAndSearch(); }} className="space-y-4">
          
          {/* Primary Search Fields - 6 Columns */}
          <div className="grid grid-cols-1 md:grid-cols-3 lg:grid-cols-6 gap-4">
            
            {/* Source Zone */}
            <div className="space-y-1">
              <label className="text-xs font-medium text-brand-400 flex items-center gap-1 h-4 mb-1">
                <Layers className="h-3 w-3" /> Src Zone
              </label>
              <input
                type="text"
                name="srcZone"
                placeholder="e.g. Trust"
                value={params.srcZone}
                onChange={handleChange}
                className="block w-full px-3 py-2 text-sm border border-slate-700 rounded-md bg-slate-950 text-slate-200 focus:ring-1 focus:ring-brand-500 focus:border-brand-500 outline-none placeholder-slate-700"
              />
            </div>

            {/* Source IP */}
            <div className="space-y-1">
              <div className="flex justify-between items-center mb-1 h-4">
                <label className="text-xs font-medium text-brand-400 flex items-center gap-1">
                  <Monitor className="h-3 w-3" /> Source IP
                </label>
                <label className="flex items-center gap-1.5 cursor-pointer group select-none" title="Exclude this IP from search results">
                   <input 
                     type="checkbox" 
                     name="isNotSrcIp"
                     checked={params.isNotSrcIp}
                     onChange={handleCheckboxChange}
                     className="w-3 h-3 rounded border-slate-700 bg-slate-900 text-brand-500 focus:ring-1 focus:ring-brand-500 focus:ring-offset-0 cursor-pointer accent-brand-500"
                   />
                   <span className={`text-[10px] font-bold ${params.isNotSrcIp ? 'text-red-400' : 'text-slate-600 group-hover:text-slate-500'}`}>NOT</span>
                </label>
              </div>
              <input
                type="text"
                name="srcIp"
                placeholder="e.g. 10.1.1.5"
                value={params.srcIp}
                onChange={handleChange}
                className={`block w-full px-3 py-2 text-sm border rounded-md bg-slate-950 text-slate-200 focus:ring-1 focus:ring-brand-500 focus:border-brand-500 outline-none placeholder-slate-700 font-mono transition-colors ${params.isNotSrcIp ? 'border-red-900/50 bg-red-950/10' : 'border-slate-700'}`}
              />
            </div>

            {/* Destination Zone */}
            <div className="space-y-1">
              <label className="text-xs font-medium text-blue-400 flex items-center gap-1 h-4 mb-1">
                <Layers className="h-3 w-3" /> Dst Zone
              </label>
              <input
                type="text"
                name="dstZone"
                placeholder="e.g. Untrust"
                value={params.dstZone}
                onChange={handleChange}
                className="block w-full px-3 py-2 text-sm border border-slate-700 rounded-md bg-slate-950 text-slate-200 focus:ring-1 focus:ring-brand-500 focus:border-brand-500 outline-none placeholder-slate-700"
              />
            </div>

            {/* Destination IP */}
            <div className="space-y-1">
              <div className="flex justify-between items-center mb-1 h-4">
                <label className="text-xs font-medium text-blue-400 flex items-center gap-1">
                  <Network className="h-3 w-3" /> Dest IP
                </label>
                <label className="flex items-center gap-1.5 cursor-pointer group select-none" title="Exclude this IP from search results">
                   <input 
                     type="checkbox" 
                     name="isNotDstIp"
                     checked={params.isNotDstIp}
                     onChange={handleCheckboxChange}
                     className="w-3 h-3 rounded border-slate-700 bg-slate-900 text-brand-500 focus:ring-1 focus:ring-brand-500 focus:ring-offset-0 cursor-pointer accent-brand-500"
                   />
                   <span className={`text-[10px] font-bold ${params.isNotDstIp ? 'text-red-400' : 'text-slate-600 group-hover:text-slate-500'}`}>NOT</span>
                </label>
              </div>
              <input
                type="text"
                name="dstIp"
                placeholder="e.g. 8.8.8.8"
                value={params.dstIp}
                onChange={handleChange}
                 className={`block w-full px-3 py-2 text-sm border rounded-md bg-slate-950 text-slate-200 focus:ring-1 focus:ring-brand-500 focus:border-brand-500 outline-none placeholder-slate-700 font-mono transition-colors ${params.isNotDstIp ? 'border-red-900/50 bg-red-950/10' : 'border-slate-700'}`}
              />
            </div>

            {/* Destination Port */}
            <div className="space-y-1">
               <div className="flex justify-between items-center mb-1 h-4">
                <label className="text-xs font-medium text-slate-400 flex items-center gap-1">
                  <Hash className="h-3 w-3" /> Dst Port
                </label>
                <label className="flex items-center gap-1.5 cursor-pointer group select-none" title="Exclude this Port from search results">
                   <input 
                     type="checkbox" 
                     name="isNotDstPort"
                     checked={params.isNotDstPort}
                     onChange={handleCheckboxChange}
                     className="w-3 h-3 rounded border-slate-700 bg-slate-900 text-brand-500 focus:ring-1 focus:ring-brand-500 focus:ring-offset-0 cursor-pointer accent-brand-500"
                   />
                   <span className={`text-[10px] font-bold ${params.isNotDstPort ? 'text-red-400' : 'text-slate-600 group-hover:text-slate-500'}`}>NOT</span>
                </label>
              </div>
              <input
                type="text"
                name="dstPort"
                placeholder="443"
                value={params.dstPort}
                onChange={handleChange}
                className={`block w-full px-3 py-2 text-sm border rounded-md bg-slate-950 text-slate-200 focus:ring-1 focus:ring-brand-500 focus:border-brand-500 outline-none placeholder-slate-700 font-mono transition-colors ${params.isNotDstPort ? 'border-red-900/50 bg-red-950/10' : 'border-slate-700'}`}
              />
            </div>

            {/* Action */}
            <div className="space-y-1">
              <label className="text-xs font-medium text-slate-400 flex items-center gap-1 h-4 mb-1">
                <Shield className="h-3 w-3" /> Action
              </label>
              <select
                name="action"
                value={params.action}
                onChange={handleChange}
                className="block w-full px-3 py-2 text-sm border border-slate-700 rounded-md bg-slate-950 text-slate-200 focus:ring-1 focus:ring-brand-500 focus:border-brand-500 outline-none"
              >
                <option value="all">All Actions</option>
                <option value="allow">Allow</option>
                <option value="deny_drop">Deny / Drop</option>
              </select>
            </div>
          </div>

          {/* Secondary Options Row: Time, Limit, Search */}
          <div className="grid grid-cols-1 md:grid-cols-4 lg:grid-cols-6 gap-4 items-end">
            
            {/* Time Range */}
            <div className="space-y-1 lg:col-span-1">
              <label className="text-xs font-medium text-slate-400 flex items-center gap-1 justify-between h-4 mb-1">
                <div className="flex items-center gap-1">
                  <Clock className="h-3 w-3" /> Time Range
                </div>
                <span className="text-[10px] text-slate-500 font-normal bg-slate-800 px-1.5 py-0.5 rounded border border-slate-700">MST</span>
              </label>
              <select
                name="timeRange"
                value={params.timeRange}
                onChange={handleChange}
                className="block w-full px-3 py-2 text-sm border border-slate-700 rounded-md bg-slate-950 text-slate-200 focus:ring-1 focus:ring-brand-500 focus:border-brand-500 outline-none"
              >
                <option value="last-15-minutes">Last 15 Mins</option>
                <option value="last-60-minutes">Last 60 Mins</option>
                <option value="last-6-hrs">Last 6 Hours</option>
                <option value="last-24-hrs">Last 24 Hours</option>
                <option value="custom">Custom Range</option>
              </select>
            </div>

            {/* Limit */}
            <div className="space-y-1 lg:col-span-1">
                <label className="text-xs font-medium text-slate-400 flex items-center gap-1 h-4 mb-1">
                    <ListFilter className="h-3 w-3" /> Limit
                </label>
                <input
                    type="number"
                    name="limit"
                    min="1"
                    max="1000"
                    value={params.limit}
                    onChange={handleChange}
                    className="block w-full px-3 py-2 text-sm border border-slate-700 rounded-md bg-slate-950 text-slate-200 outline-none focus:border-brand-500 [appearance:textfield] [&::-webkit-outer-spin-button]:appearance-none [&::-webkit-inner-spin-button]:appearance-none"
                />
            </div>

            {/* Spacer/Buttons */}
            <div className="lg:col-span-1 flex items-center gap-2">
                <button
                    type="button"
                    onClick={handleClear}
                    title="Clear all fields"
                    className="h-[38px] w-[38px] flex justify-center items-center rounded-md border border-slate-700 bg-slate-800 text-slate-400 hover:bg-slate-700 hover:text-white transition-colors"
                >
                    <Eraser className="h-4 w-4" />
                </button>
                <button
                    type="submit"
                    disabled={isSearching}
                    className="flex-1 h-[38px] flex justify-center items-center px-4 border border-transparent text-sm font-medium rounded-md shadow-sm text-white bg-brand-600 hover:bg-brand-500 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-brand-500 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
                >
                    {isSearching ? <RefreshCw className="mr-2 h-4 w-4 animate-spin" /> : <Search className="mr-2 h-4 w-4" />}
                    {isSearching ? 'Querying...' : 'Search'}
                </button>
            </div>
            
             {/* Message */}
            <div className="lg:col-span-3 flex items-center pb-2">
                <div className="flex items-center gap-1 text-[10px] text-slate-500">
                    <Info className="h-3 w-3" />
                    <span>All logs are in MST</span>
                </div>
            </div>

          </div>

          {/* Optional: Custom Time Inputs */}
          {params.timeRange === 'custom' && (
             <div className="grid grid-cols-1 md:grid-cols-2 gap-4 pt-2 border-t border-slate-800/50">
                <div className="space-y-1">
                  <label className="text-xs font-medium text-slate-400 flex items-center gap-1">
                    <Calendar className="h-3 w-3" /> Start (MST)
                  </label>
                  <input
                    type="datetime-local"
                    name="startTime"
                    value={params.startTime}
                    onChange={handleChange}
                    className="block w-full px-3 py-2 text-sm border border-slate-700 rounded-md bg-slate-950 text-slate-200 [color-scheme:dark] outline-none focus:border-brand-500"
                  />
                </div>
                <div className="space-y-1">
                  <label className="text-xs font-medium text-slate-400 flex items-center gap-1">
                    <Calendar className="h-3 w-3" /> End (MST)
                  </label>
                  <input
                    type="datetime-local"
                    name="endTime"
                    value={params.endTime}
                    onChange={handleChange}
                    className="block w-full px-3 py-2 text-sm border border-slate-700 rounded-md bg-slate-950 text-slate-200 [color-scheme:dark] outline-none focus:border-brand-500"
                  />
                </div>
             </div>
          )}

        </form>
      </div>
    </div>
  );
};

export default SearchHeader;