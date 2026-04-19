export type ColorGroup = 'groceries' | 'dining' | 'transport' | 'utilities' | 'retail' | 'neutral';

export interface Item {
  key: string;
  name: string;
  categories: string[];
  reasoning: string;
  src: string;
  time: string;
}

export interface ApiResult {
  category?: string;
  categories?: string[];
  reasoning?: string;
  confidence?: number;
}

export interface PresignResponse {
  uploadUrl: string;
  key: string;
}
