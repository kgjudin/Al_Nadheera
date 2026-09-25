const { Client } = require('pg');
const fs = require('fs');

const connectionString = 'postgresql://postgres:Jd%409746521953@db.iahwyfbkdmppgmbhteyt.supabase.co:5432/postgres';

async function runMigration() {
  const client = new Client({ connectionString });
  try {
    await client.connect();
    console.log('Connected to Supabase PostgreSQL');
    
    const sql = fs.readFileSync('./database_schema.sql', 'utf8');
    await client.query(sql);
    console.log('Migration executed successfully!');
  } catch (error) {
    console.error('Migration failed:', error);
  } finally {
    await client.end();
  }
}

runMigration();
