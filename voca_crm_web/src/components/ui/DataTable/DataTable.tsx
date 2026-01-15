import { useState } from 'react';
import type { ReactNode } from 'react';
import {
  useReactTable,
  getCoreRowModel,
  getSortedRowModel,
  getFilteredRowModel,
  getPaginationRowModel,
  flexRender,
  type ColumnDef,
  type RowSelectionState,
  type SortingState,
  type ColumnFiltersState,
  type PaginationState,
} from '@tanstack/react-table';
import { ChevronUp, ChevronDown, ChevronsUpDown } from 'lucide-react';
import { cn } from '@/lib/utils';

interface DataTableProps<T> {
  data: T[];
  columns: ColumnDef<T, unknown>[];
  enableRowSelection?: boolean;
  enableSorting?: boolean;
  enableFiltering?: boolean;
  enablePagination?: boolean;
  pageSize?: number;
  onRowSelectionChange?: (selectedRows: T[]) => void;
  renderBulkActions?: (selectedRows: T[]) => ReactNode;
  emptyMessage?: string;
  className?: string;
}

export function DataTable<T>({
  data,
  columns,
  enableRowSelection = false,
  enableSorting = true,
  enableFiltering = false,
  enablePagination = true,
  pageSize = 10,
  onRowSelectionChange,
  renderBulkActions,
  emptyMessage = '데이터가 없습니다',
  className,
}: DataTableProps<T>) {
  const [sorting, setSorting] = useState<SortingState>([]);
  const [rowSelection, setRowSelection] = useState<RowSelectionState>({});
  const [columnFilters, setColumnFilters] = useState<ColumnFiltersState>([]);
  const [globalFilter, setGlobalFilter] = useState('');
  const [pagination, setPagination] = useState<PaginationState>({
    pageIndex: 0,
    pageSize,
  });

  // CRITICAL: columns가 외부에서 memoized되어야 함
  // data도 stable reference 필수
  const table = useReactTable({
    data,
    columns,
    state: {
      sorting,
      rowSelection,
      columnFilters,
      globalFilter,
      pagination,
    },
    onSortingChange: setSorting,
    onRowSelectionChange: (updater) => {
      const newSelection = typeof updater === 'function'
        ? updater(rowSelection)
        : updater;
      setRowSelection(newSelection);

      if (onRowSelectionChange) {
        const selectedRows = Object.keys(newSelection)
          .filter(key => newSelection[key])
          .map(key => data[parseInt(key)]);
        onRowSelectionChange(selectedRows);
      }
    },
    onColumnFiltersChange: setColumnFilters,
    onGlobalFilterChange: setGlobalFilter,
    onPaginationChange: setPagination,
    getCoreRowModel: getCoreRowModel(),
    getSortedRowModel: enableSorting ? getSortedRowModel() : undefined,
    getFilteredRowModel: enableFiltering ? getFilteredRowModel() : undefined,
    getPaginationRowModel: enablePagination ? getPaginationRowModel() : undefined,
    enableRowSelection,
  });

  const selectedCount = Object.keys(rowSelection).filter(k => rowSelection[k]).length;

  return (
    <div className={cn('space-y-4', className)}>
      {/* Bulk Actions Bar */}
      {enableRowSelection && selectedCount > 0 && renderBulkActions && (
        <div className="p-3 bg-blue-50 rounded-lg flex items-center gap-4">
          <span className="text-sm font-medium text-blue-700">
            {selectedCount}개 선택됨
          </span>
          {renderBulkActions(
            table.getSelectedRowModel().rows.map(row => row.original)
          )}
        </div>
      )}

      {/* Global Filter */}
      {enableFiltering && (
        <input
          type="text"
          value={globalFilter}
          onChange={(e) => setGlobalFilter(e.target.value)}
          placeholder="검색..."
          className="w-full max-w-sm px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
        />
      )}

      {/* Table */}
      <div className="overflow-x-auto border border-gray-200 rounded-lg">
        <table className="w-full text-sm">
          <thead className="bg-gray-50 border-b border-gray-200">
            {table.getHeaderGroups().map(headerGroup => (
              <tr key={headerGroup.id}>
                {headerGroup.headers.map(header => (
                  <th
                    key={header.id}
                    className={cn(
                      'px-4 py-3 text-left font-medium text-gray-700',
                      header.column.getCanSort() && 'cursor-pointer select-none hover:bg-gray-100'
                    )}
                    onClick={header.column.getToggleSortingHandler()}
                  >
                    <div className="flex items-center gap-2">
                      {header.isPlaceholder
                        ? null
                        : flexRender(header.column.columnDef.header, header.getContext())}
                      {header.column.getCanSort() && (
                        <span className="text-gray-400">
                          {header.column.getIsSorted() === 'asc' ? (
                            <ChevronUp className="w-4 h-4" />
                          ) : header.column.getIsSorted() === 'desc' ? (
                            <ChevronDown className="w-4 h-4" />
                          ) : (
                            <ChevronsUpDown className="w-4 h-4" />
                          )}
                        </span>
                      )}
                    </div>
                  </th>
                ))}
              </tr>
            ))}
          </thead>
          <tbody className="divide-y divide-gray-200">
            {table.getRowModel().rows.length === 0 ? (
              <tr>
                <td
                  colSpan={columns.length}
                  className="px-4 py-8 text-center text-gray-500"
                >
                  {emptyMessage}
                </td>
              </tr>
            ) : (
              table.getRowModel().rows.map(row => (
                <tr
                  key={row.id}
                  className={cn(
                    'hover:bg-gray-50',
                    row.getIsSelected() && 'bg-blue-50'
                  )}
                >
                  {row.getVisibleCells().map(cell => (
                    <td key={cell.id} className="px-4 py-3">
                      {flexRender(cell.column.columnDef.cell, cell.getContext())}
                    </td>
                  ))}
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>

      {/* Pagination */}
      {enablePagination && table.getPageCount() > 1 && (
        <div className="flex items-center justify-between">
          <span className="text-sm text-gray-600">
            총 {data.length}개 중 {pagination.pageIndex * pagination.pageSize + 1}-
            {Math.min((pagination.pageIndex + 1) * pagination.pageSize, data.length)}개
          </span>
          <div className="flex items-center gap-2">
            <button
              onClick={() => table.previousPage()}
              disabled={!table.getCanPreviousPage()}
              className="px-3 py-1 text-sm border border-gray-300 rounded hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed"
            >
              이전
            </button>
            <span className="text-sm text-gray-600">
              {pagination.pageIndex + 1} / {table.getPageCount()}
            </span>
            <button
              onClick={() => table.nextPage()}
              disabled={!table.getCanNextPage()}
              className="px-3 py-1 text-sm border border-gray-300 rounded hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed"
            >
              다음
            </button>
          </div>
        </div>
      )}
    </div>
  );
}
