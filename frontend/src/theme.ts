import { createTheme } from '@mui/material/styles'

export const theme = createTheme({
  palette: {
    mode: 'light',
    background: {
      default: '#F5F0E8',
      paper: '#FFFFFF',
    },
    primary: {
      main: '#5DDBB4',
      contrastText: '#FFFFFF',
    },
    secondary: {
      main: '#E8C97A',
    },
    text: {
      primary: '#2D2D2D',
      secondary: '#9B9B9B',
    },
  },
  typography: {
    fontFamily: "'Inter', sans-serif",
  },
  components: {
    MuiButton: {
      styleOverrides: {
        root: {
          borderRadius: 24,
          textTransform: 'none',
          fontWeight: 700,
        },
      },
    },
    MuiTextField: {
      defaultProps: {
        variant: 'standard',
      },
    },
  },
})
