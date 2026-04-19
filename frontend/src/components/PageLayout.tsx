import { Box } from '@mui/material'
import { ReactNode } from 'react'

export function PageLayout({ children, maxWidth = 480 }: { children: ReactNode; maxWidth?: number }) {
  return (
    <Box sx={{ minHeight: '100vh', display: 'flex', alignItems: 'center', justifyContent: 'center', bgcolor: 'background.default', p: 3 }}>
      <Box sx={{ width: '100%', maxWidth, bgcolor: 'background.paper', borderRadius: 3, p: 4, boxShadow: 1 }}>
        {children}
      </Box>
    </Box>
  )
}
