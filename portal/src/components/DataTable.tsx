import { ReactNode } from "react";

export type DataTableColumn<T> = {
  key: string;
  header: string;
  sortable?: boolean;
  render?: (row: T) => ReactNode;
  className?: string;
};

export type DataTableProps<T> = {
  columns: DataTableColumn<T>[];
  rows: T[];
  rowKey: (row: T) => string;
  search?: string;
  onSearchChange?: (value: string) => void;
  searchPlaceholder?: string;
  statusFilter?: string;
  onStatusFilterChange?: (value: string) => void;
  statusOptions?: { value: string; label: string }[];
  sort?: string;
  order?: "asc" | "desc";
  onSortChange?: (key: string) => void;
  emptyMessage?: string;
  toolbarExtra?: ReactNode;
};

export default function DataTable<T>({
  columns,
  rows,
  rowKey,
  search = "",
  onSearchChange,
  searchPlaceholder = "Search…",
  statusFilter,
  onStatusFilterChange,
  statusOptions,
  sort,
  order = "desc",
  onSortChange,
  emptyMessage = "No rows match your filters.",
  toolbarExtra,
}: DataTableProps<T>) {
  const showToolbar =
    onSearchChange ||
    onStatusFilterChange ||
    statusOptions?.length ||
    toolbarExtra;

  function toggleSort(key: string) {
    if (!onSortChange) return;
    onSortChange(key);
  }

  return (
    <div className="data-table-root">
      {showToolbar && (
        <div className="data-table-toolbar">
          {onSearchChange && (
            <input
              type="search"
              className="data-table-search"
              placeholder={searchPlaceholder}
              value={search}
              onChange={(e) => onSearchChange(e.target.value)}
              aria-label="Search table"
            />
          )}
          {statusOptions && onStatusFilterChange && (
            <select
              className="data-table-status"
              value={statusFilter ?? ""}
              onChange={(e) => onStatusFilterChange(e.target.value)}
              aria-label="Filter by status"
            >
              {statusOptions.map((o) => (
                <option key={o.value || "__all"} value={o.value}>
                  {o.label}
                </option>
              ))}
            </select>
          )}
          {toolbarExtra}
        </div>
      )}
      <div className="table-wrap">
        <table className="data-table">
          <thead>
            <tr>
              {columns.map((col) => (
                <th key={col.key} className={col.className}>
                  {col.sortable && onSortChange ? (
                    <button
                      type="button"
                      className={`data-table-sort${sort === col.key ? " is-active" : ""}`}
                      onClick={() => toggleSort(col.key)}
                    >
                      {col.header}
                      {sort === col.key ? (
                        <span className="data-table-sort-dir" aria-hidden>
                          {order === "asc" ? " ↑" : " ↓"}
                        </span>
                      ) : null}
                    </button>
                  ) : (
                    col.header
                  )}
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {rows.length === 0 ? (
              <tr>
                <td colSpan={columns.length} className="data-table-empty">
                  {emptyMessage}
                </td>
              </tr>
            ) : (
              rows.map((row) => (
                <tr key={rowKey(row)}>
                  {columns.map((col) => (
                    <td key={col.key} className={col.className}>
                      {col.render
                        ? col.render(row)
                        : String((row as Record<string, unknown>)[col.key] ?? "—")}
                    </td>
                  ))}
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}
