import { Link } from 'react-router-dom';
import { Mic, ArrowRight, Users, MessageSquare } from 'lucide-react';
import { Button } from '@/components/ui';
import AppIcon from '@/assets/app_icon_white.png';

// 음파 애니메이션 컴포넌트
function SoundWaveBackground() {
  return (
    <div className="absolute inset-0 overflow-hidden pointer-events-none">
      {/* 그라데이션 배경 */}
      <div className="absolute inset-0 bg-gradient-to-br from-slate-950 via-indigo-950 to-slate-900" />
      
      {/* 중앙에서 퍼지는 음파 */}
      <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2">
        {[...Array(5)].map((_, i) => (
          <div
            key={i}
            className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 rounded-full border border-indigo-500/30"
            style={{
              width: `${200 + i * 150}px`,
              height: `${200 + i * 150}px`,
              animation: `ripple 4s ease-out infinite`,
              animationDelay: `${i * 0.8}s`,
            }}
          />
        ))}
      </div>

      {/* 부유하는 파티클 */}
      {[...Array(20)].map((_, i) => (
        <div
          key={`particle-${i}`}
          className="absolute w-1 h-1 bg-indigo-400/40 rounded-full"
          style={{
            left: `${Math.random() * 100}%`,
            top: `${Math.random() * 100}%`,
            animation: `float ${3 + Math.random() * 4}s ease-in-out infinite`,
            animationDelay: `${Math.random() * 2}s`,
          }}
        />
      ))}

      {/* 이퀄라이저 바 (왼쪽) */}
      <div className="absolute left-8 top-1/2 -translate-y-1/2 flex items-end gap-1 opacity-20">
        {[...Array(8)].map((_, i) => (
          <div
            key={`eq-left-${i}`}
            className="w-1 bg-gradient-to-t from-indigo-500 to-cyan-400 rounded-full"
            style={{
              height: `${20 + Math.random() * 60}px`,
              animation: `equalizer ${0.5 + Math.random() * 0.5}s ease-in-out infinite alternate`,
              animationDelay: `${i * 0.1}s`,
            }}
          />
        ))}
      </div>

      {/* 이퀄라이저 바 (오른쪽) */}
      <div className="absolute right-8 top-1/2 -translate-y-1/2 flex items-end gap-1 opacity-20">
        {[...Array(8)].map((_, i) => (
          <div
            key={`eq-right-${i}`}
            className="w-1 bg-gradient-to-t from-indigo-500 to-cyan-400 rounded-full"
            style={{
              height: `${20 + Math.random() * 60}px`,
              animation: `equalizer ${0.5 + Math.random() * 0.5}s ease-in-out infinite alternate`,
              animationDelay: `${i * 0.1}s`,
            }}
          />
        ))}
      </div>

      {/* 노이즈 오버레이 */}
      <div 
        className="absolute inset-0 opacity-[0.03]"
        style={{
          backgroundImage: `url("data:image/svg+xml,%3Csvg viewBox='0 0 256 256' xmlns='http://www.w3.org/2000/svg'%3E%3Cfilter id='noise'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='0.9' numOctaves='4' stitchTiles='stitch'/%3E%3C/filter%3E%3Crect width='100%25' height='100%25' filter='url(%23noise)'/%3E%3C/svg%3E")`,
        }}
      />
    </div>
  );
}

// 음성 파형 시각화 아이콘
function VoiceWaveIcon() {
  return (
    <div className="relative w-20 h-20 flex items-center justify-center">
      <div className="relative w-16 h-16 bg-[#1c06b1] rounded-2xl flex items-center justify-center shadow-lg shadow-[#1c06b1]/30">
        <img 
          src={AppIcon} 
          alt="VocaCRM" 
          className="relative w-16 h-16 object-contain"
        />
      </div>
    </div>
  );
}

