import React from 'react';
import { X, Copy, Check } from 'lucide-react';

interface ApiUrlModalProps {
  url: string;
  onClose: () => void;
}

const ApiUrlModal: React.FC<ApiUrlModalProps> = ({ url, onClose }) => {
  const [copied, setCopied] = React.useState(false);

  const handleCopy = async () => {
    try {
      await navigator.clipboard.writeText(url);
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    } catch (err) {
      console.error('Failed to copy:', err);
    }
  };

  return (
    <div className="fixed inset-0 bg-black/50 backdrop-blur-sm z-50 flex items-center justify-center p-4">
      <div className="bg-slate-900 border border-slate-700 rounded-xl shadow-2xl max-w-4xl w-full max-h-[90vh] flex flex-col">
        <div className="flex items-center justify-between p-6 border-b border-slate-800">
          <h2 className="text-xl font-semibold text-slate-200">API Request URL (Debug)</h2>
          <button
            onClick={onClose}
            className="text-slate-400 hover:text-slate-200 transition-colors p-2 hover:bg-slate-800 rounded-md"
          >
            <X className="h-5 w-5" />
          </button>
        </div>
        
        <div className="flex-1 overflow-auto p-6">
          <div className="bg-slate-950 border border-slate-800 rounded-lg p-4 font-mono text-sm">
            <div className="flex items-start justify-between gap-4">
              <pre className="text-slate-300 whitespace-pre-wrap break-all flex-1">
                {url}
              </pre>
              <button
                onClick={handleCopy}
                className="flex-shrink-0 flex items-center gap-2 px-3 py-2 bg-slate-800 hover:bg-slate-700 text-slate-300 rounded-md transition-colors"
                title="Copy URL"
              >
                {copied ? (
                  <>
                    <Check className="h-4 w-4 text-green-400" />
                    <span className="text-xs">Copied!</span>
                  </>
                ) : (
                  <>
                    <Copy className="h-4 w-4" />
                    <span className="text-xs">Copy</span>
                  </>
                )}
              </button>
            </div>
          </div>
          
          <div className="mt-4 p-4 bg-blue-950/30 border border-blue-800/30 rounded-lg">
            <p className="text-sm text-blue-300">
              <strong>Note:</strong> This URL includes the full API request being sent to Panorama. 
              The API key is shown for debugging purposes only.
            </p>
          </div>
        </div>
        
        <div className="p-6 border-t border-slate-800 flex justify-end">
          <button
            onClick={onClose}
            className="px-4 py-2 bg-slate-800 hover:bg-slate-700 text-slate-300 rounded-md transition-colors"
          >
            Close
          </button>
        </div>
      </div>
    </div>
  );
};

export default ApiUrlModal;

