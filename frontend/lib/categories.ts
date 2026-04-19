import type { ColorGroup } from '@/types';

const MAP: Record<string, ColorGroup> = {
  'Groceries':              'groceries',
  'Restaurant':             'groceries',
  'Fast Food':              'groceries',
  'Coffee & Cafe':          'groceries',
  'Health & Pharmacy':      'groceries',
  'Fitness & Sports':       'groceries',
  'Pet Supplies':           'groceries',
  'Childcare & Education':  'groceries',

  'Alcohol & Bar':          'dining',
  'Entertainment':          'dining',
  'Gifts & Flowers':        'dining',

  'Auto & Gas':             'transport',
  'Travel & Lodging':       'transport',
  'Utilities & Subscriptions': 'transport',

  'Electronics':            'utilities',
  'Home & Hardware':        'utilities',
  'Furniture & Appliances': 'utilities',
  'Office & Stationery':    'utilities',

  'Clothing & Apparel':     'retail',
  'Shoes & Footwear':       'retail',
  'Beauty & Personal Care': 'retail',
  'Charity & Donations':    'retail',

  'Not able to classify':   'neutral',
  'Not Receipt':            'neutral',
};

export function colorGroup(category: string): ColorGroup {
  return MAP[category] ?? 'neutral';
}
