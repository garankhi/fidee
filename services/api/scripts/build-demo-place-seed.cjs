const fs = require('fs');
const path = require('path');

const outputDir = path.join(__dirname, '..', 'seeds');
const chunksDir = path.join(outputDir, 'dynamodb');
const tableName = process.env.MAPVIBE_PLACES_TABLE || 'mapvibe-dev-places';
const chunkSize = 25;

const offsets = [
  { lat: 0.0, lng: 0.0 },
  { lat: 0.00018, lng: -0.00016 },
  { lat: -0.00012, lng: 0.00021 },
  { lat: 0.00025, lng: 0.00014 },
  { lat: -0.00022, lng: -0.00019 },
  { lat: 0.00031, lng: -0.00004 },
  { lat: -0.00035, lng: 0.00008 },
  { lat: 0.00008, lng: 0.00029 },
  { lat: -0.00009, lng: -0.00031 },
  { lat: 0.00027, lng: -0.00027 },
];

const clusters = [
  {
    label: 'Ben Thanh core',
    baseLat: 10.7726,
    baseLng: 106.69885,
    sourceNote:
      'Curated fictional demo place around Ben Thanh core in District 1; manually created for nearby scan density and not copied from third-party listings or licensed place databases.',
    places: [
      { name: 'Lantern Courtyard Pho', category: 'pho', address: '14 Le Loi, Ben Thanh, District 1, Ho Chi Minh City' },
      { name: 'Market Gate Banh Mi', category: 'banh_mi', address: '82 Phan Chu Trinh, Ben Thanh, District 1, Ho Chi Minh City' },
      { name: 'Saffron Saigon Kitchen', category: 'vietnamese', address: '27 Thu Khoa Huan, Ben Thanh, District 1, Ho Chi Minh City' },
      { name: 'Lotus Steam House', category: 'noodle_shop', address: '41 Ly Tu Trong, Ben Thanh, District 1, Ho Chi Minh City' },
      { name: 'Rice Paper Garden', category: 'vietnamese', address: '55 Truong Dinh, Ben Thanh, District 1, Ho Chi Minh City' },
      { name: 'Ben Thanh Brew Lab', category: 'cafe', address: '23 Thu Khoa Huan, Ben Thanh, District 1, Ho Chi Minh City' },
      { name: 'Golden Mortar Dessert Bar', category: 'dessert', address: '39 Phan Chu Trinh, Ben Thanh, District 1, Ho Chi Minh City' },
      { name: 'Tamarind Balcony Grill', category: 'grill', address: '18 Le Anh Xuan, Ben Thanh, District 1, Ho Chi Minh City' },
      { name: 'Morning Drum Tea House', category: 'tea_house', address: '11 Thu Khoa Huan, Ben Thanh, District 1, Ho Chi Minh City' },
      { name: 'Night Market Hotpot', category: 'hotpot', address: '71 Nguyen An Ninh, Ben Thanh, District 1, Ho Chi Minh City' },
    ],
  },
  {
    label: 'Nguyen Hue promenade',
    baseLat: 10.77365,
    baseLng: 106.7031,
    sourceNote:
      'Curated fictional demo place around Nguyen Hue promenade in District 1; manually created for nearby scan density and not copied from third-party listings or licensed place databases.',
    places: [
      { name: 'Riverlight Roastery', category: 'cafe', address: '19 Nguyen Hue, Ben Nghe, District 1, Ho Chi Minh City' },
      { name: 'Orchid Post Brunch', category: 'brunch', address: '26 Nguyen Hue, Ben Nghe, District 1, Ho Chi Minh City' },
      { name: 'Skyline Pomelo Bistro', category: 'rooftop_bar', address: '42 Nguyen Hue, Ben Nghe, District 1, Ho Chi Minh City' },
      { name: 'Mango Canvas Cafe', category: 'cafe', address: '62 Nguyen Hue, Ben Nghe, District 1, Ho Chi Minh City' },
      { name: 'Salt And Lemongrass Table', category: 'vietnamese', address: '18 Mac Thi Buoi, Ben Nghe, District 1, Ho Chi Minh City' },
      { name: 'Pearl Alley Gelato', category: 'dessert', address: '22 Ngo Duc Ke, Ben Nghe, District 1, Ho Chi Minh City' },
      { name: 'Lantern Dock Seafood', category: 'seafood', address: '44 Ton That Thiep, Ben Nghe, District 1, Ho Chi Minh City' },
      { name: 'The Banyan Juice Room', category: 'juice_bar', address: '15 Hai Trieu, Ben Nghe, District 1, Ho Chi Minh City' },
      { name: 'Promenade Bun Bowl', category: 'noodle_shop', address: '33 Nguyen Thiep, Ben Nghe, District 1, Ho Chi Minh City' },
      { name: 'Moonbridge Oyster Bar', category: 'seafood', address: '12 Ho Huan Nghiep, Ben Nghe, District 1, Ho Chi Minh City' },
    ],
  },
  {
    label: 'Dong Khoi corridor',
    baseLat: 10.77825,
    baseLng: 106.70335,
    sourceNote:
      'Curated fictional demo place around the Dong Khoi corridor in District 1; manually created for nearby scan density and not copied from third-party listings or licensed place databases.',
    places: [
      { name: 'Jasmine Opera Cafe', category: 'cafe', address: '8 Dong Khoi, Ben Nghe, District 1, Ho Chi Minh City' },
      { name: 'Indigo Balcony Dining', category: 'vietnamese', address: '21 Dong Khoi, Ben Nghe, District 1, Ho Chi Minh City' },
      { name: 'Silk Route Supper Club', category: 'rooftop_bar', address: '36 Dong Khoi, Ben Nghe, District 1, Ho Chi Minh City' },
      { name: 'Saigon Studio Bakery', category: 'bakery', address: '14 Dong Du, Ben Nghe, District 1, Ho Chi Minh City' },
      { name: 'Citrus Chamber Brunch', category: 'brunch', address: '27 Mac Thi Buoi, Ben Nghe, District 1, Ho Chi Minh City' },
      { name: 'Alley Pearl Noodles', category: 'noodle_shop', address: '17 Dong Du, Ben Nghe, District 1, Ho Chi Minh City' },
      { name: 'Whispering Fig Tea Room', category: 'tea_house', address: '45 Hai Ba Trung, Ben Nghe, District 1, Ho Chi Minh City' },
      { name: 'Ember Terrace Grill', category: 'grill', address: '31 Thi Sach, Ben Nghe, District 1, Ho Chi Minh City' },
      { name: 'Green Tile Vegetarian', category: 'vegetarian', address: '29 Dong Khoi, Ben Nghe, District 1, Ho Chi Minh City' },
      { name: 'Velvet Cocoa House', category: 'dessert', address: '6 Cong Truong Lam Son, Ben Nghe, District 1, Ho Chi Minh City' },
    ],
  },
  {
    label: 'Ton That Dam and Ho Tung Mau',
    baseLat: 10.77095,
    baseLng: 106.70105,
    sourceNote:
      'Curated fictional demo place around Ton That Dam and Ho Tung Mau in District 1; manually created for nearby scan density and not copied from third-party listings or licensed place databases.',
    places: [
      { name: 'Vault Door Coffee', category: 'cafe', address: '24 Ton That Dam, Nguyen Thai Binh, District 1, Ho Chi Minh City' },
      { name: 'Pepper Wharf Kitchen', category: 'vietnamese', address: '38 Ho Tung Mau, Ben Nghe, District 1, Ho Chi Minh City' },
      { name: 'Saigon Ledger Pho', category: 'pho', address: '12 Ho Tung Mau, Ben Nghe, District 1, Ho Chi Minh City' },
      { name: 'Tamarind Spice Corner', category: 'banh_mi', address: '71 Nguyen Cong Tru, Nguyen Thai Binh, District 1, Ho Chi Minh City' },
      { name: 'Brass Filter Roasters', category: 'cafe', address: '16 Nguyen Thai Binh, Nguyen Thai Binh, District 1, Ho Chi Minh City' },
      { name: 'Palm Sugar Dessert House', category: 'dessert', address: '48 Ton That Dam, Nguyen Thai Binh, District 1, Ho Chi Minh City' },
      { name: 'Harborline Seafood Pot', category: 'seafood', address: '29 Nguyen Cong Tru, Nguyen Thai Binh, District 1, Ho Chi Minh City' },
      { name: 'Market Bell Tea House', category: 'tea_house', address: '65 Ho Tung Mau, Ben Nghe, District 1, Ho Chi Minh City' },
      { name: 'Ledger Lane Vegetarian', category: 'vegetarian', address: '22 Pho Duc Chinh, Nguyen Thai Binh, District 1, Ho Chi Minh City' },
      { name: 'Night Shift Hotpot', category: 'hotpot', address: '54 Calmette, Nguyen Thai Binh, District 1, Ho Chi Minh City' },
    ],
  },
  {
    label: 'Pasteur and Nam Ky Khoi Nghia',
    baseLat: 10.78005,
    baseLng: 106.69995,
    sourceNote:
      'Curated fictional demo place around Pasteur and Nam Ky Khoi Nghia in District 1; manually created for nearby scan density and not copied from third-party listings or licensed place databases.',
    places: [
      { name: 'Saigon Atelier Cafe', category: 'cafe', address: '42 Pasteur, Ben Nghe, District 1, Ho Chi Minh City' },
      { name: 'Colonial Garden Kitchen', category: 'vietnamese', address: '55 Pasteur, Ben Nghe, District 1, Ho Chi Minh City' },
      { name: 'Little Basil Pho Club', category: 'pho', address: '27 Nguyen Du, Ben Nghe, District 1, Ho Chi Minh City' },
      { name: 'Orchard Brick Bakery', category: 'bakery', address: '9 Alexandre De Rhodes, Ben Nghe, District 1, Ho Chi Minh City' },
      { name: 'Silk Blossom Brunch', category: 'brunch', address: '61 Nam Ky Khoi Nghia, Ben Nghe, District 1, Ho Chi Minh City' },
      { name: 'Rooftop Lime Social', category: 'rooftop_bar', address: '88 Pasteur, Ben Nghe, District 1, Ho Chi Minh City' },
      { name: 'Ginger Alley Dumpling Bar', category: 'noodle_shop', address: '14 Han Thuyen, Ben Nghe, District 1, Ho Chi Minh City' },
      { name: 'Matcha Courtyard Tea', category: 'tea_house', address: '31 Alexandre De Rhodes, Ben Nghe, District 1, Ho Chi Minh City' },
      { name: 'Cacao Mint Dessert Lab', category: 'dessert', address: '73 Nam Ky Khoi Nghia, Ben Nghe, District 1, Ho Chi Minh City' },
      { name: 'Quiet Leaf Vegetarian', category: 'vegetarian', address: '44 Han Thuyen, Ben Nghe, District 1, Ho Chi Minh City' },
    ],
  },
  {
    label: 'Bui Vien and De Tham',
    baseLat: 10.76845,
    baseLng: 106.69565,
    sourceNote:
      'Curated fictional demo place around Bui Vien and De Tham in District 1; manually created for nearby scan density and not copied from third-party listings or licensed place databases.',
    places: [
      { name: 'Alley Beat Coffee', category: 'cafe', address: '17 De Tham, Pham Ngu Lao, District 1, Ho Chi Minh City' },
      { name: 'Backpacker Bun Cha House', category: 'vietnamese', address: '40 De Tham, Pham Ngu Lao, District 1, Ho Chi Minh City' },
      { name: 'Sunset Brick Oven', category: 'bakery', address: '28 Bui Vien, Pham Ngu Lao, District 1, Ho Chi Minh City' },
      { name: 'Night Owl Grill Yard', category: 'grill', address: '53 Bui Vien, Pham Ngu Lao, District 1, Ho Chi Minh City' },
      { name: 'Lemongrass Corner Pho', category: 'pho', address: '11 Do Quang Dau, Pham Ngu Lao, District 1, Ho Chi Minh City' },
      { name: 'Mango Alley Juice Bar', category: 'juice_bar', address: '37 Do Quang Dau, Pham Ngu Lao, District 1, Ho Chi Minh City' },
      { name: 'Paper Lantern Dessert Club', category: 'dessert', address: '16 Bui Vien, Pham Ngu Lao, District 1, Ho Chi Minh City' },
      { name: 'Hidden Courtyard Seafood', category: 'seafood', address: '24 Pham Ngu Lao, Pham Ngu Lao, District 1, Ho Chi Minh City' },
      { name: 'Calm Lotus Vegetarian', category: 'vegetarian', address: '8 Do Quang Dau, Pham Ngu Lao, District 1, Ho Chi Minh City' },
      { name: 'Rooftop Echo Bar And Kitchen', category: 'rooftop_bar', address: '65 De Tham, Pham Ngu Lao, District 1, Ho Chi Minh City' },
    ],
  },
];

