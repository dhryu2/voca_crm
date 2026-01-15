import {
  ResponsiveContainer,
  BarChart,
  Bar,
  XAxis,
  YAxis,
  Tooltip,
  Cell,
} from 'recharts';
import { cn } from '@/lib/utils';

interface DistributionDataPoint {
  name: string;
  value: number;
  color?: string;
}

interface DistributionChartProps {
  data: DistributionDataPoint[];
  height?: number;
  showValues?: boolean;
  className?: string;
}

const DEFAULT_COLORS = [
  '#eab308', // VIP - yellow
  '#f59e0b', // GOLD - amber
  '#9ca3af', // SILVER - gray
  '#f97316', // BRONZE - orange
  '#3b82f6', // NORMAL - blue
];

export function DistributionChart({
  data,
  height = 200,
  showValues = true,
  className,
}: DistributionChartProps) {
  if (!data || data.length === 0) {
    return (
      <div className={cn('flex items-center justify-center text-gray-400', className)} style={{ height }}>
        데이터가 없습니다
      </div>
    );
  }

  const total = data.reduce((sum, item) => sum + item.value, 0);

  return (
    <div className={className} style={{ height }}>
      <ResponsiveContainer width="100%" height="100%">
        <BarChart
          data={data}
          layout="vertical"
          margin={{ top: 5, right: 30, left: 50, bottom: 5 }}
        >
          <XAxis type="number" hide />
          <YAxis
            type="category"
            dataKey="name"
            tick={{ fontSize: 12, fill: '#374151' }}
            axisLine={false}
            tickLine={false}
            width={60}
          />
          <Tooltip
            formatter={(value) => [
              `${value}명 (${Math.round((Number(value) / total) * 100)}%)`,
              '',
            ]}
            contentStyle={{
              backgroundColor: 'white',
              border: '1px solid #e5e7eb',
              borderRadius: '8px',
            }}
          />
          <Bar
            dataKey="value"
            radius={[0, 4, 4, 0]}
            animationDuration={800}
          >
            {data.map((entry, index) => (
              <Cell
                key={`cell-${index}`}
                fill={entry.color || DEFAULT_COLORS[index % DEFAULT_COLORS.length]}
              />
            ))}
          </Bar>
        </BarChart>
      </ResponsiveContainer>

      {showValues && (
        <div className="mt-2 text-center text-sm text-gray-600">
          총 {total.toLocaleString()}명
        </div>
      )}
    </div>
  );
}
