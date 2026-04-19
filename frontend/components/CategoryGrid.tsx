'use client';

import { useState } from 'react';
import { ALL_CATEGORIES, colorGroup } from '@/lib/categories';
import Chip from './Chip';
import type { Item } from '@/types';
import styles from './CategoryGrid.module.css';

interface Props {
  items: Item[];
}

export default function CategoryGrid({ items }: Props) {
  const [selected, setSelected] = useState<string | null>(null);

  const countFor = (cat: string) =>
    items.filter(i => i.categories.includes(cat)).length;

  if (selected !== null) {
    const receipts = items.filter(i => i.categories.includes(selected));
    return (
      <>
        <div className={styles.drillHeader}>
          <button className={styles.backBtn} onClick={() => setSelected(null)}>← Back</button>
          <Chip category={selected} />
        </div>
        {receipts.length === 0 ? (
          <div className={styles.drillEmpty}>No receipts in this category yet.</div>
        ) : (
          <ul className={styles.drillList}>
            {receipts.map(item => (
              <li key={item.key} className={styles.drillRow}>
                <span className={styles.drillName}>{item.name}</span>
                <span className={`${styles.drillTime} mono`}>{item.time}</span>
              </li>
            ))}
          </ul>
        )}
      </>
    );
  }

  return (
    <div className={styles.grid}>
      {ALL_CATEGORIES.map(cat => {
        const group = colorGroup(cat);
        const count = countFor(cat);
        return (
          <button
            key={cat}
            className={styles.card}
            data-group={group}
            onClick={() => setSelected(cat)}
          >
            <div className={styles.cardTop}>
              <span className={styles.swatch} />
              <span className={`${styles.count} ${count > 0 ? styles.hasItems : ''}`}>
                {count}
              </span>
            </div>
            <span className={styles.name}>{cat}</span>
          </button>
        );
      })}
    </div>
  );
}
