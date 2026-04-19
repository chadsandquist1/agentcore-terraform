'use client';

import { useState, useCallback, useEffect } from 'react';
import Logo from '@/components/Logo';
import Dropzone from '@/components/Dropzone';
import Chip from '@/components/Chip';
import HistoryList from '@/components/HistoryList';
import { presign, uploadFile, pollResult } from '@/lib/api';
import { loadItems, saveItems } from '@/lib/storage';
import type { Item } from '@/types';
import styles from './upload.module.css';

function formatTime(d: Date): string {
  const p = (n: number) => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())} ${p(d.getHours())}:${p(d.getMinutes())}`;
}

export default function UploadPage() {
  const [items, setItems] = useState<Item[]>([]);
  const [isBusy, setIsBusy] = useState(false);
  const [previewSrc, setPreviewSrc] = useState<string | undefined>();
  const [currentFile, setCurrentFile] = useState<string>('');
  const [currentCategories, setCurrentCategories] = useState<string[]>([]);
  const [currentDesc, setCurrentDesc] = useState('');
  const [classifying, setClassifying] = useState(false);
  const [hasFile, setHasFile] = useState(false);

  useEffect(() => {
    setItems(loadItems());
  }, []);

  const reset = useCallback(() => {
    setPreviewSrc(undefined);
    setCurrentFile('');
    setCurrentCategories([]);
    setCurrentDesc('');
    setIsBusy(false);
    setClassifying(false);
    setHasFile(false);
  }, []);

  const handleFile = useCallback(async (file: File) => {
    const reader = new FileReader();
    reader.onload = async (e) => {
      const src = e.target?.result as string;
      setPreviewSrc(src);
      setCurrentFile(file.name);
      setCurrentCategories([]);
      setCurrentDesc('');
      setClassifying(true);
      setIsBusy(true);
      setHasFile(true);

      try {
        const { uploadUrl, key } = await presign(file.name);
        await uploadFile(uploadUrl, file);
        const result = await pollResult(key);

        const cats: string[] = result.categories
          ?? (result.category ? [result.category] : ['Not able to classify']);
        const desc = result.description ?? '';

        setCurrentCategories(cats);
        setCurrentDesc(desc);
        setClassifying(false);
        setIsBusy(false);

        const item: Item = {
          key,
          name: file.name,
          categories: cats,
          description: desc,
          src,
          time: formatTime(new Date()),
        };
        setItems(prev => {
          const next = [item, ...prev];
          saveItems(next);
          return next;
        });
      } catch (err) {
        console.error(err);
        setCurrentCategories(['Not able to classify']);
        setCurrentDesc('Classification failed. Please try again.');
        setClassifying(false);
        setIsBusy(false);
      }
    };
    reader.readAsDataURL(file);
  }, []);

  const chipLabel = classifying ? 'Classifying…' : undefined;

  return (
    <main className={styles.page}>
      <header className={styles.header}>
        <Logo />
        <h1 className={styles.title}>Receipt Classification</h1>
        <p className={styles.subtitle}>Please drop in an image of a receipt.</p>
        <div className={styles.segmented} role="tablist" aria-label="View">
          <button className={styles.seg} role="tab" aria-selected={true}>Upload</button>
        </div>
      </header>

      <section className={styles.card} aria-label="Upload receipt">
        <Dropzone onFile={handleFile} isBusy={isBusy} previewSrc={previewSrc} />

        <div className={styles.caption}>
          <div className={styles.captionLeft}>
            <div className={styles.captionRow} aria-live="polite">
              {classifying ? (
                <Chip empty label="Classifying…" />
              ) : currentCategories.length > 0 ? (
                currentCategories.map(cat => <Chip key={cat} category={cat} />)
              ) : (
                <Chip empty />
              )}
              {currentFile && (
                <span className={`${styles.fname} mono`}>{currentFile}</span>
              )}
            </div>
            {currentDesc && (
              <div className={styles.desc}>{currentDesc}</div>
            )}
          </div>
          {hasFile && (
            <button className={styles.btnClear} onClick={reset}>Clear</button>
          )}
        </div>
      </section>

      <HistoryList items={items} />

      <p className={`${styles.footnote} mono`}>proof of concept · v0.1</p>
    </main>
  );
}
