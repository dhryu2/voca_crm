import {
  ResponsiveContainer,
  AreaChart,
  Area,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
} from 'recharts';
import { cn } from '@/lib/utils';

interface TrendDataPoint {
  date: string;
  count: number;
}

interface TrendChartProps {
  data: TrendDataPoint[];
  color?: string;
  gradientId?: string;
  height?: number;
  dateFormatter?: (date: string) => string;
  valueLabel?: string;
  className?: string;
}

export function TrendChart({
  data,
  color = '#3b82f6',
  gradientId = 'trendGradient',
  height = 200,
  dateFormatter = (date) => `${new Date(date).getDate()}일`,
  valueLabel = '건',
  className,
}: TrendChartProps) {
  if (!data || data.length === 0) {
    return (
      <div className={cn('flex items-center justify-center text-gray-400', className)} style={{ height }}>
        데이터가 없습니다
      </div>
    );
  }

  return (
    <div className={className} style={{ height }}>
      <ResponsiveContainer width="100%" height="100%">
        <AreaChart data={data} margin={{ top: 10, right: 10, left: -20, bottom: 0 }}>
          <defs>
            <linearGradient id={gradientId} x1="0" y1="0" x2="0" y2="1">
              <stop offset="5%" stopColor={color} stopOpacity={0.8} />
              <stop offset="95%" stopColor={color} stopOpacity={0.1} />
            </linearGradient>
          </defs>
          <CartesianGrid strokeDasharray="3 3" stroke="#e5e7eb" />
          <XAxis
            dataKey="date"
            tickFormatter={dateFormatter}
            tick={{ fontSize: 12, fill: '#6b7280' }}
            axisLine={{ stroke: '#e5e7eb' }}
          />
          <YAxis
            tick={{ fontSize: 12, fill: '#6b7280' }}
            axisLine={{ stroke: '#e5e7eb' }}
            allowDecimals={false}
          />
          <Tooltip
            labelFormatter={(date) => new Date(date).toLocaleDateString('ko-KR')}
            formatter={(value) => [`${value}${valueLabel}`, '']}
            contentStyle={{
              backgroundColor: 'white',
              border: '1px solid #e5e7eb',
              borderRadius: '8px',
              boxShadow: '0 2px 8px rgba(0,0,0,0.1)',
            }}
          />
          <Area
            type="monotone"
            dataKey="count"
            stroke={color}
            strokeWidth={2}
            fill={`url(#${gradientId})`}
            animationDuration={800}
          />
        </AreaChart>
      </ResponsiveContainer>
    </div>
  );
}
