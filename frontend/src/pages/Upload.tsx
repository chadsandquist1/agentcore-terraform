import { useState, useRef } from 'react'
import {
  Typography, Button, Box, Alert, CircularProgress,
  Chip, Divider, IconButton,
} from '@mui/material'
import LogoutIcon from '@mui/icons-material/Logout'
import UploadFileIcon from '@mui/icons-material/UploadFile'
import { PageLayout } from '../components/PageLayout'
import { useAuth } from '../context/AuthContext'

const API_URL = import.meta.env.VITE_API_URL as string

interface Result {
  categories: string[]
  reasoning: string
  source_key: string
  timestamp: string
}

type Status = 'idle' | 'uploading' | 'processing' | 'done' | 'error'

export default function Upload() {
  const { user, signOut, getToken } = useAuth()
  const fileRef = useRef<HTMLInputElement>(null)
  const [status, setStatus]     = useState<Status>('idle')
  const [result, setResult]     = useState<Result | null>(null)
  const [errorMsg, setErrorMsg] = useState('')
  const [filename, setFilename] = useState('')

  async function handleFile(file: File) {
    if (!file.type.match(/image\/jpe?g/i) && !file.name.toLowerCase().endsWith('.jpg')) {
      setErrorMsg('Please select a JPG image.')
      setStatus('error')
      return
    }

    setStatus('uploading')
    setResult(null)
    setErrorMsg('')
    setFilename(file.name)

    try {
      const token = await getToken()

      // Get presigned URL
      const presignRes = await fetch(`${API_URL}/presign`, {
        method: 'POST',
        headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({ filename: file.name }),
      })
      if (!presignRes.ok) throw new Error('Failed to get upload URL')
      const { upload_url, key } = await presignRes.json() as { upload_url: string; key: string }

      // Upload directly to S3
      const uploadRes = await fetch(upload_url, {
        method: 'PUT',
        body: file,
        headers: { 'Content-Type': 'image/jpeg' },
      })
      if (!uploadRes.ok) throw new Error('Upload failed')

      // Poll for results
      setStatus('processing')
      const basename = key.split('/').pop() ?? file.name

      for (let attempts = 0; attempts < 40; attempts++) {
        await new Promise(r => setTimeout(r, 3000))
        const pollRes = await fetch(`${API_URL}/results/${encodeURIComponent(basename)}`, {
          headers: { Authorization: `Bearer ${token}` },
        })
        if (!pollRes.ok) throw new Error('Failed to fetch result')
        const data = await pollRes.json() as { status: string } & Result
        if (data.status === 'complete') {
          setResult(data)
          setStatus('done')
          return
        }
      }
      throw new Error('Timed out waiting for classification result')
    } catch (err) {
      setErrorMsg(err instanceof Error ? err.message : 'Something went wrong')
      setStatus('error')
    }
  }

  function handleDrop(e: React.DragEvent) {
    e.preventDefault()
    const file = e.dataTransfer.files[0]
    if (file) handleFile(file)
  }

  return (
    <PageLayout maxWidth={560}>
      <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 3 }}>
        <Typography variant="h5" fontWeight={700}>Receipt Classifier</Typography>
        <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
          <Typography variant="body2" color="text.secondary">{user?.email}</Typography>
          <IconButton size="small" onClick={signOut} title="Sign out">
            <LogoutIcon fontSize="small" />
          </IconButton>
        </Box>
      </Box>

      {/* Drop zone */}
      <Box
        onDrop={handleDrop}
        onDragOver={e => e.preventDefault()}
        onClick={() => fileRef.current?.click()}
        sx={{
          border: '2px dashed',
          borderColor: 'primary.main',
          borderRadius: 2,
          p: 4,
          textAlign: 'center',
          cursor: 'pointer',
          mb: 3,
          '&:hover': { bgcolor: 'action.hover' },
        }}
      >
        <UploadFileIcon sx={{ fontSize: 40, color: 'primary.main', mb: 1 }} />
        <Typography variant="body1" fontWeight={600}>Drop a JPG receipt here</Typography>
        <Typography variant="body2" color="text.secondary">or click to browse</Typography>
        <input
          ref={fileRef}
          type="file"
          accept="image/jpeg,.jpg"
          hidden
          onChange={e => { const f = e.target.files?.[0]; if (f) handleFile(f) }}
        />
      </Box>

      {/* Status */}
      {status === 'uploading' && (
        <Box sx={{ display: 'flex', alignItems: 'center', gap: 2 }}>
          <CircularProgress size={20} />
          <Typography variant="body2">Uploading {filename}…</Typography>
        </Box>
      )}

      {status === 'processing' && (
        <Box sx={{ display: 'flex', alignItems: 'center', gap: 2 }}>
          <CircularProgress size={20} />
          <Typography variant="body2">Classifying receipt…</Typography>
        </Box>
      )}

      {status === 'error' && (
        <Alert severity="error">{errorMsg}</Alert>
      )}

      {/* Result */}
      {status === 'done' && result && (
        <Box>
          <Divider sx={{ mb: 2 }} />
          <Typography variant="subtitle2" color="text.secondary" gutterBottom>Categories</Typography>
          <Box sx={{ display: 'flex', flexWrap: 'wrap', gap: 1, mb: 2 }}>
            {result.categories.map(cat => (
              <Chip key={cat} label={cat} color="primary" />
            ))}
          </Box>
          <Typography variant="subtitle2" color="text.secondary" gutterBottom>Reasoning</Typography>
          <Typography variant="body2">{result.reasoning}</Typography>
          <Button
            variant="outlined" size="small" sx={{ mt: 3 }}
            onClick={() => { setStatus('idle'); setResult(null) }}
          >
            Classify another
          </Button>
        </Box>
      )}
    </PageLayout>
  )
}
