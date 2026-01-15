import Papa from 'papaparse';

interface UseCSVExportOptions {
  filename?: string;
  headers?: Record<string, string>; // 컬럼명 매핑 (영어 키 -> 한글 헤더)
}

export function useCSVExport<T extends object>() {
  const exportToCSV = (
    data: T[],
    options: UseCSVExportOptions = {}
  ) => {
    const { filename = 'export', headers } = options;

    // 헤더 매핑이 있으면 적용
    let exportData = data;
    if (headers) {
      exportData = data.map(row => {
        const mapped: Record<string, unknown> = {};
        for (const [key, value] of Object.entries(row)) {
          const header = headers[key] || key;
          mapped[header] = value;
        }
        return mapped as T;
      });
    }

    const csv = Papa.unparse(exportData, {
      quotes: true,
      header: true,
    });

    // BOM for Excel Korean support
    const blob = new Blob(['\ufeff' + csv], {
      type: 'text/csv;charset=utf-8;',
    });

    const link = document.createElement('a');
    link.href = URL.createObjectURL(blob);
    link.download = `${filename}.csv`;
    link.click();
    URL.revokeObjectURL(link.href);
  };

  return { exportToCSV };
}
