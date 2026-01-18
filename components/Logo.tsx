import React from 'react';

interface LogoProps {
  className?: string;
  showTagline?: boolean;
}

const Logo: React.FC<LogoProps> = ({ className = "h-12 w-auto", showTagline = false }) => {
  return (
    <svg 
      xmlns="http://www.w3.org/2000/svg" 
      viewBox="0 0 400 120" 
      className={className} 
      fill="none"
      aria-label="PanoVision Logo"
    >
      <defs>
        <linearGradient id="glassGradient" x1="0%" y1="0%" x2="100%" y2="100%">
          <stop offset="0%" stopColor="#22d3ee" stopOpacity="0.2" />
          <stop offset="100%" stopColor="#0ea5e9" stopOpacity="0.1" />
        </linearGradient>
        <linearGradient id="rimGradient" x1="0%" y1="0%" x2="0%" y2="100%">
          <stop offset="0%" stopColor="#0ea5e9" />
          <stop offset="100%" stopColor="#0284c7" />
        </linearGradient>
        <filter id="glow" x="-20%" y="-20%" width="140%" height="140%">
          <feGaussianBlur stdDeviation="2" result="coloredBlur" />
          <feMerge>
            <feMergeNode in="coloredBlur" />
            <feMergeNode in="SourceGraphic" />
          </feMerge>
        </filter>
      </defs>

      {/* Symbol: Magnifying Glass with Circuit */}
      <g transform="translate(10, 10)">
        {/* Handle */}
        <path 
          d="M45 75 L15 105 A 5 5 0 0 0 15 112 L22 119 A 5 5 0 0 0 29 119 L59 89" 
          fill="#0f172a" 
          stroke="#334155" 
          strokeWidth="2"
        />
        <rect x="16" y="106" width="10" height="10" transform="rotate(-45 21 111)" fill="#38bdf8" fillOpacity="0.5" />

        {/* Glass Rim */}
        <circle cx="65" cy="55" r="40" stroke="url(#rimGradient)" strokeWidth="6" fill="none" />
        
        {/* Glass Lens Background */}
        <circle cx="65" cy="55" r="36" fill="url(#glassGradient)" />

        {/* Circuit Pattern inside lens */}
        <g clipPath="url(#lensClip)">
            <clipPath id="lensClip">
                <circle cx="65" cy="55" r="36" />
            </clipPath>
            {/* Circuit Lines */}
            <path d="M65 55 L65 30 M65 55 L90 55 M65 55 L40 55 M65 55 L65 80" stroke="#0ea5e9" strokeWidth="2" opacity="0.8" />
            <path d="M50 40 L65 55 L80 40" stroke="#0ea5e9" strokeWidth="1" fill="none" opacity="0.6" />
            <path d="M40 65 L65 55 L80 70" stroke="#0ea5e9" strokeWidth="1" fill="none" opacity="0.6" />
            <circle cx="65" cy="55" r="6" fill="#0f172a" stroke="#38bdf8" strokeWidth="2" />
            <rect x="62" y="52" width="6" height="6" fill="#38bdf8" />
            
            {/* Tech dots */}
            <circle cx="45" cy="35" r="1.5" fill="#38bdf8" />
            <circle cx="85" cy="75" r="1.5" fill="#38bdf8" />
            <circle cx="35" cy="55" r="1.5" fill="#38bdf8" />
            <circle cx="95" cy="55" r="1.5" fill="#38bdf8" />
        </g>
        
        {/* Gloss/Reflection */}
        <path d="M45 35 Q 65 25 85 35" stroke="white" strokeWidth="3" strokeLinecap="round" opacity="0.3" fill="none" />
      </g>

      {/* Text: Pano */}
      <text x="120" y="75" fontFamily="sans-serif" fontWeight="600" fontSize="56" fill="#0f172a">
        Pano
      </text>

      {/* Text: Vision */}
      {/* Eye icon in 'O' or dot of 'i' - keeping it simple with colored text for now matching the prompt style */}
      <text x="254" y="75" fontFamily="sans-serif" fontWeight="400" fontSize="56" fill="#0f766e">
        Vision
      </text>

      {/* Eye Symbol integrated into text (O in Pano) */}
      <g transform="translate(230, 58) scale(0.18)">
        <path d="M50 0 C20 0 0 30 0 50 C0 70 20 100 50 100 C80 100 100 70 100 50 C100 30 80 0 50 0 Z M50 85 C30 85 15 50 15 50 C15 50 30 15 50 15 C70 15 85 50 85 50 C85 50 70 85 50 85 Z" fill="#0f766e"/>
        <circle cx="50" cy="50" r="20" fill="#0f766e" />
        <circle cx="55" cy="45" r="6" fill="white" />
      </g>
      
      {/* Tagline */}
      {showTagline && (
        <text x="122" y="105" fontFamily="monospace" fontSize="14" fill="#64748b" letterSpacing="2">
          NETWORK | ANALYTICS | INSIGHTS
        </text>
      )}
    </svg>
  );
};

export default Logo;