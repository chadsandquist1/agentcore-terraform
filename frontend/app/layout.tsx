import type { Metadata } from 'next';
import { Inter, JetBrains_Mono } from 'next/font/google';
import AmplifyProvider from '@/components/AmplifyProvider';
import './globals.css';

const inter = Inter({
  subsets: ['latin'],
  weight: ['400', '500', '600'],
  variable: '--font-inter',
  display: 'swap',
});

const jetbrainsMono = JetBrains_Mono({
  subsets: ['latin'],
  weight: ['400', '500'],
  variable: '--font-mono',
  display: 'swap',
});

export const metadata: Metadata = {
  title: 'Receipt Classification',
  description: 'Classify your receipts with AI',
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className={`${inter.variable} ${jetbrainsMono.variable}`}>
      <body style={{ fontFamily: 'var(--font-inter), -apple-system, BlinkMacSystemFont, sans-serif' }}>
        <AmplifyProvider>{children}</AmplifyProvider>
      </body>
    </html>
  );
}
