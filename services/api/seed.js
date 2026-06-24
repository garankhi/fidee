const { Client } = require('pg'); 
const client = new Client({ 
  host: 'localhost', 
  port: 5432, 
  database: 'fidee', 
  user: 'postgres', 
  password: 'k6r,-BPma=8fMDvkhN9Fn^Z2fnhsHq' 
}); 
client.connect().then(() => { 
  const sql = `
INSERT INTO friendships (user_id, friend_id, status, initiated_by, accepted_at) VALUES 
('696a35fc-50e1-7069-67c5-70ace3fcf12e', 'test-user-001', 'ACCEPTED', '696a35fc-50e1-7069-67c5-70ace3fcf12e', NOW()),
('test-user-001', '696a35fc-50e1-7069-67c5-70ace3fcf12e', 'ACCEPTED', '696a35fc-50e1-7069-67c5-70ace3fcf12e', NOW()),
('696a35fc-50e1-7069-67c5-70ace3fcf12e', 'test-user-002', 'ACCEPTED', '696a35fc-50e1-7069-67c5-70ace3fcf12e', NOW()),
('test-user-002', '696a35fc-50e1-7069-67c5-70ace3fcf12e', 'ACCEPTED', '696a35fc-50e1-7069-67c5-70ace3fcf12e', NOW())
ON CONFLICT DO NOTHING;

INSERT INTO check_ins (user_id, place_id, media_id, gps_lat, gps_lng, gps_accuracy, caption, rating, visibility) VALUES
('696a35fc-50e1-7069-67c5-70ace3fcf12e', 'a1000001-0001-0001-0001-000000000002', 'mock_checkin_photo_testapi_001', 10.7718, 106.7045, 5, 'My first checkin', 5, 'FRIENDS')
ON CONFLICT DO NOTHING;
`;
  return client.query(sql);
}).then(() => { 
  console.log('Done!'); 
  client.end() 
}).catch(console.error);
