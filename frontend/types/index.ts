export type ColorGroup = 'groceries' | 'dining' | 'transport' | 'utilities' | 'retail' | 'neutral';

export interface Item {
  key: string;
  name: string;
  categories: string[];
  description: string;
  src: string;
  time: string;
}

export interface ApiResult {
  category?: string;
  categories?: string[];
  description?: string;
  confidence?: number;
}

export interface PresignResponse {
  uploadUrl: string;
  key: string;
}
