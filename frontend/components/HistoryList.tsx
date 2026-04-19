import type { Item } from '@/types';
import Chip from './Chip';
import styles from './HistoryList.module.css';

interface Props {
  items: Item[];
}

export default function HistoryList({ items }: Props) {
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
            <li key={item.key} className={styles.row}>
              <div
                className={styles.thumb}
                style={{ backgroundImage: `url('${item.src}')` }}
              />
              <div className={styles.meta}>
                <div className={styles.name}>{item.name}</div>
                {item.description && (
                  <div className={styles.sub}>{item.description}</div>
                )}
              </div>
              <div className={styles.chipWrap}>
                <Chip category={item.categories[0]} />
              </div>
            </li>
          ))}
        </ul>
      )}
    </>
  );
}
