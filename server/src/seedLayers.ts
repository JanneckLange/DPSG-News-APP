export type SeedLayer = {
  name: string;
  url?: string;
  groups?: string[];
};

export const BUNDESVERBAND_NAME = 'Bundesverband DPSG';

export const SEED_DVS: SeedLayer[] = [
  { name: 'Aachen', url: 'http://www.dpsg-ac.de/' },
  { name: 'Augsburg', url: 'http://www.dpsg-augsburg.de/' },
  { name: 'Bamberg', url: 'http://www.dpsg-bamberg.de/' },
  { name: 'Berlin', url: 'http://www.dpsg-dv-berlin.de/' },
  { name: 'Eichstätt', url: 'http://www.dpsg-eichstaett.de/' },
  { name: 'Essen', url: 'http://www.dpsg-essen.de/' },
  { name: 'Erfurt', url: 'https://dpsg-thueringen.de/' },
  { name: 'Freiburg', url: 'http://www.dpsg-freiburg.de/' },
  { name: 'Fulda', url: 'http://www.dpsg-fulda.de/' },
  { name: 'Hamburg', url: 'http://www.dpsg-hamburg.de/', groups: ['Wölflinge', 'Jungpfadfinder', 'Pfadfinder', 'Rover', 'AK Aus-& Weiterbildung'] },
  { name: 'Hildesheim', url: 'http://www.dpsg-hildesheim.de/' },
  { name: 'Köln', url: 'http://www.dpsg-koeln.de/' },
  { name: 'Limburg', url: 'http://www.dpsg-limburg.de/' },
  { name: 'Magdeburg', url: 'http://www.dpsg-dv-magdeburg.de/' },
  { name: 'Mainz', url: 'http://www.dpsg-mainz.de/' },
  { name: 'München-Freising', url: 'http://www.dpsg1300.de/' },
  { name: 'Münster', url: 'https://dpsgmuenster.de/' },
  { name: 'Osnabrück', url: 'https://dpsg-os.de/' },
  { name: 'Paderborn', url: 'http://www.dpsg-paderborn.de/' },
  { name: 'Passau', url: 'http://www.dpsg-passau.de/' },
  { name: 'Regensburg', url: 'http://www.dpsg-regensburg.de/' },
  { name: 'Rottenburg-Stuttgart', url: 'http://www.dpsg-rottenburg.de/' },
  { name: 'Speyer', url: 'http://www.dpsg-speyer.org/' },
  { name: 'Trier', url: 'http://www.dpsg-trier.de/' },
  { name: 'Würzburg', url: 'http://www.dpsg-wuerzburg.de/' },
];