export function LandingPage() {
  return (
    <div className="min-h-screen relative">
      {/* CSS Keyframes */}
      <style>{`
        @keyframes ripple {
          0% {
            transform: translate(-50%, -50%) scale(0.8);
            opacity: 0.6;
          }
          100% {
            transform: translate(-50%, -50%) scale(2);
            opacity: 0;
          }
        }
        
        @keyframes float {
          0%, 100% {
            transform: translateY(0px) translateX(0px);
            opacity: 0.4;
          }
          50% {
            transform: translateY(-20px) translateX(10px);
            opacity: 0.8;
          }
        }
        
        @keyframes equalizer {
          0% {
            height: 20px;
          }
          100% {
            height: 80px;
          }
        }

        @keyframes slideUp {
          from {
            opacity: 0;
            transform: translateY(30px);
          }
          to {
            opacity: 1;
            transform: translateY(0);
          }
        }

        .animate-slide-up {
          animation: slideUp 0.8s ease-out forwards;
        }

        .animate-slide-up-delay-1 {
          animation: slideUp 0.8s ease-out 0.1s forwards;
          opacity: 0;
        }

        .animate-slide-up-delay-2 {
          animation: slideUp 0.8s ease-out 0.2s forwards;
          opacity: 0;
        }

        .animate-slide-up-delay-3 {
          animation: slideUp 0.8s ease-out 0.3s forwards;
          opacity: 0;
        }

        .animate-slide-up-delay-4 {
          animation: slideUp 0.8s ease-out 0.4s forwards;
          opacity: 0;
        }
      `}</style>

      {/* 음파 배경 */}
      <SoundWaveBackground />

      {/* Header */}
      <header className="fixed top-0 left-0 right-0 z-50 bg-slate-950/50 backdrop-blur-xl border-b border-white/5">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex items-center justify-between h-16">
            <div className="flex items-center gap-3">
              <div className="w-9 h-9 bg-[#1c06b1] rounded-xl flex items-center justify-center shadow-lg shadow-[#1c06b1]/20">
                <img 
                  src={AppIcon} 
                  alt="VocaCRM" 
                  className="relative w-16 h-16 object-contain"
                />
              </div>
              <span className="font-bold text-xl text-white tracking-tight">VocaCRM</span>
            </div>

            <div className="flex items-center gap-3">
              <Link to="/login">
                <Button 
                  variant="ghost" 
                  size="sm"
                  className="text-slate-300 hover:text-white hover:bg-white/10"
                >
                  로그인
                </Button>
              </Link>
              <Link to="/login">
                <Button 
                  size="sm"
                  className="bg-gradient-to-r from-indigo-500 to-cyan-500 hover:from-indigo-600 hover:to-cyan-600 text-white border-0 shadow-lg shadow-indigo-500/25"
                >
                  시작하기
                </Button>
              </Link>
            </div>
          </div>
        </div>
      </header>

      {/* Hero Section */}
      <section className="relative min-h-screen flex items-center justify-center px-4 sm:px-6 lg:px-8 pt-16">
        <div className="max-w-5xl mx-auto text-center">
          {/* Voice Wave 아이콘 */}
          <div className="flex justify-center mb-8 animate-slide-up">
            <VoiceWaveIcon />
          </div>

          {/* 뱃지 */}
          <div className="animate-slide-up-delay-1">
            <div className="inline-flex items-center gap-2 px-4 py-2 rounded-full bg-white/5 border border-white/10 text-sm font-medium text-indigo-300 mb-8 backdrop-blur-sm">
              <span className="w-2 h-2 bg-emerald-400 rounded-full animate-pulse" />
              음성 고객 관리 시스템
            </div>
          </div>

          {/* 메인 헤드라인 */}
          <h1 className="text-5xl sm:text-6xl lg:text-7xl font-bold text-white leading-[1.1] mb-6 tracking-tight animate-slide-up-delay-2">
            말로 하는
            <br />
            <span className="bg-gradient-to-r from-indigo-400 via-cyan-400 to-indigo-400 bg-clip-text text-transparent">
              고객 관리
            </span>
          </h1>

          {/* 서브 카피 */}
          <p className="text-lg sm:text-xl text-slate-400 mb-10 max-w-2xl mx-auto leading-relaxed animate-slide-up-delay-3">
            "홍길동 고객 메모 추가해줘"
            <br />
            <span className="text-slate-500">손이 바빠도, 말 한마디로 고객을 관리하세요.</span>
          </p>

          {/* CTA 버튼 */}
          <div className="flex flex-col sm:flex-row items-center justify-center gap-4 animate-slide-up-delay-4">
            <Link to="/login">
              <Button 
                size="lg" 
                className="bg-gradient-to-r from-indigo-500 to-cyan-500 hover:from-indigo-600 hover:to-cyan-600 text-white border-0 shadow-xl shadow-indigo-500/30 px-8 h-14 text-base font-semibold"
              >
                무료로 시작하기
                <ArrowRight className="w-5 h-5 ml-2" />
              </Button>
            </Link>
          </div>

          {/* 핵심 기능 뱃지 */}
          <div className="flex flex-wrap items-center justify-center gap-6 mt-16 animate-slide-up-delay-4">
            <div className="flex items-center gap-2 text-slate-500">
              <Mic className="w-4 h-4 text-indigo-400" />
              <span className="text-sm">음성 명령</span>
            </div>
            <div className="w-1 h-1 bg-slate-700 rounded-full" />
            <div className="flex items-center gap-2 text-slate-500">
              <Users className="w-4 h-4 text-cyan-400" />
              <span className="text-sm">고객 관리</span>
            </div>
            <div className="w-1 h-1 bg-slate-700 rounded-full" />
            <div className="flex items-center gap-2 text-slate-500">
              <MessageSquare className="w-4 h-4 text-indigo-400" />
              <span className="text-sm">메모 기록</span>
            </div>
          </div>
        </div>
      </section>

      {/* Footer */}
      <footer className="absolute bottom-0 left-0 right-0 py-6 px-4 sm:px-6 lg:px-8 border-t border-white/5">
        <div className="max-w-7xl mx-auto">
          <div className="flex flex-col sm:flex-row items-center justify-between gap-4">
            <div className="flex items-center gap-2">
              <div className="w-6 h-6 bg-[#1c06b1] rounded-lg flex items-center justify-center">
                <img 
                  src={AppIcon} 
                  alt="VocaCRM" 
                  className="relative w-16 h-16 object-contain"
                />
              </div>
              <span className="font-semibold text-sm text-slate-400">VocaCRM</span>
            </div>
            <p className="text-xs text-slate-600">
              © 2025 VocaCRM. All rights reserved.
            </p>
          </div>
        </div>
      </footer>
    </div>
  );
}