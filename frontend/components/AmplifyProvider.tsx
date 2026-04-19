'use client';

import { useEffect, useState } from 'react';
import { useRouter, usePathname } from 'next/navigation';
import { Amplify } from 'aws-amplify';
import { getCurrentUser } from 'aws-amplify/auth';

Amplify.configure({
  Auth: {
    Cognito: {
      userPoolId: process.env.NEXT_PUBLIC_COGNITO_USER_POOL_ID ?? '',
      userPoolClientId: process.env.NEXT_PUBLIC_COGNITO_CLIENT_ID ?? '',
    },
  },
});

export default function AmplifyProvider({ children }: { children: React.ReactNode }) {
  const router = useRouter();
  const pathname = usePathname();
  const [ready, setReady] = useState(false);

  useEffect(() => {
    getCurrentUser()
      .then(() => {
        if (pathname === '/login' || pathname === '/login/') {
          router.replace('/upload/');
        }
        setReady(true);
      })
      .catch(() => {
        if (pathname !== '/login' && pathname !== '/login/') {
          router.replace('/login/');
        }
        setReady(true);
      });
  }, [pathname, router]);

  if (!ready) return null;
  return <>{children}</>;
}
