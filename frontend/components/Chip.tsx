import { colorGroup } from '@/lib/categories';
import styles from './Chip.module.css';

interface Props {
  category?: string;
  empty?: boolean;
  label?: string;
}

export default function Chip({ category, empty, label }: Props) {
  if (empty || !category) {
    return (
      <span className={`${styles.chip} ${styles.neutral}`}>
        <span className={styles.swatch} />
        {label ?? 'Waiting for upload'}
      </span>
    );
  }
  const group = colorGroup(category);
  return (
    <span className={`${styles.chip} ${styles[group]}`}>
      <span className={styles.swatch} />
      {category}
    </span>
  );
}