function roundCoord(value) {
  return Number(value.toFixed(6));
}

function slugify(value) {
  return value
    .normalize('NFKD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .replace(/-{2,}/g, '-');
}

function toDynamoItem(place) {
  return {
    PutRequest: {
      Item: {
        PK: { S: `PLACE#${place.id}` },
        SK: { S: `PLACE#${place.id}` },
        GSI1PK: { S: 'PLACE' },
        GSI1SK: { S: `NAME#${place.normalizedName}#${place.id}` },
        entityType: { S: 'PLACE' },
        status: { S: 'PUBLISHED' },
        id: { S: place.id },
        name: { S: place.name },
        normalizedName: { S: place.normalizedName },
        category: { S: place.category },
        lat: { N: place.lat.toFixed(6) },
        lng: { N: place.lng.toFixed(6) },
        address: { S: place.address },
        sourceNote: { S: place.sourceNote },
      },
    },
  };
}

function ensureDirectories() {
  fs.mkdirSync(outputDir, { recursive: true });
  fs.mkdirSync(chunksDir, { recursive: true });
}

function buildPlaces() {
  const places = [];
  let index = 1;

  for (const cluster of clusters) {
    cluster.places.forEach((place, clusterIndex) => {
      const offset = offsets[clusterIndex % offsets.length];
      const id = `demo-d1-${String(index).padStart(3, '0')}`;

      places.push({
        id,
        name: place.name,
        normalizedName: slugify(place.name),
        category: place.category,
        lat: roundCoord(cluster.baseLat + offset.lat),
        lng: roundCoord(cluster.baseLng + offset.lng),
        address: place.address,
        sourceNote: cluster.sourceNote,
      });

      index += 1;
    });
  }

  if (places.length < 50 || places.length > 100) {
    throw new Error(`Expected 50-100 places, received ${places.length}.`);
  }

  return places;
}

function chunk(array, size) {
  const chunks = [];
  for (let index = 0; index < array.length; index += size) {
    chunks.push(array.slice(index, index + size));
  }
  return chunks;
}

function writeOutputs(places) {
  fs.writeFileSync(
    path.join(outputDir, 'demo-district-1-core.places.json'),
    `${JSON.stringify(places, null, 2)}\n`,
  );

  const batches = chunk(places.map(toDynamoItem), chunkSize);

  batches.forEach((batch, batchIndex) => {
    const payload = { [tableName]: batch };
    const fileName = `demo-district-1-core.batch-${String(batchIndex + 1).padStart(2, '0')}.json`;
    fs.writeFileSync(path.join(chunksDir, fileName), `${JSON.stringify(payload, null, 2)}\n`);
  });
}

ensureDirectories();
const places = buildPlaces();
writeOutputs(places);

process.stdout.write(
  `Generated ${places.length} demo places and ${Math.ceil(places.length / chunkSize)} DynamoDB batch files for ${tableName}.\n`,
);
