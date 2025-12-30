import { Link } from 'react-router-dom';
import {
  Mic,
  Users,
  Calendar,
  BarChart3,
  ArrowRight,
  CheckCircle2,
  Sparkles,
  Shield,
  Zap,
} from 'lucide-react';
import { Button } from '@/components/ui';

const features = [
  {
    icon: Mic,
    title: '음성 명령',
    description: '음성으로 고객 정보를 검색하고 메모를 기록하세요. 손이 바쁠 때도 쉽게 관리할 수 있습니다.',
  },
  {
    icon: Users,
    title: '고객 관리',
    description: '고객 정보를 체계적으로 관리하고, 방문 기록과 메모를 한눈에 파악하세요.',
  },
  {
    icon: Calendar,
    title: '예약 시스템',
    description: '예약을 손쉽게 관리하고 일정을 효율적으로 운영하세요.',
  },
  {
    icon: BarChart3,
    title: '통계 및 분석',
    description: '비즈니스 현황을 실시간으로 파악하고 데이터 기반 의사결정을 내리세요.',
  },
];

const benefits = [
  '간편한 고객 등록 및 관리',
  '음성 인식 기반 빠른 검색',
  '실시간 예약 현황 확인',
  '방문 기록 자동 추적',
  '팀원 간 메모 공유',
  '모바일 앱과 웹 동기화',
];

const pricingPlans = [
  {
    name: '무료',
    price: '0',
    description: '소규모 비즈니스를 위한 기본 기능',
    features: ['고객 100명까지', '기본 예약 관리', '메모 기능', '1개 사업장'],
    cta: '무료로 시작하기',
    highlighted: false,
  },
  {
    name: '프로',
    price: '29,000',
    description: '성장하는 비즈니스를 위한 확장 기능',
    features: [
      '고객 무제한',
      '고급 예약 관리',
      '음성 명령',
      '통계 및 분석',
      '3개 사업장',
      '우선 지원',
    ],
    cta: '프로 시작하기',
    highlighted: true,
  },
  {
    name: '엔터프라이즈',
    price: '문의',
    description: '대규모 조직을 위한 맞춤 솔루션',
    features: [
      '모든 프로 기능',
      '무제한 사업장',
      'API 액세스',
      '전담 매니저',
      'SLA 보장',
      '온보딩 지원',
    ],
    cta: '문의하기',
    highlighted: false,
  },
];

