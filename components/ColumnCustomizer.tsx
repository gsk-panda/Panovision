import React from 'react';
import { ColumnDef } from '../types';
import { X, ArrowUp, ArrowDown, Eye, EyeOff, RotateCcw } from 'lucide-react';

interface Props {
  columns: ColumnDef[];
  setColumns: (cols: ColumnDef[]) => void;
  onClose: () => void;
  onReset: () => void;
}

const ColumnCustomizer: React.FC<Props> = ({ columns, setColumns, onClose, onReset }) => {
  const toggle = (id: string) => {
    setColumns(columns.map(c => c.id === id ? { ...c, visible: !c.visible } : c));
  };

  const move = (idx: number, dir: 'up' | 'down') => {
    const newCols = [...columns];
    const target = dir === 'up' ? idx - 1 : idx + 1;
    if (target >= 0 && target < newCols.length) {
      [newCols[idx], newCols[target]] = [newCols[target], newCols[idx]];
      setColumns(newCols);
    }
  };

  return (
    <div className="fixed inset-0 bg-slate-950/80 backdrop-blur-sm flex items-center justify-center z-50 p-4">
      <div className="bg-slate-900 border border-slate-700 rounded-xl shadow-2xl w-full max-w-md flex flex-col max-h-[80vh] animate-in fade-in zoom-in duration-200">
        <div className="flex items-center justify-between p-4 border-b border-slate-800">
          <h3 className="text-lg font-medium text-white">Customize Columns</h3>
          <button onClick={onClose} className="text-slate-400 hover:text-white transition-colors">
            <X className="h-5 w-5" />
          </button>
        </div>
        
        <div className="p-4 overflow-y-auto custom-scrollbar flex-1 space-y-2">
          {columns.map((col, index) => (
            <div 
              key={col.id} 
              className={`flex items-center justify-between p-3 rounded-lg border transition-all ${
                col.visible 
                  ? 'bg-slate-800 border-slate-700' 
                  : 'bg-slate-900/50 border-slate-800 opacity-60 hover:opacity-100'
              }`}
            >
              <div className="flex items-center gap-3">
                <button 
                  onClick={() => toggle(col.id as string)} 
                  className={`p-1.5 rounded-md transition-colors ${col.visible ? 'text-brand-400 bg-brand-400/10' : 'text-slate-500 hover:bg-slate-800'}`}
                >
                  {col.visible ? <Eye className="h-4 w-4" /> : <EyeOff className="h-4 w-4" />}
                </button>
                <span className="text-sm font-medium text-slate-200">{col.label}</span>
              </div>
              
              <div className="flex items-center gap-1">
                <button 
                  onClick={() => move(index, 'up')} 
                  disabled={index === 0}
                  className="p-1 text-slate-400 hover:text-white disabled:opacity-30"
                >
                  <ArrowUp className="h-4 w-4" />
                </button>
                <button 
                  onClick={() => move(index, 'down')} 
                  disabled={index === columns.length - 1}
                  className="p-1 text-slate-400 hover:text-white disabled:opacity-30"
                >
                  <ArrowDown className="h-4 w-4" />
                </button>
              </div>
            </div>
          ))}
        </div>
        
        <div className="p-4 border-t border-slate-800 bg-slate-900/50 rounded-b-xl flex justify-between items-center">
          <button
            onClick={onReset}
            className="flex items-center gap-2 px-3 py-2 text-xs font-medium text-slate-400 hover:text-white hover:bg-slate-800 rounded-lg transition-colors"
          >
            <RotateCcw className="h-3 w-3" />
            Reset Defaults
          </button>

          <button 
            onClick={onClose} 
            className="px-4 py-2 bg-brand-600 hover:bg-brand-500 text-white text-sm font-medium rounded-lg transition-colors"
          >
            Done
          </button>
        </div>
      </div>
    </div>
  );
};

export default ColumnCustomizer;