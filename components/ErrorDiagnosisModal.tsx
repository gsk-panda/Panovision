import React, { useState } from 'react';
import { ApiError } from '../services/panoramaService';
import { X, AlertTriangle, Copy, CheckCircle, Clock, Globe, Code, FileText, Server } from 'lucide-react';

interface Props {
  error: ApiError;
  onClose: () => void;
}

const ErrorDiagnosisModal: React.FC<Props> = ({ error, onClose }) => {
  const [copied, setCopied] = useState(false);

  const copyToClipboard = (text: string) => {
    navigator.clipboard.writeText(text);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  const getDiagnosis = (): string[] => {
    const diagnoses: string[] = [];
    
    if (error.statusCode === 401 || error.statusCode === 403) {
      diagnoses.push('Authentication failed - verify API key is valid and has proper permissions');
      diagnoses.push('Check if API key has expired or been revoked');
    } else if (error.statusCode === 404) {
      diagnoses.push('Endpoint not found - verify Panorama server URL is correct');
      diagnoses.push('Check if the API endpoint path is correct');
    } else if (error.statusCode === 500 || error.statusCode === 502 || error.statusCode === 503) {
      diagnoses.push('Server error - Panorama may be experiencing issues');
      diagnoses.push('Check Panorama server status and logs');
      diagnoses.push('Verify network connectivity to Panorama server');
    } else if (error.statusCode === 0 || !error.statusCode) {
      diagnoses.push('Network connectivity issue - unable to reach Panorama server');
      diagnoses.push('Check CORS settings if accessing from browser');
      diagnoses.push('Verify Panorama server is accessible from this network');
      diagnoses.push('Check firewall rules allowing outbound HTTPS connections');
    } else if (error.message.includes('timeout')) {
      diagnoses.push('Request timeout - query may be too large or server is slow');
      diagnoses.push('Try reducing the time range or log limit');
      diagnoses.push('Check Panorama server performance and load');
    } else if (error.responseBody?.includes('Invalid')) {
      diagnoses.push('Invalid query parameters - check search filters');
      diagnoses.push('Verify time range format is correct');
      diagnoses.push('Check query syntax matches Panorama API requirements');
    }
    
    if (diagnoses.length === 0) {
      diagnoses.push('Review error details below for specific issue');
      diagnoses.push('Check Panorama API documentation for error codes');
      diagnoses.push('Verify all configuration parameters are correct');
    }
    
    return diagnoses;
  };

  const diagnoses = getDiagnosis();

  return (
    <div className="fixed inset-0 bg-slate-950/90 backdrop-blur-sm flex items-center justify-center z-[70] p-4" onClick={(e) => e.target === e.currentTarget && onClose()}>
      <div className="bg-slate-900 border border-red-500/30 rounded-xl shadow-2xl w-full max-w-4xl flex flex-col max-h-[90vh] animate-in fade-in zoom-in duration-200">
        
        <div className="flex items-center justify-between p-5 border-b border-red-500/20 bg-red-950/10 rounded-t-xl">
          <div className="flex items-center gap-4">
            <div className="p-3 bg-red-500/10 rounded-xl border border-red-500/20">
              <AlertTriangle className="h-6 w-6 text-red-400" />
            </div>
            <div>
              <h3 className="text-xl font-bold text-white tracking-tight">API Error Diagnosis</h3>
              <p className="text-sm text-slate-400 mt-1">Detailed error information and troubleshooting steps</p>
            </div>
          </div>
          <button onClick={onClose} className="p-2 text-slate-400 hover:text-white hover:bg-slate-800 rounded-lg transition-colors">
            <X className="h-6 w-6" />
          </button>
        </div>

        <div className="p-6 overflow-y-auto custom-scrollbar flex-1 space-y-6">
          
          <div className="bg-red-950/20 border border-red-500/20 rounded-lg p-4">
            <div className="flex items-start gap-3">
              <AlertTriangle className="h-5 w-5 text-red-400 mt-0.5 flex-shrink-0" />
              <div className="flex-1">
                <h4 className="text-sm font-semibold text-red-400 mb-1">Error Message</h4>
                <p className="text-sm text-slate-200 font-mono">{error.message}</p>
              </div>
            </div>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            {error.statusCode && (
              <div className="bg-slate-950/50 border border-slate-800 rounded-lg p-4">
                <div className="flex items-center gap-2 text-xs font-medium text-slate-500 uppercase tracking-wider mb-2">
                  <Server className="w-3 h-3" />
                  HTTP Status
                </div>
                <div className="text-lg font-semibold text-slate-200">
                  {error.statusCode} {error.statusText && <span className="text-sm text-slate-400">({error.statusText})</span>}
                </div>
              </div>
            )}

            <div className="bg-slate-950/50 border border-slate-800 rounded-lg p-4">
              <div className="flex items-center gap-2 text-xs font-medium text-slate-500 uppercase tracking-wider mb-2">
                <Clock className="w-3 h-3" />
                Timestamp
              </div>
              <div className="text-sm text-slate-300 font-mono">
                {new Date(error.timestamp).toLocaleString()}
              </div>
            </div>
          </div>

          {error.url && (
            <div className="bg-slate-950/50 border border-slate-800 rounded-lg p-4">
              <div className="flex items-center justify-between mb-2">
                <div className="flex items-center gap-2 text-xs font-medium text-slate-500 uppercase tracking-wider">
                  <Globe className="w-3 h-3" />
                  Request URL
                </div>
                <button
                  onClick={() => copyToClipboard(error.url || '')}
                  className="text-xs text-brand-400 hover:text-brand-300 flex items-center gap-1 transition-colors"
                >
                  {copied ? <CheckCircle className="w-3 h-3" /> : <Copy className="w-3 h-3" />}
                  {copied ? 'Copied' : 'Copy'}
                </button>
              </div>
              <p className="text-sm text-slate-300 font-mono break-all">{error.url}</p>
            </div>
          )}

          <div>
            <h4 className="text-sm font-semibold text-white mb-3 flex items-center gap-2">
              <span className="w-1 h-4 bg-blue-500 rounded-full"></span>
              Troubleshooting Steps
            </h4>
            <ul className="space-y-2">
              {diagnoses.map((diagnosis, idx) => (
                <li key={idx} className="flex items-start gap-3 text-sm text-slate-300">
                  <span className="text-blue-400 mt-1.5">•</span>
                  <span>{diagnosis}</span>
                </li>
              ))}
            </ul>
          </div>

          {error.responseBody && (
            <div className="bg-slate-950/50 border border-slate-800 rounded-lg p-4">
              <div className="flex items-center justify-between mb-3">
                <div className="flex items-center gap-2 text-xs font-medium text-slate-500 uppercase tracking-wider">
                  <FileText className="w-3 h-3" />
                  Response Body
                </div>
                <button
                  onClick={() => copyToClipboard(error.responseBody || '')}
                  className="text-xs text-brand-400 hover:text-brand-300 flex items-center gap-1 transition-colors"
                >
                  {copied ? <CheckCircle className="w-3 h-3" /> : <Copy className="w-3 h-3" />}
                  {copied ? 'Copied' : 'Copy'}
                </button>
              </div>
              <pre className="text-xs text-slate-400 font-mono bg-slate-950 p-3 rounded border border-slate-800 overflow-x-auto max-h-64 overflow-y-auto">
                {error.responseBody.length > 2000 
                  ? error.responseBody.substring(0, 2000) + '\n\n... (truncated, use copy to see full response)'
                  : error.responseBody}
              </pre>
            </div>
          )}

        </div>

        <div className="p-4 border-t border-slate-800 bg-slate-900/50 rounded-b-xl flex justify-end gap-3">
          <button 
            onClick={() => copyToClipboard(JSON.stringify(error, null, 2))}
            className="px-4 py-2 bg-slate-800 hover:bg-slate-700 text-white text-sm font-medium rounded-lg transition-colors border border-slate-700 flex items-center gap-2"
          >
            <Copy className="h-4 w-4" />
            Copy Error Details
          </button>
          <button 
            onClick={onClose} 
            className="px-5 py-2 bg-slate-800 hover:bg-slate-700 text-white text-sm font-medium rounded-lg transition-colors border border-slate-700"
          >
            Close
          </button>
        </div>
      </div>
    </div>
  );
};

export default ErrorDiagnosisModal;

