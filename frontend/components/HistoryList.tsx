import type { Item } from '@/types';
import Chip from './Chip';
import styles from './HistoryList.module.css';

interface Props {
  items: Item[];
  selectedKey?: string;
  onSelect: (item: Item) => void;
  onDelete: (key: string) => void;
}

export default function HistoryList({ items, selectedKey, onSelect, onDelete }: Props) {
  const n = items.length;
  return (
    <>
      <div className={styles.section}>
        <h2 className={styles.heading}>Recent</h2>
        <span className={`${styles.count} mono`}>{n === 1 ? '1 item' : `${n} items`}</span>
      </div>

      {n === 0 ? (
        <div className={styles.empty}>
          No receipts yet. Your classified receipts will appear here.
        </div>
      ) : (
        <ul className={styles.list} aria-live="polite">
          {items.map(item => (
            <li
              key={item.key}
              className={`${styles.row} ${item.key === selectedKey ? styles.selected : ''}`}
              onClick={() => onSelect(item)}
            >
              <div
                className={styles.thumb}
                style={{ backgroundImage: `url('${item.src}')` }}
              />
              <div className={styles.meta}>
                <div className={styles.name}>{item.name}</div>
                <div className={`${styles.time} mono`}>{item.time}</div>
              </div>
              <div className={styles.chipWrap}>
                <Chip category={item.categories[0]} />
                <button
                  className={styles.deleteBtn}
                  onClick={e => { e.stopPropagation(); onDelete(item.key); }}
                  aria-label={`Delete ${item.name}`}
                >
                  ×
                </button>
              </div>
            </li>
          ))}
        </ul>
      )}
    </>
  );
}
