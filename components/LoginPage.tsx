import React, { useState } from 'react';
import { Loader2, Lock } from 'lucide-react';
import Logo from './Logo';
import { login, getUserInfo } from '../services/authService';
import { AuthUser } from '../types';

interface LoginPageProps {
  onLoginSuccess: (user: AuthUser) => void;
}

const LoginPage: React.FC<LoginPageProps> = ({ onLoginSuccess }) => {
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const handleLogin = async () => {
    setIsLoading(true);
    setError(null);
    
    try {
      const account = await login();
      if (!account) {
        setIsLoading(false);
        return;
      }

      const userInfo = await getUserInfo();
      if (userInfo) {
        onLoginSuccess(userInfo);
      } else {
        setError('Failed to retrieve user information');
        setIsLoading(false);
      }
    } catch (err: any) {
      console.error('Login error:', err);
      setError(err.message || 'Authentication failed. Please try again.');
      setIsLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-slate-950 flex flex-col items-center justify-center p-4 relative overflow-hidden">
      {/* Background Decor */}
      <div className="absolute top-0 left-0 w-full h-full overflow-hidden pointer-events-none">
        <div className="absolute -top-24 -right-24 w-96 h-96 bg-brand-500/10 rounded-full blur-3xl"></div>
        <div className="absolute top-1/2 -left-24 w-64 h-64 bg-blue-600/10 rounded-full blur-3xl"></div>
      </div>

      <div className="w-full max-w-md bg-slate-900 border border-slate-800 rounded-2xl shadow-2xl p-8 text-center relative z-10">
        <div className="flex justify-center mb-8">
            <div className="bg-white p-6 rounded-xl shadow-lg shadow-brand-500/10 w-full max-w-[280px]">
                <Logo className="w-full h-auto" showTagline={true} />
            </div>
        </div>
        
        <p className="text-slate-400 text-sm mt-2 mb-8">Secure Traffic Analysis Portal</p>
        
        {error && (
          <div className="mb-4 p-3 bg-red-950/50 border border-red-500/30 rounded-lg text-sm text-red-400">
            {error}
          </div>
        )}
        
        <button 
          onClick={handleLogin} 
          disabled={isLoading} 
          className="w-full flex justify-center items-center gap-3 px-4 py-3 bg-white text-slate-950 font-semibold rounded-lg hover:bg-slate-200 transition-all duration-200 disabled:opacity-70 disabled:cursor-not-allowed"
        >
          {isLoading ? <Loader2 className="animate-spin h-5 w-5" /> : 'Sign in with Azure AD'}
        </button>
        
        <div className="mt-8 flex justify-center items-center gap-2 text-xs text-slate-500">
          <Lock className="h-3 w-3" />
          <span>Restricted Access / 2FA Required</span>
        </div>
      </div>
      
      <div className="absolute bottom-6 text-slate-600 text-xs">
        v2.0.0 &bull; Panorama Integration
      </div>
    </div>
  );
};

export default LoginPage;