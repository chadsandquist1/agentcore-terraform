export default function Logo() {
  return (
    <div
      style={{
        width: 56, height: 56,
        borderRadius: '50%',
        background: '#fff',
        border: '1px solid var(--line)',
        display: 'grid', placeItems: 'center',
        boxShadow: '0 1px 2px rgba(20,20,20,0.03), 0 6px 20px -12px rgba(20,20,20,0.12)',
        flexShrink: 0,
      }}
      aria-hidden="true"
    >
      <svg width="26" height="26" viewBox="0 0 26 26" fill="none">
        <rect x="6.5" y="3.5" width="13" height="19" rx="1.5"
          stroke="oklch(0.22 0.01 80)" strokeWidth="1.4" fill="#fff" />
        <line x1="9" y1="9" x2="17" y2="9"
          stroke="oklch(0.22 0.01 80)" strokeWidth="1.4" strokeLinecap="round" />
        <line x1="9" y1="12.5" x2="17" y2="12.5"
          stroke="oklch(0.45 0.01 80)" strokeWidth="1.4" strokeLinecap="round" />
        <line x1="9" y1="16" x2="14" y2="16"
          stroke="oklch(0.45 0.01 80)" strokeWidth="1.4" strokeLinecap="round" />
        <path
          d="M6.5 22.5 L8.5 21 L10.5 22.5 L12.5 21 L14.5 22.5 L16.5 21 L18.5 22.5 L19.5 22.5"
          stroke="oklch(0.22 0.01 80)" strokeWidth="1.4" strokeLinejoin="round" fill="none"
        />
      </svg>
    </div>
  );
}
