const { Client } = require('pg');

const connectionString = 'postgresql://postgres:Jd%409746521953@db.iahwyfbkdmppgmbhteyt.supabase.co:5432/postgres';

async function runUpdate() {
  const client = new Client({ connectionString });
  try {
    await client.connect();
    console.log('Connected to Supabase PostgreSQL...');

    await client.query(`
      ALTER TABLE public.chat_messages 
      ADD COLUMN IF NOT EXISTS receiver_id UUID REFERENCES auth.users(id) ON DELETE CASCADE;
      
      NOTIFY pgrst, 'reload schema';
    `);
    console.log('Successfully added receiver_id column and reloaded schema cache!');
  } catch (error) {
    console.error('Update failed:', error);
  } finally {
    await client.end();
  }
}

runUpdate();
