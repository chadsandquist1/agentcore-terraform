import { Navigate } from 'react-router-dom'
import { Box, CircularProgress } from '@mui/material'
import { ReactNode } from 'react'
import { useAuth } from '../context/AuthContext'

export function PrivateRoute({ children }: { children: ReactNode }) {
  const { user, loading } = useAuth()

  if (loading) {
    return (
      <Box sx={{ minHeight: '100vh', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
        <CircularProgress color="primary" />
      </Box>
    )
  }

  return user ? <>{children}</> : <Navigate to="/login" replace />
}
