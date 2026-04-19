'use client';

import { useState, FormEvent } from 'react';
import { useRouter } from 'next/navigation';
import { signIn } from 'aws-amplify/auth';
import Logo from '@/components/Logo';
import styles from './login.module.css';

export default function LoginPage() {
  const router = useRouter();
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [busy, setBusy] = useState(false);

  async function onSubmit(e: FormEvent) {
    e.preventDefault();
    setBusy(true);
    setError('');
    try {
      await signIn({ username, password });
      router.replace('/upload/');
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Sign in failed');
      setBusy(false);
    }
  }

  return (
    <main className={styles.page}>
      <header className={styles.header}>
        <Logo />
        <h1 className={styles.title}>Receipt Classification</h1>
        <p className={styles.subtitle}>Sign in to continue.</p>
      </header>

      <form className={styles.card} onSubmit={onSubmit}>
        <div className={styles.field}>
          <label className={styles.label} htmlFor="username">Username</label>
          <input
            id="username"
            className={styles.input}
            type="text"
            autoComplete="username"
            value={username}
            onChange={e => setUsername(e.target.value)}
            required
          />
        </div>

        <div className={styles.field}>
          <label className={styles.label} htmlFor="password">Password</label>
          <input
            id="password"
            className={styles.input}
            type="password"
            autoComplete="current-password"
            value={password}
            onChange={e => setPassword(e.target.value)}
            required
          />
        </div>

        {error && <div className={styles.error}>{error}</div>}

        <button className={styles.btn} type="submit" disabled={busy}>
          {busy ? 'Signing in…' : 'Sign in'}
        </button>
      </form>

      <p className={`${styles.footnote} mono`}>proof of concept · v0.1</p>
    </main>
  );
}
