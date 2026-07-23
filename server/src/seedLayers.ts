export type SeedLayer = {
  name: string;
  groups?: string[];
};

export const BUNDESVERBAND_NAME = 'Bundesverband DPSG';

export const SEED_DVS: SeedLayer[] = [
  { name: 'Aachen' },
  { name: 'Augsburg' },
  { name: 'Bamberg' },
  { name: 'Berlin' },
  { name: 'Eichstätt' },
  { name: 'Essen' },
  { name: 'Erfurt' },
  { name: 'Freiburg' },
  { name: 'Fulda' },
  { name: 'Hamburg', groups: ['Wölflinge', 'Jungpfadfinder', 'Pfadfinder', 'Rover', 'AK Aus-& Weiterbildung'] },
  { name: 'Hildesheim' },
  { name: 'Köln' },
  { name: 'Limburg' },
  { name: 'Magdeburg' },
  { name: 'Mainz' },
  { name: 'München-Freising' },
  { name: 'Münster' },
  { name: 'Osnabrück' },
  { name: 'Paderborn' },
  { name: 'Passau' },
  { name: 'Regensburg' },
  { name: 'Rottenburg-Stuttgart' },
  { name: 'Speyer' },
  { name: 'Trier' },
  { name: 'Würzburg' },
];
