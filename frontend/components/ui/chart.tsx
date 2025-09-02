import * as React from "react"
import {
  Bar,
  BarChart,
  Line,
  LineChart,
  Pie,
  PieChart,
  Cell,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  Legend,
  ResponsiveContainer,
} from "recharts"
import { useTranslation } from "next-i18next"

interface ChartProps {
  data: any[]
  type: "bar" | "line" | "pie"
  dataKey: string
  xAxisKey?: string
  title?: string
  colors?: string[]
  height?: number
}

const defaultColors = [
  "#4F46E5", // Primary
  "#10B981", // Secondary
  "#EF4444", // Danger
  "#F59E0B", // Warning
  "#3B82F6", // Info
  "#8B5CF6", // Purple
  "#06B6D4", // Cyan
  "#84CC16", // Lime
]

export function Chart({
  data,
  type,
  dataKey,
  xAxisKey = "name",
  title,
  colors = defaultColors,
  height = 300,
}: ChartProps) {
  const { t } = useTranslation("common")

  const renderChart = () => {
    switch (type) {
      case "bar":
        return (
          <BarChart data={data}>
            <CartesianGrid strokeDasharray="3 3" />
            <XAxis
              dataKey={xAxisKey}
              fontSize={12}
              tick={{ fill: "hsl(var(--muted-foreground))" }}
            />
            <YAxis
              fontSize={12}
              tick={{ fill: "hsl(var(--muted-foreground))" }}
            />
            <Tooltip
              contentStyle={{
                backgroundColor: "hsl(var(--background))",
                border: "1px solid hsl(var(--border))",
                borderRadius: "6px",
              }}
            />
            <Legend />
            <Bar dataKey={dataKey} fill={colors[0]} />
          </BarChart>
        )

      case "line":
        return (
          <LineChart data={data}>
            <CartesianGrid strokeDasharray="3 3" />
            <XAxis
              dataKey={xAxisKey}
              fontSize={12}
              tick={{ fill: "hsl(var(--muted-foreground))" }}
            />
            <YAxis
              fontSize={12}
              tick={{ fill: "hsl(var(--muted-foreground))" }}
            />
            <Tooltip
              contentStyle={{
                backgroundColor: "hsl(var(--background))",
                border: "1px solid hsl(var(--border))",
                borderRadius: "6px",
              }}
            />
            <Legend />
            <Line
              type="monotone"
              dataKey={dataKey}
              stroke={colors[0]}
              strokeWidth={2}
              dot={{ fill: colors[0] }}
            />
          </LineChart>
        )

      case "pie":
        return (
          <PieChart>
            <Pie
              data={data}
              cx="50%"
              cy="50%"
              labelLine={false}
              label={({ name, percent }) => `${name} ${(percent * 100).toFixed(0)}%`}
              outerRadius={80}
              fill="#8884d8"
              dataKey={dataKey}
            >
              {data.map((entry, index) => (
                <Cell key={`cell-${index}`} fill={colors[index % colors.length]} />
              ))}
            </Pie>
            <Tooltip
              contentStyle={{
                backgroundColor: "hsl(var(--background))",
                border: "1px solid hsl(var(--border))",
                borderRadius: "6px",
              }}
            />
            <Legend />
          </PieChart>
        )

      default:
        return null
    }
  }

  return (
    <div className="w-full">
      {title && (
        <h3 className="text-lg font-semibold mb-4 text-center">{title}</h3>
      )}
      <ResponsiveContainer width="100%" height={height}>
        {renderChart()}
      </ResponsiveContainer>
    </div>
  )
}

export default Chart
