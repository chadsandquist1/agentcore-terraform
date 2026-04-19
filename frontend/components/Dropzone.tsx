'use client';

import { useRef, useState, useCallback, DragEvent, KeyboardEvent } from 'react';
import styles from './Dropzone.module.css';

interface Props {
  onFile: (file: File) => void;
  isBusy: boolean;
  previewSrc?: string;
}

export default function Dropzone({ onFile, isBusy, previewSrc }: Props) {
  const [isOver, setIsOver] = useState(false);
  const inputRef = useRef<HTMLInputElement>(null);

  const handleFile = useCallback((file: File | null | undefined) => {
    if (!file || !file.type.startsWith('image/')) return;
    onFile(file);
  }, [onFile]);

  const onDragOver = (e: DragEvent) => { e.preventDefault(); setIsOver(true); };
  const onDragLeave = () => setIsOver(false);
  const onDrop = (e: DragEvent) => {
    e.preventDefault();
    setIsOver(false);
    handleFile(e.dataTransfer.files[0]);
  };
  const onClick = () => { if (!isBusy) inputRef.current?.click(); };
  const onKey = (e: KeyboardEvent) => {
    if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); onClick(); }
  };

  const cls = [
    styles.dropzone,
    isOver ? styles.isOver : '',
    isBusy ? styles.isBusy : '',
  ].filter(Boolean).join(' ');

  return (
    <div
      className={cls}
      tabIndex={0}
      role="button"
      aria-label="Drop a receipt image or click to upload"
      onClick={onClick}
      onDragOver={onDragOver}
      onDragLeave={onDragLeave}
      onDrop={onDrop}
      onKeyDown={onKey}
    >
      {!previewSrc && (
        <div className={styles.inner}>
          <div className={styles.placeholder} aria-hidden="true" />
          <p className={styles.label}>
            <b>Drop a receipt</b> here, or <u>click to browse</u>
          </p>
          <p className={`${styles.hint} mono`}>png · jpg · heic — up to 10 mb</p>
        </div>
      )}

      {previewSrc && (
        <div className={styles.preview} aria-hidden="true">
          <img src={previewSrc} alt="" />
        </div>
      )}

      {isBusy && (
        <div className={styles.scanning} aria-hidden="true">
          <span className={styles.scanPill}>
            <span className={styles.dot} />
            Classifying receipt…
          </span>
        </div>
      )}

      <input
        ref={inputRef}
        type="file"
        accept="image/*"
        style={{ display: 'none' }}
        onChange={e => handleFile(e.target.files?.[0])}
      />
    </div>
  );
}
