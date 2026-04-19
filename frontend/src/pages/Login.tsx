import { useState } from 'react'
import { Typography, TextField, Button, Alert, Box } from '@mui/material'
import { useNavigate } from 'react-router-dom'
import { signIn } from 'aws-amplify/auth'
import { PageLayout } from '../components/PageLayout'
import { useAuth } from '../context/AuthContext'

export default function Login() {
  const navigate = useNavigate()
  const { refresh } = useAuth()
  const [email, setEmail]       = useState('')
  const [password, setPassword] = useState('')
  const [error, setError]       = useState('')
  const [loading, setLoading]   = useState(false)

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    setError('')
    setLoading(true)
    try {
      const { isSignedIn } = await signIn({ username: email, password })
      if (isSignedIn) {
        await refresh()
        navigate('/')
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Sign in failed')
    } finally {
      setLoading(false)
    }
  }

  return (
    <PageLayout>
      <Typography variant="h5" fontWeight={700} gutterBottom>Receipt Classifier</Typography>
      <Typography variant="body2" color="text.secondary" sx={{ mb: 3 }}>Sign in to continue</Typography>

      <Box component="form" onSubmit={handleSubmit}>
        <TextField
          label="Email" type="email" fullWidth required
          value={email} onChange={e => setEmail(e.target.value)}
          sx={{ mb: 2 }}
        />
        <TextField
          label="Password" type="password" fullWidth required
          value={password} onChange={e => setPassword(e.target.value)}
          sx={{ mb: 3 }}
        />
        {error && <Alert severity="error" sx={{ mb: 2 }}>{error}</Alert>}
        <Button type="submit" variant="contained" fullWidth disabled={loading}>
          {loading ? 'Signing in…' : 'Sign In'}
        </Button>
      </Box>
    </PageLayout>
  )
}
