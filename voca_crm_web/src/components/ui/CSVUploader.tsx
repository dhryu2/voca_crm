import { useCallback } from 'react';
import { useCSVReader } from 'react-papaparse';
import { Upload, X, FileText } from 'lucide-react';
import { cn } from '@/lib/utils';

interface CSVUploaderProps<T> {
  onUpload: (data: T[]) => void;
  expectedHeaders?: string[];
  className?: string;
}

export function CSVUploader<T extends object>({
  onUpload,
  expectedHeaders,
  className,
}: CSVUploaderProps<T>) {
  const { CSVReader } = useCSVReader();

  const handleUpload = useCallback(
    (results: { data: string[][] }) => {
      const [headers, ...rows] = results.data;

      // 헤더 검증 (선택적)
      if (expectedHeaders) {
        const missingHeaders = expectedHeaders.filter(
          (h) => !headers.includes(h)
        );
        if (missingHeaders.length > 0) {
          alert(`필수 컬럼이 없습니다: ${missingHeaders.join(', ')}`);
          return;
        }
      }

      // 데이터 변환
      const data = rows
        .filter((row) => row.some((cell) => cell.trim())) // 빈 행 제거
        .map((row) => {
          const obj: Record<string, string> = {};
          headers.forEach((header, index) => {
            obj[header.trim()] = row[index]?.trim() || '';
          });
          return obj as T;
        });

      onUpload(data);
    },
    [onUpload, expectedHeaders]
  );

  return (
    <CSVReader
      onUploadAccepted={handleUpload}
      config={{
        encoding: 'UTF-8',
      }}
    >
      {({
        getRootProps,
        acceptedFile,
        ProgressBar,
        getRemoveFileProps,
      }: {
        getRootProps: () => object;
        acceptedFile: File | null;
        ProgressBar: React.ComponentType;
        getRemoveFileProps: () => { onClick?: () => void };
      }) => (
        <div className={cn('space-y-2', className)}>
          <div
            {...getRootProps()}
            className={cn(
              'border-2 border-dashed rounded-lg p-6 text-center cursor-pointer transition-colors',
              'hover:border-primary-500 hover:bg-primary-50/50',
              acceptedFile ? 'border-green-500 bg-green-50' : 'border-gray-300'
            )}
          >
            {acceptedFile ? (
              <div className="flex items-center justify-center gap-2">
                <FileText className="w-5 h-5 text-green-600" />
                <span className="text-green-700 font-medium">
                  {acceptedFile.name}
                </span>
                <button
                  className="p-1 rounded-full hover:bg-green-200 transition-colors"
                  onClick={(e) => {
                    e.stopPropagation();
                    const props = getRemoveFileProps();
                    if (props.onClick) props.onClick();
                  }}
                >
                  <X className="w-4 h-4 text-green-600" />
                </button>
              </div>
            ) : (
              <div className="space-y-2">
                <Upload className="w-8 h-8 text-gray-400 mx-auto" />
                <p className="text-gray-600">
                  CSV 파일을 여기에 드래그하거나 클릭하여 선택
                </p>
                <p className="text-xs text-gray-400">
                  UTF-8 인코딩 권장
                </p>
              </div>
            )}
          </div>
          <ProgressBar />
        </div>
      )}
    </CSVReader>
  );
}