export function LandingPage() {
  return (
    <div className="min-h-screen bg-white">
      {/* Header */}
      <header className="fixed top-0 left-0 right-0 z-50 bg-white/80 backdrop-blur-md border-b border-gray-100">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex items-center justify-between h-16">
            <div className="flex items-center gap-2">
              <div className="w-8 h-8 bg-primary-800 rounded-lg flex items-center justify-center">
                <span className="text-white font-bold text-sm">V</span>
              </div>
              <span className="font-bold text-xl text-gray-900">VocaCRM</span>
            </div>

            <nav className="hidden md:flex items-center gap-8">
              <a href="#features" className="text-sm text-gray-600 hover:text-gray-900 transition-colors">
                기능
              </a>
              <a href="#pricing" className="text-sm text-gray-600 hover:text-gray-900 transition-colors">
                요금제
              </a>
            </nav>

            <div className="flex items-center gap-3">
              <Link to="/login">
                <Button variant="ghost" size="sm">
                  로그인
                </Button>
              </Link>
              <Link to="/login">
                <Button size="sm">
                  무료로 시작하기
                </Button>
              </Link>
            </div>
          </div>
        </div>
      </header>

      {/* Hero Section */}
      <section className="pt-32 pb-20 px-4 sm:px-6 lg:px-8">
        <div className="max-w-7xl mx-auto">
          <div className="text-center max-w-4xl mx-auto">
            <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-primary-50 text-primary-700 text-sm font-medium mb-6">
              <Sparkles className="w-4 h-4" />
              음성으로 더 쉬운 고객 관리
            </div>

            <h1 className="text-5xl sm:text-6xl font-bold text-gray-900 leading-tight mb-6">
              고객 관리를
              <br />
              <span className="text-primary-700">더 스마트하게</span>
            </h1>

            <p className="text-xl text-gray-600 mb-10 max-w-2xl mx-auto">
              음성 명령으로 고객을 검색하고, 예약을 관리하고, 메모를 기록하세요.
              VocaCRM으로 비즈니스 운영을 혁신하세요.
            </p>

            <div className="flex flex-col sm:flex-row items-center justify-center gap-4">
              <Link to="/login">
                <Button size="lg" rightIcon={<ArrowRight className="w-5 h-5" />}>
                  무료로 시작하기
                </Button>
              </Link>
              <a href="#features">
                <Button variant="outline" size="lg">
                  자세히 알아보기
                </Button>
              </a>
            </div>
          </div>

          {/* Hero Image Placeholder */}
          <div className="mt-16 relative">
            <div className="absolute inset-0 bg-gradient-to-b from-white via-transparent to-white z-10 pointer-events-none"></div>
            <div className="bg-gradient-to-br from-primary-50 to-primary-100 rounded-2xl shadow-2xl shadow-primary-500/10 aspect-[16/9] max-w-5xl mx-auto flex items-center justify-center border border-primary-200">
              <div className="text-center p-8">
                <div className="w-20 h-20 bg-primary-800 rounded-2xl flex items-center justify-center mx-auto mb-4">
                  <Mic className="w-10 h-10 text-white" />
                </div>
                <p className="text-lg font-medium text-primary-800">대시보드 미리보기</p>
                <p className="text-sm text-primary-600 mt-1">로그인 후 실시간 데이터를 확인하세요</p>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* Features Section */}
      <section id="features" className="py-20 px-4 sm:px-6 lg:px-8 bg-gray-50">
        <div className="max-w-7xl mx-auto">
          <div className="text-center mb-16">
            <h2 className="text-3xl sm:text-4xl font-bold text-gray-900 mb-4">
              모든 것을 한곳에서
            </h2>
            <p className="text-lg text-gray-600 max-w-2xl mx-auto">
              고객 관리에 필요한 모든 기능을 VocaCRM 하나로 해결하세요
            </p>
          </div>

          <div className="grid md:grid-cols-2 lg:grid-cols-4 gap-8">
            {features.map((feature) => (
              <div
                key={feature.title}
                className="bg-white p-6 rounded-xl border border-gray-200 hover:shadow-lg hover:border-primary-200 transition-all"
              >
                <div className="w-12 h-12 bg-primary-100 rounded-xl flex items-center justify-center mb-4">
                  <feature.icon className="w-6 h-6 text-primary-700" />
                </div>
                <h3 className="text-lg font-semibold text-gray-900 mb-2">
                  {feature.title}
                </h3>
                <p className="text-gray-600 text-sm">{feature.description}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* Benefits Section */}
      <section className="py-20 px-4 sm:px-6 lg:px-8">
        <div className="max-w-7xl mx-auto">
          <div className="grid lg:grid-cols-2 gap-12 items-center">
            <div>
              <h2 className="text-3xl sm:text-4xl font-bold text-gray-900 mb-6">
                왜 VocaCRM인가요?
              </h2>
              <p className="text-lg text-gray-600 mb-8">
                VocaCRM은 바쁜 현장에서도 쉽게 사용할 수 있도록 설계되었습니다.
                음성 명령과 직관적인 인터페이스로 업무 효율을 극대화하세요.
              </p>

              <div className="grid sm:grid-cols-2 gap-4">
                {benefits.map((benefit) => (
                  <div key={benefit} className="flex items-center gap-3">
                    <CheckCircle2 className="w-5 h-5 text-green-500 flex-shrink-0" />
                    <span className="text-gray-700">{benefit}</span>
                  </div>
                ))}
              </div>
            </div>

            <div className="grid grid-cols-2 gap-4">
              <div className="bg-gradient-to-br from-primary-500 to-primary-700 p-6 rounded-2xl text-white">
                <Shield className="w-8 h-8 mb-3" />
                <h4 className="font-semibold mb-1">안전한 데이터</h4>
                <p className="text-sm text-white/80">
                  모든 데이터는 암호화되어 안전하게 보관됩니다
                </p>
              </div>
              <div className="bg-gradient-to-br from-gray-800 to-gray-900 p-6 rounded-2xl text-white mt-8">
                <Zap className="w-8 h-8 mb-3" />
                <h4 className="font-semibold mb-1">빠른 속도</h4>
                <p className="text-sm text-white/80">
                  음성 검색으로 0.5초 만에 고객 정보를 찾으세요
                </p>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* Pricing Section */}
      <section id="pricing" className="py-20 px-4 sm:px-6 lg:px-8 bg-gray-50">
        <div className="max-w-7xl mx-auto">
          <div className="text-center mb-16">
            <h2 className="text-3xl sm:text-4xl font-bold text-gray-900 mb-4">
              심플한 요금제
            </h2>
            <p className="text-lg text-gray-600">
              비즈니스 규모에 맞는 요금제를 선택하세요
            </p>
          </div>

          <div className="grid md:grid-cols-3 gap-8 max-w-5xl mx-auto">
            {pricingPlans.map((plan) => (
              <div
                key={plan.name}
                className={`bg-white rounded-2xl p-8 ${
                  plan.highlighted
                    ? 'ring-2 ring-primary-500 shadow-xl'
                    : 'border border-gray-200'
                }`}
              >
                {plan.highlighted && (
                  <div className="inline-block px-3 py-1 bg-primary-100 text-primary-700 text-xs font-semibold rounded-full mb-4">
                    가장 인기
                  </div>
                )}
                <h3 className="text-xl font-bold text-gray-900">{plan.name}</h3>
                <div className="mt-4 mb-6">
                  <span className="text-4xl font-bold text-gray-900">
                    {plan.price === '문의' ? '' : '₩'}
                    {plan.price}
                  </span>
                  {plan.price !== '문의' && (
                    <span className="text-gray-500">/월</span>
                  )}
                </div>
                <p className="text-gray-600 text-sm mb-6">{plan.description}</p>

                <ul className="space-y-3 mb-8">
                  {plan.features.map((feature) => (
                    <li key={feature} className="flex items-center gap-3 text-sm">
                      <CheckCircle2 className="w-4 h-4 text-green-500 flex-shrink-0" />
                      <span className="text-gray-700">{feature}</span>
                    </li>
                  ))}
                </ul>

                <Link to="/login" className="block">
                  <Button
                    className="w-full"
                    variant={plan.highlighted ? 'primary' : 'outline'}
                  >
                    {plan.cta}
                  </Button>
                </Link>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* CTA Section */}
      <section className="py-20 px-4 sm:px-6 lg:px-8">
        <div className="max-w-4xl mx-auto text-center">
          <h2 className="text-3xl sm:text-4xl font-bold text-gray-900 mb-6">
            지금 바로 시작하세요
          </h2>
          <p className="text-lg text-gray-600 mb-8">
            무료로 VocaCRM을 체험하고 비즈니스를 성장시키세요
          </p>
          <Link to="/login">
            <Button size="lg" rightIcon={<ArrowRight className="w-5 h-5" />}>
              무료로 시작하기
            </Button>
          </Link>
        </div>
      </section>

      {/* Footer */}
      <footer className="py-12 px-4 sm:px-6 lg:px-8 border-t border-gray-200">
        <div className="max-w-7xl mx-auto">
          <div className="flex flex-col md:flex-row items-center justify-between gap-4">
            <div className="flex items-center gap-2">
              <div className="w-8 h-8 bg-primary-800 rounded-lg flex items-center justify-center">
                <span className="text-white font-bold text-sm">V</span>
              </div>
              <span className="font-bold text-lg text-gray-900">VocaCRM</span>
            </div>

            <p className="text-sm text-gray-500">
              © 2024 VocaCRM. All rights reserved.
            </p>
          </div>
        </div>
      </footer>
    </div>
  );
}
