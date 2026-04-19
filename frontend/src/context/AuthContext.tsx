import { createContext, useContext, useEffect, useState, useCallback, ReactNode } from 'react'
import { getCurrentUser, fetchAuthSession, signOut as amplifySignOut } from 'aws-amplify/auth'

interface AuthUser {
  userId: string
  email: string
}

interface AuthContextType {
  user: AuthUser | null
  loading: boolean
  refresh: () => Promise<void>
  signOut: () => Promise<void>
  getToken: () => Promise<string>
}

const AuthContext = createContext<AuthContextType | null>(null)

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<AuthUser | null>(null)
  const [loading, setLoading] = useState(true)

  const refresh = useCallback(async () => {
    try {
      const { userId } = await getCurrentUser()
      const session = await fetchAuthSession()
      const payload = session.tokens?.idToken?.payload
      setUser({ userId, email: (payload?.email as string) ?? '' })
    } catch {
      setUser(null)
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => { refresh() }, [refresh])

  const signOut = async () => {
    await amplifySignOut()
    setUser(null)
  }

  const getToken = async (): Promise<string> => {
    const session = await fetchAuthSession()
    return session.tokens?.idToken?.toString() ?? ''
  }

  return (
    <AuthContext.Provider value={{ user, loading, refresh, signOut, getToken }}>
      {children}
    </AuthContext.Provider>
  )
}

export function useAuth() {
  const ctx = useContext(AuthContext)
  if (!ctx) throw new Error('useAuth must be used within AuthProvider')
  return ctx
}
