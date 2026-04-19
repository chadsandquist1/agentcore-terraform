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

  // current upload state
  const [isBusy, setIsBusy] = useState(false);
  const [previewSrc, setPreviewSrc] = useState<string | undefined>();
  const [currentFile, setCurrentFile] = useState<string>('');
  const [currentCategories, setCurrentCategories] = useState<string[]>([]);
  const [currentReasoning, setCurrentReasoning] = useState('');
  const [classifying, setClassifying] = useState(false);
  const [hasFile, setHasFile] = useState(false);

  // history viewing state
  const [viewingItem, setViewingItem] = useState<Item | null>(null);

  useEffect(() => {
    setItems(loadItems());
  }, []);

  const reset = useCallback(() => {
    setPreviewSrc(undefined);
    setCurrentFile('');
    setCurrentCategories([]);
    setCurrentReasoning('');
    setIsBusy(false);
    setClassifying(false);
    setHasFile(false);
  }, []);

  const handleFile = useCallback(async (file: File) => {
    // leaving history view when a new file is dropped
    setViewingItem(null);

    const reader = new FileReader();
    reader.onload = async (e) => {
      const src = e.target?.result as string;
      setPreviewSrc(src);
      setCurrentFile(file.name);
      setCurrentCategories([]);
      setCurrentReasoning('');
      setClassifying(true);
      setIsBusy(true);
      setHasFile(true);

      try {
        const { uploadUrl, key } = await presign(file.name);
        await uploadFile(uploadUrl, file);
        const result = await pollResult(key);

        const cats: string[] = result.categories
          ?? (result.category ? [result.category] : ['Not able to classify']);
        const reasoning = result.reasoning ?? '';

        setCurrentCategories(cats);
        setCurrentReasoning(reasoning);
        setClassifying(false);
        setIsBusy(false);

        const item: Item = {
          key,
          name: file.name,
          categories: cats,
          reasoning,
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
        setCurrentReasoning('Classification failed. Please try again.');
        setClassifying(false);
        setIsBusy(false);
      }
    };
    reader.readAsDataURL(file);
  }, []);

  const handleSelectHistory = useCallback((item: Item) => {
    setViewingItem(item);
  }, []);

  const handleBack = useCallback(() => {
    setViewingItem(null);
  }, []);

  const handleDelete = useCallback((key: string) => {
    setItems(prev => {
      const next = prev.filter(i => i.key !== key);
      saveItems(next);
      return next;
    });
    setViewingItem(prev => (prev?.key === key ? null : prev));
  }, []);

  // what the dropzone / caption shows depends on whether we're viewing history
  const displaySrc = viewingItem ? viewingItem.src : previewSrc;
  const displayCategories = viewingItem ? viewingItem.categories : currentCategories;
  const displayReasoning = viewingItem ? viewingItem.reasoning : currentReasoning;
  const displayFile = viewingItem ? viewingItem.name : currentFile;
  const isClassifying = !viewingItem && classifying;

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
        <Dropzone
          onFile={handleFile}
          isBusy={isBusy}
          previewSrc={displaySrc}
          readOnly={!!viewingItem}
        />

        <div className={styles.caption}>
          <div className={styles.captionLeft}>
            <div className={styles.captionRow} aria-live="polite">
              {isClassifying ? (
                <Chip empty label="Classifying…" />
              ) : displayCategories.length > 0 ? (
                displayCategories.map(cat => <Chip key={cat} category={cat} />)
              ) : (
                <Chip empty />
              )}
              {displayFile && (
                <span className={`${styles.fname} mono`}>{displayFile}</span>
              )}
            </div>
            {displayReasoning && (
              <div className={styles.desc}>{displayReasoning}</div>
            )}
          </div>

          {viewingItem ? (
            <button className={styles.btnBack} onClick={handleBack}>← Back</button>
          ) : hasFile ? (
            <button className={styles.btnClear} onClick={reset}>Clear</button>
          ) : null}
        </div>
      </section>

      <HistoryList
        items={items}
        selectedKey={viewingItem?.key}
        onSelect={handleSelectHistory}
        onDelete={handleDelete}
      />

      <p className={`${styles.footnote} mono`}>proof of concept · v0.1</p>
    </main>
  );
}
