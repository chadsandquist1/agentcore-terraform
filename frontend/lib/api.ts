import { fetchAuthSession } from 'aws-amplify/auth';
import type { ApiResult, PresignResponse } from '@/types';

async function authHeaders(): Promise<Record<string, string>> {
  const session = await fetchAuthSession();
  const token = session.tokens?.idToken?.toString();
  return token ? { Authorization: `Bearer ${token}` } : {};
}

const API = process.env.NEXT_PUBLIC_API_URL ?? '';

export async function presign(filename: string): Promise<PresignResponse> {
  const headers = await authHeaders();
  const res = await fetch(`${API}/presign`, {
    method: 'POST',
    headers: { ...headers, 'Content-Type': 'application/json' },
    body: JSON.stringify({ filename }),
  });
  if (!res.ok) throw new Error(`presign failed: ${res.status}`);
  return res.json() as Promise<PresignResponse>;
}

export async function uploadFile(uploadUrl: string, file: File): Promise<void> {
  const res = await fetch(uploadUrl, {
    method: 'PUT',
    headers: { 'Content-Type': file.type || 'image/jpeg' },
    body: file,
  });
  if (!res.ok) throw new Error(`upload failed: ${res.status}`);
}

export async function pollResult(key: string, timeoutMs = 60_000): Promise<ApiResult> {
  const headers = await authHeaders();
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    await new Promise(r => setTimeout(r, 3_000));
    const res = await fetch(`${API}/results/${encodeURIComponent(key)}`, { headers });
    if (res.status === 404) continue;
    if (!res.ok) throw new Error(`poll failed: ${res.status}`);
    return res.json() as Promise<ApiResult>;
  }
  throw new Error('classification timed out');
}
